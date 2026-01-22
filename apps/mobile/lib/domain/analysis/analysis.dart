/// Sleep analysis domain models and calculators
///
/// This module provides age-based sleep analysis capabilities:
/// - Age banding for developmental stages
/// - Curated sleep expectations by age
/// - Metrics calculation from session data
/// - Insight generation (empathetic, explainable)
/// - Routine suggestions (wake windows)
library;

export 'age_band.dart';
export 'insight_cards_catalog.dart';
export 'insight_render_model.dart';
export 'insight_rules/insight_rule.dart';
export 'insight_rules/sleep_insight_rules.dart';
export 'sleep_expectations.dart';
// Hide InsightCtaAction from sleep_insight.dart to avoid conflict with insight_render_model.dart
export 'sleep_insight.dart' hide InsightCtaAction;
export 'sleep_insight_engine.dart';
export 'sleep_metrics.dart';
export 'sleep_metrics_calculator.dart';
export 'sleep_routine_suggester.dart';
export 'sleep_routine_suggestion.dart';
