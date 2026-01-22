import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:temp_flutter/application/providers/stats_filter_provider.dart';
import 'package:temp_flutter/core/utils/local_time_utils.dart';
import 'package:temp_flutter/domain/stats/stats_filter_state.dart';

/// Represents a date range for stats calculations
class DateRange {
  final DateTime startLocal;
  final DateTime endExclusiveLocal;

  const DateRange({
    required this.startLocal,
    required this.endExclusiveLocal,
  });

  /// Number of days in this range
  int get days => endExclusiveLocal.difference(startLocal).inDays;

  /// Returns true if [date] falls within this range [startLocal, endExclusiveLocal)
  bool contains(DateTime date) {
    final local = LocalTimeUtils.toLocal(date);
    return !local.isBefore(startLocal) && local.isBefore(endExclusiveLocal);
  }

  @override
  String toString() =>
      'DateRange($startLocal - $endExclusiveLocal, $days days)';
}

/// Provider for the current stats period date range.
///
/// Derives from [statsFilterProvider] to get the selected period.
/// Returns a [DateRange] in local time.
final statsPeriodRangeProvider = Provider<DateRange>((ref) {
  final filter = ref.watch(statsFilterProvider);
  return _computePeriodRange(filter);
});

/// Provider for the comparison period date range.
///
/// Returns null if compare is disabled.
/// The comparison period is the same duration, immediately before the current period.
final statsComparePeriodRangeProvider = Provider<DateRange?>((ref) {
  final filter = ref.watch(statsFilterProvider);
  
  if (!filter.compareEnabled || !filter.canCompare) {
    return null;
  }
  
  final currentRange = _computePeriodRange(filter);
  final days = currentRange.days;
  
  // Previous period is same duration, immediately before
  final compareEndExclusive = currentRange.startLocal;
  final compareStart = compareEndExclusive.subtract(Duration(days: days));
  
  return DateRange(
    startLocal: compareStart,
    endExclusiveLocal: compareEndExclusive,
  );
});

/// Computes the date range for the current filter settings
DateRange _computePeriodRange(StatsFilterState filter) {
  final now = DateTime.now();
  final todayRange = LocalTimeUtils.localDayRange(now);
  
  switch (filter.period) {
    case StatsPeriod.day:
      return DateRange(
        startLocal: todayRange.startLocal,
        endExclusiveLocal: todayRange.endExclusiveLocal,
      );
      
    case StatsPeriod.week:
      final startLocal = todayRange.startLocal.subtract(const Duration(days: 6));
      return DateRange(
        startLocal: startLocal,
        endExclusiveLocal: todayRange.endExclusiveLocal,
      );
      
    case StatsPeriod.fourteenDays:
      final startLocal = todayRange.startLocal.subtract(const Duration(days: 13));
      return DateRange(
        startLocal: startLocal,
        endExclusiveLocal: todayRange.endExclusiveLocal,
      );
      
    case StatsPeriod.month:
      final startLocal = todayRange.startLocal.subtract(const Duration(days: 29));
      return DateRange(
        startLocal: startLocal,
        endExclusiveLocal: todayRange.endExclusiveLocal,
      );
      
    case StatsPeriod.custom:
      if (filter.customStart != null && filter.customEnd != null) {
        final startRange = LocalTimeUtils.localDayRange(filter.customStart!);
        final endRange = LocalTimeUtils.localDayRange(filter.customEnd!);
        return DateRange(
          startLocal: startRange.startLocal,
          endExclusiveLocal: endRange.endExclusiveLocal,
        );
      }
      // Fallback to week if custom dates not set
      final startLocal = todayRange.startLocal.subtract(const Duration(days: 6));
      return DateRange(
        startLocal: startLocal,
        endExclusiveLocal: todayRange.endExclusiveLocal,
      );
  }
}
