import 'package:flutter_test/flutter_test.dart';
import 'package:temp_flutter/domain/analysis/age_band.dart';
import 'package:temp_flutter/domain/analysis/sleep_expectations.dart';
import 'package:temp_flutter/domain/analysis/sleep_metrics.dart';
import 'package:temp_flutter/domain/analysis/sleep_routine_suggester.dart';

void main() {
  group('SleepRoutineSuggester', () {
    final now = DateTime(2026, 1, 19, 14, 0); // 2pm

    SleepMetrics _createMetrics({
      DateTime? lastWakeTime,
      bool isCurrentlySleeping = false,
      DateTime? medianBedtime,
    }) {
      return SleepMetrics(
        totalSleepLast24h: const Duration(hours: 12),
        napCountLast24h: 2,
        shortNapRate: 0.3,
        fragmentationScore: 0.2,
        bedtimeConsistencyMinutes: 20,
        lastWakeTime: lastWakeTime,
        isCurrentlySleeping: isCurrentlySleeping,
        currentSessionStart: isCurrentlySleeping ? now.subtract(const Duration(hours: 1)) : null,
        totalSleepByDay: const {},
        sessionCountLast24h: 3,
        medianBedtime: medianBedtime,
        daysWithData: 5,
        calculatedAt: now,
      );
    }

    const expectations4to6m = SleepExpectations(
      ageBand: SleepAgeBand.months4to6,
      totalSleep24hMin: 720,
      totalSleep24hMax: 900,
      wakeWindowDayMin: 105, // 1h45m
      wakeWindowDayMax: 150, // 2h30m
      wakeWindowPreBedMin: 120,
      wakeWindowPreBedMax: 180,
      bedtimeWindowStart: '18:00',
      bedtimeWindowEnd: '20:30',
    );

    group('no data', () {
      test('returns noData when lastWakeTime is null and not sleeping', () {
        final metrics = _createMetrics(lastWakeTime: null);

        final suggestion = SleepRoutineSuggester.suggest(
          metrics: metrics,
          expectations: expectations4to6m,
          now: now,
        );

        expect(suggestion.hasSufficientData, isFalse);
        expect(suggestion.noSuggestionReasonPt, isNotNull);
      });
    });

    group('currently sleeping', () {
      test('returns sleeping suggestion with bedtime info', () {
        final metrics = _createMetrics(
          isCurrentlySleeping: true,
          medianBedtime: DateTime(2026, 1, 19, 19, 30),
        );

        final suggestion = SleepRoutineSuggester.suggest(
          metrics: metrics,
          expectations: expectations4to6m,
          now: now,
        );

        expect(suggestion.isCurrentlySleeping, isTrue);
        expect(suggestion.canSuggestNap, isFalse);
        expect(suggestion.bedtimeSuggested, isNotNull);
      });
    });

    group('with expectations', () {
      test('calculates nap window from lastWakeTime and wake window', () {
        // Wake at 12:30 so the window (12:30 + 105min = 14:15, 12:30 + 150min = 15:00)
        // is still in the future at 2pm
        final lastWake = DateTime(2026, 1, 19, 12, 30);
        final metrics = _createMetrics(lastWakeTime: lastWake);

        final suggestion = SleepRoutineSuggester.suggest(
          metrics: metrics,
          expectations: expectations4to6m,
          now: now, // 14:00
        );

        expect(suggestion.hasSufficientData, isTrue);
        expect(suggestion.canSuggestNap, isTrue);

        // Wake window is 105-150 min (1h45m - 2h30m)
        // lastWake 12:30 + 105min = 14:15
        // lastWake 12:30 + 150min = 15:00
        expect(suggestion.nextNapWindowStart, DateTime(2026, 1, 19, 14, 15));
        expect(suggestion.nextNapWindowEnd, DateTime(2026, 1, 19, 15, 0));

        // Suggested is midpoint (127 min = 2h7m) = 14:37
        expect(suggestion.nextNapSuggested!.hour, 14);
      });

      test('returns null nap when window has passed', () {
        // Woke at 10am, now is 2pm = 4 hours ago (well past 2.5h window)
        final lastWake = DateTime(2026, 1, 19, 10, 0);
        final metrics = _createMetrics(lastWakeTime: lastWake);

        final suggestion = SleepRoutineSuggester.suggest(
          metrics: metrics,
          expectations: expectations4to6m,
          now: now,
        );

        expect(suggestion.canSuggestNap, isFalse);
        expect(suggestion.nextNapSuggested, isNull);
      });

      test('suggests bedtime from expectations window', () {
        final lastWake = DateTime(2026, 1, 19, 15, 0);
        final metrics = _createMetrics(
          lastWakeTime: lastWake,
          medianBedtime: DateTime(2026, 1, 19, 19, 0),
        );

        final suggestion = SleepRoutineSuggester.suggest(
          metrics: metrics,
          expectations: expectations4to6m,
          now: DateTime(2026, 1, 19, 17, 0),
        );

        expect(suggestion.canSuggestBedtime, isTrue);

        // Bedtime window is 18:00-20:30
        expect(suggestion.bedtimeWindowStart?.hour, 18);
        expect(suggestion.bedtimeWindowEnd?.hour, 20);
        expect(suggestion.bedtimeWindowEnd?.minute, 30);
      });
    });

    group('without expectations (generic)', () {
      test('uses generic 2-3h wake window', () {
        final lastWake = DateTime(2026, 1, 19, 12, 0); // Woke at noon
        final metrics = _createMetrics(lastWakeTime: lastWake);

        final suggestion = SleepRoutineSuggester.suggest(
          metrics: metrics,
          expectations: null, // No birthDate
          now: now,
        );

        expect(suggestion.hasSufficientData, isTrue);
        expect(suggestion.canSuggestNap, isTrue);

        // Generic wake window is 2-3h
        // lastWake 12:00 + 2h = 14:00
        // lastWake 12:00 + 3h = 15:00
        expect(suggestion.nextNapWindowStart, DateTime(2026, 1, 19, 14, 0));
        expect(suggestion.nextNapWindowEnd, DateTime(2026, 1, 19, 15, 0));
      });

      test('uses generic bedtime window 19:00-20:30', () {
        final lastWake = DateTime(2026, 1, 19, 15, 0);
        final metrics = _createMetrics(lastWakeTime: lastWake);

        final suggestion = SleepRoutineSuggester.suggest(
          metrics: metrics,
          expectations: null,
          now: DateTime(2026, 1, 19, 17, 0),
        );

        expect(suggestion.bedtimeWindowStart?.hour, 19);
        expect(suggestion.bedtimeWindowEnd?.hour, 20);
        expect(suggestion.bedtimeWindowEnd?.minute, 30);
      });
    });

    group('explanation', () {
      test('includes explanation with age-based info', () {
        final lastWake = DateTime(2026, 1, 19, 12, 0);
        final metrics = _createMetrics(
          lastWakeTime: lastWake,
          medianBedtime: DateTime(2026, 1, 19, 19, 30),
        );

        final suggestion = SleepRoutineSuggester.suggest(
          metrics: metrics,
          expectations: expectations4to6m,
          now: now,
        );

        expect(suggestion.explanationPt, isNotNull);
        expect(suggestion.explanationPt, contains('Acordou'));
        expect(suggestion.explanationPt, contains('idade'));
      });

      test('includes wake window used in wakeWindowUsedMinutes', () {
        final lastWake = DateTime(2026, 1, 19, 12, 0);
        final metrics = _createMetrics(lastWakeTime: lastWake);

        final suggestion = SleepRoutineSuggester.suggest(
          metrics: metrics,
          expectations: expectations4to6m,
          now: now,
        );

        // Midpoint of 105-150 = 127.5
        expect(suggestion.wakeWindowUsedMinutes, 127);
      });
    });

    group('formatTime', () {
      test('formats time correctly', () {
        // Use a wake time where the nap window is still valid
        final suggestion = SleepRoutineSuggester.suggest(
          metrics: _createMetrics(lastWakeTime: DateTime(2026, 1, 19, 12, 30)),
          expectations: expectations4to6m,
          now: now, // 14:00
        );

        // Window should be 14:15-15:00, so nap is suggested
        expect(suggestion.canSuggestNap, isTrue);
        expect(
          suggestion.nextNapFormatted,
          matches(RegExp(r'\d{2}:\d{2}')),
        );
      });
    });
  });
}
