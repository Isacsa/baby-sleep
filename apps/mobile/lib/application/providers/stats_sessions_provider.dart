import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:temp_flutter/application/providers/active_baby_provider.dart';
import 'package:temp_flutter/application/providers/sleep_events_provider.dart';
import 'package:temp_flutter/application/providers/stats_filter_provider.dart';
import 'package:temp_flutter/application/providers/stats_period_provider.dart';
import 'package:temp_flutter/core/utils/local_time_utils.dart';
import 'package:temp_flutter/domain/stats/stats_filter_state.dart';
import 'package:temp_flutter/domain/value_objects/sleep_session.dart';

/// Provider for sleep sessions within the current stats period.
///
/// Filters sessions that overlap with the selected date range.
/// Respects the sleep type filter (all/night/naps).
final statsSessionsProvider = Provider<AsyncValue<List<SleepSession>>>((ref) {
  final activeBaby = ref.watch(activeBabyProvider);
  if (activeBaby == null) {
    return const AsyncValue.data([]);
  }

  final eventsAsync = ref.watch(sleepEventsNotifierProvider);
  final periodRange = ref.watch(statsPeriodRangeProvider);
  final filter = ref.watch(statsFilterProvider);

  return eventsAsync.when(
    data: (events) {
      final allSessions = SleepSession.fromEventList(events);
      final filtered = _filterSessionsForRange(
        sessions: allSessions,
        range: periodRange,
        sleepType: filter.sleepType,
      );
      return AsyncValue.data(filtered);
    },
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
  );
});

/// Provider for sleep sessions in the comparison period.
///
/// Returns empty list if compare is disabled.
final statsCompareSessionsProvider =
    Provider<AsyncValue<List<SleepSession>>>((ref) {
  final activeBaby = ref.watch(activeBabyProvider);
  if (activeBaby == null) {
    return const AsyncValue.data([]);
  }

  final compareRange = ref.watch(statsComparePeriodRangeProvider);
  if (compareRange == null) {
    return const AsyncValue.data([]);
  }

  final eventsAsync = ref.watch(sleepEventsNotifierProvider);
  final filter = ref.watch(statsFilterProvider);

  return eventsAsync.when(
    data: (events) {
      final allSessions = SleepSession.fromEventList(events);
      final filtered = _filterSessionsForRange(
        sessions: allSessions,
        range: compareRange,
        sleepType: filter.sleepType,
      );
      return AsyncValue.data(filtered);
    },
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
  );
});

/// Filters sessions that overlap with a date range.
///
/// Also applies sleep type filter if not "all".
List<SleepSession> _filterSessionsForRange({
  required List<SleepSession> sessions,
  required DateRange range,
  required SleepTypeFilter sleepType,
}) {
  final nowUtc = DateTime.now().toUtc();

  return sessions.where((session) {
    final sessionStartUtc = session.startEvent.timestamp;
    final sessionEndUtc = session.endEvent?.timestamp ?? nowUtc;

    // Check if session overlaps with the range
    final overlaps = LocalTimeUtils.sessionOverlapsDay(
      sessionStartUtc: sessionStartUtc,
      sessionEndUtc: sessionEndUtc,
      dayStartLocal: range.startLocal,
      dayEndExclusiveLocal: range.endExclusiveLocal,
    );

    if (!overlaps) return false;

    // Apply sleep type filter
    if (sleepType == SleepTypeFilter.all) return true;

    // Classify session as night or nap based on duration and start time
    final isNap = _isNapSession(session, nowUtc);
    
    if (sleepType == SleepTypeFilter.naps) return isNap;
    if (sleepType == SleepTypeFilter.night) return !isNap;

    return true;
  }).toList();
}

/// Determines if a session is a nap based on duration and start time.
///
/// A session is considered a nap if:
/// - Duration < 3 hours, OR
/// - Starts during daytime hours (6:00-18:00) with duration < 4 hours
bool _isNapSession(SleepSession session, DateTime nowUtc) {
  final duration = session.duration ?? nowUtc.difference(session.startEvent.timestamp);
  final startHour = LocalTimeUtils.localHour(session.startEvent.timestamp);
  
  // Short sessions are always naps
  if (duration.inHours < 3) return true;
  
  // Daytime starts with moderate duration are naps
  if (LocalTimeUtils.isDaytimeHour(startHour) && duration.inHours < 4) {
    return true;
  }
  
  return false;
}
