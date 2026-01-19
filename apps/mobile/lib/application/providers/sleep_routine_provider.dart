import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:temp_flutter/application/providers/active_baby_provider.dart';
import 'package:temp_flutter/application/providers/sleep_expectations_provider.dart';
import 'package:temp_flutter/application/providers/sleep_metrics_provider.dart';
import 'package:temp_flutter/domain/analysis/sleep_routine_suggester.dart';
import 'package:temp_flutter/domain/analysis/sleep_routine_suggestion.dart';

/// Provider for sleep routine suggestions
///
/// Combines:
/// - [sleepMetricsProvider] for lastWakeTime and patterns
/// - [activeBabySleepExpectationsProvider] for age-based wake windows
///
/// Returns [SleepRoutineSuggestion] with:
/// - Next nap window and suggested time
/// - Bedtime window and suggested time
/// - Explanation
final sleepRoutineProvider = Provider<AsyncValue<SleepRoutineSuggestion>>((ref) {
  final metricsAsync = ref.watch(sleepMetricsProvider);
  final expectationsAsync = ref.watch(activeBabySleepExpectationsProvider);
  final activeBaby = ref.watch(activeBabyProvider);

  // No baby = no suggestion
  if (activeBaby == null) {
    return AsyncValue.data(SleepRoutineSuggestion.noData());
  }

  // Wait for metrics
  return metricsAsync.when(
    data: (metrics) {
      // Get expectations (may be null if no birthDate)
      final expectationsData = expectationsAsync.when(
        data: (data) => data,
        loading: () => null,
        error: (_, __) => null,
      );

      // Generate suggestion
      final suggestion = SleepRoutineSuggester.suggest(
        metrics: metrics,
        expectations: expectationsData?.expectations,
      );

      return AsyncValue.data(suggestion);
    },
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
  );
});

/// Convenience extension
extension SleepRoutineProviderExtension on AsyncValue<SleepRoutineSuggestion> {
  SleepRoutineSuggestion get valueOrEmpty => when(
        data: (s) => s,
        loading: () => SleepRoutineSuggestion.noData(),
        error: (_, __) => SleepRoutineSuggestion.noData(),
      );
}
