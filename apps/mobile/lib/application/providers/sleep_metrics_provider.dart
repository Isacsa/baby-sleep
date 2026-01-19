import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:temp_flutter/application/providers/active_baby_provider.dart';
import 'package:temp_flutter/application/providers/sleep_events_provider.dart';
import 'package:temp_flutter/application/providers/sleep_state_provider.dart';
import 'package:temp_flutter/domain/analysis/sleep_metrics.dart';
import 'package:temp_flutter/domain/analysis/sleep_metrics_calculator.dart';
import 'package:temp_flutter/domain/value_objects/sleep_session.dart';

/// Provider for sleep metrics calculated from session data
///
/// Depends on:
/// - [sleepEventsNotifierProvider] for raw events
/// - [sleepStateNotifierProvider] for current sleeping state
/// - [activeBabyProvider] for baby context
///
/// Automatically recalculates when events change.
/// Pure derived state - no network, no side effects.
final sleepMetricsProvider = Provider<AsyncValue<SleepMetrics>>((ref) {
  final eventsAsync = ref.watch(sleepEventsNotifierProvider);
  final sleepState = ref.watch(sleepStateNotifierProvider);
  final activeBaby = ref.watch(activeBabyProvider);

  // If no active baby, return empty metrics
  if (activeBaby == null) {
    return AsyncValue.data(SleepMetrics.empty());
  }

  // Transform events async to metrics
  return eventsAsync.when(
    data: (events) {
      // Derive sessions from events
      final sessions = SleepSession.fromEventList(events);

      // Calculate metrics
      final metrics = SleepMetricsCalculator.calculate(
        sessions: sessions,
        sleepState: sleepState,
        lookbackDays: 7,
      );

      return AsyncValue.data(metrics);
    },
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
  );
});

/// Provider for sleep metrics with configurable lookback days
///
/// Use this for stats views that need different time windows.
final sleepMetricsWithLookbackProvider =
    Provider.family<AsyncValue<SleepMetrics>, int>((ref, lookbackDays) {
  final eventsAsync = ref.watch(sleepEventsNotifierProvider);
  final sleepState = ref.watch(sleepStateNotifierProvider);
  final activeBaby = ref.watch(activeBabyProvider);

  if (activeBaby == null) {
    return AsyncValue.data(SleepMetrics.empty());
  }

  return eventsAsync.when(
    data: (events) {
      final sessions = SleepSession.fromEventList(events);

      final metrics = SleepMetricsCalculator.calculate(
        sessions: sessions,
        sleepState: sleepState,
        lookbackDays: lookbackDays,
      );

      return AsyncValue.data(metrics);
    },
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
  );
});

/// Convenience extension for accessing metrics synchronously when loaded
extension SleepMetricsProviderExtension on AsyncValue<SleepMetrics> {
  /// Returns metrics if loaded, otherwise empty metrics
  SleepMetrics get valueOrEmpty => when(
        data: (m) => m,
        loading: () => SleepMetrics.empty(),
        error: (_, __) => SleepMetrics.empty(),
      );
}
