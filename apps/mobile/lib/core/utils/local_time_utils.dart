import 'package:flutter/material.dart';

/// Utilities for local time handling, day boundaries, and timezone-aware operations.
///
/// Use this for:
/// - Converting between UTC and local time
/// - Calculating local day boundaries (for calendars, stats, grouping)
/// - Clipping session durations to day intervals
/// - Validating user-picked times against DST transitions
///
/// Note: [TimestampUtils] in `timestamp_utils.dart` handles UTC-only operations.
/// This file handles local time and day boundary calculations.
class LocalTimeUtils {
  LocalTimeUtils._();

  // ============================================================
  // CONVERSION HELPERS
  // ============================================================

  /// Converts any DateTime to UTC.
  ///
  /// If already UTC, returns as-is.
  static DateTime toUtc(DateTime dateTime) {
    return dateTime.isUtc ? dateTime : dateTime.toUtc();
  }

  /// Converts any DateTime to local time.
  ///
  /// If already local, returns as-is.
  static DateTime toLocal(DateTime dateTime) {
    return dateTime.isUtc ? dateTime.toLocal() : dateTime;
  }

  // ============================================================
  // LOCAL DAY BOUNDARIES
  // ============================================================

  /// Returns the local day range for a given reference time.
  ///
  /// The day is a half-open interval: [startLocal, endExclusiveLocal)
  /// This correctly handles DST days with 23 or 25 hours.
  ///
  /// [reference] can be in UTC or local time; it will be converted to local.
  ///
  /// Returns:
  /// - `startLocal`: 00:00:00.000 local time on the reference day
  /// - `endExclusiveLocal`: 00:00:00.000 local time on the NEXT day
  /// - `key`: date string in format "yyyy-MM-dd" (local date)
  static ({DateTime startLocal, DateTime endExclusiveLocal, String key}) localDayRange(
    DateTime reference,
  ) {
    final local = toLocal(reference);
    final startLocal = DateTime(local.year, local.month, local.day);
    final endExclusiveLocal = DateTime(local.year, local.month, local.day + 1);
    final key = _formatDateKey(startLocal);

    return (
      startLocal: startLocal,
      endExclusiveLocal: endExclusiveLocal,
      key: key,
    );
  }

  /// Returns local day range for a specific date (year, month, day).
  ///
  /// Useful when iterating over a range of days.
  static ({DateTime startLocal, DateTime endExclusiveLocal, String key}) localDayRangeFromDate(
    int year,
    int month,
    int day,
  ) {
    final startLocal = DateTime(year, month, day);
    final endExclusiveLocal = DateTime(year, month, day + 1);
    final key = _formatDateKey(startLocal);

    return (
      startLocal: startLocal,
      endExclusiveLocal: endExclusiveLocal,
      key: key,
    );
  }

  /// Formats a DateTime as "yyyy-MM-dd" date key (uses local date).
  static String dateKey(DateTime dateTime) {
    final local = toLocal(dateTime);
    return _formatDateKey(local);
  }

  static String _formatDateKey(DateTime local) {
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }

  // ============================================================
  // OVERLAP AND CLIPPING
  // ============================================================

  /// Checks if a session (defined by start/end UTC) overlaps with a local day.
  ///
  /// Overlap is true if: sessionStart < dayEndExclusive AND sessionEnd > dayStart
  ///
  /// [sessionStartUtc]: session start in UTC
  /// [sessionEndUtc]: session end in UTC (use `now` for ongoing sessions)
  /// [dayStartLocal]: 00:00 local of the day
  /// [dayEndExclusiveLocal]: 00:00 local of the next day
  static bool sessionOverlapsDay({
    required DateTime sessionStartUtc,
    required DateTime sessionEndUtc,
    required DateTime dayStartLocal,
    required DateTime dayEndExclusiveLocal,
  }) {
    final sessionStartLocal = toLocal(sessionStartUtc);
    final sessionEndLocal = toLocal(sessionEndUtc);

    // Session overlaps if it starts before day ends AND ends after day starts
    return sessionStartLocal.isBefore(dayEndExclusiveLocal) &&
        sessionEndLocal.isAfter(dayStartLocal);
  }

