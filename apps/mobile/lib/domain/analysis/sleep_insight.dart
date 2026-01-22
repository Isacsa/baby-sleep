import 'age_band.dart';
import 'sleep_expectations.dart';

/// A single insight about sleep patterns
///
/// Read-only value object for display. Each insight has:
/// - A category (what aspect of sleep)
/// - A message (empathetic, non-medical)
/// - Evidence (which metrics led to this insight)
/// - Optional action suggestion
/// - Cooldown and display rules
class SleepInsight {
  /// Unique identifier for this insight type
  final String id;

  /// Category of the insight
  final InsightCategory category;

  /// Priority for display ordering (lower = more important)
  final int priority;

  /// Main message (empathetic, Portuguese)
  final String messagePt;

  /// Evidence/reason for this insight (for transparency)
  final String evidencePt;

  /// Suggested action (optional, practical tip)
  final String? actionPt;

  /// Range comparison result (for total sleep insights)
  final RangeComparison? rangeComparison;

  /// Whether this is a positive/neutral/needs-attention insight
  final InsightTone tone;

  // === Extended fields for Insights v2 ===

  /// Cooldown in hours before this insight can be shown again
  final int cooldownHours;

  /// Minimum days of data required to show this insight
  final int requiresDataDays;

  /// Whether this insight requires birth date to be shown
  final bool requiresDob;

  /// Age bands this insight applies to (null = all ages)
  final List<SleepAgeBand>? ageBands;

  /// CTA action type
  final InsightCtaAction ctaAction;

  /// CTA label (Portuguese)
  final String? ctaLabel;

  /// Reference sources for the insight
  final List<String> sourcesRefs;

  /// Confidence level (0.0-1.0), used for ranking
  final double confidence;

  const SleepInsight({
    required this.id,
    required this.category,
    required this.priority,
    required this.messagePt,
    required this.evidencePt,
    this.actionPt,
    this.rangeComparison,
    required this.tone,
    // Extended fields with defaults
    this.cooldownHours = 24,
    this.requiresDataDays = 1,
    this.requiresDob = false,
    this.ageBands,
    this.ctaAction = InsightCtaAction.none,
    this.ctaLabel,
    this.sourcesRefs = const [],
    this.confidence = 1.0,
  });

  @override
  String toString() => 'SleepInsight($id: ${messagePt.substring(0, 30)}...)';
}

/// Categories of sleep insights
enum InsightCategory {
  /// Total sleep in 24h compared to age expectations
  totalSleep,

  /// Bedtime consistency across days
  consistency,

  /// Sleep fragmentation (night wakings, short sessions)
  fragmentation,

  /// Nap patterns (count, duration)
  naps,

  /// Current state and next steps
  currentState,

  /// General encouragement or age-appropriate notes
  general,
}

/// Extension for InsightCategory
extension InsightCategoryExtension on InsightCategory {
  String get labelPt {
    switch (this) {
      case InsightCategory.totalSleep:
        return 'Sono total';
      case InsightCategory.consistency:
        return 'Consistência';
      case InsightCategory.fragmentation:
        return 'Fragmentação';
      case InsightCategory.naps:
        return 'Sestas';
      case InsightCategory.currentState:
        return 'Estado atual';
      case InsightCategory.general:
        return 'Geral';
    }
  }

  String get iconName {
    switch (this) {
      case InsightCategory.totalSleep:
        return 'bedtime';
      case InsightCategory.consistency:
        return 'schedule';
      case InsightCategory.fragmentation:
        return 'nights_stay';
      case InsightCategory.naps:
        return 'wb_sunny';
      case InsightCategory.currentState:
        return 'info';
      case InsightCategory.general:
        return 'lightbulb';
    }
  }
}

/// Tone of the insight (for styling)
enum InsightTone {
  /// Positive feedback (green)
  positive,

  /// Neutral observation (blue/gray)
  neutral,

  /// Needs attention but not alarming (amber)
  attention,
}

/// Extension for InsightTone
extension InsightToneExtension on InsightTone {
  bool get isPositive => this == InsightTone.positive;
  bool get isNeutral => this == InsightTone.neutral;
  bool get needsAttention => this == InsightTone.attention;
}

/// CTA action types for insights
enum InsightCtaAction {
  /// No action
  none,
  
  /// Open a specific anchor in the Guide section
  openGuideAnchor,
  
  /// Open a checklist bottom sheet
  openChecklist,
  
  /// Open the baby profile to add DOB
  openBabyProfile,
  
  /// Open the routine editor
  openRoutineEditor,
  
  /// Save as favorite
  saveFavorite,
}

/// A suggested action for today
///
/// Separate from SleepInsight to allow specific "action cards" in UI.
class SuggestedAction {
  /// Unique identifier
  final String id;

  /// Short title (Portuguese)
  final String titlePt;

  /// Description/explanation (Portuguese)
  final String descriptionPt;

  /// Why this action is suggested
  final String reasonPt;

  /// Priority (lower = more important)
  final int priority;

  const SuggestedAction({
    required this.id,
    required this.titlePt,
    required this.descriptionPt,
    required this.reasonPt,
    required this.priority,
  });

  @override
  String toString() => 'SuggestedAction($id: $titlePt)';
}
