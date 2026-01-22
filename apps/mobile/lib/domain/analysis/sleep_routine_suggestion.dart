/// Suggested sleep routine based on wake windows and recent patterns
///
/// Read-only value object for display. Provides suggestions for:
/// - Next nap time
/// - Bedtime
/// All times are local and presented as suggestions, not rules.
class SleepRoutineSuggestion {
  /// Suggested next nap window start (local time)
  final DateTime? nextNapWindowStart;

  /// Suggested next nap window end (local time)
  final DateTime? nextNapWindowEnd;

  /// Suggested next nap time (midpoint of window)
  final DateTime? nextNapSuggested;

  /// Suggested bedtime window start (local time)
  final DateTime? bedtimeWindowStart;

  /// Suggested bedtime window end (local time)
  final DateTime? bedtimeWindowEnd;

  /// Suggested bedtime (considering recent patterns)
  final DateTime? bedtimeSuggested;

  /// Explanation of how the suggestion was calculated (Portuguese)
  final String? explanationPt;

  /// Whether we have enough data to make suggestions
  final bool hasSufficientData;

  /// Whether the baby is currently sleeping (no nap suggestion if so)
  final bool isCurrentlySleeping;

  /// Last wake time used for calculation
  final DateTime? lastWakeTime;

  /// Wake window used for nap calculation (minutes)
  final int? wakeWindowUsedMinutes;

  /// Message when no suggestion available (Portuguese)
  final String? noSuggestionReasonPt;

  // === Extended fields for Insights v2 ===

  /// Suggested number of naps for the day (based on age if available)
  final int? suggestedNapsCount;

  /// Estimated nap duration based on recent patterns
  final Duration? estimatedNapDuration;

  /// Whether the suggestion is based on birthDate age expectations
  final bool hasAgeBasedSuggestion;

  /// Confidence level for the suggestion (0.0-1.0)
  final double confidence;

  const SleepRoutineSuggestion({
    this.nextNapWindowStart,
    this.nextNapWindowEnd,
    this.nextNapSuggested,
    this.bedtimeWindowStart,
    this.bedtimeWindowEnd,
    this.bedtimeSuggested,
    this.explanationPt,
    required this.hasSufficientData,
    required this.isCurrentlySleeping,
    this.lastWakeTime,
    this.wakeWindowUsedMinutes,
    this.noSuggestionReasonPt,
    // Extended fields
    this.suggestedNapsCount,
    this.estimatedNapDuration,
    this.hasAgeBasedSuggestion = false,
    this.confidence = 1.0,
  });

  /// Whether we can suggest a next nap
  bool get canSuggestNap =>
      hasSufficientData && !isCurrentlySleeping && nextNapSuggested != null;

  /// Whether we can suggest a bedtime
  bool get canSuggestBedtime => hasSufficientData && bedtimeSuggested != null;

  /// Formats a time as "HH:mm"
  static String formatTime(DateTime? time) {
    if (time == null) return '--:--';
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// Formatted next nap suggestion
  String get nextNapFormatted => formatTime(nextNapSuggested);

  /// Formatted next nap window
  String get nextNapWindowFormatted {
    if (nextNapWindowStart == null || nextNapWindowEnd == null) return '--';
    return '${formatTime(nextNapWindowStart)} - ${formatTime(nextNapWindowEnd)}';
  }

  /// Formatted bedtime suggestion
  String get bedtimeFormatted => formatTime(bedtimeSuggested);

  /// Formatted bedtime window
  String get bedtimeWindowFormatted {
    if (bedtimeWindowStart == null || bedtimeWindowEnd == null) return '--';
    return '${formatTime(bedtimeWindowStart)} - ${formatTime(bedtimeWindowEnd)}';
  }

  /// Creates an empty suggestion (no data)
  factory SleepRoutineSuggestion.noData({String? reason}) {
    return SleepRoutineSuggestion(
      hasSufficientData: false,
      isCurrentlySleeping: false,
      noSuggestionReasonPt:
          reason ?? 'Ainda não há dados suficientes para sugerir uma rotina.',
    );
  }

  /// Creates a suggestion when baby is sleeping
  factory SleepRoutineSuggestion.sleeping({
    DateTime? bedtimeWindowStart,
    DateTime? bedtimeWindowEnd,
    DateTime? bedtimeSuggested,
    String? explanationPt,
  }) {
    return SleepRoutineSuggestion(
      hasSufficientData: true,
      isCurrentlySleeping: true,
      bedtimeWindowStart: bedtimeWindowStart,
      bedtimeWindowEnd: bedtimeWindowEnd,
      bedtimeSuggested: bedtimeSuggested,
      explanationPt: explanationPt,
      noSuggestionReasonPt: 'O bebé está a dormir.',
    );
  }

  @override
  String toString() =>
      'SleepRoutineSuggestion(nap: $nextNapFormatted, bed: $bedtimeFormatted, sleeping: $isCurrentlySleeping)';
}
