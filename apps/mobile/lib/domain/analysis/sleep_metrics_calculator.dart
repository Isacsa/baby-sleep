import 'dart:math' as math;

import 'package:temp_flutter/domain/value_objects/sleep_session.dart';
import 'package:temp_flutter/domain/value_objects/sleep_state.dart';

import 'sleep_metrics.dart';

/// Calculator for sleep metrics from session data
///
/// Pure function-based calculator. No side effects, no network.
/// Takes sessions and current state, returns computed metrics.
class SleepMetricsCalculator {
  const SleepMetricsCalculator._();

  /// Calculates sleep metrics from a list of sessions
  ///
  /// [sessions] - All sessions for the baby (complete and incomplete)
  /// [sleepState] - Current sleep state (for isCurrentlySleeping)
  /// [now] - Reference time for "last 24h" calculations
  /// [lookbackDays] - Number of days to analyze for consistency metrics (default 7)
  static SleepMetrics calculate({
    required List<SleepSession> sessions,
    required SleepState sleepState,
    DateTime? now,
    int lookbackDays = 7,
  }) {
    final referenceTime = now ?? DateTime.now();
    final last24hStart = referenceTime.subtract(const Duration(hours: 24));

    // Filter sessions that overlap with the last 24 hours
    final sessionsLast24h = _sessionsInWindow(sessions, last24hStart, referenceTime);

    // Calculate total sleep in last 24h (clipped to window)
    final totalSleepLast24h = _totalSleepInWindow(
      sessionsLast24h,
      last24hStart,
      referenceTime,
      sleepState,
    );

    // Calculate nap metrics (daytime sessions, roughly 6:00-20:00)
    final napSessions = _filterNapSessions(sessionsLast24h, referenceTime);
    final napCountLast24h = napSessions.length;
    final avgNapDuration = _averageDuration(napSessions);
    final shortNapRate = _shortNapRate(napSessions);

    // Calculate fragmentation (night sessions analysis)
    final fragmentationScore = _calculateFragmentation(
      sessions,
      referenceTime,
      lookbackDays: lookbackDays,
    );

    // Calculate bedtime consistency
    final bedtimeConsistency = _calculateBedtimeConsistency(
      sessions,
      referenceTime,
      lookbackDays: lookbackDays,
    );

    // Last wake time
    final lastWakeTime = _findLastWakeTime(sessions, sleepState);

    // Current session info
    final isCurrentlySleeping = sleepState.isSleeping;
    final currentSessionStart = isCurrentlySleeping
        ? sessions.where((s) => !s.isComplete).firstOrNull?.startEvent.timestamp
        : null;

    // Total sleep by day
    final totalSleepByDay = _calculateSleepByDay(
      sessions,
      referenceTime,
      lookbackDays: lookbackDays,
    );

    // Session count and longest
    final completeSessions24h = sessionsLast24h.where((s) => s.isComplete).toList();
    final sessionCountLast24h = completeSessions24h.length;
    final longestSessionLast24h = _longestSession(completeSessions24h);

    // Median bedtime
    final medianBedtime = _calculateMedianBedtime(
      sessions,
      referenceTime,
      lookbackDays: lookbackDays,
    );

    // Days with data
    final daysWithData = totalSleepByDay.keys.length;

    return SleepMetrics(
      totalSleepLast24h: totalSleepLast24h,
      napCountLast24h: napCountLast24h,
      avgNapDuration: avgNapDuration,
      shortNapRate: shortNapRate,
      fragmentationScore: fragmentationScore,
      bedtimeConsistencyMinutes: bedtimeConsistency,
      lastWakeTime: lastWakeTime,
      isCurrentlySleeping: isCurrentlySleeping,
      currentSessionStart: currentSessionStart,
      totalSleepByDay: totalSleepByDay,
      sessionCountLast24h: sessionCountLast24h,
      longestSessionLast24h: longestSessionLast24h,
      medianBedtime: medianBedtime,
      daysWithData: daysWithData,
      calculatedAt: referenceTime,
    );
  }

  /// Filters sessions that overlap with the given time window
  static List<SleepSession> _sessionsInWindow(
    List<SleepSession> sessions,
    DateTime windowStart,
    DateTime windowEnd,
  ) {
    return sessions.where((session) {
      final sessionStart = session.startEvent.timestamp;
      final sessionEnd = session.endEvent?.timestamp ?? windowEnd;
      // Session overlaps if it starts before window ends AND ends after window starts
      return sessionStart.isBefore(windowEnd) && sessionEnd.isAfter(windowStart);
    }).toList();
  }

