import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:temp_flutter/application/providers/active_baby_provider.dart';
import 'package:temp_flutter/application/providers/stats_period_provider.dart';
import 'package:temp_flutter/application/providers/stats_sessions_provider.dart';
import 'package:temp_flutter/data/cache/daily_aggregates_cache.dart';
import 'package:temp_flutter/domain/stats/daily_sleep_aggregate.dart';
import 'package:temp_flutter/domain/stats/period_kpis.dart';

/// Provider for daily aggregates in the current stats period.
///
/// Uses incremental caching to avoid recalculating unchanged days.
final statsDailyAggregatesProvider =
    Provider<AsyncValue<List<DailySleepAggregate>>>((ref) {
  final sessionsAsync = ref.watch(statsSessionsProvider);
  final periodRange = ref.watch(statsPeriodRangeProvider);
  final activeBaby = ref.watch(activeBabyProvider);
  final cache = ref.watch(dailyAggregatesCacheProvider);

  if (activeBaby == null) {
    return const AsyncValue.data([]);
  }

  return sessionsAsync.when(
    data: (sessions) {
      // Try to get from cache first
      final cached = cache.getCached(
        babyId: activeBaby.id,
        startLocal: periodRange.startLocal,
        endExclusiveLocal: periodRange.endExclusiveLocal,
        currentSessions: sessions,
      );

      if (cached != null) {
        return AsyncValue.data(cached);
      }

      // Calculate and cache
      final aggregates = DailySleepAggregateCalculator.calculate(
        sessions: sessions,
        startLocal: periodRange.startLocal,
        endExclusiveLocal: periodRange.endExclusiveLocal,
      );

      cache.updateCache(
        babyId: activeBaby.id,
        aggregates: aggregates,
        sessions: sessions,
      );

      return AsyncValue.data(aggregates);
    },
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
  );
});

/// Provider for daily aggregates in the comparison period.
final statsCompareDailyAggregatesProvider =
    Provider<AsyncValue<List<DailySleepAggregate>>>((ref) {
  final sessionsAsync = ref.watch(statsCompareSessionsProvider);
  final compareRange = ref.watch(statsComparePeriodRangeProvider);

  if (compareRange == null) {
    return const AsyncValue.data([]);
  }

  return sessionsAsync.when(
    data: (sessions) {
      final aggregates = DailySleepAggregateCalculator.calculate(
        sessions: sessions,
        startLocal: compareRange.startLocal,
        endExclusiveLocal: compareRange.endExclusiveLocal,
      );
      return AsyncValue.data(aggregates);
    },
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
  );
});

/// Provider for current period KPIs.
final statsKPIsProvider = Provider<AsyncValue<PeriodKPIs>>((ref) {
  final aggregatesAsync = ref.watch(statsDailyAggregatesProvider);

  return aggregatesAsync.when(
    data: (aggregates) {
      final kpis = PeriodKPIsCalculator.calculate(aggregates);
      return AsyncValue.data(kpis);
    },
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
  );
});

/// Provider for comparison period KPIs.
final statsCompareKPIsProvider = Provider<AsyncValue<PeriodKPIs?>>((ref) {
  final compareRange = ref.watch(statsComparePeriodRangeProvider);
  if (compareRange == null) {
    return const AsyncValue.data(null);
  }

  final aggregatesAsync = ref.watch(statsCompareDailyAggregatesProvider);

  return aggregatesAsync.when(
    data: (aggregates) {
      final kpis = PeriodKPIsCalculator.calculate(aggregates);
      return AsyncValue.data(kpis);
    },
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
  );
});

/// Provider for KPI comparison when compare is enabled.
final statsKPIComparisonProvider = Provider<AsyncValue<KPIComparison?>>((ref) {
  final currentAsync = ref.watch(statsKPIsProvider);
  final compareAsync = ref.watch(statsCompareKPIsProvider);

  // Combine async values
  if (currentAsync.isLoading || compareAsync.isLoading) {
    return const AsyncValue.loading();
  }

  if (currentAsync.hasError) {
    return AsyncValue.error(
      currentAsync.error!,
      currentAsync.stackTrace ?? StackTrace.current,
    );
  }

  final current = currentAsync.value;
  final compare = compareAsync.value;

  if (current == null || compare == null) {
    return const AsyncValue.data(null);
  }

  return AsyncValue.data(KPIComparison(
    current: current,
    previous: compare,
  ));
});
