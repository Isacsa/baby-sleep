import 'package:flutter_test/flutter_test.dart';
import 'package:temp_flutter/domain/analysis/sleep_goal.dart';

void main() {
  group('SleepGoalRange', () {
    group('fromAgeMonths', () {
      test('0-3 months returns 14-17h range', () {
        final range0 = SleepGoalRange.fromAgeMonths(0);
        expect(range0.minMinutes, 14 * 60);
        expect(range0.maxMinutes, 17 * 60);

        final range2 = SleepGoalRange.fromAgeMonths(2);
        expect(range2.minMinutes, 14 * 60);
        expect(range2.maxMinutes, 17 * 60);

        final range3 = SleepGoalRange.fromAgeMonths(3.5);
        expect(range3.minMinutes, 14 * 60);
        expect(range3.maxMinutes, 17 * 60);
      });

      test('4-12 months returns 12-16h range', () {
        final range4 = SleepGoalRange.fromAgeMonths(4);
        expect(range4.minMinutes, 12 * 60);
        expect(range4.maxMinutes, 16 * 60);

        final range8 = SleepGoalRange.fromAgeMonths(8);
        expect(range8.minMinutes, 12 * 60);
        expect(range8.maxMinutes, 16 * 60);

        final range12 = SleepGoalRange.fromAgeMonths(12);
        expect(range12.minMinutes, 12 * 60);
        expect(range12.maxMinutes, 16 * 60);
      });

      test('13-24 months returns 11-14h range', () {
        final range13 = SleepGoalRange.fromAgeMonths(13);
        expect(range13.minMinutes, 11 * 60);
        expect(range13.maxMinutes, 14 * 60);

        final range18 = SleepGoalRange.fromAgeMonths(18);
        expect(range18.minMinutes, 11 * 60);
        expect(range18.maxMinutes, 14 * 60);

        final range24 = SleepGoalRange.fromAgeMonths(24);
        expect(range24.minMinutes, 11 * 60);
        expect(range24.maxMinutes, 14 * 60);
      });

      test('25+ months returns 11-14h fallback range', () {
        final range25 = SleepGoalRange.fromAgeMonths(25);
        expect(range25.minMinutes, 11 * 60);
        expect(range25.maxMinutes, 14 * 60);

        final range36 = SleepGoalRange.fromAgeMonths(36);
        expect(range36.minMinutes, 11 * 60);
        expect(range36.maxMinutes, 14 * 60);
      });
    });

    test('unknown returns generic 10-18h range', () {
      final range = SleepGoalRange.unknown();
      expect(range.minMinutes, 10 * 60);
      expect(range.maxMinutes, 18 * 60);
      expect(range.source, SleepGoalSource.generic);
    });

    test('formatting works correctly', () {
      final range = SleepGoalRange.fromAgeMonths(6);
      expect(range.minFormatted, '12h');
      expect(range.maxFormatted, '16h');
      expect(range.rangeFormatted, '12h–16h');
    });
  });

  group('SleepGoalComputed', () {
    test('noBirthDate creates correct state', () {
      final goal = SleepGoalComputed.noBirthDate();
      expect(goal.status, SleepGoalStatus.noBirthDate);
      expect(goal.totalMinutes, 0);
      expect(goal.ageMonths, null);
    });

    test('noData creates correct state', () {
      final range = SleepGoalRange.fromAgeMonths(6);
      final goal = SleepGoalComputed.noData(goalRange: range, ageMonths: 6);
      expect(goal.status, SleepGoalStatus.noData);
      expect(goal.totalMinutes, 0);
      expect(goal.ageMonths, 6);
    });

    group('compute', () {
      test('below status when total < min', () {
        final goal = SleepGoalComputed.compute(
          totalMinutes: 10 * 60, // 10h
          goalRange: SleepGoalRange.fromAgeMonths(6), // 12-16h
          ageMonths: 6,
          hasOngoingSleep: false,
        );
        expect(goal.status, SleepGoalStatus.below);
        expect(goal.progressToMin, closeTo(10 / 12, 0.01));
      });

      test('within status when min <= total <= max', () {
        final goal = SleepGoalComputed.compute(
          totalMinutes: 14 * 60, // 14h
          goalRange: SleepGoalRange.fromAgeMonths(6), // 12-16h
          ageMonths: 6,
          hasOngoingSleep: false,
        );
        expect(goal.status, SleepGoalStatus.within);
        expect(goal.progressToMin, closeTo(14 / 12, 0.01));
      });

      test('above status when total > max', () {
        final goal = SleepGoalComputed.compute(
          totalMinutes: 18 * 60, // 18h
          goalRange: SleepGoalRange.fromAgeMonths(6), // 12-16h
          ageMonths: 6,
          hasOngoingSleep: false,
        );
        expect(goal.status, SleepGoalStatus.above);
        expect(goal.progressToMax, closeTo(18 / 16, 0.01));
      });

      test('inProgress status when hasOngoingSleep is true', () {
        final goal = SleepGoalComputed.compute(
          totalMinutes: 8 * 60,
          goalRange: SleepGoalRange.fromAgeMonths(6),
          ageMonths: 6,
          hasOngoingSleep: true,
        );
        expect(goal.status, SleepGoalStatus.inProgress);
      });

      test('noData status when totalMinutes is 0', () {
        final goal = SleepGoalComputed.compute(
          totalMinutes: 0,
          goalRange: SleepGoalRange.fromAgeMonths(6),
          ageMonths: 6,
          hasOngoingSleep: false,
        );
        expect(goal.status, SleepGoalStatus.noData);
      });
    });

    test('isUnder4Months returns true for young babies', () {
      final goal = SleepGoalComputed.compute(
        totalMinutes: 14 * 60,
        goalRange: SleepGoalRange.fromAgeMonths(2),
        ageMonths: 2,
        hasOngoingSleep: false,
      );
      expect(goal.isUnder4Months, true);
    });

    test('isUnder4Months returns false for older babies', () {
      final goal = SleepGoalComputed.compute(
        totalMinutes: 14 * 60,
        goalRange: SleepGoalRange.fromAgeMonths(6),
        ageMonths: 6,
        hasOngoingSleep: false,
      );
      expect(goal.isUnder4Months, false);
    });

    test('totalFormatted formats correctly', () {
      expect(
        SleepGoalComputed.compute(
          totalMinutes: 90,
          goalRange: SleepGoalRange.fromAgeMonths(6),
          ageMonths: 6,
          hasOngoingSleep: false,
        ).totalFormatted,
        '1h 30m',
      );

      expect(
        SleepGoalComputed.compute(
          totalMinutes: 60,
          goalRange: SleepGoalRange.fromAgeMonths(6),
          ageMonths: 6,
          hasOngoingSleep: false,
        ).totalFormatted,
        '1h',
      );

      expect(
        SleepGoalComputed.compute(
          totalMinutes: 45,
          goalRange: SleepGoalRange.fromAgeMonths(6),
          ageMonths: 6,
          hasOngoingSleep: false,
        ).totalFormatted,
        '45m',
      );
    });
  });

  group('SleepGoalCalculator', () {
    test('compute returns noBirthDate when birthDate is null', () {
      final goal = SleepGoalCalculator.compute(
        todayTotalMinutes: 10 * 60,
        birthDate: null,
      );
      expect(goal.status, SleepGoalStatus.noBirthDate);
    });

    test('compute uses age-based range from birthDate', () {
      final now = DateTime.now();
      final birthDate = now.subtract(const Duration(days: 180)); // ~6 months

      final goal = SleepGoalCalculator.compute(
        todayTotalMinutes: 14 * 60,
        birthDate: birthDate,
      );

      expect(goal.goalRange.minMinutes, 12 * 60); // 4-12m range
      expect(goal.goalRange.maxMinutes, 16 * 60);
      expect(goal.status, SleepGoalStatus.within);
    });

    test('compute handles hasOngoingSleep', () {
      final now = DateTime.now();
      final birthDate = now.subtract(const Duration(days: 180));

      final goal = SleepGoalCalculator.compute(
        todayTotalMinutes: 8 * 60,
        birthDate: birthDate,
        hasOngoingSleep: true,
      );

      expect(goal.status, SleepGoalStatus.inProgress);
      expect(goal.hasOngoingSleep, true);
    });
  });
}
