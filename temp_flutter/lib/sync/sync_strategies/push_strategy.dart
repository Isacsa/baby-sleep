import 'package:temp_flutter/domain/entities/sleep_event.dart';
import 'package:temp_flutter/domain/common/result.dart';

/// Push strategy
/// 
/// Handles sending local events to backend
/// Processes events with syncedAt = NULL
abstract class PushStrategy {
  /// Pushes unsynced events to backend
  /// 
  /// [babyId] - Baby ID
  /// [events] - List of unsynced events to push
  /// 
  /// Returns list of successfully synced events
  Future<DomainResult<List<SleepEvent>>> pushEvents({
    required String babyId,
    required List<SleepEvent> events,
  });
}

