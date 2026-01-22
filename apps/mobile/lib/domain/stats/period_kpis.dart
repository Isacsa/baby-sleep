import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:temp_flutter/domain/stats/daily_sleep_aggregate.dart';

/// KPIs (Key Performance Indicators) for a stats period.
///
/// Calculated from daily aggregates to provide summary metrics.
@immutable
class PeriodKPIs {
  /// Median total sleep per day (in minutes)
  final int medianTotalMinutesPerDay;
  
  /// Average total sleep per day (in minutes)
  final double avgTotalMinutesPerDay;
  
  /// Total night sleep in the period (in minutes)
  final int totalNightMinutes;
  
  /// Total nap sleep in the period (in minutes)
  final int totalNapMinutes;
  
  /// Night sleep percentage (0.0-1.0)
  final double nightPercentage;
  
  /// Longest sleep block in the period (in minutes)
  final int longestBlockMinutes;
  
  /// Average night episodes per night (fragmentation)
  final double avgNightEpisodes;
  
  /// Bedtime consistency: range in minutes (max - min)
  final int? bedtimeRangeMinutes;
  
  /// Bedtime consistency: standard deviation in minutes
  final double? bedtimeStdDevMinutes;
  
  /// Number of days with data
  final int daysWithData;
  
  /// Total days in period
  final int totalDays;

  const PeriodKPIs({
    required this.medianTotalMinutesPerDay,
    required this.avgTotalMinutesPerDay,
    required this.totalNightMinutes,
    required this.totalNapMinutes,
    required this.nightPercentage,
    required this.longestBlockMinutes,
    required this.avgNightEpisodes,
    this.bedtimeRangeMinutes,
    this.bedtimeStdDevMinutes,
    required this.daysWithData,
    required this.totalDays,
  });

  /// Creates empty KPIs
  factory PeriodKPIs.empty() {
    return const PeriodKPIs(
      medianTotalMinutesPerDay: 0,
      avgTotalMinutesPerDay: 0,
      totalNightMinutes: 0,
      totalNapMinutes: 0,
      nightPercentage: 0,
      longestBlockMinutes: 0,
      avgNightEpisodes: 0,
      daysWithData: 0,
      totalDays: 0,
    );
  }

  /// Total sleep in the period (in minutes)
  int get totalMinutes => totalNightMinutes + totalNapMinutes;

  /// Nap percentage (0.0-1.0)
  double get napPercentage => 1.0 - nightPercentage;

  /// Whether there's enough data for bedtime consistency (>= 7 nights)
  bool get hasBedtimeConsistency => bedtimeRangeMinutes != null;

  /// Formatted median total per day (e.g., "12.5h")
  String get medianTotalFormatted {
    final hours = medianTotalMinutesPerDay / 60.0;
    return '${hours.toStringAsFixed(1)}h';
  }

  /// Formatted average total per day (e.g., "12.3h")
  String get avgTotalFormatted {
    final hours = avgTotalMinutesPerDay / 60.0;
    return '${hours.toStringAsFixed(1)}h';
  }

  /// Formatted longest block (e.g., "6h 30m")
  String get longestBlockFormatted {
    final hours = longestBlockMinutes ~/ 60;
    final mins = longestBlockMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${mins}m';
    }
    return '${mins}m';
  }

  /// Formatted bedtime consistency (e.g., "±15min")
  String? get bedtimeConsistencyFormatted {
    if (bedtimeRangeMinutes == null) return null;
    final halfRange = bedtimeRangeMinutes! ~/ 2;
    return '±${halfRange}min';
  }
}

/// KPI comparison between two periods.
@immutable
class KPIComparison {
  /// Current period KPIs
  final PeriodKPIs current;
  
  /// Previous period KPIs
  final PeriodKPIs previous;

  const KPIComparison({
    required this.current,
    required this.previous,
  });

  /// Delta in average total minutes per day
  int get deltaAvgMinutesPerDay =>
      (current.avgTotalMinutesPerDay - previous.avgTotalMinutesPerDay).round();

  /// Delta in night percentage (in percentage points)
  double get deltaNightPercentagePoints =>
      (current.nightPercentage - previous.nightPercentage) * 100;

  /// Delta in longest block (in minutes)
  int get deltaLongestBlock =>
      current.longestBlockMinutes - previous.longestBlockMinutes;

  /// Delta in average night episodes
  double get deltaAvgNightEpisodes =>
      current.avgNightEpisodes - previous.avgNightEpisodes;

  /// Formatted delta for average (e.g., "+18min/dia", "-5min/dia")
  String get deltaAvgFormatted {
    final sign = deltaAvgMinutesPerDay >= 0 ? '+' : '';
    return '$sign${deltaAvgMinutesPerDay}min';
  }

  /// Formatted delta for night percentage (e.g., "+3pp", "-2pp")
  String get deltaNightPPFormatted {
    final sign = deltaNightPercentagePoints >= 0 ? '+' : '';
    return '$sign${deltaNightPercentagePoints.toStringAsFixed(0)}pp';
  }

