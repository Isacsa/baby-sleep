import 'dart:math' as math;

import 'package:temp_flutter/core/utils/local_time_utils.dart';
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

    // === Extended metrics for Insights v2 ===
    
    // Average and median total sleep 7d
    final (avgTotal7d, medianTotal7d) = _calculateAverageAndMedianTotalSleep(
      totalSleepByDay, 
      referenceTime, 
      lookbackDays: 7,
    );
    
    // Average total sleep 14d
    final totalSleepByDay14d = _calculateSleepByDay(
      sessions,
      referenceTime,
      lookbackDays: 14,
    );
    final (avgTotal14d, _) = _calculateAverageAndMedianTotalSleep(
      totalSleepByDay14d, 
      referenceTime, 
      lookbackDays: 14,
    );
    
    // Bedtime variability range (max - min)
    final bedtimeVariabilityRange = _calculateBedtimeVariabilityRange(
      sessions,
      referenceTime,
      lookbackDays: lookbackDays,
    );
    
    // Average episodes per night
    final avgEpisodesPerNight = _calculateAvgEpisodesPerNight(
      sessions,
      referenceTime,
      lookbackDays: lookbackDays,
    );
    
    // Night vs nap split for last 24h
    final (nightSleep24h, napSleep24h) = _calculateNightVsNapSplit(
      sessionsLast24h,
      last24hStart,
      referenceTime,
      sleepState,
    );
    
    // Longest session 7d
    final sessionsLast7d = _sessionsInWindow(
      sessions, 
      referenceTime.subtract(const Duration(days: 7)),
      referenceTime,
    );
    final longestSession7d = _longestSession(
      sessionsLast7d.where((s) => s.isComplete).toList(),
    );
    
    // Average gap between sessions (wake time)
    final avgGap24h = _calculateAvgGapBetweenSessions(
      sessionsLast24h,
      last24hStart,
      referenceTime,
    );
    
    // Difference from 7d average
    Duration? diffFromAvg7d;
    if (avgTotal7d != null) {
      diffFromAvg7d = totalSleepLast24h - avgTotal7d;
    }

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
      // Extended metrics
      avgTotalSleep7d: avgTotal7d,
      medianTotalSleep7d: medianTotal7d,
      avgTotalSleep14d: avgTotal14d,
      bedtimeVariabilityRangeMinutes: bedtimeVariabilityRange,
      avgEpisodesPerNight7d: avgEpisodesPerNight,
      nightSleepLast24h: nightSleep24h,
      napSleepLast24h: napSleep24h,
      longestSession7d: longestSession7d,
      avgGapBetweenSessions24h: avgGap24h,
      diffFromAvg7d: diffFromAvg7d,
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

  /// Filters sessions that are likely "naps" (daytime, roughly 6:00-18:00 LOCAL time)
  static List<SleepSession> _filterNapSessions(
    List<SleepSession> sessions,
    DateTime referenceTime,
  ) {
    return sessions.where((session) {
      // Use LOCAL hour for nap classification
      final startHourLocal = LocalTimeUtils.localHour(session.startEvent.timestamp);
      // Nap is roughly between 6:00 and 18:00 local and typically shorter
      return LocalTimeUtils.isDaytimeHour(startHourLocal) && session.isComplete;
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
  /// - Night waking frequency (sessions between 20:00-06:00 LOCAL)
  /// - Short session rate at night (< 45 min)
  static double _calculateFragmentation(
    List<SleepSession> sessions,
    DateTime referenceTime, {
    int lookbackDays = 7,
  }) {
    final windowStart = referenceTime.subtract(Duration(days: lookbackDays));

    // Get night sessions (20:00-06:00 LOCAL time)
    final nightSessions = sessions.where((session) {
      final startTime = session.startEvent.timestamp;
      if (startTime.isBefore(windowStart)) return false;

      // Use LOCAL hour for night classification
      final hourLocal = LocalTimeUtils.localHour(startTime);
      // Night is 20:00-23:59 or 00:00-05:59 local
      return LocalTimeUtils.isNighttimeHour(hourLocal);
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
  /// Uses LOCAL time for bedtime detection and day grouping.
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

      // Use LOCAL hour for bedtime detection (18:00-23:59 local)
      final startLocal = LocalTimeUtils.toLocal(startTime);
      final hourLocal = startLocal.hour;
      if (!LocalTimeUtils.isBedtimeHour(hourLocal)) continue;

      // Use LOCAL date as key (for the evening, use that day's date)
      final dateKey = LocalTimeUtils.dateKey(startTime);

      // Minutes from midnight in LOCAL time
      final minutesFromMidnight = hourLocal * 60 + startLocal.minute;

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

  /// Calculates total sleep by LOCAL day with proper clipping
  ///
  /// Uses local day boundaries (00:00 local to 00:00 next day local).
  /// Cross-midnight sessions are clipped to each day they overlap with.
  static Map<String, Duration> _calculateSleepByDay(
    List<SleepSession> sessions,
    DateTime referenceTime, {
    int lookbackDays = 7,
  }) {
    final result = <String, int>{};
    final nowUtc = DateTime.now().toUtc();

    for (var i = 0; i < lookbackDays; i++) {
      final day = referenceTime.subtract(Duration(days: i));
      final dayRange = LocalTimeUtils.localDayRange(day);

      var dayTotalMinutes = 0;

      for (final session in sessions) {
        final sessionStartUtc = session.startEvent.timestamp;
        // For incomplete sessions, use now as end
        final sessionEndUtc = session.endEvent?.timestamp ?? nowUtc;

        // Check if session overlaps with this day
        if (!LocalTimeUtils.sessionOverlapsDay(
          sessionStartUtc: sessionStartUtc,
          sessionEndUtc: sessionEndUtc,
          dayStartLocal: dayRange.startLocal,
          dayEndExclusiveLocal: dayRange.endExclusiveLocal,
        )) {
          continue;
        }

        // Clip duration to this day
        final clippedDuration = LocalTimeUtils.clipDurationToLocalDay(
          sessionStartUtc: sessionStartUtc,
          sessionEndUtc: sessionEndUtc,
          dayStartLocal: dayRange.startLocal,
          dayEndExclusiveLocal: dayRange.endExclusiveLocal,
        );

        dayTotalMinutes += clippedDuration.inMinutes;
      }

      if (dayTotalMinutes > 0) {
        result[dayRange.key] = dayTotalMinutes;
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
  ///
  /// Uses LOCAL time for bedtime detection and calculation.
  static DateTime? _calculateMedianBedtime(
    List<SleepSession> sessions,
    DateTime referenceTime, {
    int lookbackDays = 7,
  }) {
    final windowStart = referenceTime.subtract(Duration(days: lookbackDays));

    // Collect bedtimes (first night session each evening, in LOCAL time)
    final bedtimeMinutes = <int>[];

    final bedtimesByDay = <String, DateTime>{};

    for (final session in sessions) {
      final startTime = session.startEvent.timestamp;
      if (startTime.isBefore(windowStart)) continue;

      // Use LOCAL hour for bedtime detection
      final startLocal = LocalTimeUtils.toLocal(startTime);
      final hourLocal = startLocal.hour;
      if (!LocalTimeUtils.isBedtimeHour(hourLocal)) continue;

      // Use LOCAL date as key
      final dateKey = LocalTimeUtils.dateKey(startTime);

      if (!bedtimesByDay.containsKey(dateKey) ||
          startLocal.isBefore(bedtimesByDay[dateKey]!)) {
        bedtimesByDay[dateKey] = startLocal;
      }
    }

    for (final time in bedtimesByDay.values) {
      // time is already in local
      bedtimeMinutes.add(time.hour * 60 + time.minute);
    }

    if (bedtimeMinutes.length < 3) return null;

    bedtimeMinutes.sort();
    final medianMinutes = bedtimeMinutes[bedtimeMinutes.length ~/ 2];

    // Return a DateTime for today (local) with the median time
    final refLocal = LocalTimeUtils.toLocal(referenceTime);
    return DateTime(
      refLocal.year,
      refLocal.month,
      refLocal.day,
      medianMinutes ~/ 60,
      medianMinutes % 60,
    );
  }

  // === Extended metrics calculations ===

  /// Calculates average and median total sleep from daily totals
  ///
  /// Returns (average, median) as Duration? tuple.
  /// Requires at least 3 days of data.
  static (Duration?, Duration?) _calculateAverageAndMedianTotalSleep(
    Map<String, Duration> totalSleepByDay,
    DateTime referenceTime, {
    required int lookbackDays,
  }) {
    if (totalSleepByDay.length < 3) return (null, null);
    
    final dailyMinutes = totalSleepByDay.values.map((d) => d.inMinutes).toList();
    if (dailyMinutes.isEmpty) return (null, null);
    
    // Average
    final avg = dailyMinutes.reduce((a, b) => a + b) / dailyMinutes.length;
    
    // Median
    dailyMinutes.sort();
    final median = dailyMinutes[dailyMinutes.length ~/ 2];
    
    return (
      Duration(minutes: avg.round()),
      Duration(minutes: median),
    );
  }

  /// Calculates bedtime variability range (max - min bedtime) in minutes
  ///
  /// Returns null if fewer than 3 nights of data.
  static int? _calculateBedtimeVariabilityRange(
    List<SleepSession> sessions,
    DateTime referenceTime, {
    int lookbackDays = 7,
  }) {
    final windowStart = referenceTime.subtract(Duration(days: lookbackDays));
    final bedtimeMinutes = <int>[];
    final bedtimesByDay = <String, int>{};

    for (final session in sessions) {
      final startTime = session.startEvent.timestamp;
      if (startTime.isBefore(windowStart)) continue;

      final startLocal = LocalTimeUtils.toLocal(startTime);
      final hourLocal = startLocal.hour;
      if (!LocalTimeUtils.isBedtimeHour(hourLocal)) continue;

      final dateKey = LocalTimeUtils.dateKey(startTime);
      final minutesFromMidnight = hourLocal * 60 + startLocal.minute;

      if (!bedtimesByDay.containsKey(dateKey) ||
          minutesFromMidnight < bedtimesByDay[dateKey]!) {
        bedtimesByDay[dateKey] = minutesFromMidnight;
      }
    }

    if (bedtimesByDay.length < 3) return null;

    bedtimeMinutes.addAll(bedtimesByDay.values);
    final minBedtime = bedtimeMinutes.reduce(math.min);
    final maxBedtime = bedtimeMinutes.reduce(math.max);

    return maxBedtime - minBedtime;
  }

  /// Calculates average episodes (sessions) per night
  static double? _calculateAvgEpisodesPerNight(
    List<SleepSession> sessions,
    DateTime referenceTime, {
    int lookbackDays = 7,
  }) {
    final windowStart = referenceTime.subtract(Duration(days: lookbackDays));
    final episodesByNight = <String, int>{};

    for (final session in sessions) {
      final startTime = session.startEvent.timestamp;
      if (startTime.isBefore(windowStart)) continue;

      final hourLocal = LocalTimeUtils.localHour(startTime);
      if (!LocalTimeUtils.isNighttimeHour(hourLocal)) continue;

      // Use the date of the evening (for overnight sessions, this is the start date)
      final dateKey = LocalTimeUtils.dateKey(startTime);
      episodesByNight[dateKey] = (episodesByNight[dateKey] ?? 0) + 1;
    }

    if (episodesByNight.isEmpty) return null;

    final totalEpisodes = episodesByNight.values.reduce((a, b) => a + b);
    return totalEpisodes / episodesByNight.length;
  }

  /// Calculates night vs nap split for sessions in a window
  ///
  /// Returns (nightSleep, napSleep) as Durations.
  /// Night = session where >50% of duration falls in night window (19:00-07:00)
  static (Duration, Duration) _calculateNightVsNapSplit(
    List<SleepSession> sessions,
    DateTime windowStart,
    DateTime windowEnd,
    SleepState sleepState,
  ) {
    var nightMinutes = 0;
    var napMinutes = 0;

    for (final session in sessions) {
      final sessionStart = session.startEvent.timestamp;
      final sessionEnd = session.endEvent?.timestamp ?? windowEnd;

      // Clip to window boundaries
      final clippedStart = sessionStart.isBefore(windowStart) ? windowStart : sessionStart;
      final clippedEnd = sessionEnd.isAfter(windowEnd) ? windowEnd : sessionEnd;

      if (!clippedEnd.isAfter(clippedStart)) continue;

      final totalMinutes = clippedEnd.difference(clippedStart).inMinutes;
      
      // Calculate how many minutes are in night window (19:00-07:00 local)
      final nightWindowMinutes = _calculateMinutesInNightWindow(
        clippedStart,
        clippedEnd,
      );

      // Classify: >50% in night window = night, else = nap
      if (nightWindowMinutes > totalMinutes / 2) {
        nightMinutes += totalMinutes;
      } else {
        napMinutes += totalMinutes;
      }
    }

    return (
      Duration(minutes: nightMinutes),
      Duration(minutes: napMinutes),
    );
  }

  /// Calculates minutes that fall within night window (19:00-07:00 local)
  static int _calculateMinutesInNightWindow(DateTime start, DateTime end) {
    var nightMinutes = 0;
    var current = start;

    while (current.isBefore(end)) {
      final currentLocal = LocalTimeUtils.toLocal(current);
      final hourLocal = currentLocal.hour;
      
      // Night hours: 19:00-23:59 (19-23) or 00:00-06:59 (0-6)
      final isNightHour = hourLocal >= 19 || hourLocal < 7;
      
      // Move by 1 minute
      final next = current.add(const Duration(minutes: 1));
      if (next.isAfter(end)) {
        if (isNightHour) nightMinutes += 1;
        break;
      }
      
      if (isNightHour) nightMinutes += 1;
      current = next;
    }

    return nightMinutes;
  }

  /// Calculates average gap between sessions (awake time)
  static Duration? _calculateAvgGapBetweenSessions(
    List<SleepSession> sessions,
    DateTime windowStart,
    DateTime windowEnd,
  ) {
    // Sort by start time
    final sorted = sessions.toList()
      ..sort((a, b) => a.startEvent.timestamp.compareTo(b.startEvent.timestamp));

    if (sorted.length < 2) return null;

    var totalGapMinutes = 0;
    var gapCount = 0;

    for (var i = 1; i < sorted.length; i++) {
      final prevEnd = sorted[i - 1].endEvent?.timestamp;
      final currStart = sorted[i].startEvent.timestamp;

      if (prevEnd != null && currStart.isAfter(prevEnd)) {
        final gap = currStart.difference(prevEnd).inMinutes;
        if (gap > 0 && gap < 720) { // Ignore gaps > 12h (likely data error)
          totalGapMinutes += gap;
          gapCount++;
        }
      }
    }

    if (gapCount == 0) return null;

    return Duration(minutes: totalGapMinutes ~/ gapCount);
  }
}

