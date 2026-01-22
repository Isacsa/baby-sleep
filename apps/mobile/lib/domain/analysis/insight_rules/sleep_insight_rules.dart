import 'package:temp_flutter/domain/analysis/age_band.dart';
import 'package:temp_flutter/domain/analysis/insight_render_model.dart';
import 'package:temp_flutter/domain/analysis/insight_rules/insight_rule.dart';
import 'package:temp_flutter/domain/analysis/sleep_expectations.dart';
import 'package:temp_flutter/domain/content/content_ids.dart';

// =============================================================================
// SUMMARY CARDS (always shown in "Hoje" section)
// =============================================================================

/// Summary 24h card - shows total sleep vs average
class Summary24hRule extends InsightRule {
  @override
  String get id => InsightId.summary24h;
  @override
  InsightPriority get priority => InsightPriority.high;
  @override
  int get cooldownHours => 0; // Always show
  @override
  int get requiresDataDays => 0;
  @override
  bool get requiresDob => false;
  @override
  List<SleepAgeBand> get ageBands => [];

  @override
  InsightRenderModel? evaluate(InsightRuleContext context) {
    final metrics = context.metrics;
    final total24h = metrics.totalSleepLast24h;

    // No data case - total is zero duration
    if (total24h.inMinutes == 0 && context.dataWindowDays < 1) {
      return InsightRenderModel(
        id: id,
        titleKey: 'insightSummary24hTitle',
        bodyKey: 'insightSummary24hNoData',
        priority: priority,
        cooldownHours: cooldownHours,
      );
    }

    final hours = total24h.inHours;
    final minutes = total24h.inMinutes % 60;

    // Calculate diff from 7d average
    final avg7d = metrics.avgTotalSleep7d;
    final diffMinutes = metrics.diffFromAvg7d?.inMinutes;

    String? whyKey;
    Map<String, dynamic> args = {'hours': hours, 'minutes': minutes};

    if (diffMinutes != null && avg7d != null) {
      final sign = diffMinutes >= 0 ? '+' : '';
      args['sign'] = sign;
      args['diffMinutes'] = diffMinutes.abs();
      whyKey = 'insightSummary24hVsAvg';
    }

    return InsightRenderModel(
      id: id,
      titleKey: 'insightSummary24hTitle',
      bodyKey: 'insightSummary24hBody',
      whyKey: whyKey,
      args: args,
      priority: priority,
      cooldownHours: cooldownHours,
    );
  }
}

/// Currently sleeping card
class CurrentlySleepingRule extends InsightRule {
  @override
  String get id => InsightId.currentlySleeping;
  @override
  InsightPriority get priority => InsightPriority.high;
  @override
  int get cooldownHours => 0;
  @override
  int get requiresDataDays => 0;
  @override
  bool get requiresDob => false;
  @override
  List<SleepAgeBand> get ageBands => [];

  @override
  InsightRenderModel? evaluate(InsightRuleContext context) {
    if (!context.metrics.isCurrentlySleeping) return null;

    final sleepingSince = context.metrics.currentSessionStart;
    final timeStr = sleepingSince != null
        ? '${sleepingSince.hour.toString().padLeft(2, '0')}:${sleepingSince.minute.toString().padLeft(2, '0')}'
        : '';

    return InsightRenderModel(
      id: id,
      titleKey: 'insightCurrentlySleepingTitle',
      bodyKey: 'insightCurrentlySleepingBody',
      args: {'time': timeStr},
      priority: priority,
      cooldownHours: cooldownHours,
    );
  }
}

// =============================================================================
// SLEEP VS EXPECTED (requires DOB)
// =============================================================================

/// Sleep below expected for age
class SleepBelowExpectedRule extends SimpleInsightRule {
  @override
  String get id => InsightId.sleepBelowExpected;
  @override
  InsightPriority get priority => InsightPriority.high;
  @override
  int get cooldownHours => 48;
  @override
  int get requiresDataDays => 3;
  @override
  bool get requiresDob => true;
  @override
  List<SleepAgeBand> get ageBands => [];

