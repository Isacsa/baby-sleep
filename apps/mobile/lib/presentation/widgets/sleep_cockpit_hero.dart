import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:temp_flutter/application/providers/sleep_cockpit_provider.dart';
import 'package:temp_flutter/core/l10n/l10n.dart';
import 'package:temp_flutter/domain/analysis/sleep_goal.dart';
import 'package:temp_flutter/presentation/theme/night_theme.dart';
import 'package:temp_flutter/presentation/widgets/next_sleep_prediction_card.dart';
import 'package:temp_flutter/presentation/widgets/sleep_goal_ring.dart';

/// The hero section of the sleep cockpit
///
/// Contains:
/// - Sleep Goal Ring with progress
/// - Next Sleep Prediction Card
class SleepCockpitHero extends ConsumerWidget {
  /// Callback when "Add DOB" is tapped
  final VoidCallback? onAddDob;

  /// Callback when "See data quality details" is tapped
  final VoidCallback? onSeeDataQualityDetails;

  const SleepCockpitHero({
    super.key,
    this.onAddDob,
    this.onSeeDataQualityDetails,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cockpit = ref.watch(sleepCockpitProvider);

    return Column(
      children: [
        // Sleep Goal Section
        _SleepGoalSection(
          goal: cockpit.goal,
          onAddDob: onAddDob,
        ),

        const SizedBox(height: 16),

        // Next Sleep Prediction Card
        NextSleepPredictionCard(
          prediction: cockpit.prediction,
          dataQuality: cockpit.dataQuality.status,
          onSeeDetails: onSeeDataQualityDetails,
          onHowWeCalculate: () => _showExplanationSheet(context),
        ),
      ],
    );
  }

  void _showExplanationSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const PredictionExplanationSheet(),
    );
  }
}

/// The sleep goal section with ring and text
class _SleepGoalSection extends StatelessWidget {
  final SleepGoalComputed goal;
  final VoidCallback? onAddDob;

  const _SleepGoalSection({
    required this.goal,
    this.onAddDob,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: NightTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: NightTheme.textSecondary.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // "Today" label removed from here as it's now inside the info column
          // Main row: Ring + Info
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Ring
              SleepGoalRing(goal: goal),

              const SizedBox(width: 20),

              // Info column
              Expanded(
                child: _buildInfoColumn(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoColumn(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label "Today"
        Text(
          l10n.cockpitTodayLabel.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            color: NightTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 4),

        // Total Value + Badge (Wrapped)
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            Text(
              goal.totalFormatted,
              style: const TextStyle(
                fontSize: 28, // Hero size
                fontWeight: FontWeight.w700,
                color: NightTheme.textPrimary,
                height: 1.0,
              ),
            ),
            // In progress badge
            if (goal.hasOngoingSleep)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: NightTheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: NightTheme.primary.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Pulsing dot effect could be added here
                    const Icon(Icons.timelapse, size: 12, color: NightTheme.primary),
                    const SizedBox(width: 4),
                    Text(
                      l10n.cockpitInProgress,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: NightTheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        
        const SizedBox(height: 8),

        // Range or CTA
        if (goal.status == SleepGoalStatus.noBirthDate)
          _buildAddDobCta(context)
        else
          _buildRangeText(context),

        const SizedBox(height: 4),

        // Microcopy
        Text(
          _getMicrocopy(context),
          style: const TextStyle(
            fontSize: 12,
            color: NightTheme.textSecondary,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildRangeText(BuildContext context) {
    final l10n = context.l10n;
    final rangeStr = goal.goalRange.rangeFormatted;

    // Use "Reference" for babies < 4 months, "Recommended" otherwise
    final text = goal.isUnder4Months
        ? l10n.cockpitReference(rangeStr)
        : l10n.cockpitRecommended(rangeStr);

    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        color: NightTheme.textSecondary,
      ),
    );
  }

  Widget _buildAddDobCta(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.cockpitAddDobForGoal,
          style: const TextStyle(
            fontSize: 12,
            color: NightTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: onAddDob,
          child: Text(
            l10n.cockpitAddDob,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: NightTheme.primary,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }

  String _getMicrocopy(BuildContext context) {
    final l10n = context.l10n;

    switch (goal.status) {
      case SleepGoalStatus.noBirthDate:
        return l10n.cockpitAddDobForGoal;
      case SleepGoalStatus.noData:
        return l10n.cockpitNoDataYet;
      case SleepGoalStatus.below:
        // Softer tone for < 4 months
        return goal.isUnder4Months
            ? l10n.cockpitApproachingReference
            : l10n.cockpitApproachingMin;
      case SleepGoalStatus.within:
        return goal.isUnder4Months
            ? l10n.cockpitWithinReference
            : l10n.cockpitWithinRange;
      case SleepGoalStatus.above:
        return l10n.cockpitDifferentToday;
      case SleepGoalStatus.inProgress:
        return l10n.cockpitUpdatingWhileSleeping;
    }
  }
}
