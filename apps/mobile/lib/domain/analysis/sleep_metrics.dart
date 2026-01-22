/// Sleep metrics calculated from session data
///
/// Read-only value object that holds derived metrics for display and analysis.
/// All durations are stored as Duration for type safety.
class SleepMetrics {
  /// Total sleep in the last 24 hours (rolling window)
  final Duration totalSleepLast24h;

  /// Number of naps in the last 24 hours
  final int napCountLast24h;

  /// Average nap duration (null if no naps)
  final Duration? avgNapDuration;

  /// Rate of short naps (<30 min) as a fraction 0.0-1.0
  final double shortNapRate;

  /// Fragmentation score (0.0 = consolidated, 1.0 = highly fragmented)
  ///
  /// Heuristic based on:
  /// - Number of night wakings
  /// - Percentage of sessions < 45 min at night
  final double fragmentationScore;

  /// Bedtime consistency (standard deviation in minutes)
  ///
  /// Lower = more consistent. null if insufficient data (< 3 days).
  final double? bedtimeConsistencyMinutes;

  /// Last wake time (end of last sleep or null if no data)
  final DateTime? lastWakeTime;

  /// Whether the baby is currently sleeping
  final bool isCurrentlySleeping;

  /// Current session start time (if sleeping)
  final DateTime? currentSessionStart;

  /// Total sleep by local day (map of date string to duration)
  ///
  /// Key format: "yyyy-MM-dd"
  /// Duration is clipped to each day's boundaries.
  final Map<String, Duration> totalSleepByDay;

  /// Number of complete sessions in the last 24h
  final int sessionCountLast24h;

  /// Longest session duration in the last 24h
  final Duration? longestSessionLast24h;

  /// Median bedtime (local hour + minutes) over last N days
  ///
  /// null if insufficient data.
  final DateTime? medianBedtime;

  /// Number of days with data used for calculations
  final int daysWithData;

  /// Timestamp when these metrics were calculated
  final DateTime calculatedAt;

  // === Extended metrics for Insights v2 ===

  /// Average total sleep per day over last 7 days (null if <3 days)
  final Duration? avgTotalSleep7d;

  /// Median total sleep per day over last 7 days (null if <3 days)
  final Duration? medianTotalSleep7d;

  /// Average total sleep per day over last 14 days (null if <7 days)
  final Duration? avgTotalSleep14d;

  /// Bedtime variability range (max - min bedtime) in minutes over last 7 days
  /// 
  /// Useful for showing "variação ±X min" in UI. null if <3 days.
  final int? bedtimeVariabilityRangeMinutes;

  /// Average episodes (sessions) per night over last 7 days
  /// 
  /// Used for fragmentation insights.
  final double? avgEpisodesPerNight7d;

  /// Total night sleep in last 24h (sessions classified as night)
  final Duration nightSleepLast24h;

  /// Total nap sleep in last 24h (sessions classified as daytime naps)
  final Duration napSleepLast24h;

  /// Longest session over the last 7 days
  final Duration? longestSession7d;

  /// Average gap between sessions (awake time) in last 24h
  final Duration? avgGapBetweenSessions24h;

  /// Difference from 7d average (positive = more sleep, negative = less)
  final Duration? diffFromAvg7d;

  const SleepMetrics({
    required this.totalSleepLast24h,
    required this.napCountLast24h,
    this.avgNapDuration,
    required this.shortNapRate,
    required this.fragmentationScore,
    this.bedtimeConsistencyMinutes,
    this.lastWakeTime,
    required this.isCurrentlySleeping,
    this.currentSessionStart,
    required this.totalSleepByDay,
    required this.sessionCountLast24h,
    this.longestSessionLast24h,
    this.medianBedtime,
    required this.daysWithData,
    required this.calculatedAt,
    // Extended metrics
    this.avgTotalSleep7d,
    this.medianTotalSleep7d,
    this.avgTotalSleep14d,
    this.bedtimeVariabilityRangeMinutes,
    this.avgEpisodesPerNight7d,
    this.nightSleepLast24h = Duration.zero,
    this.napSleepLast24h = Duration.zero,
    this.longestSession7d,
    this.avgGapBetweenSessions24h,
    this.diffFromAvg7d,
  });

