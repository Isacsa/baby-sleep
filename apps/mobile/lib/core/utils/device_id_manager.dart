import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Manages device ID for events
/// 
/// Device ID is a free-form string used for auditing
/// Backend does not validate format or uniqueness
/// This manager ensures consistent device identification
class DeviceIdManager {
  DeviceIdManager._();

  static const String _deviceIdKey = 'device_id';
  static const _uuid = Uuid();
  static String? _cachedDeviceId;

  /// Gets or creates device ID
  /// 
  /// Device ID is persisted locally and reused across app sessions
  /// Format: UUID v4 (but can be any string)
  static Future<String> getDeviceId() async {
    // Return cached value if available
    if (_cachedDeviceId != null) {
      return _cachedDeviceId!;
    }

    // Try to get from local storage
    final db = await _getSettingsDatabase();
    final result = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [_deviceIdKey],
      limit: 1,
    );

    if (result.isNotEmpty) {
      _cachedDeviceId = result.first['value'] as String;
      return _cachedDeviceId!;
    }

    // Generate new device ID
    _cachedDeviceId = _uuid.v4();
    await db.insert('settings', {
      'key': _deviceIdKey,
      'value': _cachedDeviceId,
    });

    return _cachedDeviceId!;
  }

  /// Gets the settings database (separate from main database)
  static Future<Database> _getSettingsDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'settings.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE settings (
            key TEXT PRIMARY KEY NOT NULL,
            value TEXT NOT NULL
          )
        ''');
      },
    );
  }

  /// Resets the device ID (for testing only)
  static void resetForTesting() {
    _cachedDeviceId = null;
  }
}
