import '../../../core/types/result.dart';
import '../../../core/errors/failures.dart';
import '../../value_objects/sleep_state.dart';
import '../../repositories/sleep_event_repository.dart';

/// Use case: Derive sleep state
/// 
/// Derives current sleep state from events
/// State is calculated in memory, not persisted
/// Uses only valid events (isCorrected = false)
class DeriveSleepState {
  final SleepEventRepository sleepEventRepository;

  DeriveSleepState({required this.sleepEventRepository});

  /// Executes the use case
  /// 
  /// [babyId] - Baby ID
  /// 
  /// Returns derived sleep state or failure
  Future<Result<SleepState, Failure>> execute(String babyId) async {
    // Get events timeline (only valid events)
    final eventsResult = await sleepEventRepository.getSleepEventsTimeline(
      babyId: babyId,
      includeCorrected: false,
    );

    if (eventsResult.isError) {
      return Error(eventsResult.failureOrNull!);
    }

    final events = eventsResult.dataOrNull ?? [];

    // Derive state from events
    final state = SleepState.fromEvents(events);

    return Success(state);
  }
}

