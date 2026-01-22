import 'package:temp_flutter/domain/analysis/age_band.dart';

/// CTA action types for insights
enum InsightCtaAction {
  none,
  learnMore,
  openGuide,
  save,
  dismiss,
  addDob,
}

/// Priority levels for insights
enum InsightPriority {
  low,
  medium,
  high,
  critical,
}

/// Render model for an insight card
///
/// Contains only keys and args - no hardcoded text.
/// UI uses l10n to resolve keys to localized strings.
class InsightRenderModel {
  /// Unique ID (from InsightId)
  final String id;

  /// ARB key for title
  final String titleKey;

  /// ARB key for body text
  final String bodyKey;

  /// ARB key for "why" explanation (optional)
  final String? whyKey;

  /// ARB key for CTA label (optional)
  final String? ctaLabelKey;

  /// Arguments for string interpolation (e.g., hours, minutes, count)
  final Map<String, dynamic> args;

  /// CTA action type
  final InsightCtaAction ctaAction;

  /// Guide section to open (if ctaAction is openGuide)
  final String? guideSectionId;

  /// Source IDs referenced by this insight
  final List<String> sourceIds;

  /// Priority (for sorting)
  final InsightPriority priority;

  /// Confidence score (0.0 to 1.0)
  final double confidence;

  /// Cooldown in hours before showing again
  final int cooldownHours;

  /// Age bands where this insight applies (empty = all ages)
  final List<SleepAgeBand> ageBands;

  /// Minimum days of data required
  final int requiresDataDays;

  /// Whether this insight requires date of birth
  final bool requiresDob;

  const InsightRenderModel({
    required this.id,
    required this.titleKey,
    required this.bodyKey,
    this.whyKey,
    this.ctaLabelKey,
    this.args = const {},
    this.ctaAction = InsightCtaAction.none,
    this.guideSectionId,
    this.sourceIds = const [],
    this.priority = InsightPriority.medium,
    this.confidence = 1.0,
    this.cooldownHours = 24,
    this.ageBands = const [],
    this.requiresDataDays = 0,
    this.requiresDob = false,
  });

  /// Creates a copy with updated fields
  InsightRenderModel copyWith({
    String? id,
    String? titleKey,
    String? bodyKey,
    String? whyKey,
    String? ctaLabelKey,
    Map<String, dynamic>? args,
    InsightCtaAction? ctaAction,
    String? guideSectionId,
    List<String>? sourceIds,
    InsightPriority? priority,
    double? confidence,
    int? cooldownHours,
    List<SleepAgeBand>? ageBands,
    int? requiresDataDays,
    bool? requiresDob,
  }) {
    return InsightRenderModel(
      id: id ?? this.id,
      titleKey: titleKey ?? this.titleKey,
      bodyKey: bodyKey ?? this.bodyKey,
      whyKey: whyKey ?? this.whyKey,
      ctaLabelKey: ctaLabelKey ?? this.ctaLabelKey,
      args: args ?? this.args,
      ctaAction: ctaAction ?? this.ctaAction,
      guideSectionId: guideSectionId ?? this.guideSectionId,
      sourceIds: sourceIds ?? this.sourceIds,
      priority: priority ?? this.priority,
      confidence: confidence ?? this.confidence,
      cooldownHours: cooldownHours ?? this.cooldownHours,
      ageBands: ageBands ?? this.ageBands,
      requiresDataDays: requiresDataDays ?? this.requiresDataDays,
      requiresDob: requiresDob ?? this.requiresDob,
    );
  }

  @override
  String toString() => 'InsightRenderModel($id, priority: $priority)';
}

/// Result from the insight engine v2
class InsightEngineResult {
  /// Section "Hoje" cards (max 2)
  final List<InsightRenderModel> todayCards;

  /// Section "Padrões detetados" cards (max 4)
  final List<InsightRenderModel> patternCards;

  /// Whether the user is missing DOB (show banner)
  final bool needsDob;

  /// Whether there's insufficient data
  final bool insufficientData;

  /// Number of days of data used
  final int dataWindowDays;

  const InsightEngineResult({
    this.todayCards = const [],
    this.patternCards = const [],
    this.needsDob = false,
    this.insufficientData = false,
    this.dataWindowDays = 0,
  });

  bool get hasAnyInsights => todayCards.isNotEmpty || patternCards.isNotEmpty;

  factory InsightEngineResult.empty() => const InsightEngineResult();

  factory InsightEngineResult.noDob() => const InsightEngineResult(
    needsDob: true,
  );

  factory InsightEngineResult.insufficientData({int dataWindowDays = 0}) =>
      InsightEngineResult(
        insufficientData: true,
        dataWindowDays: dataWindowDays,
      );
}
