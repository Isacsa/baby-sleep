import 'package:temp_flutter/domain/common/result.dart';
import 'package:temp_flutter/domain/value_objects/sleep_state.dart';
import 'package:temp_flutter/domain/repositories/sleep_event_repository.dart';

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
  Future<DomainResult<SleepState>> execute(String babyId) async {
    // Get events timeline (only valid events)
    final eventsResult = await sleepEventRepository.getSleepEventsTimeline(
      babyId: babyId,
      includeCorrected: false,
    );

    if (eventsResult.isError) {
      return DomainError(eventsResult.failureOrNull!);
    }

    final events = eventsResult.dataOrNull ?? [];

    // Derive state from events
    final state = SleepState.fromEvents(events);

    return DomainSuccess(state);
  }
}
