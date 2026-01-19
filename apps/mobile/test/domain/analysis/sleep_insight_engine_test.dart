import 'package:flutter_test/flutter_test.dart';
import 'package:temp_flutter/domain/analysis/age_band.dart';
import 'package:temp_flutter/domain/analysis/sleep_expectations.dart';
import 'package:temp_flutter/domain/analysis/sleep_insight.dart';
import 'package:temp_flutter/domain/analysis/sleep_insight_engine.dart';
import 'package:temp_flutter/domain/analysis/sleep_metrics.dart';

void main() {
  group('SleepInsightEngine', () {
    final now = DateTime(2026, 1, 19, 12, 0);

    SleepMetrics _createMetrics({
      Duration totalSleepLast24h = const Duration(hours: 12),
      int napCountLast24h = 2,
      double fragmentationScore = 0.2,
      double? bedtimeConsistencyMinutes = 20,
      int daysWithData = 5,
      bool isCurrentlySleeping = false,
    }) {
      return SleepMetrics(
        totalSleepLast24h: totalSleepLast24h,
        napCountLast24h: napCountLast24h,
        shortNapRate: 0.3,
        fragmentationScore: fragmentationScore,
        bedtimeConsistencyMinutes: bedtimeConsistencyMinutes,
        isCurrentlySleeping: isCurrentlySleeping,
        totalSleepByDay: {
          '2026-01-18': const Duration(hours: 12),
          '2026-01-17': const Duration(hours: 11),
        },
        sessionCountLast24h: 3,
        daysWithData: daysWithData,
        calculatedAt: now,
      );
    }

    const expectations4to6m = SleepExpectations(
      ageBand: SleepAgeBand.months4to6,
      totalSleep24hMin: 720, // 12h
      totalSleep24hMax: 900, // 15h
      wakeWindowDayMin: 105,
      wakeWindowDayMax: 150,
      wakeWindowPreBedMin: 120,
      wakeWindowPreBedMax: 180,
      descriptionPt: 'O sono nocturno torna-se mais longo.',
    );

    group('with age expectations', () {
      test('returns within range for sleep in expected range', () {
        final metrics = _createMetrics(
          totalSleepLast24h: const Duration(hours: 13), // Within 12-15h
        );

        final result = SleepInsightEngine.generate(
          metrics: metrics,
          expectations: expectations4to6m,
          babyName: 'João',
        );

        expect(result.hasAgeExpectations, isTrue);
        expect(result.rangeComparison, RangeComparison.within);

        final totalSleepInsight = result.allInsights.firstWhere(
          (i) => i.id == 'total_sleep_24h',
        );
        expect(totalSleepInsight.tone, InsightTone.positive);
        expect(totalSleepInsight.messagePt, contains('dentro do esperado'));
      });

      test('returns below for sleep under minimum', () {
        final metrics = _createMetrics(
          totalSleepLast24h: const Duration(hours: 10), // Below 12h min
        );

        final result = SleepInsightEngine.generate(
          metrics: metrics,
          expectations: expectations4to6m,
          babyName: 'Maria',
        );

        expect(result.rangeComparison, RangeComparison.below);

        final totalSleepInsight = result.allInsights.firstWhere(
          (i) => i.id == 'total_sleep_24h',
        );
        expect(totalSleepInsight.tone, InsightTone.attention);
        expect(totalSleepInsight.messagePt, contains('abaixo do esperado'));
      });

      test('returns above for sleep over maximum', () {
        final metrics = _createMetrics(
          totalSleepLast24h: const Duration(hours: 16), // Above 15h max
        );

        final result = SleepInsightEngine.generate(
          metrics: metrics,
          expectations: expectations4to6m,
          babyName: 'Pedro',
        );

        expect(result.rangeComparison, RangeComparison.above);

        final totalSleepInsight = result.allInsights.firstWhere(
          (i) => i.id == 'total_sleep_24h',
        );
        expect(totalSleepInsight.tone, InsightTone.neutral);
        expect(totalSleepInsight.messagePt, contains('acima do esperado'));
      });
    });

    group('without age expectations', () {
      test('returns generic insight without range comparison', () {
        final metrics = _createMetrics(
          totalSleepLast24h: const Duration(hours: 11),
        );

        final result = SleepInsightEngine.generate(
          metrics: metrics,
          expectations: null,
          babyName: 'Ana',
        );

        expect(result.hasAgeExpectations, isFalse);
        expect(result.rangeComparison, isNull);

        // Should have a no_birthdate prompt
        final noBirthdateInsight = result.allInsights.firstWhere(
          (i) => i.id == 'no_birthdate',
        );
        expect(noBirthdateInsight, isNotNull);
        expect(noBirthdateInsight.messagePt, contains('data de nascimento'));
      });

      test('returns generic total sleep insight', () {
        final metrics = _createMetrics(
          totalSleepLast24h: const Duration(hours: 11),
        );

        final result = SleepInsightEngine.generate(
          metrics: metrics,
          expectations: null,
          babyName: 'Ana',
        );

        final insight = result.allInsights.firstWhere(
          (i) => i.id == 'total_sleep_24h_generic',
        );
        expect(insight, isNotNull);
        expect(insight.messagePt, contains('11h'));
      });
    });

    group('fragmentation', () {
      test('generates fragmentation insight when score is high', () {
        final metrics = _createMetrics(
          fragmentationScore: 0.6,
        );

        final result = SleepInsightEngine.generate(
          metrics: metrics,
          expectations: expectations4to6m,
          babyName: 'Lucas',
        );

        final fragmentationInsight = result.allInsights.firstWhere(
          (i) => i.id == 'fragmentation',
        );
        expect(fragmentationInsight, isNotNull);
        // 0.6 is > 0.5 but <= 0.7, so it says "tem algumas interrupções"
        expect(fragmentationInsight.messagePt, contains('interrupções'));
        expect(fragmentationInsight.tone, InsightTone.attention);
      });

      test('includes calming routine action for high fragmentation', () {
        final metrics = _createMetrics(
          fragmentationScore: 0.7,
        );

        final result = SleepInsightEngine.generate(
          metrics: metrics,
          expectations: expectations4to6m,
          babyName: 'Lucas',
        );

        expect(result.hasActions, isTrue);
        final calmingAction = result.suggestedActions.firstWhere(
          (a) => a.id == 'action_calming_routine',
        );
        expect(calmingAction, isNotNull);
        expect(calmingAction.titlePt, 'Rotina calmante');
      });
    });

    group('consistency', () {
      test('generates positive consistency insight when consistent', () {
        final metrics = _createMetrics(
          bedtimeConsistencyMinutes: 15,
        );

        final result = SleepInsightEngine.generate(
          metrics: metrics,
          expectations: expectations4to6m,
          babyName: 'Sofia',
        );

        final consistencyInsight = result.allInsights.firstWhere(
          (i) => i.id == 'bedtime_consistency',
        );
        expect(consistencyInsight, isNotNull);
        expect(consistencyInsight.tone, InsightTone.positive);
        expect(consistencyInsight.messagePt, contains('consistente'));
      });

      test('generates attention insight when inconsistent', () {
        final metrics = _createMetrics(
          bedtimeConsistencyMinutes: 75,
        );

        final result = SleepInsightEngine.generate(
          metrics: metrics,
          expectations: expectations4to6m,
          babyName: 'Miguel',
        );

        final consistencyInsight = result.allInsights.firstWhere(
          (i) => i.id == 'bedtime_consistency',
        );
        expect(consistencyInsight, isNotNull);
        expect(consistencyInsight.tone, InsightTone.attention);
        expect(consistencyInsight.messagePt, contains('variado'));
      });
    });

    group('insufficient data', () {
      test('returns single insight when no minimum data', () {
        final metrics = SleepMetrics.empty(calculatedAt: now);

        final result = SleepInsightEngine.generate(
          metrics: metrics,
          expectations: expectations4to6m,
          babyName: 'Test',
        );

        expect(result.allInsights.length, 1);
        expect(result.allInsights.first.id, 'insufficient_data');
        expect(result.topInsights, isEmpty);
        expect(result.suggestedActions, isEmpty);
      });
    });

    group('topInsights', () {
      test('returns max 2 top insights', () {
        final metrics = _createMetrics(
          fragmentationScore: 0.6,
          bedtimeConsistencyMinutes: 70,
        );

        final result = SleepInsightEngine.generate(
          metrics: metrics,
          expectations: expectations4to6m,
          babyName: 'Test',
        );

        expect(result.topInsights.length, lessThanOrEqualTo(2));
      });

      test('excludes currently_sleeping and no_birthdate from top insights', () {
        final metrics = _createMetrics(isCurrentlySleeping: true);

        final result = SleepInsightEngine.generate(
          metrics: metrics,
          expectations: null,
          babyName: 'Test',
        );

        final topIds = result.topInsights.map((i) => i.id).toList();
        expect(topIds, isNot(contains('currently_sleeping')));
        expect(topIds, isNot(contains('no_birthdate')));
      });
    });

    group('no medical language', () {
      test('insights do not contain medical terms', () {
        final metrics = _createMetrics(
          totalSleepLast24h: const Duration(hours: 8),
          fragmentationScore: 0.8,
        );

        final result = SleepInsightEngine.generate(
          metrics: metrics,
          expectations: expectations4to6m,
          babyName: 'Test',
        );

        final allText = result.allInsights
            .map((i) => i.messagePt.toLowerCase())
            .join(' ');

        // Forbidden medical terms
        expect(allText, isNot(contains('diagnóstico')));
        expect(allText, isNot(contains('doença')));
        expect(allText, isNot(contains('tratamento')));
        expect(allText, isNot(contains('patologia')));
        expect(allText, isNot(contains('médico')));
        expect(allText, isNot(contains('consultar')));
      });
    });
  });
}