  /// Formatted delta for fragmentation (e.g., "-0.4 episódios/noite")
  String get deltaFragmentationFormatted {
    final sign = deltaAvgNightEpisodes >= 0 ? '+' : '';
    return '$sign${deltaAvgNightEpisodes.toStringAsFixed(1)}';
  }
}

/// Calculator for period KPIs from daily aggregates.
class PeriodKPIsCalculator {
  /// Minimum nights required for bedtime consistency calculation
  static const _minNightsForBedtimeConsistency = 7;

  /// Calculates KPIs from a list of daily aggregates.
  static PeriodKPIs calculate(List<DailySleepAggregate> aggregates) {
    if (aggregates.isEmpty) {
      return PeriodKPIs.empty();
    }

    final totalDays = aggregates.length;
    
    // Filter days with data
    final daysWithData = aggregates.where((a) => a.totalMinutes > 0).toList();
    final daysWithDataCount = daysWithData.length;

    if (daysWithDataCount == 0) {
      return PeriodKPIs(
        medianTotalMinutesPerDay: 0,
        avgTotalMinutesPerDay: 0,
        totalNightMinutes: 0,
        totalNapMinutes: 0,
        nightPercentage: 0,
        longestBlockMinutes: 0,
        avgNightEpisodes: 0,
        daysWithData: 0,
        totalDays: totalDays,
      );
    }

    // Calculate totals
    final totalNightMinutes = aggregates.fold<int>(
      0,
      (sum, a) => sum + a.nightMinutes,
    );
    final totalNapMinutes = aggregates.fold<int>(
      0,
      (sum, a) => sum + a.napMinutes,
    );
    final totalMinutes = totalNightMinutes + totalNapMinutes;

    // Calculate median and average
    final dailyTotals = daysWithData.map((a) => a.totalMinutes).toList()..sort();
    final medianTotal = _median(dailyTotals);
    final avgTotal = dailyTotals.reduce((a, b) => a + b) / daysWithDataCount;

    // Longest block
    final longestBlock = aggregates
        .map((a) => a.longestBlockMinutes)
        .reduce((a, b) => a > b ? a : b);

    // Average night episodes (fragmentation)
    final nightEpisodesSum = aggregates.fold<int>(
      0,
      (sum, a) => sum + a.nightEpisodesCount,
    );
    // Count nights (days with night episodes)
    final nightsWithEpisodes = aggregates.where((a) => a.nightEpisodesCount > 0).length;
    final avgNightEpisodes = nightsWithEpisodes > 0
        ? nightEpisodesSum / nightsWithEpisodes
        : 0.0;

    // Bedtime consistency (only if >= 7 nights with bedtime)
    final bedtimes = aggregates
        .where((a) => a.bedtimeStartLocal != null)
        .map((a) => a.bedtimeStartLocal!)
        .toList();

    int? bedtimeRangeMinutes;
    double? bedtimeStdDevMinutes;

    if (bedtimes.length >= _minNightsForBedtimeConsistency) {
      // Convert to minutes since midnight for comparison
      final bedtimeMinutes = bedtimes.map((dt) {
        var mins = dt.hour * 60 + dt.minute;
        // Handle bedtimes after midnight (0-6am = add 24h)
        if (dt.hour < 6) mins += 24 * 60;
        return mins;
      }).toList();

      final minBedtime = bedtimeMinutes.reduce((a, b) => a < b ? a : b);
      final maxBedtime = bedtimeMinutes.reduce((a, b) => a > b ? a : b);
      bedtimeRangeMinutes = maxBedtime - minBedtime;

      // Standard deviation
      final avgBedtime = bedtimeMinutes.reduce((a, b) => a + b) / bedtimeMinutes.length;
      final variance = bedtimeMinutes
          .map((m) => math.pow(m - avgBedtime, 2))
          .reduce((a, b) => a + b) / bedtimeMinutes.length;
      bedtimeStdDevMinutes = math.sqrt(variance);
    }

    return PeriodKPIs(
      medianTotalMinutesPerDay: medianTotal,
      avgTotalMinutesPerDay: avgTotal,
      totalNightMinutes: totalNightMinutes,
      totalNapMinutes: totalNapMinutes,
      nightPercentage: totalMinutes > 0 ? totalNightMinutes / totalMinutes : 0,
      longestBlockMinutes: longestBlock,
      avgNightEpisodes: avgNightEpisodes,
      bedtimeRangeMinutes: bedtimeRangeMinutes,
      bedtimeStdDevMinutes: bedtimeStdDevMinutes,
      daysWithData: daysWithDataCount,
      totalDays: totalDays,
    );
  }

  /// Calculates the median of a sorted list of integers.
  static int _median(List<int> sorted) {
    if (sorted.isEmpty) return 0;
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) {
      return sorted[mid];
    }
    return ((sorted[mid - 1] + sorted[mid]) / 2).round();
  }
}