  /// Calculates total sleep duration within a time window (clipped)
  static Duration _totalSleepInWindow(
    List<SleepSession> sessions,
    DateTime windowStart,
    DateTime windowEnd,
    SleepState sleepState,
  ) {
    var totalMinutes = 0;

    for (final session in sessions) {
      final sessionStart = session.startEvent.timestamp;
      // For incomplete sessions, use windowEnd as the end time
      final sessionEnd = session.endEvent?.timestamp ?? windowEnd;

      // Clip to window boundaries
      final clippedStart = sessionStart.isBefore(windowStart) ? windowStart : sessionStart;
      final clippedEnd = sessionEnd.isAfter(windowEnd) ? windowEnd : sessionEnd;

      if (clippedEnd.isAfter(clippedStart)) {
        totalMinutes += clippedEnd.difference(clippedStart).inMinutes;
      }
    }

    return Duration(minutes: totalMinutes);
  }

  /// Filters sessions that are likely "naps" (daytime, roughly 6:00-20:00)
  static List<SleepSession> _filterNapSessions(
    List<SleepSession> sessions,
    DateTime referenceTime,
  ) {
    return sessions.where((session) {
      final startHour = session.startEvent.timestamp.hour;
      // Nap is roughly between 6:00 and 20:00 and typically shorter
      // We consider it a nap if it starts between 6:00 and 18:00
      return startHour >= 6 && startHour < 18 && session.isComplete;
    }).toList();
  }

  /// Calculates average duration of completed sessions
  static Duration? _averageDuration(List<SleepSession> sessions) {
    final completeSessions = sessions.where((s) => s.isComplete && s.duration != null).toList();
    if (completeSessions.isEmpty) return null;

    final totalMinutes = completeSessions
        .map((s) => s.duration!.inMinutes)
        .reduce((a, b) => a + b);

    return Duration(minutes: totalMinutes ~/ completeSessions.length);
  }

  /// Calculates the rate of short naps (< 30 minutes)
  static double _shortNapRate(List<SleepSession> napSessions) {
    if (napSessions.isEmpty) return 0.0;

    final shortNaps = napSessions.where((s) {
      final duration = s.duration;
      return duration != null && duration.inMinutes < 30;
    }).length;

    return shortNaps / napSessions.length;
  }

  /// Calculates fragmentation score (0.0 = consolidated, 1.0 = fragmented)
  ///
  /// Heuristic based on:
  /// - Night waking frequency (sessions between 20:00-06:00)
  /// - Short session rate at night (< 45 min)
  static double _calculateFragmentation(
    List<SleepSession> sessions,
    DateTime referenceTime, {
    int lookbackDays = 7,
  }) {
    final windowStart = referenceTime.subtract(Duration(days: lookbackDays));

    // Get night sessions (20:00-06:00)
    final nightSessions = sessions.where((session) {
      final startTime = session.startEvent.timestamp;
      if (startTime.isBefore(windowStart)) return false;

      final hour = startTime.hour;
      // Night is 20:00-23:59 or 00:00-05:59
      return hour >= 20 || hour < 6;
    }).toList();

    if (nightSessions.isEmpty) return 0.0;

    // Count short night sessions (< 45 min)
    final shortNightSessions = nightSessions.where((s) {
      final duration = s.duration;
      return duration != null && duration.inMinutes < 45;
    }).length;

    // Calculate waking frequency per night
    final nightCount = lookbackDays.toDouble();
    final wakingsPerNight = nightSessions.length / nightCount;

    // Normalize: 0-1 waking/night = low, 3+ = high
    final wakingScore = math.min(1.0, wakingsPerNight / 4.0);

    // Short session ratio
    final shortSessionRatio = shortNightSessions / nightSessions.length;

    // Combined score (weighted average)
    return (wakingScore * 0.6 + shortSessionRatio * 0.4).clamp(0.0, 1.0);
  }