  @override
  bool condition(InsightRuleContext context) {
    if (!context.hasExpectations) return false;
    final totalMinutes = context.metrics.totalSleepLast24h.inMinutes;
    if (totalMinutes == 0) return false;

    final comparison = context.expectations!.compareTotalSleep24h(totalMinutes);
    return comparison == RangeComparison.below;
  }

  @override
  InsightRenderModel buildInsight(InsightRuleContext context) {
    final exp = context.expectations!;
    return InsightRenderModel(
      id: id,
      titleKey: 'insightSleepBelowExpectedTitle',
      bodyKey: 'insightSleepBelowExpectedBody',
      whyKey: 'insightSleepBelowExpectedWhy',
      args: {
        'min': exp.totalSleep24hMin ~/ 60, // Convert minutes to hours
        'max': exp.totalSleep24hMax ~/ 60,
      },
      ctaAction: InsightCtaAction.openGuide,
      ctaLabelKey: 'insightCtaCheckGuide',
      guideSectionId: GuideSectionId.normalPorIdade,
      sourceIds: [SourceId.aasmSleepDuration],
      priority: priority,
      cooldownHours: cooldownHours,
      requiresDob: requiresDob,
      requiresDataDays: requiresDataDays,
    );
  }
}

/// Sleep within expected for age
class SleepWithinExpectedRule extends SimpleInsightRule {
  @override
  String get id => InsightId.sleepWithinExpected;
  @override
  InsightPriority get priority => InsightPriority.low;
  @override
  int get cooldownHours => 72;
  @override
  int get requiresDataDays => 3;
  @override
  bool get requiresDob => true;
  @override
  List<SleepAgeBand> get ageBands => [];

  @override
  bool condition(InsightRuleContext context) {
    if (!context.hasExpectations) return false;
    final totalMinutes = context.metrics.totalSleepLast24h.inMinutes;
    if (totalMinutes == 0) return false;

    final comparison = context.expectations!.compareTotalSleep24h(totalMinutes);
    return comparison == RangeComparison.within;
  }

  @override
  InsightRenderModel buildInsight(InsightRuleContext context) {
    return InsightRenderModel(
      id: id,
      titleKey: 'insightSleepWithinExpectedTitle',
      bodyKey: 'insightSleepWithinExpectedBody',
      priority: priority,
      cooldownHours: cooldownHours,
      requiresDob: requiresDob,
      requiresDataDays: requiresDataDays,
    );
  }
}

/// Sleep above expected for age
class SleepAboveExpectedRule extends SimpleInsightRule {
  @override
  String get id => InsightId.sleepAboveExpected;
  @override
  InsightPriority get priority => InsightPriority.low;
  @override
  int get cooldownHours => 72;
  @override
  int get requiresDataDays => 3;
  @override
  bool get requiresDob => true;
  @override
  List<SleepAgeBand> get ageBands => [];

  @override
  bool condition(InsightRuleContext context) {
    if (!context.hasExpectations) return false;
    final totalMinutes = context.metrics.totalSleepLast24h.inMinutes;
    if (totalMinutes == 0) return false;

    final comparison = context.expectations!.compareTotalSleep24h(totalMinutes);
    return comparison == RangeComparison.above;
  }

  @override
  InsightRenderModel buildInsight(InsightRuleContext context) {
    return InsightRenderModel(
      id: id,
      titleKey: 'insightSleepAboveExpectedTitle',
      bodyKey: 'insightSleepAboveExpectedBody',
      priority: priority,
      cooldownHours: cooldownHours,
      requiresDob: requiresDob,
      requiresDataDays: requiresDataDays,
    );
  }
}

// =============================================================================
// BEDTIME CONSISTENCY
// =============================================================================

/// High bedtime variability
class BedtimeVariabilityHighRule extends SimpleInsightRule {
  @override
  String get id => InsightId.bedtimeVariabilityHigh;
  @override
  InsightPriority get priority => InsightPriority.medium;
  @override
  int get cooldownHours => 48;
  @override
  int get requiresDataDays => 5;
  @override
  bool get requiresDob => false;
  @override
  List<SleepAgeBand> get ageBands => [];

  @override
  bool condition(InsightRuleContext context) {
    final variability = context.metrics.bedtimeVariabilityRangeMinutes;
    return variability != null && variability > 45;
  }

