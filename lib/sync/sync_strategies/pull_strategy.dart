import '../../../core/types/result.dart';
import '../../../core/errors/failures.dart';
import '../../domain/entities/sleep_event.dart';

/// Pull strategy
/// 
/// Handles receiving remote events from backend
/// Processes events with syncedAt > lastSyncedAt
abstract class PullStrategy {
  /// Pulls new remote events from backend
  /// 
  /// [babyId] - Baby ID
  /// [lastSyncedAt] - Timestamp of last successful sync
  /// 
  /// Returns list of new remote events
  Future<Result<List<SleepEvent>, Failure>> pullEvents({
    required String babyId,
    required DateTime lastSyncedAt,
  });
}

