import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:temp_flutter/application/providers/stats_aggregates_provider.dart';
import 'package:temp_flutter/domain/stats/data_quality_assessment.dart';

/// Provider for data quality assessment of the current stats period.
final statsDataQualityProvider = Provider<AsyncValue<DataQualityAssessment>>((ref) {
  final aggregatesAsync = ref.watch(statsDailyAggregatesProvider);

  return aggregatesAsync.when(
    data: (aggregates) {
      final assessment = DataQualityAssessmentCalculator.assess(aggregates);
      return AsyncValue.data(assessment);
    },
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
  );
});