  @override
  InsightRenderModel buildInsight(InsightRuleContext context) {
    return InsightRenderModel(
      id: id,
      titleKey: 'insightBedtimeVariabilityHighTitle',
      bodyKey: 'insightBedtimeVariabilityHighBody',
      whyKey: 'insightBedtimeVariabilityHighWhy',
      args: {'minutes': context.metrics.bedtimeVariabilityRangeMinutes!},
      ctaAction: InsightCtaAction.openGuide,
      ctaLabelKey: 'insightCtaCheckGuide',
      guideSectionId: GuideSectionId.rotinaAntesDormir,
      priority: priority,
      cooldownHours: cooldownHours,
      requiresDataDays: requiresDataDays,
    );
  }
}

/// Good bedtime consistency
class BedtimeConsistencyGoodRule extends SimpleInsightRule {
  @override
  String get id => InsightId.bedtimeConsistencyGood;
  @override
  InsightPriority get priority => InsightPriority.low;
  @override
  int get cooldownHours => 72;
  @override
  int get requiresDataDays => 5;
  @override
  bool get requiresDob => false;
  @override
  List<SleepAgeBand> get ageBands => [];

  @override
  bool condition(InsightRuleContext context) {
    final variability = context.metrics.bedtimeVariabilityRangeMinutes;
    return variability != null && variability <= 30;
  }

  @override
  InsightRenderModel buildInsight(InsightRuleContext context) {
    return InsightRenderModel(
      id: id,
      titleKey: 'insightBedtimeConsistencyGoodTitle',
      bodyKey: 'insightBedtimeConsistencyGoodBody',
      priority: priority,
      cooldownHours: cooldownHours,
      requiresDataDays: requiresDataDays,
    );
  }
}

// =============================================================================
// FRAGMENTATION
// =============================================================================

/// High night fragmentation
class NightFragmentationHighRule extends SimpleInsightRule {
  @override
  String get id => InsightId.nightFragmentationHigh;
  @override
  InsightPriority get priority => InsightPriority.medium;
  @override
  int get cooldownHours => 48;
  @override
  int get requiresDataDays => 3;
  @override
  bool get requiresDob => false;
  @override
  List<SleepAgeBand> get ageBands => [];

  @override
  bool condition(InsightRuleContext context) {
    final avgEpisodes = context.metrics.avgEpisodesPerNight7d;
    return avgEpisodes != null && avgEpisodes > 3;
  }

  @override
  InsightRenderModel buildInsight(InsightRuleContext context) {
    return InsightRenderModel(
      id: id,
      titleKey: 'insightNightFragmentationHighTitle',
      bodyKey: 'insightNightFragmentationHighBody',
      whyKey: 'insightNightFragmentationHighWhy',
      args: {'count': context.metrics.avgEpisodesPerNight7d!.round()},
      priority: priority,
      cooldownHours: cooldownHours,
      requiresDataDays: requiresDataDays,
    );
  }
}

// =============================================================================
// AGE NORMALIZATION
// =============================================================================

/// 0-4 months: variability is normal
class AgeNorm0to4Rule extends SimpleInsightRule {
  @override
  String get id => InsightId.ageNorm0to3Variability;
  @override
  InsightPriority get priority => InsightPriority.medium;
  @override
  int get cooldownHours => 168; // 1 week
  @override
  int get requiresDataDays => 3;
  @override
  bool get requiresDob => true;
  @override
  List<SleepAgeBand> get ageBands => [
    SleepAgeBand.newborn0to28d,
    SleepAgeBand.months1to2,
    SleepAgeBand.months2to4,
  ];

  @override
  bool condition(InsightRuleContext context) {
    // Always show for this age band if we have enough data
    return true;
  }

  @override
  InsightRenderModel buildInsight(InsightRuleContext context) {
    return InsightRenderModel(
      id: id,
      titleKey: 'insightAgeNorm0to3Title',
      bodyKey: 'insightAgeNorm0to3Body',
      ctaAction: InsightCtaAction.openGuide,
      ctaLabelKey: 'insightCtaLearnMore',
      guideSectionId: GuideSectionId.normalPorIdade,
      priority: priority,
      cooldownHours: cooldownHours,
      requiresDob: requiresDob,
      requiresDataDays: requiresDataDays,
      ageBands: ageBands,
    );
  }
}

