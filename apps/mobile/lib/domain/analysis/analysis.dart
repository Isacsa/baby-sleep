/// Sleep analysis domain models and calculators
///
/// This module provides age-based sleep analysis capabilities:
/// - Age banding for developmental stages
/// - Curated sleep expectations by age
/// - Metrics calculation from session data
/// - Insight generation (empathetic, explainable)
/// - Routine suggestions (wake windows)
library analysis;

export 'age_band.dart';
export 'sleep_expectations.dart';
export 'sleep_insight.dart';
export 'sleep_insight_engine.dart';
export 'sleep_metrics.dart';
export 'sleep_metrics_calculator.dart';
export 'sleep_routine_suggester.dart';
export 'sleep_routine_suggestion.dart';
