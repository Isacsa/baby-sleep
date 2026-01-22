import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:temp_flutter/application/providers/active_baby_provider.dart';
import 'package:temp_flutter/application/providers/sleep_expectations_provider.dart';
import 'package:temp_flutter/application/providers/sleep_metrics_provider.dart';
import 'package:temp_flutter/data/datasources/local/insight_impressions_local_datasource.dart';
import 'package:temp_flutter/domain/analysis/insight_render_model.dart';
import 'package:temp_flutter/domain/analysis/insight_rules/insight_rule.dart';
import 'package:temp_flutter/domain/analysis/insight_rules/sleep_insight_rules.dart';
import 'package:temp_flutter/domain/content/content_ids.dart';

/// Provider for insight impressions local data source
final insightImpressionsProvider = Provider<InsightImpressionsLocalDataSource>(
  (ref) => InsightImpressionsLocalDataSource(),
);

/// Provider for insights using the v2 rule-based engine
///
/// Pipeline:
/// 1. Get metrics and expectations
/// 2. Evaluate all rules
/// 3. Filter by requiresDob, requiresDataDays
/// 4. Apply cooldown (async check)
/// 5. Sort by priority
/// 6. Select "Hoje" (max 2) and "Padrões" (max 4)
final insightsV2Provider = FutureProvider<InsightEngineResult>((ref) async {
  final activeBaby = ref.watch(activeBabyProvider);
  final metricsAsync = ref.watch(sleepMetricsProvider);
  final expectationsAsync = ref.watch(activeBabySleepExpectationsProvider);

  // No baby = empty
  if (activeBaby == null) {
    return InsightEngineResult.empty();
  }

  // Wait for metrics
  final metrics = metricsAsync.when(
    data: (m) => m,
    loading: () => null,
    error: (e, s) => null,
  );

  if (metrics == null) {
    return InsightEngineResult.empty();
  }

  // Get expectations (may be null if no birthDate)
  final expectationsData = expectationsAsync.when(
    data: (d) => d,
    loading: () => null,
    error: (e, s) => null,
  );

  // Determine age band
  final ageBand = expectationsData?.ageBand;
  final expectations = expectationsData?.expectations;

  // Build context
  final context = InsightRuleContext(
    metrics: metrics,
    expectations: expectations,
    ageBand: ageBand,
    babyName: activeBaby.name,
    now: DateTime.now(),
    dataWindowDays: metrics.daysWithData,
  );

  // Check if we need DOB banner
  final needsDob = activeBaby.birthDate == null;

  // Check if insufficient data
  if (metrics.daysWithData < 1) {
    return InsightEngineResult.insufficientData(
      dataWindowDays: metrics.daysWithData,
    );
  }

  // Evaluate all rules
  final allRules = allInsightRules;
  final triggeredInsights = <InsightRenderModel>[];

  for (final rule in allRules) {
    final insight = rule.evaluate(context);
    if (insight != null) {
      triggeredInsights.add(insight);
    }
  }

  // Apply cooldown filter
  final impressionsDs = ref.read(insightImpressionsProvider);
  final babyId = activeBaby.id;

  final afterCooldown = <InsightRenderModel>[];
  for (final insight in triggeredInsights) {
    // Skip cooldown for summary cards (always show)
    if (insight.id == InsightId.summary24h ||
        insight.id == InsightId.currentlySleeping) {
      afterCooldown.add(insight);
      continue;
    }

    final inCooldown = await impressionsDs.isInCooldown(
      babyId,
      insight.id,
      insight.cooldownHours,
    );

    if (!inCooldown) {
      afterCooldown.add(insight);
    }
  }

  // Sort by priority (high first), then confidence
  afterCooldown.sort((a, b) {
    final priorityCompare = b.priority.index.compareTo(a.priority.index);
    if (priorityCompare != 0) return priorityCompare;
    return b.confidence.compareTo(a.confidence);
  });

  // Select "Hoje" cards (summary + currently sleeping)
  final todayCards = <InsightRenderModel>[];
  final patternCards = <InsightRenderModel>[];

  for (final insight in afterCooldown) {
    if (insight.id == InsightId.summary24h ||
        insight.id == InsightId.currentlySleeping) {
      if (todayCards.length < 2) {
        todayCards.add(insight);
      }
    } else {
      if (patternCards.length < 4) {
        patternCards.add(insight);
      }
    }
  }

  // Record impressions for shown patterns (not summary)
  for (final insight in patternCards) {
    await impressionsDs.recordImpression(babyId, insight.id);
  }

  return InsightEngineResult(
    todayCards: todayCards,
    patternCards: patternCards,
    needsDob: needsDob,
    insufficientData: metrics.daysWithData < 3,
    dataWindowDays: metrics.daysWithData,
  );
});

/// Provider for just the "Hoje" section cards
final todayCardsProvider = Provider<AsyncValue<List<InsightRenderModel>>>((ref) {
  return ref.watch(insightsV2Provider).when(
    data: (result) => AsyncValue.data(result.todayCards),
    loading: () => const AsyncValue.loading(),
    error: (e, s) => AsyncValue.error(e, s),
  );
});

/// Provider for just the "Padrões" section cards
final patternCardsProvider = Provider<AsyncValue<List<InsightRenderModel>>>((ref) {
  return ref.watch(insightsV2Provider).when(
    data: (result) => AsyncValue.data(result.patternCards),
    loading: () => const AsyncValue.loading(),
    error: (e, s) => AsyncValue.error(e, s),
  );
});

/// Provider for checking if DOB banner should show
final needsDobBannerProvider = Provider<bool>((ref) {
  final baby = ref.watch(activeBabyProvider);
  return baby?.birthDate == null;
});

/// Convenience extension
extension InsightsV2ResultExtension on AsyncValue<InsightEngineResult> {
  InsightEngineResult get valueOrEmpty => when(
    data: (r) => r,
    loading: () => InsightEngineResult.empty(),
    error: (e, s) => InsightEngineResult.empty(),
  );
}