/// 4-12 months: consolidation in progress
class AgeNorm4to12Rule extends SimpleInsightRule {
  @override
  String get id => InsightId.ageNorm4to12Consolidation;
  @override
  InsightPriority get priority => InsightPriority.medium;
  @override
  int get cooldownHours => 168;
  @override
  int get requiresDataDays => 3;
  @override
  bool get requiresDob => true;
  @override
  List<SleepAgeBand> get ageBands => [
    SleepAgeBand.months4to6,
    SleepAgeBand.months6to9,
    SleepAgeBand.months9to12,
  ];

  @override
  bool condition(InsightRuleContext context) => true;

  @override
  InsightRenderModel buildInsight(InsightRuleContext context) {
    return InsightRenderModel(
      id: id,
      titleKey: 'insightAgeNorm4to12Title',
      bodyKey: 'insightAgeNorm4to12Body',
      ctaAction: InsightCtaAction.openGuide,
      ctaLabelKey: 'insightCtaLearnMore',
      guideSectionId: GuideSectionId.normalPorIdade,
      priority: priority,
      cooldownHours: cooldownHours,
      requiresDob: requiresDob,
      requiresDataDays: requiresDataDays,
      ageBands: ageBands,
    );
  }
}

/// 12-24 months: testing limits is normal
class AgeNorm12to24Rule extends SimpleInsightRule {
  @override
  String get id => InsightId.ageNorm12to24Boundaries;
  @override
  InsightPriority get priority => InsightPriority.medium;
  @override
  int get cooldownHours => 168;
  @override
  int get requiresDataDays => 3;
  @override
  bool get requiresDob => true;
  @override
  List<SleepAgeBand> get ageBands => [
    SleepAgeBand.months12to18,
    SleepAgeBand.months18to24,
  ];

  @override
  bool condition(InsightRuleContext context) => true;

  @override
  InsightRenderModel buildInsight(InsightRuleContext context) {
    return InsightRenderModel(
      id: id,
      titleKey: 'insightAgeNorm12to24Title',
      bodyKey: 'insightAgeNorm12to24Body',
      ctaAction: InsightCtaAction.openGuide,
      ctaLabelKey: 'insightCtaLearnMore',
      guideSectionId: GuideSectionId.normalPorIdade,
      priority: priority,
      cooldownHours: cooldownHours,
      requiresDob: requiresDob,
      requiresDataDays: requiresDataDays,
      ageBands: ageBands,
    );
  }
}

// =============================================================================
// SAFE SLEEP & TIPS
// =============================================================================

/// Safe sleep reminder
class SafeSleepBackToSleepRule extends SimpleInsightRule {
  @override
  String get id => InsightId.safeSleepBackToSleep;
  @override
  InsightPriority get priority => InsightPriority.medium;
  @override
  int get cooldownHours => 168; // 1 week
  @override
  int get requiresDataDays => 1;
  @override
  bool get requiresDob => true;
  @override
  List<SleepAgeBand> get ageBands => [
    SleepAgeBand.newborn0to28d,
    SleepAgeBand.months1to2,
    SleepAgeBand.months2to4,
    SleepAgeBand.months4to6,
    SleepAgeBand.months6to9,
    SleepAgeBand.months9to12,
  ];

  @override
  bool condition(InsightRuleContext context) => true;

  @override
  InsightRenderModel buildInsight(InsightRuleContext context) {
    return InsightRenderModel(
      id: id,
      titleKey: 'insightSafeSleepBackToSleepTitle',
      bodyKey: 'insightSafeSleepBackToSleepBody',
      ctaAction: InsightCtaAction.openGuide,
      ctaLabelKey: 'insightCtaCheckGuide',
      guideSectionId: GuideSectionId.sonoSeguro,
      sourceIds: [SourceId.aapSafeSleep, SourceId.cdcSafeSleep],
      priority: priority,
      cooldownHours: cooldownHours,
      requiresDob: requiresDob,
      requiresDataDays: requiresDataDays,
      ageBands: ageBands,
    );
  }
}

