import '../../../core/types/result.dart';
import '../../../core/errors/failures.dart';
import '../../domain/entities/sleep_event.dart';

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
  Future<Result<List<SleepEvent>, Failure>> pushEvents({
    required String babyId,
    required List<SleepEvent> events,
  });
}