  /// Total sleep in last 24h as minutes (for comparisons)
  int get totalSleepLast24hMinutes => totalSleepLast24h.inMinutes;

  /// Whether we have enough data for meaningful insights
  ///
  /// Requires at least 1 day of data.
  bool get hasMinimumData => daysWithData >= 1;

  /// Whether we have enough data for consistency metrics
  ///
  /// Requires at least 3 days of data.
  bool get hasConsistencyData => daysWithData >= 3;

  /// Formatted total sleep (e.g., "12h 30m")
  String get totalSleepLast24hFormatted {
    final hours = totalSleepLast24h.inHours;
    final minutes = totalSleepLast24h.inMinutes % 60;
    if (hours == 0) return '${minutes}m';
    if (minutes == 0) return '${hours}h';
    return '${hours}h ${minutes}m';
  }

  /// Creates an empty/default metrics object
  factory SleepMetrics.empty({DateTime? calculatedAt}) {
    return SleepMetrics(
      totalSleepLast24h: Duration.zero,
      napCountLast24h: 0,
      avgNapDuration: null,
      shortNapRate: 0.0,
      fragmentationScore: 0.0,
      bedtimeConsistencyMinutes: null,
      lastWakeTime: null,
      isCurrentlySleeping: false,
      currentSessionStart: null,
      totalSleepByDay: const {},
      sessionCountLast24h: 0,
      longestSessionLast24h: null,
      medianBedtime: null,
      daysWithData: 0,
      calculatedAt: calculatedAt ?? DateTime.now(),
      // Extended metrics defaults
      avgTotalSleep7d: null,
      medianTotalSleep7d: null,
      avgTotalSleep14d: null,
      bedtimeVariabilityRangeMinutes: null,
      avgEpisodesPerNight7d: null,
      nightSleepLast24h: Duration.zero,
      napSleepLast24h: Duration.zero,
      longestSession7d: null,
      avgGapBetweenSessions24h: null,
      diffFromAvg7d: null,
    );
  }

  /// Formatted difference from 7d average (e.g., "+45 min" or "-30 min")
  String? get diffFromAvg7dFormatted {
    if (diffFromAvg7d == null) return null;
    final minutes = diffFromAvg7d!.inMinutes;
    if (minutes == 0) return '0 min';
    final sign = minutes > 0 ? '+' : '';
    if (minutes.abs() >= 60) {
      final hours = minutes ~/ 60;
      final mins = minutes.abs() % 60;
      if (mins == 0) return '$sign${hours}h';
      return '$sign${hours}h ${mins}m';
    }
    return '$sign$minutes min';
  }

  /// Formatted night sleep (e.g., "8h 30m")
  String get nightSleepLast24hFormatted {
    final hours = nightSleepLast24h.inHours;
    final minutes = nightSleepLast24h.inMinutes % 60;
    if (hours == 0) return '${minutes}m';
    if (minutes == 0) return '${hours}h';
    return '${hours}h ${minutes}m';
  }

  /// Formatted nap sleep (e.g., "2h 15m")
  String get napSleepLast24hFormatted {
    final hours = napSleepLast24h.inHours;
    final minutes = napSleepLast24h.inMinutes % 60;
    if (hours == 0) return '${minutes}m';
    if (minutes == 0) return '${hours}h';
    return '${hours}h ${minutes}m';
  }

  /// Whether we have data for 7-day trends
  bool get hasTrendData => daysWithData >= 7;

  @override
  String toString() =>
      'SleepMetrics(total24h: $totalSleepLast24hFormatted, naps: $napCountLast24h, sleeping: $isCurrentlySleeping)';
}
