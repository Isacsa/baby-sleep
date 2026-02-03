import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:temp_flutter/application/providers/active_baby_provider.dart';
import 'package:temp_flutter/application/providers/sleep_events_provider.dart';
import 'package:temp_flutter/application/providers/sleep_expectations_provider.dart';
import 'package:temp_flutter/core/utils/local_time_utils.dart';
import 'package:temp_flutter/domain/analysis/next_sleep_prediction.dart';
import 'package:temp_flutter/domain/analysis/next_sleep_predictor.dart';
import 'package:temp_flutter/domain/analysis/sleep_goal.dart';
import 'package:temp_flutter/domain/stats/daily_sleep_aggregate.dart';
import 'package:temp_flutter/domain/stats/data_quality_assessment.dart';
import 'package:temp_flutter/domain/stats/sleep_data_quality_view_model.dart';
import 'package:temp_flutter/domain/value_objects/sleep_session.dart';

/// Provider for today's sleep aggregate (clipped to local day boundaries)
final todayAggregateProvider = Provider<DailySleepAggregate>((ref) {
  final eventsAsync = ref.watch(sleepEventsNotifierProvider);

  // Get today's local day range
  final now = DateTime.now();
  final dayRange = LocalTimeUtils.localDayRange(now);

  // Return empty if no events loaded
  if (!eventsAsync.hasValue || eventsAsync.value == null) {
    return DailySleepAggregate.empty(dayRange.startLocal);
  }

  // Derive sessions from events
  final events = eventsAsync.value!;
  final sessions = SleepSession.fromEventList(events);

  // Calculate aggregate for today
  final aggregates = DailySleepAggregateCalculator.calculate(
    sessions: sessions,
    startLocal: dayRange.startLocal,
    endExclusiveLocal: dayRange.endExclusiveLocal,
  );

  return aggregates.isNotEmpty
      ? aggregates.first
      : DailySleepAggregate.empty(dayRange.startLocal);
});

/// Provider for the computed sleep goal state
final sleepGoalProvider = Provider<SleepGoalComputed>((ref) {
  final todayAggregate = ref.watch(todayAggregateProvider);
  final activeBaby = ref.watch(activeBabyProvider);
  final expectationsAsync = ref.watch(activeBabySleepExpectationsProvider);

  // No baby selected
  if (activeBaby == null) {
    return SleepGoalComputed.noBirthDate();
  }

  // Get expectations if available
  final expectationsData = expectationsAsync.valueOrNull;
  final expectations = expectationsData?.expectations;

  return SleepGoalCalculator.compute(
    todayTotalMinutes: todayAggregate.totalMinutes,
    birthDate: activeBaby.birthDate,
    hasOngoingSleep: todayAggregate.hasOngoingSleep,
    expectations: expectations,
  );
});

/// Provider for the last 7 days aggregates (for data quality assessment)
final last7DaysAggregatesProvider = Provider<List<DailySleepAggregate>>((ref) {
  final eventsAsync = ref.watch(sleepEventsNotifierProvider);

  // Calculate date range: last 7 days including today
  final now = DateTime.now();
  final todayRange = LocalTimeUtils.localDayRange(now);
  final startLocal = todayRange.startLocal.subtract(const Duration(days: 6));
  final endExclusiveLocal = todayRange.endExclusiveLocal;

  // Return empty list if no events loaded
  if (!eventsAsync.hasValue || eventsAsync.value == null) {
    return [];
  }

  // Derive sessions from events
  final events = eventsAsync.value!;
  final sessions = SleepSession.fromEventList(events);

  // Calculate aggregates
  return DailySleepAggregateCalculator.calculate(
    sessions: sessions,
    startLocal: startLocal,
    endExclusiveLocal: endExclusiveLocal,
  );
});

/// Provider for data quality assessment for the cockpit
final sleepDataQualityProvider = Provider<DataQualityAssessment>((ref) {
  final aggregates = ref.watch(last7DaysAggregatesProvider);

  if (aggregates.isEmpty) {
    return DataQualityAssessment.empty();
  }

  return DataQualityAssessmentCalculator.assess(aggregates);
});

/// Provider for all sessions derived from events
final allSessionsProvider = Provider<List<SleepSession>>((ref) {
  final eventsAsync = ref.watch(sleepEventsNotifierProvider);

  if (!eventsAsync.hasValue || eventsAsync.value == null) {
    return [];
  }

  return SleepSession.fromEventList(eventsAsync.value!);
});

/// Provider for next sleep prediction
final nextSleepPredictionProvider = Provider<NextSleepPrediction>((ref) {
  final sessions = ref.watch(allSessionsProvider);
  final dataQuality = ref.watch(sleepDataQualityProvider);

  return NextSleepPredictor.predict(
    sessions: sessions,
    dataQuality: dataQuality.status,
  );
});

/// Provider for the data quality view model
final sleepDataQualityViewModelProvider =
    Provider<SleepDataQualityViewModel>((ref) {
  final assessment = ref.watch(sleepDataQualityProvider);
  final prediction = ref.watch(nextSleepPredictionProvider);

  return SleepDataQualityViewModel(
    assessment: assessment,
    predictionSampleCount: prediction.sampleCount,
    predictionConfidence: prediction.confidence,
  );
});

/// Combined cockpit state for easy consumption
class SleepCockpitState {
  /// Today's aggregate data
  final DailySleepAggregate todayAggregate;

  /// Computed sleep goal
  final SleepGoalComputed goal;

  /// Data quality assessment
  final DataQualityAssessment dataQuality;

  /// Data quality view model (for UI)
  final SleepDataQualityViewModel dataQualityViewModel;

  /// Next sleep prediction
  final NextSleepPrediction prediction;

  /// Sessions for today (for timeline)
  List<SleepSession> get todaySessions => todayAggregate.sessions;

  /// Whether data quality is good
  bool get isDataQualityGood => dataQuality.status == DataQualityStatus.good;

  /// Whether prediction is available and should be shown
  bool get showPrediction => prediction.isAvailable;

  /// Whether to show the data quality warning badge in the prediction card
  bool get showDataQualityBadge => dataQualityViewModel.showWarningBadge;

  const SleepCockpitState({
    required this.todayAggregate,
    required this.goal,
    required this.dataQuality,
    required this.dataQualityViewModel,
    required this.prediction,
  });
}

/// Provider for the combined cockpit state
final sleepCockpitProvider = Provider<SleepCockpitState>((ref) {
  return SleepCockpitState(
    todayAggregate: ref.watch(todayAggregateProvider),
    goal: ref.watch(sleepGoalProvider),
    dataQuality: ref.watch(sleepDataQualityProvider),
    dataQualityViewModel: ref.watch(sleepDataQualityViewModelProvider),
    prediction: ref.watch(nextSleepPredictionProvider),
  );
});
