/// Application-wide constants
/// 
/// Contains device_id, timeouts, and other configuration values
class AppConstants {
  AppConstants._();

  // Device identification
  static String? deviceId;

  // Sync configuration
  static const Duration syncInterval = Duration(minutes: 5);
  static const Duration syncTimeout = Duration(seconds: 30);
  static const int maxRetryAttempts = 3;

  // Conflict resolution
  static const Duration conflictTimeWindow = Duration(seconds: 1);
}

