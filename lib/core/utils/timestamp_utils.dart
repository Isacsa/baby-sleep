/// Utilities for timestamp handling
/// 
/// All timestamps are in UTC
/// timestamp = when event occurred in reality
/// created_at = when event was created locally
class TimestampUtils {
  TimestampUtils._();

  /// Gets current UTC timestamp
  /// 
  /// Used for created_at when creating events locally
  static DateTime nowUtc() {
    return DateTime.now().toUtc();
  }

  /// Converts DateTime to UTC if not already
  static DateTime toUtc(DateTime dateTime) {
    return dateTime.isUtc ? dateTime : dateTime.toUtc();
  }

  /// Validates timestamp is not too far in future
  /// 
  /// Backend blocks timestamps > 1 hour in future
  static bool isValidTimestamp(DateTime timestamp) {
    final now = nowUtc();
    final maxFuture = now.add(const Duration(hours: 1));
    return timestamp.isBefore(maxFuture) || timestamp.isAtSameMomentAs(maxFuture);
  }
}

