import 'package:flutter_test/flutter_test.dart';
import 'package:temp_flutter/domain/stats/daily_sleep_aggregate.dart';
import 'package:temp_flutter/domain/stats/period_kpis.dart';

void main() {
  group('PeriodKPIsCalculator', () {
    test('calculates median correctly for odd number of days', () {
      final aggregates = [
        _createAggregate(date: DateTime(2024, 1, 1), totalMinutes: 600),
        _createAggregate(date: DateTime(2024, 1, 2), totalMinutes: 700),
        _createAggregate(date: DateTime(2024, 1, 3), totalMinutes: 800),
      ];

      final kpis = PeriodKPIsCalculator.calculate(aggregates);

      expect(kpis.medianTotalMinutesPerDay, 700);
    });

    test('calculates median correctly for even number of days', () {
      final aggregates = [
        _createAggregate(date: DateTime(2024, 1, 1), totalMinutes: 600),
        _createAggregate(date: DateTime(2024, 1, 2), totalMinutes: 700),
        _createAggregate(date: DateTime(2024, 1, 3), totalMinutes: 800),
        _createAggregate(date: DateTime(2024, 1, 4), totalMinutes: 900),
      ];

      final kpis = PeriodKPIsCalculator.calculate(aggregates);

      // Median of 600, 700, 800, 900 = (700 + 800) / 2 = 750
      expect(kpis.medianTotalMinutesPerDay, 750);
    });

    test('calculates average correctly', () {
      final aggregates = [
        _createAggregate(date: DateTime(2024, 1, 1), totalMinutes: 600),
        _createAggregate(date: DateTime(2024, 1, 2), totalMinutes: 700),
        _createAggregate(date: DateTime(2024, 1, 3), totalMinutes: 800),
      ];

      final kpis = PeriodKPIsCalculator.calculate(aggregates);

      expect(kpis.avgTotalMinutesPerDay, 700);
    });

    test('calculates night percentage correctly', () {
      final aggregates = [
        _createAggregate(
          date: DateTime(2024, 1, 1),
          totalMinutes: 600,
          nightMinutes: 480,
          napMinutes: 120,
        ),
      ];

      final kpis = PeriodKPIsCalculator.calculate(aggregates);

      expect(kpis.nightPercentage, closeTo(0.8, 0.01)); // 480 / 600 = 0.8
      expect(kpis.napPercentage, closeTo(0.2, 0.01));
    });

    test('finds longest block correctly', () {
      final aggregates = [
        _createAggregate(
          date: DateTime(2024, 1, 1),
          totalMinutes: 600,
          longestBlockMinutes: 300,
        ),
        _createAggregate(
          date: DateTime(2024, 1, 2),
          totalMinutes: 600,
          longestBlockMinutes: 420,
        ),
        _createAggregate(
          date: DateTime(2024, 1, 3),
          totalMinutes: 600,
          longestBlockMinutes: 360,
        ),
      ];

      final kpis = PeriodKPIsCalculator.calculate(aggregates);

      expect(kpis.longestBlockMinutes, 420);
    });

    test('calculates fragmentation correctly', () {
      final aggregates = [
        _createAggregate(
          date: DateTime(2024, 1, 1),
          totalMinutes: 600,
          nightEpisodesCount: 2,
        ),
        _createAggregate(
          date: DateTime(2024, 1, 2),
          totalMinutes: 600,
          nightEpisodesCount: 4,
        ),
        _createAggregate(
          date: DateTime(2024, 1, 3),
          totalMinutes: 600,
          nightEpisodesCount: 3,
        ),
      ];

      final kpis = PeriodKPIsCalculator.calculate(aggregates);

      expect(kpis.avgNightEpisodes, 3.0); // (2 + 4 + 3) / 3
    });

    test('ignores days without data for statistics', () {
      final aggregates = [
        _createAggregate(date: DateTime(2024, 1, 1), totalMinutes: 600),
        _createAggregate(date: DateTime(2024, 1, 2), totalMinutes: 0), // No data
        _createAggregate(date: DateTime(2024, 1, 3), totalMinutes: 800),
      ];

      final kpis = PeriodKPIsCalculator.calculate(aggregates);

      expect(kpis.daysWithData, 2);
      expect(kpis.totalDays, 3);
      expect(kpis.medianTotalMinutesPerDay, 700); // Median of 600, 800
    });

    test('returns empty KPIs for empty list', () {
      final kpis = PeriodKPIsCalculator.calculate([]);

      expect(kpis.medianTotalMinutesPerDay, 0);
      expect(kpis.avgTotalMinutesPerDay, 0);
      expect(kpis.daysWithData, 0);
      expect(kpis.totalDays, 0);
    });
  });

  group('KPIComparison', () {
    test('calculates deltas correctly', () {
      final current = PeriodKPIs(
        medianTotalMinutesPerDay: 720,
        avgTotalMinutesPerDay: 720,
        totalNightMinutes: 4800,
        totalNapMinutes: 1200,
        nightPercentage: 0.8,
        longestBlockMinutes: 420,
        avgNightEpisodes: 2.0,
        daysWithData: 7,
        totalDays: 7,
      );

      final previous = PeriodKPIs(
        medianTotalMinutesPerDay: 700,
        avgTotalMinutesPerDay: 700,
        totalNightMinutes: 4600,
        totalNapMinutes: 1400,
        nightPercentage: 0.77,
        longestBlockMinutes: 380,
        avgNightEpisodes: 2.5,
        daysWithData: 7,
        totalDays: 7,
      );

      final comparison = KPIComparison(current: current, previous: previous);

      expect(comparison.deltaAvgMinutesPerDay, 20); // 720 - 700
      expect(comparison.deltaLongestBlock, 40); // 420 - 380
      expect(comparison.deltaAvgNightEpisodes, -0.5); // 2.0 - 2.5 (improvement!)
      expect(comparison.deltaNightPercentagePoints, closeTo(3.0, 0.1)); // 80% - 77%
    });
  });
}

DailySleepAggregate _createAggregate({
  required DateTime date,
  int totalMinutes = 0,
  int nightMinutes = 0,
  int napMinutes = 0,
  int longestBlockMinutes = 0,
  int nightEpisodesCount = 0,
}) {
  final total = totalMinutes > 0 ? totalMinutes : nightMinutes + napMinutes;

  return DailySleepAggregate(
    dateLocal: date,
    totalMinutes: total,
    nightMinutes: nightMinutes,
    napMinutes: napMinutes,
    longestBlockMinutes: longestBlockMinutes,
    nightEpisodesCount: nightEpisodesCount,
    sessions: const [],
  );
}
