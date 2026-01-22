/// Stats filter state model
///
/// Stores user preferences for the Stats tab:
/// - Period selection (day, week, 14 days, month, custom)
/// - Type filter (all, night, naps)
/// - Compare toggle
///
/// Persisted per baby via SharedPreferences.
library;

import 'package:flutter/foundation.dart';

/// Available period options for stats filtering
enum StatsPeriod {
  day,
  week,
  fourteenDays,
  month,
  custom,
}

/// Sleep type filter
enum SleepTypeFilter {
  all,
  night,
  naps,
}

/// Immutable state for stats filters
@immutable
class StatsFilterState {
  final StatsPeriod period;
  final SleepTypeFilter sleepType;
  final bool compareEnabled;
  final DateTime? customStart;
  final DateTime? customEnd;

  const StatsFilterState({
    this.period = StatsPeriod.week,
    this.sleepType = SleepTypeFilter.all,
    this.compareEnabled = false,
    this.customStart,
    this.customEnd,
  });

  /// Creates a copy with updated fields
  StatsFilterState copyWith({
    StatsPeriod? period,
    SleepTypeFilter? sleepType,
    bool? compareEnabled,
    DateTime? customStart,
    DateTime? customEnd,
    bool clearCustomDates = false,
  }) {
    return StatsFilterState(
      period: period ?? this.period,
      sleepType: sleepType ?? this.sleepType,
      compareEnabled: compareEnabled ?? this.compareEnabled,
      customStart: clearCustomDates ? null : (customStart ?? this.customStart),
      customEnd: clearCustomDates ? null : (customEnd ?? this.customEnd),
    );
  }

  /// Returns the number of days for the selected period
  ///
  /// For custom period, calculates from customStart/customEnd.
  /// Returns 7 as fallback if custom dates are incomplete.
  int get periodDays {
    switch (period) {
      case StatsPeriod.day:
        return 1;
      case StatsPeriod.week:
        return 7;
      case StatsPeriod.fourteenDays:
        return 14;
      case StatsPeriod.month:
        return 30;
      case StatsPeriod.custom:
        if (customStart != null && customEnd != null) {
          return customEnd!.difference(customStart!).inDays + 1;
        }
        return 7; // Fallback
    }
  }

  /// Whether compare toggle should be visible
  ///
  /// Compare is not available for single day view.
  bool get canCompare => period != StatsPeriod.day;

  /// Serializes to JSON for persistence
  Map<String, dynamic> toJson() {
    return {
      'period': period.name,
      'sleepType': sleepType.name,
      'compareEnabled': compareEnabled,
      'customStart': customStart?.toIso8601String(),
      'customEnd': customEnd?.toIso8601String(),
    };
  }

  /// Deserializes from JSON
  factory StatsFilterState.fromJson(Map<String, dynamic> json) {
    return StatsFilterState(
      period: StatsPeriod.values.firstWhere(
        (e) => e.name == json['period'],
        orElse: () => StatsPeriod.week,
      ),
      sleepType: SleepTypeFilter.values.firstWhere(
        (e) => e.name == json['sleepType'],
        orElse: () => SleepTypeFilter.all,
      ),
      compareEnabled: json['compareEnabled'] as bool? ?? false,
      customStart: json['customStart'] != null
          ? DateTime.tryParse(json['customStart'] as String)
          : null,
      customEnd: json['customEnd'] != null
          ? DateTime.tryParse(json['customEnd'] as String)
          : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StatsFilterState &&
          runtimeType == other.runtimeType &&
          period == other.period &&
          sleepType == other.sleepType &&
          compareEnabled == other.compareEnabled &&
          customStart == other.customStart &&
          customEnd == other.customEnd;

  @override
  int get hashCode => Object.hash(
        period,
        sleepType,
        compareEnabled,
        customStart,
        customEnd,
      );

  @override
  String toString() =>
      'StatsFilterState(period: $period, sleepType: $sleepType, compare: $compareEnabled)';
}
