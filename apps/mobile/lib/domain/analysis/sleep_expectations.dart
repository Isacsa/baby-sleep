import 'age_band.dart';

/// Sleep expectations for a specific age band
///
/// Contains reference ranges for sleep metrics based on developmental stage.
/// All durations are in minutes for consistency and easy comparison.
/// Values are curated from pediatric sleep research (bundled, not fetched).
class SleepExpectations {
  /// The age band these expectations apply to
  final SleepAgeBand ageBand;

  /// Total sleep in 24h (minutes) - minimum expected
  final int totalSleep24hMin;

  /// Total sleep in 24h (minutes) - maximum expected
  final int totalSleep24hMax;

  /// Night sleep typical range (minutes) - minimum
  final int? nightSleepMin;

  /// Night sleep typical range (minutes) - maximum
  final int? nightSleepMax;

  /// Typical number of naps - minimum
  final int? napCountMin;

  /// Typical number of naps - maximum
  final int? napCountMax;

  /// Wake window during day (minutes) - minimum
  final int wakeWindowDayMin;

  /// Wake window during day (minutes) - maximum
  final int wakeWindowDayMax;

  /// Wake window before bed (minutes) - minimum
  final int wakeWindowPreBedMin;

  /// Wake window before bed (minutes) - maximum
  final int wakeWindowPreBedMax;

  /// Typical bedtime window start (local time, e.g., "19:00")
  final String? bedtimeWindowStart;

  /// Typical bedtime window end (local time, e.g., "21:00")
  final String? bedtimeWindowEnd;

  /// Short description of what's normal at this age (Portuguese)
  final String? descriptionPt;

  /// Common challenges at this age (Portuguese)
  final List<String> commonChallengesPt;

  const SleepExpectations({
    required this.ageBand,
    required this.totalSleep24hMin,
    required this.totalSleep24hMax,
    this.nightSleepMin,
    this.nightSleepMax,
    this.napCountMin,
    this.napCountMax,
    required this.wakeWindowDayMin,
    required this.wakeWindowDayMax,
    required this.wakeWindowPreBedMin,
    required this.wakeWindowPreBedMax,
    this.bedtimeWindowStart,
    this.bedtimeWindowEnd,
    this.descriptionPt,
    this.commonChallengesPt = const [],
  });

  /// Total sleep 24h range as Duration
  Duration get totalSleep24hMinDuration => Duration(minutes: totalSleep24hMin);
  Duration get totalSleep24hMaxDuration => Duration(minutes: totalSleep24hMax);

  /// Wake window day range as Duration
  Duration get wakeWindowDayMinDuration => Duration(minutes: wakeWindowDayMin);
  Duration get wakeWindowDayMaxDuration => Duration(minutes: wakeWindowDayMax);

  /// Wake window pre-bed range as Duration
  Duration get wakeWindowPreBedMinDuration =>
      Duration(minutes: wakeWindowPreBedMin);
  Duration get wakeWindowPreBedMaxDuration =>
      Duration(minutes: wakeWindowPreBedMax);

  /// Midpoint of total sleep 24h range (in minutes)
  int get totalSleep24hMid => (totalSleep24hMin + totalSleep24hMax) ~/ 2;

  /// Midpoint of wake window day range (in minutes)
  int get wakeWindowDayMid => (wakeWindowDayMin + wakeWindowDayMax) ~/ 2;

  /// Midpoint of wake window pre-bed range (in minutes)
  int get wakeWindowPreBedMid =>
      (wakeWindowPreBedMin + wakeWindowPreBedMax) ~/ 2;

  /// Compares a value against the expected range
  ///
  /// Returns:
  /// - [RangeComparison.below] if value < min
  /// - [RangeComparison.within] if min <= value <= max
  /// - [RangeComparison.above] if value > max
  RangeComparison compareTotalSleep24h(int totalMinutes) {
    if (totalMinutes < totalSleep24hMin) return RangeComparison.below;
    if (totalMinutes > totalSleep24hMax) return RangeComparison.above;
    return RangeComparison.within;
  }

  /// Parses bedtime window start as TimeOfDay-like (hour, minute)
  ({int hour, int minute})? get bedtimeStartTime {
    return _parseTime(bedtimeWindowStart);
  }

  /// Parses bedtime window end as TimeOfDay-like (hour, minute)
  ({int hour, int minute})? get bedtimeEndTime {
    return _parseTime(bedtimeWindowEnd);
  }

  static ({int hour, int minute})? _parseTime(String? timeStr) {
    if (timeStr == null) return null;
    final parts = timeStr.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return (hour: hour, minute: minute);
  }

  /// Creates from JSON (for loading from bundled assets)
  factory SleepExpectations.fromJson(Map<String, dynamic> json) {
    return SleepExpectations(
      ageBand: SleepAgeBand.values.firstWhere(
        (b) => b.name == json['ageBand'],
        orElse: () => SleepAgeBand.unknown,
      ),
      totalSleep24hMin: json['totalSleep24hMin'] as int,
      totalSleep24hMax: json['totalSleep24hMax'] as int,
      nightSleepMin: json['nightSleepMin'] as int?,
      nightSleepMax: json['nightSleepMax'] as int?,
      napCountMin: json['napCountMin'] as int?,
      napCountMax: json['napCountMax'] as int?,
      wakeWindowDayMin: json['wakeWindowDayMin'] as int,
      wakeWindowDayMax: json['wakeWindowDayMax'] as int,
      wakeWindowPreBedMin: json['wakeWindowPreBedMin'] as int,
      wakeWindowPreBedMax: json['wakeWindowPreBedMax'] as int,
      bedtimeWindowStart: json['bedtimeWindowStart'] as String?,
      bedtimeWindowEnd: json['bedtimeWindowEnd'] as String?,
      descriptionPt: json['descriptionPt'] as String?,
      commonChallengesPt: (json['commonChallengesPt'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'ageBand': ageBand.name,
        'totalSleep24hMin': totalSleep24hMin,
        'totalSleep24hMax': totalSleep24hMax,
        'nightSleepMin': nightSleepMin,
        'nightSleepMax': nightSleepMax,
        'napCountMin': napCountMin,
        'napCountMax': napCountMax,
        'wakeWindowDayMin': wakeWindowDayMin,
        'wakeWindowDayMax': wakeWindowDayMax,
        'wakeWindowPreBedMin': wakeWindowPreBedMin,
        'wakeWindowPreBedMax': wakeWindowPreBedMax,
        'bedtimeWindowStart': bedtimeWindowStart,
        'bedtimeWindowEnd': bedtimeWindowEnd,
        'descriptionPt': descriptionPt,
        'commonChallengesPt': commonChallengesPt,
      };

  @override
  String toString() =>
      'SleepExpectations(ageBand: $ageBand, total24h: $totalSleep24hMin-$totalSleep24hMax min)';
}

/// Result of comparing a value to an expected range
enum RangeComparison {
  /// Below the minimum expected
  below,

  /// Within the expected range
  within,

  /// Above the maximum expected
  above,
}

/// Extension for RangeComparison
extension RangeComparisonExtension on RangeComparison {
  /// Label in Portuguese
  String get labelPt {
    switch (this) {
      case RangeComparison.below:
        return 'abaixo';
      case RangeComparison.within:
        return 'dentro';
      case RangeComparison.above:
        return 'acima';
    }
  }

  /// Whether this is a "concerning" result (below only, above is neutral)
  bool get isBelow => this == RangeComparison.below;
  bool get isWithin => this == RangeComparison.within;
  bool get isAbove => this == RangeComparison.above;
}
