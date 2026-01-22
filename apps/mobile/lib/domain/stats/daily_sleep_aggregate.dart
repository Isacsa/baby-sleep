import 'package:flutter/foundation.dart';
import 'package:temp_flutter/core/utils/local_time_utils.dart';
import 'package:temp_flutter/domain/value_objects/sleep_session.dart';

/// Night window definition (local time)
/// 
/// Default: 19:00-07:00
/// Sessions with >50% of their duration in this window are classified as "night".
class NightWindow {
  /// Start hour (inclusive), e.g., 19 for 19:00
  final int startHour;
  
  /// End hour (exclusive), e.g., 7 for 07:00
  final int endHour;

  const NightWindow({
    this.startHour = 19,
    this.endHour = 7,
  });

  /// Checks if a local hour falls within the night window.
  bool containsHour(int hour) {
    if (startHour > endHour) {
      // Window crosses midnight (e.g., 19:00-07:00)
      return hour >= startHour || hour < endHour;
    } else {
      // Window doesn't cross midnight
      return hour >= startHour && hour < endHour;
    }
  }
}

/// Day boundary policy for aggregation.
/// 
/// V1: Midnight-to-midnight (00:00-00:00)
/// Future: Could support "sleep day" (e.g., 19:00-19:00)
enum DayBoundaryPolicy {
  midnight,
}

/// Aggregated sleep data for a single local day.
@immutable
class DailySleepAggregate {
  /// The local date (00:00 of the day)
  final DateTime dateLocal;
  
  /// Total sleep minutes clipped to this day
  final int totalMinutes;
  
  /// Night sleep minutes (within night window)
  final int nightMinutes;
  
  /// Nap sleep minutes (outside night window)
  final int napMinutes;
  
  /// Longest sleep block clipped to this day (in minutes)
  final int longestBlockMinutes;
  
  /// Number of night sleep episodes touching this day's night window
  final int nightEpisodesCount;
  
  /// Bedtime start (first session starting 19:00-02:00 with duration >= 30min)
  final DateTime? bedtimeStartLocal;
  
  /// Sessions that overlap with this day (for timeline/audit)
  final List<SleepSession> sessions;
  
  /// Whether there's an ongoing sleep session on this day
  final bool hasOngoingSleep;
  
  /// Whether there were any overlaps detected/resolved on this day
  final bool hasOverlaps;

  const DailySleepAggregate({
    required this.dateLocal,
    required this.totalMinutes,
    required this.nightMinutes,
    required this.napMinutes,
    required this.longestBlockMinutes,
    required this.nightEpisodesCount,
    this.bedtimeStartLocal,
    required this.sessions,
    this.hasOngoingSleep = false,
    this.hasOverlaps = false,
  });

  /// Creates an empty aggregate for a day with no data
  factory DailySleepAggregate.empty(DateTime dateLocal) {
    return DailySleepAggregate(
      dateLocal: dateLocal,
      totalMinutes: 0,
      nightMinutes: 0,
      napMinutes: 0,
      longestBlockMinutes: 0,
      nightEpisodesCount: 0,
      sessions: const [],
    );
  }

  /// Returns duration as Duration object
  Duration get totalDuration => Duration(minutes: totalMinutes);
  Duration get nightDuration => Duration(minutes: nightMinutes);
  Duration get napDuration => Duration(minutes: napMinutes);
  Duration get longestBlockDuration => Duration(minutes: longestBlockMinutes);

  /// Night percentage (0.0-1.0)
  double get nightPercentage => 
      totalMinutes > 0 ? nightMinutes / totalMinutes : 0.0;

  /// Nap percentage (0.0-1.0)
  double get napPercentage => 
      totalMinutes > 0 ? napMinutes / totalMinutes : 0.0;

  @override
  String toString() =>
      'DailySleepAggregate($dateLocal: ${totalMinutes}m total, ${nightMinutes}m night, ${napMinutes}m naps)';
}

/// Calculator for daily sleep aggregates.
///
/// Splits sessions across day boundaries and classifies night vs nap time.
class DailySleepAggregateCalculator {
  static const _defaultNightWindow = NightWindow();
  static const _minBedtimeDurationMinutes = 30;

  /// Calculates daily aggregates for a range of days.
  ///
  /// [sessions]: All sessions that may overlap with the range
  /// [startLocal]: First day to include (00:00)
  /// [endExclusiveLocal]: Day after the last day to include
  /// [nightWindow]: Night window definition (default 19:00-07:00)
  /// [policy]: Day boundary policy (default midnight)
  static List<DailySleepAggregate> calculate({
    required List<SleepSession> sessions,
    required DateTime startLocal,
    required DateTime endExclusiveLocal,
    NightWindow nightWindow = _defaultNightWindow,
    DayBoundaryPolicy policy = DayBoundaryPolicy.midnight,
  }) {
    final aggregates = <DailySleepAggregate>[];
    final nowUtc = DateTime.now().toUtc();
    
    // Iterate through each day in the range
    var currentDate = startLocal;
    while (currentDate.isBefore(endExclusiveLocal)) {
      final dayRange = LocalTimeUtils.localDayRange(currentDate);
      final dayAggregate = _calculateForDay(
        sessions: sessions,
        dayRange: dayRange,
        nightWindow: nightWindow,
        nowUtc: nowUtc,
      );
      aggregates.add(dayAggregate);
      
      currentDate = dayRange.endExclusiveLocal;
    }
    
    return aggregates;
  }

