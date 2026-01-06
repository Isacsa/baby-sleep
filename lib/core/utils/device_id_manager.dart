import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:uuid/uuid.dart';

/// Manages device ID for events
/// 
/// Device ID is a free-form string used for auditing
/// Backend does not validate format or uniqueness
/// This manager ensures consistent device identification
class DeviceIdManager {
  DeviceIdManager._();

  static const String _deviceIdKey = 'device_id';
  static const _uuid = Uuid();

  /// Gets or creates device ID
  /// 
  /// Device ID is persisted locally and reused across app sessions
  /// Format: UUID v4 (but can be any string)
  static Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString(_deviceIdKey);

    if (deviceId == null) {
      // Generate new device ID
      deviceId = _generateDeviceId();
      await prefs.setString(_deviceIdKey, deviceId);
    }

    return deviceId;
  }

  static String _generateDeviceId() {
    // Try to use device identifier, fallback to UUID
    // For MVP, using UUID is sufficient
    return _uuid.v4();
  }
}

