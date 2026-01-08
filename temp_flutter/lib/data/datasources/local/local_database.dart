import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Local SQLite database singleton
/// 
/// Handles database initialization, schema creation, and access
/// Used for offline-first persistence
class LocalDatabase {
  static const String _databaseName = 'baby_sleep.db';
  static const int _databaseVersion = 2;

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
    await db.execute('''
      CREATE TABLE babies (
        id TEXT PRIMARY KEY NOT NULL,
        name TEXT NOT NULL,
        created_at TEXT NOT NULL,
        created_by TEXT NOT NULL,
        birth_date TEXT,
        updated_at TEXT NOT NULL
      )
    ''');

    // Create caregivers table
    await db.execute('''
      CREATE TABLE caregivers (
        id TEXT PRIMARY KEY NOT NULL,
        baby_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        role TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        invited_by TEXT,
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

    // Create sync_state table for tracking last synced timestamp per baby
    await db.execute('''
      CREATE TABLE sync_state (
        baby_id TEXT PRIMARY KEY NOT NULL,
        last_synced_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (baby_id) REFERENCES babies (id)
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_sync_state_baby_id ON sync_state (baby_id)
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
