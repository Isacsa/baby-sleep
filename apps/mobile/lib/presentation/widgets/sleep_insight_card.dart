import 'package:flutter/material.dart';
import 'package:temp_flutter/domain/analysis/sleep_insight.dart';
import 'package:temp_flutter/presentation/theme/night_theme.dart';

/// Card widget for displaying a sleep insight
///
/// Shows the insight message with appropriate styling based on tone.
/// Optionally shows evidence text on expansion (future feature).
class SleepInsightCard extends StatelessWidget {
  final SleepInsight insight;
  final bool showEvidence;
  final bool compact;

  const SleepInsightCard({
    super.key,
    required this.insight,
    this.showEvidence = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconData = _getIcon();
    final iconColor = _getIconColor();
    final borderColor = _getBorderColor();

    return Container(
      padding: EdgeInsets.all(compact ? 12 : 14),
      decoration: BoxDecoration(
        color: NightTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: compact ? 28 : 32,
            height: compact ? 28 : 32,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              iconData,
              size: compact ? 16 : 18,
              color: iconColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight.messagePt,
                  style: TextStyle(
                    fontSize: compact ? 13 : 14,
                    height: 1.4,
                    color: NightTheme.textBody,
                  ),
                ),
                if (showEvidence && insight.evidencePt.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    insight.evidencePt,
                    style: TextStyle(
                      fontSize: compact ? 11 : 12,
                      color: NightTheme.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIcon() {
    switch (insight.category) {
      case InsightCategory.totalSleep:
        return Icons.bedtime_outlined;
      case InsightCategory.consistency:
        return Icons.schedule_outlined;
      case InsightCategory.fragmentation:
        return Icons.nights_stay_outlined;
      case InsightCategory.naps:
        return Icons.wb_sunny_outlined;
      case InsightCategory.currentState:
        return Icons.info_outline;
      case InsightCategory.general:
        return Icons.lightbulb_outline;
    }
  }

  Color _getIconColor() {
    switch (insight.tone) {
      case InsightTone.positive:
        return NightTheme.success;
      case InsightTone.neutral:
        return NightTheme.accent;
      case InsightTone.attention:
        return NightTheme.warning;
    }
  }

  Color _getBorderColor() {
    switch (insight.tone) {
      case InsightTone.positive:
        return NightTheme.success;
      case InsightTone.neutral:
        return NightTheme.textSecondary;
      case InsightTone.attention:
        return NightTheme.warning;
    }
  }
}

/// Card widget for displaying a suggested action
class SuggestedActionCard extends StatelessWidget {
  final SuggestedAction action;

  const SuggestedActionCard({
    super.key,
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NightTheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: NightTheme.primary.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: NightTheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.tips_and_updates_outlined,
              size: 18,
              color: NightTheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  action.titlePt,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: NightTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  action.descriptionPt,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: NightTheme.textBody,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
