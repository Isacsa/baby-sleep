import 'package:flutter/material.dart';
import 'package:temp_flutter/core/l10n/l10n.dart';
import 'package:temp_flutter/domain/analysis/next_sleep_prediction.dart';
import 'package:temp_flutter/domain/stats/data_quality_assessment.dart';
import 'package:temp_flutter/presentation/theme/night_theme.dart';

/// Card showing the next sleep prediction
class NextSleepPredictionCard extends StatelessWidget {
  /// The prediction data
  final NextSleepPrediction prediction;

  /// Data quality status (for badge)
  final DataQualityStatus dataQuality;

  /// Callback when "See details" is tapped
  final VoidCallback? onSeeDetails;

  /// Callback when "How we calculate" is tapped
  final VoidCallback? onHowWeCalculate;

  const NextSleepPredictionCard({
    super.key,
    required this.prediction,
    required this.dataQuality,
    this.onSeeDetails,
    this.onHowWeCalculate,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NightTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: NightTheme.textSecondary.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            l10n.predictionTitle,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: NightTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),

          // Main content based on state
          if (prediction.isAvailable)
            _buildAvailablePrediction(context)
          else
            _buildUnavailablePrediction(context),

          // How we calculate (only if available)
          if (prediction.isAvailable || prediction.isCollectingPattern) ...[
            const SizedBox(height: 12),
            _buildActions(context),
          ],
        ],
      ),
    );
  }

  Widget _buildAvailablePrediction(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Window time
        Text(
          prediction.windowFormatted ?? '—',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: NightTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),

        // Badges row
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            // Confidence badge
            _ConfidenceBadge(confidence: prediction.confidence),

            // Data quality badge (if not good)
            if (dataQuality != DataQualityStatus.good)
              _DataQualityBadge(
                status: dataQuality,
                onTap: onSeeDetails,
              ),
          ],
        ),
        const SizedBox(height: 8),

        // Explanation line
        Text(
          l10n.predictionBasedOn(prediction.sampleCount),
          style: const TextStyle(
            fontSize: 12,
            color: NightTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildUnavailablePrediction(BuildContext context) {
    final l10n = context.l10n;

    String message;
    IconData icon;
    Color iconColor;

    switch (prediction.reason) {
      case PredictionReason.sleepingNow:
        message = l10n.predictionSleepingNow;
        icon = Icons.bedtime;
        iconColor = NightTheme.primary;
      case PredictionReason.collectingPattern:
        message = l10n.predictionCollecting;
        icon = Icons.hourglass_empty;
        iconColor = NightTheme.textSecondary;
      case PredictionReason.dataQualityTooLow:
        message = l10n.predictionDataQualityLow;
        icon = Icons.warning_amber_rounded;
        iconColor = NightTheme.warning;
      case PredictionReason.windowPassed:
        message = l10n.predictionWindowPassed;
        icon = Icons.schedule;
        iconColor = NightTheme.textSecondary;
      default:
        message = l10n.predictionCollecting;
        icon = Icons.hourglass_empty;
        iconColor = NightTheme.textSecondary;
    }

    return Row(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
              fontSize: 14,
              color: NightTheme.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActions(BuildContext context) {
    final l10n = context.l10n;

    return Row(
      children: [
        // Remind me (placeholder)
        Expanded(
          child: OutlinedButton.icon(
            onPressed: null, // Disabled placeholder
            icon: const Icon(Icons.notifications_outlined, size: 16),
            label: Text(l10n.predictionRemindMeSoon),
            style: OutlinedButton.styleFrom(
              foregroundColor: NightTheme.textSecondary.withValues(alpha: 0.5),
              side: BorderSide(
                color: NightTheme.textSecondary.withValues(alpha: 0.2),
              ),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              textStyle: const TextStyle(fontSize: 12),
            ),
          ),
        ),
        const SizedBox(width: 8),

        // How we calculate
        Expanded(
          child: TextButton.icon(
            onPressed: onHowWeCalculate,
            icon: const Icon(Icons.info_outline, size: 16),
            label: Text(l10n.predictionHowWeCalculate),
            style: TextButton.styleFrom(
              foregroundColor: NightTheme.textSecondary,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              textStyle: const TextStyle(fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }
}

/// Badge showing confidence level
class _ConfidenceBadge extends StatelessWidget {
  final ConfidenceLevel confidence;

  const _ConfidenceBadge({required this.confidence});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    Color bgColor;
    Color textColor;

    switch (confidence) {
      case ConfidenceLevel.high:
        bgColor = NightTheme.success.withValues(alpha: 0.2);
        textColor = NightTheme.success;
      case ConfidenceLevel.medium:
        bgColor = NightTheme.primary.withValues(alpha: 0.2);
        textColor = NightTheme.primary;
      case ConfidenceLevel.low:
        bgColor = NightTheme.textSecondary.withValues(alpha: 0.2);
        textColor = NightTheme.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        l10n.predictionConfidence(confidence.labelEn),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
    );
  }
}

/// Badge showing data quality warning
class _DataQualityBadge extends StatelessWidget {
  final DataQualityStatus status;
  final VoidCallback? onTap;

  const _DataQualityBadge({
    required this.status,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    final label = status == DataQualityStatus.partial
        ? l10n.predictionDataPartial
        : l10n.predictionDataIncomplete;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: NightTheme.warning.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: NightTheme.warning,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right,
                size: 14,
                color: NightTheme.warning,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet explaining how prediction works
class PredictionExplanationSheet extends StatelessWidget {
  const PredictionExplanationSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: NightTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: NightTheme.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Text(
            l10n.predictionExplainTitle,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: NightTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),

          // Bullet points
          _ExplainBullet(text: l10n.predictionExplain1),
          const SizedBox(height: 8),
          _ExplainBullet(text: l10n.predictionExplain2),
          const SizedBox(height: 8),
          _ExplainBullet(text: l10n.predictionExplain3),

          const SizedBox(height: 24),

          // Close button
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.commonOk),
            ),
          ),

          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

class _ExplainBullet extends StatelessWidget {
  final String text;

  const _ExplainBullet({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '•',
          style: TextStyle(
            fontSize: 16,
            color: NightTheme.primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              color: NightTheme.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
