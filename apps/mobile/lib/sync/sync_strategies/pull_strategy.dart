import 'package:temp_flutter/domain/entities/sleep_event.dart';
import 'package:temp_flutter/domain/common/result.dart';

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
  Future<DomainResult<List<SleepEvent>>> pullEvents({
    required String babyId,
    required DateTime lastSyncedAt,
  });
}