  /// Calculates aggregate for a single day.
  static DailySleepAggregate _calculateForDay({
    required List<SleepSession> sessions,
    required ({DateTime startLocal, DateTime endExclusiveLocal, String key}) dayRange,
    required NightWindow nightWindow,
    required DateTime nowUtc,
  }) {
    int totalMinutes = 0;
    int nightMinutes = 0;
    int napMinutes = 0;
    int longestBlockMinutes = 0;
    int nightEpisodesCount = 0;
    DateTime? bedtimeStartLocal;
    bool hasOngoingSleep = false;
    final daySessions = <SleepSession>[];

    for (final session in sessions) {
      final sessionStartUtc = session.startEvent.timestamp;
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

      daySessions.add(session);

      // Check for ongoing sleep
      if (!session.isComplete) {
        hasOngoingSleep = true;
      }

      // Calculate clipped duration for this day
      final clippedDuration = LocalTimeUtils.clipDurationToLocalDay(
        sessionStartUtc: sessionStartUtc,
        sessionEndUtc: sessionEndUtc,
        dayStartLocal: dayRange.startLocal,
        dayEndExclusiveLocal: dayRange.endExclusiveLocal,
      );

      final clippedMinutes = clippedDuration.inMinutes;
      totalMinutes += clippedMinutes;

      // Track longest block
      if (clippedMinutes > longestBlockMinutes) {
        longestBlockMinutes = clippedMinutes;
      }

      // Split into night vs nap minutes
      final (nightMins, napMins) = _splitNightNap(
        sessionStartUtc: sessionStartUtc,
        sessionEndUtc: sessionEndUtc,
        dayRange: dayRange,
        nightWindow: nightWindow,
      );
      nightMinutes += nightMins;
      napMinutes += napMins;

      // Count night episodes (sessions with any night intersection)
      if (nightMins > 0) {
        nightEpisodesCount++;
      }

      // Check for bedtime (first session starting 19:00-02:00 with duration >= 30min)
      if (bedtimeStartLocal == null) {
        final startLocal = LocalTimeUtils.toLocal(sessionStartUtc);
        final startHour = startLocal.hour;
        final sessionDuration = sessionEndUtc.difference(sessionStartUtc);
        
        // Check if start is in bedtime window (19:00-02:00)
        final isBedtimeStart = startHour >= 19 || startHour < 2;
        final isLongEnough = sessionDuration.inMinutes >= _minBedtimeDurationMinutes;
        
        // Session must start on this day
        final startsOnThisDay = !startLocal.isBefore(dayRange.startLocal) &&
            startLocal.isBefore(dayRange.endExclusiveLocal);
        
        if (isBedtimeStart && isLongEnough && startsOnThisDay) {
          bedtimeStartLocal = startLocal;
        }
      }
    }

    return DailySleepAggregate(
      dateLocal: dayRange.startLocal,
      totalMinutes: totalMinutes,
      nightMinutes: nightMinutes,
      napMinutes: napMinutes,
      longestBlockMinutes: longestBlockMinutes,
      nightEpisodesCount: nightEpisodesCount,
      bedtimeStartLocal: bedtimeStartLocal,
      sessions: daySessions,
      hasOngoingSleep: hasOngoingSleep,
    );
  }

  /// Splits clipped session duration into night and nap minutes.
  ///
  /// Uses hour-by-hour bucketing to accurately split sessions that span
  /// the night window boundaries.
  static (int nightMinutes, int napMinutes) _splitNightNap({
    required DateTime sessionStartUtc,
    required DateTime sessionEndUtc,
    required ({DateTime startLocal, DateTime endExclusiveLocal, String key}) dayRange,
    required NightWindow nightWindow,
  }) {
    final sessionStartLocal = LocalTimeUtils.toLocal(sessionStartUtc);
    final sessionEndLocal = LocalTimeUtils.toLocal(sessionEndUtc);

    // Clip to day boundaries
    final clippedStart = sessionStartLocal.isBefore(dayRange.startLocal)
        ? dayRange.startLocal
        : sessionStartLocal;
    final clippedEnd = sessionEndLocal.isAfter(dayRange.endExclusiveLocal)
        ? dayRange.endExclusiveLocal
        : sessionEndLocal;

    if (!clippedEnd.isAfter(clippedStart)) {
      return (0, 0);
    }

    // Simple approach: iterate by minute buckets (efficient for typical session lengths)
    int nightMinutes = 0;
    int napMinutes = 0;

    var current = clippedStart;
    while (current.isBefore(clippedEnd)) {
      final hour = current.hour;
      if (nightWindow.containsHour(hour)) {
        nightMinutes++;
      } else {
        napMinutes++;
      }
      current = current.add(const Duration(minutes: 1));
    }

    return (nightMinutes, napMinutes);
  }
}
