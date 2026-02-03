import 'package:flutter/material.dart';
import 'package:temp_flutter/core/l10n/l10n.dart';
import 'package:temp_flutter/domain/stats/data_quality_assessment.dart';
import 'package:temp_flutter/domain/stats/sleep_data_quality_view_model.dart';
import 'package:temp_flutter/presentation/theme/night_theme.dart';

/// Compact indicator showing data quality status
class DataQualityIndicator extends StatelessWidget {
  /// The data quality view model
  final SleepDataQualityViewModel viewModel;

  /// Callback when "See details" is tapped
  final VoidCallback? onSeeDetails;

  const DataQualityIndicator({
    super.key,
    required this.viewModel,
    this.onSeeDetails,
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
          // Header row
          Row(
            children: [
              Text(
                l10n.dataQualityTitle,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: NightTheme.textSecondary,
                ),
              ),
              const Spacer(),
              _StatusBadge(status: viewModel.status),
            ],
          ),

          // Warning message (if not good)
          if (!viewModel.isGood) ...[
            const SizedBox(height: 8),
            Text(
              viewModel.predictionWarningEn ?? '',
              style: const TextStyle(
                fontSize: 12,
                color: NightTheme.textSecondary,
              ),
            ),
          ],

          // See details CTA
          if (viewModel.hasIssues) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: onSeeDetails,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.dataQualitySeeDetails,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: NightTheme.primary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: NightTheme.primary,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Status badge
class _StatusBadge extends StatelessWidget {
  final DataQualityStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    String label;
    Color bgColor;
    Color textColor;
    IconData icon;

    switch (status) {
      case DataQualityStatus.good:
        label = l10n.dataQualityGood;
        bgColor = NightTheme.success.withValues(alpha: 0.2);
        textColor = NightTheme.success;
        icon = Icons.check_circle_outline;
      case DataQualityStatus.partial:
        label = l10n.dataQualityPartial;
        bgColor = NightTheme.warning.withValues(alpha: 0.2);
        textColor = NightTheme.warning;
        icon = Icons.remove_circle_outline;
      case DataQualityStatus.incomplete:
        label = l10n.dataQualityIncomplete;
        bgColor = NightTheme.error.withValues(alpha: 0.2);
        textColor = NightTheme.error;
        icon = Icons.error_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet showing data quality issues
class DataQualityDetailsSheet extends StatelessWidget {
  final SleepDataQualityViewModel viewModel;

  const DataQualityDetailsSheet({
    super.key,
    required this.viewModel,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final issues = viewModel.issuesForDisplay;

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

          // Title with status
          Row(
            children: [
              Text(
                l10n.dataQualityTitle,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: NightTheme.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              _StatusBadge(status: viewModel.status),
            ],
          ),
          const SizedBox(height: 16),

          // Issues list
          if (issues.isEmpty)
            Text(
              'No issues detected.',
              style: TextStyle(
                fontSize: 14,
                color: NightTheme.textSecondary,
              ),
            )
          else
            ...issues.map((issue) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _IssueCard(issue: issue),
                )),

          const SizedBox(height: 16),

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

/// Card showing a single issue
class _IssueCard extends StatelessWidget {
  final DataQualityIssueDisplay issue;

  const _IssueCard({required this.issue});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: NightTheme.backgroundBase.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            issue.titleEn,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: NightTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),

          // Impact
          Text(
            issue.impactEn,
            style: const TextStyle(
              fontSize: 12,
              color: NightTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 4),

          // Action
          Text(
            issue.actionEn,
            style: const TextStyle(
              fontSize: 12,
              color: NightTheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
