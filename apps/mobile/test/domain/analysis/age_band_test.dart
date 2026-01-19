import 'package:flutter_test/flutter_test.dart';
import 'package:temp_flutter/domain/analysis/age_band.dart';

void main() {
  group('AgeCalculator', () {
    group('ageInDays', () {
      test('returns null when birthDate is null', () {
        expect(AgeCalculator.ageInDays(null), isNull);
      });

      test('returns null when birthDate is in the future', () {
        final futureDate = DateTime.now().add(const Duration(days: 10));
        expect(AgeCalculator.ageInDays(futureDate), isNull);
      });

      test('returns 0 for today', () {
        final today = DateTime.now();
        final todayStart = DateTime(today.year, today.month, today.day);
        expect(AgeCalculator.ageInDays(todayStart, referenceDate: todayStart), 0);
      });

      test('returns correct days for a week ago', () {
        final now = DateTime(2026, 1, 19);
        final weekAgo = DateTime(2026, 1, 12);
        expect(AgeCalculator.ageInDays(weekAgo, referenceDate: now), 7);
      });

      test('returns correct days for exactly 28 days', () {
        final now = DateTime(2026, 1, 28);
        final birthDate = DateTime(2025, 12, 31);
        expect(AgeCalculator.ageInDays(birthDate, referenceDate: now), 28);
      });
    });

    group('ageInMonths', () {
      test('returns null when birthDate is null', () {
        expect(AgeCalculator.ageInMonths(null), isNull);
      });

      test('returns approximately 3 months for 91 days', () {
        final now = DateTime(2026, 1, 19);
        final birthDate = now.subtract(const Duration(days: 91));
        final months = AgeCalculator.ageInMonths(birthDate, referenceDate: now)!;
        expect(months, closeTo(3.0, 0.1));
      });
    });

    group('ageBand', () {
      test('returns unknown for null birthDate', () {
        expect(AgeCalculator.ageBand(null), SleepAgeBand.unknown);
      });

      test('returns newborn0to28d for 0 days', () {
        final now = DateTime(2026, 1, 19);
        final birthDate = now;
        expect(AgeCalculator.ageBand(birthDate, referenceDate: now), SleepAgeBand.newborn0to28d);
      });

      test('returns newborn0to28d for exactly 28 days', () {
        final now = DateTime(2026, 1, 28);
        final birthDate = DateTime(2025, 12, 31);
        expect(AgeCalculator.ageBand(birthDate, referenceDate: now), SleepAgeBand.newborn0to28d);
      });

      test('returns months1to2 for 29 days', () {
        final now = DateTime(2026, 1, 29);
        final birthDate = DateTime(2025, 12, 31);
        expect(AgeCalculator.ageBand(birthDate, referenceDate: now), SleepAgeBand.months1to2);
      });

      test('returns months1to2 for 60 days', () {
        final now = DateTime(2026, 3, 1);
        final birthDate = DateTime(2025, 12, 31);
        expect(AgeCalculator.ageBand(birthDate, referenceDate: now), SleepAgeBand.months1to2);
      });

      test('returns months2to4 for 61 days', () {
        final now = DateTime(2026, 3, 2);
        final birthDate = DateTime(2025, 12, 31);
        expect(AgeCalculator.ageBand(birthDate, referenceDate: now), SleepAgeBand.months2to4);
      });

      test('returns months4to6 for 150 days (~5 months)', () {
        final now = DateTime(2026, 1, 19);
        final birthDate = now.subtract(const Duration(days: 150));
        expect(AgeCalculator.ageBand(birthDate, referenceDate: now), SleepAgeBand.months4to6);
      });

      test('returns months6to9 for 200 days', () {
        final now = DateTime(2026, 1, 19);
        final birthDate = now.subtract(const Duration(days: 200));
        expect(AgeCalculator.ageBand(birthDate, referenceDate: now), SleepAgeBand.months6to9);
      });

      test('returns months9to12 for 300 days', () {
        final now = DateTime(2026, 1, 19);
        final birthDate = now.subtract(const Duration(days: 300));
        expect(AgeCalculator.ageBand(birthDate, referenceDate: now), SleepAgeBand.months9to12);
      });

      test('returns months12to18 for 400 days', () {
        final now = DateTime(2026, 1, 19);
        final birthDate = now.subtract(const Duration(days: 400));
        expect(AgeCalculator.ageBand(birthDate, referenceDate: now), SleepAgeBand.months12to18);
      });

      test('returns months18to24 for 600 days', () {
        final now = DateTime(2026, 1, 19);
        final birthDate = now.subtract(const Duration(days: 600));
        expect(AgeCalculator.ageBand(birthDate, referenceDate: now), SleepAgeBand.months18to24);
      });

      test('returns years2to3 for 800 days', () {
        final now = DateTime(2026, 1, 19);
        final birthDate = now.subtract(const Duration(days: 800));
        expect(AgeCalculator.ageBand(birthDate, referenceDate: now), SleepAgeBand.years2to3);
      });

      test('returns years3plus for 1200 days', () {
        final now = DateTime(2026, 1, 19);
        final birthDate = now.subtract(const Duration(days: 1200));
        expect(AgeCalculator.ageBand(birthDate, referenceDate: now), SleepAgeBand.years3plus);
      });
    });
  });

  group('SleepAgeBand', () {
    test('labelPt returns correct Portuguese labels', () {
      expect(SleepAgeBand.newborn0to28d.labelPt, 'Recém-nascido (0-4 semanas)');
      expect(SleepAgeBand.months1to2.labelPt, '1-2 meses');
      expect(SleepAgeBand.months4to6.labelPt, '4-6 meses');
      expect(SleepAgeBand.years3plus.labelPt, '3+ anos');
      expect(SleepAgeBand.unknown.labelPt, 'Idade desconhecida');
    });

    test('shortLabelPt returns compact labels', () {
      expect(SleepAgeBand.newborn0to28d.shortLabelPt, '0-4 sem');
      expect(SleepAgeBand.months1to2.shortLabelPt, '1-2m');
      expect(SleepAgeBand.years3plus.shortLabelPt, '3+a');
    });

    test('hasExpectations returns false only for unknown', () {
      expect(SleepAgeBand.newborn0to28d.hasExpectations, isTrue);
      expect(SleepAgeBand.months4to6.hasExpectations, isTrue);
      expect(SleepAgeBand.unknown.hasExpectations, isFalse);
    });
  });
}
