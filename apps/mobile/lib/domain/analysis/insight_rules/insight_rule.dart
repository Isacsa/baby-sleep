import 'package:temp_flutter/domain/analysis/age_band.dart';
import 'package:temp_flutter/domain/analysis/insight_render_model.dart';
import 'package:temp_flutter/domain/analysis/sleep_expectations.dart';
import 'package:temp_flutter/domain/analysis/sleep_metrics.dart';

/// Context passed to insight rules for evaluation
class InsightRuleContext {
  final SleepMetrics metrics;
  final SleepExpectations? expectations;
  final SleepAgeBand? ageBand;
  final String? babyName;
  final DateTime now;
  final int dataWindowDays;

  const InsightRuleContext({
    required this.metrics,
    this.expectations,
    this.ageBand,
    this.babyName,
    required this.now,
    required this.dataWindowDays,
  });

  bool get hasDob => ageBand != null;
  bool get hasExpectations => expectations != null;
}

/// Interface for insight rules
///
/// Each rule evaluates metrics and returns an insight if triggered.
/// Rules should be stateless and pure.
abstract class InsightRule {
  /// Unique ID for this rule (matches InsightId)
  String get id;

  /// Priority of this insight
  InsightPriority get priority;

  /// Cooldown in hours
  int get cooldownHours;

  /// Minimum days of data required
  int get requiresDataDays;

  /// Whether this rule requires DOB
  bool get requiresDob;

  /// Age bands where this rule applies (empty = all ages)
  List<SleepAgeBand> get ageBands;

  /// Evaluates the rule and returns an insight if triggered
  ///
  /// Returns null if the rule doesn't apply.
  InsightRenderModel? evaluate(InsightRuleContext context);

  /// Checks if this rule should be considered given the context
  bool shouldEvaluate(InsightRuleContext context) {
    // Check DOB requirement
    if (requiresDob && !context.hasDob) return false;

    // Check data window requirement
    if (context.dataWindowDays < requiresDataDays) return false;

    // Check age band
    if (ageBands.isNotEmpty && context.ageBand != null) {
      if (!ageBands.contains(context.ageBand)) return false;
    }

    return true;
  }
}

/// Base class for simple rules that just check a condition
abstract class SimpleInsightRule extends InsightRule {
  @override
  InsightRenderModel? evaluate(InsightRuleContext context) {
    if (!shouldEvaluate(context)) return null;
    if (!condition(context)) return null;
    return buildInsight(context);
  }

  /// The condition to check
  bool condition(InsightRuleContext context);

  /// Builds the insight when condition is true
  InsightRenderModel buildInsight(InsightRuleContext context);
}
