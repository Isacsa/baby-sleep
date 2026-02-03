import 'package:flutter/foundation.dart';
import 'package:temp_flutter/domain/analysis/age_band.dart';
import 'package:temp_flutter/domain/analysis/sleep_expectations.dart';

/// Range of expected sleep per day (in minutes)
@immutable
class SleepGoalRange {
  /// Minimum recommended sleep per 24h (in minutes)
  final int minMinutes;

  /// Maximum recommended sleep per 24h (in minutes)
  final int maxMinutes;

  /// Source of the range (e.g., "age-based", "custom")
  final SleepGoalSource source;

  const SleepGoalRange({
    required this.minMinutes,
    required this.maxMinutes,
    required this.source,
  });

  /// Creates a range from SleepExpectations
  factory SleepGoalRange.fromExpectations(SleepExpectations expectations) {
    return SleepGoalRange(
      minMinutes: expectations.totalSleep24hMin,
      maxMinutes: expectations.totalSleep24hMax,
      source: SleepGoalSource.ageBased,
    );
  }

  /// Creates a default range for when no age is available
  /// Uses a wide generic range (10-18h) that covers most ages
  factory SleepGoalRange.unknown() {
    return const SleepGoalRange(
      minMinutes: 10 * 60, // 10h
      maxMinutes: 18 * 60, // 18h
      source: SleepGoalSource.generic,
    );
  }

  /// Returns range from the plan's simplified age mapping:
  /// - 0-3m: 14-17h
  /// - 4-12m: 12-16h
  /// - 1-2y: 11-14h
  /// - 2y+: 11-14h (fallback)
  static SleepGoalRange fromAgeMonths(double ageMonths) {
    if (ageMonths < 4) {
      return const SleepGoalRange(
        minMinutes: 14 * 60, // 14h
        maxMinutes: 17 * 60, // 17h
        source: SleepGoalSource.ageBased,
      );
    } else if (ageMonths < 13) {
      return const SleepGoalRange(
        minMinutes: 12 * 60, // 12h
        maxMinutes: 16 * 60, // 16h
        source: SleepGoalSource.ageBased,
      );
    } else if (ageMonths < 25) {
      return const SleepGoalRange(
        minMinutes: 11 * 60, // 11h
        maxMinutes: 14 * 60, // 14h
        source: SleepGoalSource.ageBased,
      );
    } else {
      // 2y+ fallback
      return const SleepGoalRange(
        minMinutes: 11 * 60, // 11h
        maxMinutes: 14 * 60, // 14h
        source: SleepGoalSource.ageBased,
      );
    }
  }

  /// Minimum as Duration
  Duration get minDuration => Duration(minutes: minMinutes);

  /// Maximum as Duration
  Duration get maxDuration => Duration(minutes: maxMinutes);

  /// Midpoint of the range (in minutes)
  int get midMinutes => (minMinutes + maxMinutes) ~/ 2;

  /// Formatted min (e.g., "14h")
  String get minFormatted {
    final h = minMinutes ~/ 60;
    final m = minMinutes % 60;
    return m > 0 ? '${h}h${m}m' : '${h}h';
  }

  /// Formatted max (e.g., "17h")
  String get maxFormatted {
    final h = maxMinutes ~/ 60;
    final m = maxMinutes % 60;
    return m > 0 ? '${h}h${m}m' : '${h}h';
  }

  /// Formatted range (e.g., "14–17h")
  String get rangeFormatted => '$minFormatted–$maxFormatted';

  @override
  String toString() => 'SleepGoalRange($minFormatted-$maxFormatted, $source)';
}

/// Source of the sleep goal range
enum SleepGoalSource {
  /// Derived from baby's age
  ageBased,

  /// Generic range (no age available)
  generic,

  /// Custom user-defined range
  custom,
}

/// Status of the sleep goal for a day
enum SleepGoalStatus {
  /// No birthDate available - show CTA
  noBirthDate,

  /// No sleep data for the day
  noData,

  /// Below the minimum recommended
  below,

  /// Within the recommended range
  within,

  /// Above the maximum recommended
  above,

  /// Currently sleeping (total is still updating)
  inProgress,
}

/// Extension methods for SleepGoalStatus
extension SleepGoalStatusExtension on SleepGoalStatus {
  /// Whether this status indicates "active" data (not empty/error states)
  bool get hasData => this != SleepGoalStatus.noBirthDate && this != SleepGoalStatus.noData;

  /// Whether the sleep is ongoing
  bool get isInProgress => this == SleepGoalStatus.inProgress;
}

/// Computed sleep goal state for a day
@immutable
class SleepGoalComputed {
  /// Total sleep time for the day (in minutes, clipped to day boundaries)
  final int totalMinutes;

