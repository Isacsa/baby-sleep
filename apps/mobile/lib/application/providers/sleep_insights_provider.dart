import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:temp_flutter/application/providers/active_baby_provider.dart';
import 'package:temp_flutter/application/providers/sleep_expectations_provider.dart';
import 'package:temp_flutter/application/providers/sleep_metrics_provider.dart';
import 'package:temp_flutter/domain/analysis/sleep_insight_engine.dart';

/// Provider for sleep insights generated from metrics and expectations
///
/// Combines:
/// - [sleepMetricsProvider] for calculated metrics
/// - [activeBabySleepExpectationsProvider] for age-based expectations
///
/// Returns [SleepInsightResult] with:
/// - All insights (for Stats)
/// - Top insights (for Home, max 2)
/// - Suggested actions (max 2)
final sleepInsightsProvider = Provider<AsyncValue<SleepInsightResult>>((ref) {
  final metricsAsync = ref.watch(sleepMetricsProvider);
  final expectationsAsync = ref.watch(activeBabySleepExpectationsProvider);
  final activeBaby = ref.watch(activeBabyProvider);

  // No baby = empty result
  if (activeBaby == null) {
    return AsyncValue.data(SleepInsightResult.empty());
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

      // Generate insights
      final result = SleepInsightEngine.generate(
        metrics: metrics,
        expectations: expectationsData?.expectations,
        babyName: activeBaby.name,
      );

      return AsyncValue.data(result);
    },
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
  );
});

/// Provider for just the top insights (for Home page)
final topSleepInsightsProvider = Provider<AsyncValue<List<dynamic>>>((ref) {
  final insightsAsync = ref.watch(sleepInsightsProvider);

  return insightsAsync.when(
    data: (result) => AsyncValue.data(result.topInsights),
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
  );
});

/// Provider for suggested actions
final suggestedActionsProvider = Provider<AsyncValue<List<dynamic>>>((ref) {
  final insightsAsync = ref.watch(sleepInsightsProvider);

  return insightsAsync.when(
    data: (result) => AsyncValue.data(result.suggestedActions),
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
  );
});

/// Convenience extension
extension SleepInsightsProviderExtension on AsyncValue<SleepInsightResult> {
  SleepInsightResult get valueOrEmpty => when(
        data: (r) => r,
        loading: () => SleepInsightResult.empty(),
        error: (_, __) => SleepInsightResult.empty(),
      );
}
