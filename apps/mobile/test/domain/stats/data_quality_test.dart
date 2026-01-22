import 'package:flutter_test/flutter_test.dart';
import 'package:temp_flutter/domain/stats/daily_sleep_aggregate.dart';
import 'package:temp_flutter/domain/stats/data_quality_assessment.dart';

void main() {
  group('DataQualityAssessmentCalculator', () {
    test('returns good status when all days have data', () {
      final aggregates = [
        _createAggregate(date: DateTime(2024, 1, 1), totalMinutes: 600),
        _createAggregate(date: DateTime(2024, 1, 2), totalMinutes: 650),
        _createAggregate(date: DateTime(2024, 1, 3), totalMinutes: 700),
      ];

      final assessment = DataQualityAssessmentCalculator.assess(aggregates);

      expect(assessment.status, DataQualityStatus.good);
      expect(assessment.missingDaysCount, 0);
      expect(assessment.hasIssues, false);
    });

    test('returns partial status when some days are missing', () {
      final aggregates = [
        _createAggregate(date: DateTime(2024, 1, 1), totalMinutes: 600),
        _createAggregate(date: DateTime(2024, 1, 2), totalMinutes: 0), // Missing
        _createAggregate(date: DateTime(2024, 1, 3), totalMinutes: 700),
        _createAggregate(date: DateTime(2024, 1, 4), totalMinutes: 650),
        _createAggregate(date: DateTime(2024, 1, 5), totalMinutes: 620),
        _createAggregate(date: DateTime(2024, 1, 6), totalMinutes: 680),
        _createAggregate(date: DateTime(2024, 1, 7), totalMinutes: 0), // Missing
      ];

      final assessment = DataQualityAssessmentCalculator.assess(aggregates);

      expect(assessment.status, DataQualityStatus.partial);
      expect(assessment.missingDaysCount, 2);
      expect(assessment.hasIssues, true);
    });

    test('returns incomplete status when many days are missing', () {
      final aggregates = [
        _createAggregate(date: DateTime(2024, 1, 1), totalMinutes: 600),
        _createAggregate(date: DateTime(2024, 1, 2), totalMinutes: 0),
        _createAggregate(date: DateTime(2024, 1, 3), totalMinutes: 0),
        _createAggregate(date: DateTime(2024, 1, 4), totalMinutes: 0),
        _createAggregate(date: DateTime(2024, 1, 5), totalMinutes: 0),
      ];

      final assessment = DataQualityAssessmentCalculator.assess(aggregates);

      expect(assessment.status, DataQualityStatus.incomplete);
      expect(assessment.missingDaysCount, 4);
    });

    test('detects improbable durations', () {
      // Note: To properly test this, we'd need to create sessions
      // with improbable durations and include them in the aggregate.
      // For now, this is a placeholder test.
      
      final aggregates = [
        _createAggregate(date: DateTime(2024, 1, 1), totalMinutes: 600),
      ];

      final assessment = DataQualityAssessmentCalculator.assess(aggregates);

      // No improbable durations in empty session list
      expect(assessment.improbableDurationsCount, 0);
    });

    test('calculates completeness percentage correctly', () {
      final aggregates = [
        _createAggregate(date: DateTime(2024, 1, 1), totalMinutes: 600),
        _createAggregate(date: DateTime(2024, 1, 2), totalMinutes: 0),
        _createAggregate(date: DateTime(2024, 1, 3), totalMinutes: 700),
        _createAggregate(date: DateTime(2024, 1, 4), totalMinutes: 0),
      ];

      final assessment = DataQualityAssessmentCalculator.assess(aggregates);

      expect(assessment.completeness, 0.5); // 2 out of 4 days
    });

    test('returns empty assessment for empty list', () {
      final assessment = DataQualityAssessmentCalculator.assess([]);

      expect(assessment.status, DataQualityStatus.good);
      expect(assessment.totalDays, 0);
      expect(assessment.daysWithData, 0);
    });
  });
}

DailySleepAggregate _createAggregate({
  required DateTime date,
  required int totalMinutes,
}) {
  return DailySleepAggregate(
    dateLocal: date,
    totalMinutes: totalMinutes,
    nightMinutes: (totalMinutes * 0.8).round(),
    napMinutes: (totalMinutes * 0.2).round(),
    longestBlockMinutes: (totalMinutes * 0.5).round(),
    nightEpisodesCount: totalMinutes > 0 ? 1 : 0,
    sessions: const [],
  );
}