  /// Clips a session duration to a local day interval.
  ///
  /// Returns the duration of the session that falls within [dayStartLocal, dayEndExclusiveLocal).
  /// Returns Duration.zero if no overlap.
  ///
  /// [sessionStartUtc]: session start in UTC
  /// [sessionEndUtc]: session end in UTC (use `now` for ongoing sessions)
  /// [dayStartLocal]: 00:00 local of the day
  /// [dayEndExclusiveLocal]: 00:00 local of the next day
  static Duration clipDurationToLocalDay({
    required DateTime sessionStartUtc,
    required DateTime sessionEndUtc,
    required DateTime dayStartLocal,
    required DateTime dayEndExclusiveLocal,
  }) {
    final sessionStartLocal = toLocal(sessionStartUtc);
    final sessionEndLocal = toLocal(sessionEndUtc);

    // Clip to day boundaries
    final clippedStart = sessionStartLocal.isBefore(dayStartLocal)
        ? dayStartLocal
        : sessionStartLocal;
    final clippedEnd = sessionEndLocal.isAfter(dayEndExclusiveLocal)
        ? dayEndExclusiveLocal
        : sessionEndLocal;

    // If clipped interval is valid (end > start), return duration
    if (clippedEnd.isAfter(clippedStart)) {
      return clippedEnd.difference(clippedStart);
    }

    return Duration.zero;
  }

  // ============================================================
  // DST VALIDATION (BEST-EFFORT)
  // ============================================================

  /// Builds a local DateTime from a date and time, with DST validation.
  ///
  /// Returns the constructed DateTime and a flag indicating if DST adjustment occurred.
  ///
  /// **DST spring-forward (gap):** When clocks skip an hour (e.g., 02:00 → 03:00),
  /// DateTime(...) may adjust the time. We detect this by checking if the
  /// resulting hour/minute differs from the input.
  ///
  /// **DST fall-back (overlap):** When clocks repeat an hour, DateTime uses
  /// the system default (typically the second occurrence). We cannot detect
  /// or disambiguate this without a timezone package.
  ///
  /// [dateLocal]: A local DateTime representing the date (year, month, day).
  ///              Hour/minute/second are ignored.
  /// [time]: The TimeOfDay to combine with the date.
  ///
  /// Returns:
  /// - `local`: The constructed DateTime in local time.
  /// - `isDstGap`: True if the time was adjusted (likely DST gap).
  static ({DateTime local, bool isDstGap}) buildValidatedLocalDateTime({
    required DateTime dateLocal,
    required TimeOfDay time,
  }) {
    // Ensure we're working with local date
    final localDate = toLocal(dateLocal);

    // Build the DateTime
    final result = DateTime(
      localDate.year,
      localDate.month,
      localDate.day,
      time.hour,
      time.minute,
    );

    // Check if hour/minute was adjusted (DST gap detection)
    final isDstGap = result.hour != time.hour || result.minute != time.minute;

    return (local: result, isDstGap: isDstGap);
  }

  /// Combines a date and time into a local DateTime.
  ///
  /// Simple version without DST validation. Use [buildValidatedLocalDateTime]
  /// when user input needs validation.
  static DateTime combineDateTime(DateTime dateLocal, TimeOfDay time) {
    final local = toLocal(dateLocal);
    return DateTime(local.year, local.month, local.day, time.hour, time.minute);
  }

  // ============================================================
  // DATE HELPERS
  // ============================================================

  /// Checks if two DateTimes are on the same local day.
  static bool isSameLocalDay(DateTime a, DateTime b) {
    final localA = toLocal(a);
    final localB = toLocal(b);
    return localA.year == localB.year &&
        localA.month == localB.month &&
        localA.day == localB.day;
  }

  /// Returns today's local day range.
  static ({DateTime startLocal, DateTime endExclusiveLocal, String key}) todayLocalRange() {
    return localDayRange(DateTime.now());
  }

  /// Returns yesterday's local day range.
  static ({DateTime startLocal, DateTime endExclusiveLocal, String key}) yesterdayLocalRange() {
    final today = DateTime.now();
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    return localDayRange(yesterday);
  }

  /// Returns the local hour (0-23) for a UTC DateTime.
  ///
  /// Useful for nap/night classification based on local time.
  static int localHour(DateTime utcDateTime) {
    return toLocal(utcDateTime).hour;
  }

  /// Checks if a local hour is considered "daytime" (6:00-17:59).
  ///
  /// Used for nap classification.
  static bool isDaytimeHour(int localHour) {
    return localHour >= 6 && localHour < 18;
  }

  /// Checks if a local hour is considered "evening/night" (18:00-23:59 or 00:00-05:59).
  ///
  /// Used for bedtime/night session classification.
  static bool isNighttimeHour(int localHour) {
    return localHour >= 18 || localHour < 6;
  }

  /// Checks if a local hour is considered "night sleep start" (18:00-23:59).
  ///
  /// Used for bedtime consistency calculations.
  static bool isBedtimeHour(int localHour) {
    return localHour >= 18;
  }
}