/// Day vs night tip
class DayNightLowStimulusRule extends SimpleInsightRule {
  @override
  String get id => InsightId.dayNightLowStimulus;
  @override
  InsightPriority get priority => InsightPriority.medium;
  @override
  int get cooldownHours => 168;
  @override
  int get requiresDataDays => 1;
  @override
  bool get requiresDob => false;
  @override
  List<SleepAgeBand> get ageBands => [];

  @override
  bool condition(InsightRuleContext context) {
    // Show periodically, no specific trigger
    return true;
  }

  @override
  InsightRenderModel buildInsight(InsightRuleContext context) {
    return InsightRenderModel(
      id: id,
      titleKey: 'insightDayNightLowStimulusTitle',
      bodyKey: 'insightDayNightLowStimulusBody',
      ctaAction: InsightCtaAction.openGuide,
      ctaLabelKey: 'insightCtaLearnMore',
      guideSectionId: GuideSectionId.diaVsNoite,
      sourceIds: [SourceId.nhsDayNight],
      priority: priority,
      cooldownHours: cooldownHours,
      requiresDataDays: requiresDataDays,
    );
  }
}

/// Bedtime routine tip
class RoutineShortConsistentRule extends SimpleInsightRule {
  @override
  String get id => InsightId.routineShortConsistent;
  @override
  InsightPriority get priority => InsightPriority.medium;
  @override
  int get cooldownHours => 168;
  @override
  int get requiresDataDays => 1;
  @override
  bool get requiresDob => false;
  @override
  List<SleepAgeBand> get ageBands => [];

  @override
  bool condition(InsightRuleContext context) => true;

  @override
  InsightRenderModel buildInsight(InsightRuleContext context) {
    return InsightRenderModel(
      id: id,
      titleKey: 'insightRoutineShortConsistentTitle',
      bodyKey: 'insightRoutineShortConsistentBody',
      ctaAction: InsightCtaAction.openGuide,
      ctaLabelKey: 'insightCtaLearnMore',
      guideSectionId: GuideSectionId.rotinaAntesDormir,
      sourceIds: [SourceId.aapBedtimeRoutine, SourceId.nhsBedtimeRoutine],
      priority: priority,
      cooldownHours: cooldownHours,
      requiresDataDays: requiresDataDays,
    );
  }
}

// =============================================================================
// UTILITY: FEW DATA
// =============================================================================

/// Learning pattern (shown when insufficient data)
class FewDataLearningRule extends InsightRule {
  @override
  String get id => InsightId.fewDataLearning;
  @override
  InsightPriority get priority => InsightPriority.low;
  @override
  int get cooldownHours => 24;
  @override
  int get requiresDataDays => 0;
  @override
  bool get requiresDob => false;
  @override
  List<SleepAgeBand> get ageBands => [];

  @override
  InsightRenderModel? evaluate(InsightRuleContext context) {
    // Show when we have less than 3 days of data
    if (context.dataWindowDays >= 3) return null;

    return InsightRenderModel(
      id: id,
      titleKey: 'insightFewDataLearningTitle',
      bodyKey: 'insightFewDataLearningBody',
      priority: priority,
      cooldownHours: cooldownHours,
    );
  }
}

// =============================================================================
// ALL RULES REGISTRY
// =============================================================================

/// All available insight rules
List<InsightRule> get allInsightRules => [
  // Summary (always evaluated)
  Summary24hRule(),
  CurrentlySleepingRule(),

  // Sleep vs expected
  SleepBelowExpectedRule(),
  SleepWithinExpectedRule(),
  SleepAboveExpectedRule(),

  // Bedtime consistency
  BedtimeVariabilityHighRule(),
  BedtimeConsistencyGoodRule(),

  // Fragmentation
  NightFragmentationHighRule(),

  // Age normalization
  AgeNorm0to4Rule(),
  AgeNorm4to12Rule(),
  AgeNorm12to24Rule(),

  // Safe sleep & tips
  SafeSleepBackToSleepRule(),
  DayNightLowStimulusRule(),
  RoutineShortConsistentRule(),

  // Utility
  FewDataLearningRule(),
];