  /// Goal range for this baby's age
  final SleepGoalRange goalRange;

  /// Current status
  final SleepGoalStatus status;

  /// Progress towards minimum (0.0-1.0, can exceed 1.0)
  final double progressToMin;

  /// Progress towards maximum (0.0-1.0+)
  final double progressToMax;

  /// Age in months (null if no birthDate)
  final double? ageMonths;

  /// Whether there's an ongoing sleep session
  final bool hasOngoingSleep;

  const SleepGoalComputed({
    required this.totalMinutes,
    required this.goalRange,
    required this.status,
    required this.progressToMin,
    required this.progressToMax,
    this.ageMonths,
    this.hasOngoingSleep = false,
  });

  /// Creates a "no birthdate" state with CTA
  factory SleepGoalComputed.noBirthDate() {
    return SleepGoalComputed(
      totalMinutes: 0,
      goalRange: SleepGoalRange.unknown(),
      status: SleepGoalStatus.noBirthDate,
      progressToMin: 0,
      progressToMax: 0,
      ageMonths: null,
    );
  }

  /// Creates a "no data" state
  factory SleepGoalComputed.noData({
    required SleepGoalRange goalRange,
    double? ageMonths,
  }) {
    return SleepGoalComputed(
      totalMinutes: 0,
      goalRange: goalRange,
      status: SleepGoalStatus.noData,
      progressToMin: 0,
      progressToMax: 0,
      ageMonths: ageMonths,
    );
  }

  /// Computes the goal state from aggregate data
  factory SleepGoalComputed.compute({
    required int totalMinutes,
    required SleepGoalRange goalRange,
    required double? ageMonths,
    required bool hasOngoingSleep,
  }) {
    // Calculate progress
    final progressToMin = goalRange.minMinutes > 0
        ? totalMinutes / goalRange.minMinutes
        : 0.0;
    final progressToMax = goalRange.maxMinutes > 0
        ? totalMinutes / goalRange.maxMinutes
        : 0.0;

    // Determine status
    SleepGoalStatus status;
    if (hasOngoingSleep) {
      status = SleepGoalStatus.inProgress;
    } else if (totalMinutes == 0) {
      status = SleepGoalStatus.noData;
    } else if (totalMinutes < goalRange.minMinutes) {
      status = SleepGoalStatus.below;
    } else if (totalMinutes > goalRange.maxMinutes) {
      status = SleepGoalStatus.above;
    } else {
      status = SleepGoalStatus.within;
    }

    return SleepGoalComputed(
      totalMinutes: totalMinutes,
      goalRange: goalRange,
      status: status,
      progressToMin: progressToMin,
      progressToMax: progressToMax,
      ageMonths: ageMonths,
      hasOngoingSleep: hasOngoingSleep,
    );
  }

  /// Whether the baby is under 4 months (use "reference" tone, not "goal")
  bool get isUnder4Months => ageMonths != null && ageMonths! < 4;

  /// Formatted total (e.g., "8h 30m" or "45m")
  String get totalFormatted {
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  /// Total as Duration
  Duration get totalDuration => Duration(minutes: totalMinutes);

  @override
  String toString() =>
      'SleepGoalComputed(total: $totalFormatted, status: $status, progress: ${(progressToMin * 100).toStringAsFixed(0)}%)';
}

/// Calculator for sleep goal from aggregates and baby data
class SleepGoalCalculator {
  const SleepGoalCalculator._();

  /// Computes sleep goal state for today
  ///
  /// [todayTotalMinutes] - Total sleep minutes for today (from DailySleepAggregate)
  /// [birthDate] - Baby's birth date (null if not set)
  /// [hasOngoingSleep] - Whether there's an ongoing sleep session
  /// [expectations] - Optional curated expectations (if available, takes precedence)
  static SleepGoalComputed compute({
    required int todayTotalMinutes,
    DateTime? birthDate,
    bool hasOngoingSleep = false,
    SleepExpectations? expectations,
  }) {
    // No birthDate → noBirthDate state
    if (birthDate == null) {
      return SleepGoalComputed.noBirthDate();
    }

    // Calculate age
    final ageMonths = AgeCalculator.ageInMonths(birthDate);

    // Get goal range
    SleepGoalRange goalRange;
    if (expectations != null) {
      goalRange = SleepGoalRange.fromExpectations(expectations);
    } else if (ageMonths != null) {
      goalRange = SleepGoalRange.fromAgeMonths(ageMonths);
    } else {
      goalRange = SleepGoalRange.unknown();
    }

    return SleepGoalComputed.compute(
      totalMinutes: todayTotalMinutes,
      goalRange: goalRange,
      ageMonths: ageMonths,
      hasOngoingSleep: hasOngoingSleep,
    );
  }
}
