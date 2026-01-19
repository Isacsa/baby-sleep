import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:temp_flutter/application/providers/active_baby_provider.dart';
import 'package:temp_flutter/application/providers/sleep_expectations_provider.dart';
import 'package:temp_flutter/application/providers/sleep_insights_provider.dart';
import 'package:temp_flutter/application/providers/sleep_routine_provider.dart';
import 'package:temp_flutter/domain/analysis/age_band.dart';
import 'package:temp_flutter/domain/analysis/sleep_expectations.dart';
import 'package:temp_flutter/presentation/theme/night_theme.dart';
import 'package:temp_flutter/presentation/widgets/insight_card.dart';
import 'package:temp_flutter/presentation/widgets/sleep_insight_card.dart';
import 'package:temp_flutter/presentation/widgets/sleep_routine_card.dart';

/// InsightsPage - Tab dedicada a insights e sugestões
///
/// Mostra:
/// - Sugestão de rotina (wake windows)
/// - Insights completos (com evidência)
/// - Sugestões para hoje (ações práticas)
class InsightsPage extends ConsumerWidget {
  const InsightsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeBaby = ref.watch(activeBabyProvider);
    final insightsAsync = ref.watch(sleepInsightsProvider);
    final expectationsDataAsync = ref.watch(activeBabySleepExpectationsProvider);
    final routineAsync = ref.watch(sleepRoutineProvider);

    if (activeBaby == null) {
      return const Center(
        child: Text(
          'Seleciona um bebé',
          style: TextStyle(color: NightTheme.textSecondary),
        ),
      );
    }

    final insightResult = insightsAsync.valueOrEmpty;
    final expectationsData = expectationsDataAsync.valueOrNull;
    final routine = routineAsync.valueOrEmpty;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Insights',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: NightTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Para o bebé ${activeBaby.name}',
              style: const TextStyle(
                fontSize: 12,
                color: NightTheme.textSecondary,
              ),
            ),

            const SizedBox(height: 20),

            // Birthdate prompt (if missing)
            if (expectationsData != null && !expectationsData.hasBirthDate)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: NightTheme.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: NightTheme.accent.withValues(alpha: 0.3),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.cake_outlined, size: 18, color: NightTheme.accent),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Adiciona a data de nascimento para ver insights por idade.',
                        style: TextStyle(fontSize: 12, color: NightTheme.textBody),
                      ),
                    ),
                  ],
                ),
              ),

            if (expectationsData != null && !expectationsData.hasBirthDate)
              const SizedBox(height: 16),

            // Age expectations summary (if available)
            if (expectationsData != null && expectationsData.hasExpectations) ...[
              _AgeExpectationsSummary(
                expectationsData: expectationsData,
                rangeComparison: insightResult.rangeComparison,
              ),
              const SizedBox(height: 16),
            ],

            // Routine suggestion
            const Text(
              'Sugestão para hoje',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: NightTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            if (!routine.hasSufficientData)
              const InsightCard(
                icon: Icons.schedule,
                text: 'Ainda não há dados suficientes para sugerir uma rotina.',
              )
            else
              SleepRoutineCard(suggestion: routine),

            const SizedBox(height: 24),

            // Insights list
            const Text(
              'Insights',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: NightTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            if (!insightResult.hasInsights)
              const InsightCard(
                icon: Icons.lightbulb_outline,
                text: 'Regista mais algumas noites para ver insights personalizados.',
              )
            else
              ...insightResult.allInsights.map((insight) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SleepInsightCard(
                      insight: insight,
                      showEvidence: true,
                    ),
                  )),

            const SizedBox(height: 16),

            // Suggested actions
            if (insightResult.hasActions) ...[
              const Text(
                'Sugestões para hoje',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: NightTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              ...insightResult.suggestedActions.map((action) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SuggestedActionCard(action: action),
                  )),
            ],
          ],
        ),
      ),
    );
  }
}

class _AgeExpectationsSummary extends StatelessWidget {
  final BabySleepExpectationsData expectationsData;
  final RangeComparison? rangeComparison;

  const _AgeExpectationsSummary({
    required this.expectationsData,
    required this.rangeComparison,
  });

  @override
  Widget build(BuildContext context) {
    final expectations = expectationsData.expectations!;
    final rangeText =
        '${expectations.totalSleep24hMin ~/ 60}-${expectations.totalSleep24hMax ~/ 60}h';

    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (rangeComparison) {
      case RangeComparison.below:
        statusColor = NightTheme.warning;
        statusIcon = Icons.arrow_downward;
        statusText = 'Abaixo';
        break;
      case RangeComparison.within:
        statusColor = NightTheme.success;
        statusIcon = Icons.check_circle_outline;
        statusText = 'Dentro';
        break;
      case RangeComparison.above:
        statusColor = NightTheme.accent;
        statusIcon = Icons.arrow_upward;
        statusText = 'Acima';
        break;
      default:
        statusColor = NightTheme.textSecondary;
        statusIcon = Icons.horizontal_rule;
        statusText = 'N/A';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NightTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 14, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'do esperado',
                style: TextStyle(
                  fontSize: 12,
                  color: NightTheme.textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                expectationsData.ageFormattedPt,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: NightTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Para ${expectationsData.ageBand.labelPt}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: NightTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Sono esperado em 24h: $rangeText',
            style: const TextStyle(
              fontSize: 13,
              color: NightTheme.textBody,
            ),
          ),
        ],
      ),
    );
  }
}

