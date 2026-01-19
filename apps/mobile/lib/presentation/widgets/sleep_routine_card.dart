import 'package:flutter/material.dart';
import 'package:temp_flutter/domain/analysis/sleep_routine_suggestion.dart';
import 'package:temp_flutter/presentation/theme/night_theme.dart';

/// Card widget for displaying sleep routine suggestion
///
/// Shows next nap and bedtime suggestions in a compact format.
class SleepRoutineCard extends StatelessWidget {
  final SleepRoutineSuggestion suggestion;
  final bool compact;

  const SleepRoutineCard({
    super.key,
    required this.suggestion,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    // Don't show if no data
    if (!suggestion.hasSufficientData) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: NightTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: NightTheme.secondary.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: NightTheme.secondary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.schedule_outlined,
                  size: 16,
                  color: NightTheme.secondary,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Sugestão para hoje',
                style: TextStyle(
                  fontSize: compact ? 13 : 14,
                  fontWeight: FontWeight.w600,
                  color: NightTheme.textPrimary,
                ),
              ),
            ],
          ),
          
          SizedBox(height: compact ? 12 : 16),
          
          // Suggestions row
          Row(
            children: [
              // Next nap
              if (suggestion.canSuggestNap)
                Expanded(
                  child: _SuggestionItem(
                    icon: Icons.wb_sunny_outlined,
                    label: 'Próxima sesta',
                    time: suggestion.nextNapFormatted,
                    window: suggestion.nextNapWindowFormatted,
                    compact: compact,
                  ),
                )
              else if (!suggestion.isCurrentlySleeping)
                const Expanded(
                  child: _SuggestionItem(
                    icon: Icons.wb_sunny_outlined,
                    label: 'Próxima sesta',
                    time: '--',
                    window: 'Janela passou',
                    compact: false,
                  ),
                ),
              
              if (suggestion.canSuggestNap && suggestion.canSuggestBedtime)
                Container(
                  width: 1,
                  height: 40,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  color: NightTheme.textSecondary.withValues(alpha: 0.2),
                ),
              
              // Bedtime
              if (suggestion.canSuggestBedtime)
                Expanded(
                  child: _SuggestionItem(
                    icon: Icons.bedtime_outlined,
                    label: 'Deitar',
                    time: suggestion.bedtimeFormatted,
                    window: suggestion.bedtimeWindowFormatted,
                    compact: compact,
                  ),
                ),
            ],
          ),
          
          // Explanation (if not compact)
          if (!compact && suggestion.explanationPt != null) ...[
            const SizedBox(height: 12),
            Text(
              suggestion.explanationPt!,
              style: const TextStyle(
                fontSize: 11,
                color: NightTheme.textSecondary,
              ),
            ),
          ],
          
          // Currently sleeping message
          if (suggestion.isCurrentlySleeping) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.nightlight_round,
                  size: 14,
                  color: NightTheme.primary.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 6),
                Text(
                  'O bebé está a dormir',
                  style: TextStyle(
                    fontSize: 12,
                    color: NightTheme.primary.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SuggestionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String time;
  final String window;
  final bool compact;

  const _SuggestionItem({
    required this.icon,
    required this.label,
    required this.time,
    required this.window,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: NightTheme.textSecondary),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: compact ? 10 : 11,
                color: NightTheme.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          time,
          style: TextStyle(
            fontSize: compact ? 18 : 22,
            fontWeight: FontWeight.w700,
            color: NightTheme.textPrimary,
          ),
        ),
        if (!compact)
          Text(
            window,
            style: const TextStyle(
              fontSize: 11,
              color: NightTheme.textSecondary,
            ),
          ),
      ],
    );
  }
}
