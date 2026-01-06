import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../domain/value_objects/sleep_state.dart';
import 'sleep_events_provider.dart';

part 'sleep_state_provider.g.dart';

/// Sleep state provider
/// 
/// Derives current sleep state from events
/// Depends on sleepEventsProvider
/// Updates automatically when events change
@riverpod
SleepState sleepState(SleepStateRef ref) {
  final eventsAsync = ref.watch(sleepEventsProviderProvider);
  
  return eventsAsync.when(
    data: (events) => SleepState.fromEvents(events),
    loading: () => const SleepState(isSleeping: false),
    error: (_, __) => const SleepState(isSleeping: false),
  );
}

