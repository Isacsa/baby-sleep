import 'package:flutter/material.dart';
import 'package:temp_flutter/core/l10n/l10n.dart';
import 'package:temp_flutter/presentation/theme/night_theme.dart';

/// DaySummaryCard - Card com resumo do dia
/// 
/// Mostra total de horas dormidas e número de sestas
class DaySummaryCard extends StatelessWidget {
  final Duration totalSleep;
  final int napCount;
  final int sessionCount;

  const DaySummaryCard({
    super.key,
    required this.totalSleep,
    required this.napCount,
    required this.sessionCount,
  });

  @override
  Widget build(BuildContext context) {
    final hours = totalSleep.inHours;
    final minutes = totalSleep.inMinutes % 60;
    final totalText = hours > 0 
        ? '${hours}h ${minutes}m'
        : '${minutes}m';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            NightTheme.primary.withValues(alpha: 0.15),
            NightTheme.secondary.withValues(alpha: 0.15),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: NightTheme.primary.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Total sleep
          Expanded(
            child: Column(
              children: [
                const Icon(
                  Icons.bedtime,
                  color: NightTheme.primary,
                  size: 28,
                ),
                const SizedBox(height: 8),
                Text(
                  totalText,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: NightTheme.textPrimary,
                  ),
                ),
                Text(
                  context.l10n.summaryTotalSleep,
                  style: const TextStyle(
                    fontSize: 12,
                    color: NightTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          
          // Divider
          Container(
            width: 1,
            height: 60,
            color: NightTheme.textSecondary.withValues(alpha: 0.2),
          ),
          
          // Naps
          Expanded(
            child: Column(
              children: [
                const Icon(
                  Icons.brightness_5,
                  color: NightTheme.secondary,
                  size: 28,
                ),
                const SizedBox(height: 8),
                Text(
                  napCount.toString(),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: NightTheme.textPrimary,
                  ),
                ),
                Text(
                  context.l10n.statsTotalNaps,
                  style: const TextStyle(
                    fontSize: 12,
                    color: NightTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          
          // Divider
          Container(
            width: 1,
            height: 60,
            color: NightTheme.textSecondary.withValues(alpha: 0.2),
          ),
          
          // Sessions
          Expanded(
            child: Column(
              children: [
                const Icon(
                  Icons.nights_stay,
                  color: NightTheme.accent,
                  size: 28,
                ),
                const SizedBox(height: 8),
                Text(
                  sessionCount.toString(),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: NightTheme.textPrimary,
                  ),
                ),
                Text(
                  context.l10n.sessionsSleep,
                  style: const TextStyle(
                    fontSize: 12,
                    color: NightTheme.textSecondary,
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
