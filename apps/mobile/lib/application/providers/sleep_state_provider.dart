import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:temp_flutter/domain/entities/sleep_event.dart';
import 'package:temp_flutter/domain/value_objects/sleep_state.dart';
import 'sleep_events_provider.dart';

part 'sleep_state_provider.g.dart';

/// Sleep state provider
/// 
/// Provides derived sleep state from events
/// Recalculates when events change
@riverpod
class SleepStateNotifier extends _$SleepStateNotifier {
  @override
  SleepState build() {
    final eventsAsync = ref.watch(sleepEventsNotifierProvider);
    
    final events = eventsAsync.value ?? <SleepEvent>[];
    
    // Derive state from events directly
    return SleepState.fromEvents(events);
  }
}