  /// Calculates bedtime consistency (standard deviation in minutes)
  ///
  /// Returns null if fewer than 3 nights of data.
  static double? _calculateBedtimeConsistency(
    List<SleepSession> sessions,
    DateTime referenceTime, {
    int lookbackDays = 7,
  }) {
    final windowStart = referenceTime.subtract(Duration(days: lookbackDays));

    // Find the first night session for each day (main sleep start)
    final bedtimesByDay = <String, int>{};

    for (final session in sessions) {
      final startTime = session.startEvent.timestamp;
      if (startTime.isBefore(windowStart)) continue;

      // Consider bedtime if between 18:00-23:59
      final hour = startTime.hour;
      if (hour < 18) continue;

      // Use date as key (for the evening, use that day's date)
      final dateKey = _dateKey(startTime);

      // Minutes from midnight (for 19:00 = 19*60 = 1140)
      final minutesFromMidnight = hour * 60 + startTime.minute;

      // Keep earliest bedtime for each day
      if (!bedtimesByDay.containsKey(dateKey) ||
          minutesFromMidnight < bedtimesByDay[dateKey]!) {
        bedtimesByDay[dateKey] = minutesFromMidnight;
      }
    }

    if (bedtimesByDay.length < 3) return null;

    final bedtimes = bedtimesByDay.values.toList();
    final mean = bedtimes.reduce((a, b) => a + b) / bedtimes.length;
    final variance = bedtimes
        .map((t) => math.pow(t - mean, 2))
        .reduce((a, b) => a + b) / bedtimes.length;

    return math.sqrt(variance);
  }

  /// Finds the last wake time (end of most recent completed session)
  static DateTime? _findLastWakeTime(
    List<SleepSession> sessions,
    SleepState sleepState,
  ) {
    if (sleepState.isSleeping) return null;

    // Sort by end time descending
    final completeSessions = sessions
        .where((s) => s.isComplete && s.endEvent != null)
        .toList()
      ..sort((a, b) => b.endEvent!.timestamp.compareTo(a.endEvent!.timestamp));

    return completeSessions.firstOrNull?.endEvent?.timestamp;
  }

  /// Calculates total sleep by local day
  static Map<String, Duration> _calculateSleepByDay(
    List<SleepSession> sessions,
    DateTime referenceTime, {
    int lookbackDays = 7,
  }) {
    final result = <String, int>{};

    for (var i = 0; i < lookbackDays; i++) {
      final day = referenceTime.subtract(Duration(days: i));
      final dayStart = DateTime(day.year, day.month, day.day);
      final dayEnd = dayStart.add(const Duration(days: 1));
      final dateKey = _dateKey(dayStart);

      final daySessions = _sessionsInWindow(sessions, dayStart, dayEnd);
      final dayTotal = _totalSleepInWindow(
        daySessions,
        dayStart,
        dayEnd,
        const SleepState(isSleeping: false),
      );

      if (dayTotal.inMinutes > 0) {
        result[dateKey] = dayTotal.inMinutes;
      }
    }

    return result.map((k, v) => MapEntry(k, Duration(minutes: v)));
  }

  /// Finds the longest session in a list
  static Duration? _longestSession(List<SleepSession> sessions) {
    if (sessions.isEmpty) return null;

    final durations = sessions
        .where((s) => s.duration != null)
        .map((s) => s.duration!)
        .toList();

    if (durations.isEmpty) return null;

    return durations.reduce((a, b) => a > b ? a : b);
  }

  /// Calculates median bedtime from recent nights
  static DateTime? _calculateMedianBedtime(
    List<SleepSession> sessions,
    DateTime referenceTime, {
    int lookbackDays = 7,
  }) {
    final windowStart = referenceTime.subtract(Duration(days: lookbackDays));

    // Collect bedtimes (first night session each evening)
    final bedtimeMinutes = <int>[];

    final bedtimesByDay = <String, DateTime>{};

    for (final session in sessions) {
      final startTime = session.startEvent.timestamp;
      if (startTime.isBefore(windowStart)) continue;

      final hour = startTime.hour;
      if (hour < 18) continue;

      final dateKey = _dateKey(startTime);

      if (!bedtimesByDay.containsKey(dateKey) ||
          startTime.isBefore(bedtimesByDay[dateKey]!)) {
        bedtimesByDay[dateKey] = startTime;
      }
    }

    for (final time in bedtimesByDay.values) {
      bedtimeMinutes.add(time.hour * 60 + time.minute);
    }

    if (bedtimeMinutes.length < 3) return null;

    bedtimeMinutes.sort();
    final medianMinutes = bedtimeMinutes[bedtimeMinutes.length ~/ 2];

    // Return a DateTime for today with the median time
    return DateTime(
      referenceTime.year,
      referenceTime.month,
      referenceTime.day,
      medianMinutes ~/ 60,
      medianMinutes % 60,
    );
  }

  /// Generates a date key string "yyyy-MM-dd"
  static String _dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
