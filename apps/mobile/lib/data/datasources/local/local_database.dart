import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Local SQLite database singleton
/// 
/// Handles database initialization, schema creation, and access
/// Used for offline-first persistence
class LocalDatabase {
  static const String _databaseName = 'baby_sleep.db';
  static const int _databaseVersion = 5;

  // Singleton instance
  static LocalDatabase? _instance;
  static Database? _database;

  LocalDatabase._internal();

  /// Gets the singleton instance
  static LocalDatabase get instance {
    _instance ??= LocalDatabase._internal();
    return _instance!;
  }

  /// Gets the database, initializing if needed
  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  /// Initializes the database
  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Creates database schema (version 1)
  Future<void> _onCreate(Database db, int version) async {
    // Create babies table
    // synced_at: NULL = never synced (local only), set = pushed to Supabase
    await db.execute('''
      CREATE TABLE babies (
        id TEXT PRIMARY KEY NOT NULL,
        name TEXT NOT NULL,
        created_at TEXT NOT NULL,
        created_by TEXT NOT NULL,
        birth_date TEXT,
        updated_at TEXT NOT NULL,
        synced_at TEXT
      )
    ''');

    // Create caregivers table
    // synced_at: NULL = never synced (local only), set = pushed to Supabase
    await db.execute('''
      CREATE TABLE caregivers (
        id TEXT PRIMARY KEY NOT NULL,
        baby_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        role TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        invited_by TEXT,
        synced_at TEXT,
        FOREIGN KEY (baby_id) REFERENCES babies (id)
      )
    ''');

    // Create sleep_events table
    await db.execute('''
      CREATE TABLE sleep_events (
        id TEXT PRIMARY KEY NOT NULL,
        baby_id TEXT NOT NULL,
        type TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        caregiver_id TEXT NOT NULL,
        device_id TEXT NOT NULL,
        created_at TEXT NOT NULL,
        is_corrected INTEGER NOT NULL DEFAULT 0,
        synced_at TEXT,
        corrected_by TEXT,
        metadata TEXT,
        FOREIGN KEY (baby_id) REFERENCES babies (id),
        FOREIGN KEY (caregiver_id) REFERENCES caregivers (id)
      )
    ''');

    // Create indexes for common queries
    await db.execute('''
      CREATE INDEX idx_sleep_events_baby_id ON sleep_events (baby_id)
    ''');

    await db.execute('''
      CREATE INDEX idx_sleep_events_timeline ON sleep_events (baby_id, timestamp DESC, created_at DESC)
    ''');

    await db.execute('''
      CREATE INDEX idx_sleep_events_unsynced ON sleep_events (baby_id, synced_at) WHERE synced_at IS NULL
    ''');

    await db.execute('''
      CREATE INDEX idx_caregivers_baby_id ON caregivers (baby_id)
    ''');

    await db.execute('''
      CREATE INDEX idx_caregivers_user_id ON caregivers (user_id)
    ''');

    // Index for unsynced babies (layered sync)
    await db.execute('''
      CREATE INDEX idx_babies_unsynced ON babies (synced_at) WHERE synced_at IS NULL
    ''');

    // Index for unsynced caregivers (layered sync)
    await db.execute('''
      CREATE INDEX idx_caregivers_unsynced ON caregivers (synced_at) WHERE synced_at IS NULL
    ''');

    // Create sync_state table for tracking last synced cursor per baby
    // Uses composite cursor (last_synced_at, last_synced_id) for reliable incremental pull
    await db.execute('''
      CREATE TABLE sync_state (
        baby_id TEXT PRIMARY KEY NOT NULL,
        last_synced_at TEXT NOT NULL,
        last_synced_id TEXT,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (baby_id) REFERENCES babies (id)
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_sync_state_baby_id ON sync_state (baby_id)
    ''');

    // Create sync queue table for tracking pending sync operations
    // Supports both INSERT (new events) and UPDATE (normalization corrections)
    await db.execute('''
      CREATE TABLE sleep_event_sync_queue (
        event_id TEXT PRIMARY KEY NOT NULL,
        action TEXT NOT NULL,
        enqueued_at TEXT NOT NULL,
        FOREIGN KEY (event_id) REFERENCES sleep_events (id)
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_sync_queue_action ON sleep_event_sync_queue (action, enqueued_at)
    ''');
  }

  /// Handles database upgrades (future migrations)
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Migration to version 2: Add sync_state table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS sync_state (
          baby_id TEXT PRIMARY KEY NOT NULL,
          last_synced_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          FOREIGN KEY (baby_id) REFERENCES babies (id)
        )
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_sync_state_baby_id ON sync_state (baby_id)
      ''');
    }

    if (oldVersion < 3) {
      // Migration to version 3: Add synced_at to babies and caregivers
      // 
      // WHY: Enable layered sync (Baby → Caregiver → SleepEvent)
      // Without synced_at tracking, we can't know if Baby/Caregiver
      // exists remotely, causing push failures on dependent SleepEvents.
      // 
      // NULL = never synced (local only)
      // ISO8601 = pushed to Supabase at that time
      
      await db.execute('ALTER TABLE babies ADD COLUMN synced_at TEXT');
      await db.execute('ALTER TABLE caregivers ADD COLUMN synced_at TEXT');

      // Create indexes for efficient unsynced queries
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_babies_unsynced ON babies (synced_at) WHERE synced_at IS NULL
      ''');
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_caregivers_unsynced ON caregivers (synced_at) WHERE synced_at IS NULL
      ''');
    }

    if (oldVersion < 4) {
      // Migration to version 4: Add last_synced_id to sync_state
      // 
      // WHY: Enable composite cursor (synced_at, id) for reliable incremental pull
      // Using synced_at alone can miss events when multiple events have same synced_at
      // The composite cursor (synced_at, id) with server-generated synced_at eliminates:
      // - Clock skew issues (synced_at is server-time, not client-time)
      // - Duplicate/missed events (id provides tie-breaker)
      
      await db.execute('ALTER TABLE sync_state ADD COLUMN last_synced_id TEXT');
    }

    if (oldVersion < 5) {
      // Migration to version 5: Add sync queue table
      // 
      // WHY: Support both INSERT and UPDATE operations for sync
      // - INSERT: new events created locally
      // - UPDATE: events corrected by normalizer
      // This enables the normalizer to mark events for remote sync

      await db.execute('''
        CREATE TABLE IF NOT EXISTS sleep_event_sync_queue (
          event_id TEXT PRIMARY KEY NOT NULL,
          action TEXT NOT NULL,
          enqueued_at TEXT NOT NULL,
          FOREIGN KEY (event_id) REFERENCES sleep_events (id)
        )
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_sync_queue_action ON sleep_event_sync_queue (action, enqueued_at)
      ''');
    }
  }

  /// Closes the database
  Future<void> close() async {
    final db = _database;
    if (db != null && db.isOpen) {
      await db.close();
      _database = null;
    }
  }

  /// Clears all data (for testing/reset)
  Future<void> clear() async {
    final db = await database;
    await db.delete('sleep_events');
    await db.delete('caregivers');
    await db.delete('babies');
  }

  /// Resets the database (drops and recreates)
  Future<void> reset() async {
    await close();
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, _databaseName);
    await deleteDatabase(path);
    _database = await _initDatabase();
  }
}
