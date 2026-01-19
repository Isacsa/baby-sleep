import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:temp_flutter/application/providers/active_baby_provider.dart';
import 'package:temp_flutter/application/providers/sleep_events_provider.dart';
import 'package:temp_flutter/application/providers/sleep_metrics_provider.dart';
import 'package:temp_flutter/domain/analysis/sleep_metrics.dart';
import 'package:temp_flutter/domain/value_objects/sleep_session.dart';
import 'package:temp_flutter/presentation/theme/night_theme.dart';

/// StatsPage - Tab Estatísticas
/// 
/// Features:
/// - Toggle Semana/Mês
/// - Gráfico de barras simples (CustomPaint)
/// - Insights textuais
/// - Info do bebé
class StatsPage extends ConsumerStatefulWidget {
  const StatsPage({super.key});

  @override
  ConsumerState<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends ConsumerState<StatsPage> {
  bool _isWeekly = true;

  @override
  Widget build(BuildContext context) {
    final activeBaby = ref.watch(activeBabyProvider);
    final eventsAsync = ref.watch(sleepEventsNotifierProvider);
    final days = _isWeekly ? 7 : 30;
    final metricsAsync = ref.watch(sleepMetricsWithLookbackProvider(days));

    if (activeBaby == null) {
      return const Center(
        child: Text('Seleciona um bebé', style: TextStyle(color: NightTheme.textSecondary)),
      );
    }

    final events = eventsAsync.value ?? [];
    final sessions = SleepSession.fromEventList(events);
    final dailyTotals = _calculateDailyTotals(sessions, days);
    final metrics = metricsAsync.valueOrEmpty;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Estatísticas',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: NightTheme.textPrimary,
                    ),
                  ),
                ),
                // Toggle
                Container(
                  decoration: BoxDecoration(
                    color: NightTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ToggleButton(
                        label: 'Semana',
                        isSelected: _isWeekly,
                        onTap: () => setState(() => _isWeekly = true),
                      ),
                      _ToggleButton(
                        label: 'Mês',
                        isSelected: !_isWeekly,
                        onTap: () => setState(() => _isWeekly = false),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Chart
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: NightTheme.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(16),
              child: dailyTotals.isEmpty
                  ? const Center(
                      child: Text(
                        'Ainda sem dados',
                        style: TextStyle(color: NightTheme.textSecondary),
                      ),
                    )
                  : CustomPaint(
                      size: Size.infinite,
                      painter: _BarChartPainter(
                        dailyTotals: dailyTotals,
                        days: days,
                      ),
                    ),
            ),
            
            const SizedBox(height: 24),
            
            // Summary stats
            _buildSummaryRow(metrics),
            
            const SizedBox(height: 24),
            
            const SizedBox(height: 24),
            
            // Baby info
            _buildBabyInfo(activeBaby.name, activeBaby.birthDate),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(SleepMetrics metrics) {
    // Calculate average from metrics
    final daysWithData = metrics.daysWithData;
    final totalMinutes = metrics.totalSleepByDay.values
        .fold<int>(0, (sum, d) => sum + d.inMinutes);
    final avgHours = daysWithData > 0 
        ? totalMinutes / daysWithData / 60.0
        : 0.0;
    
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            label: 'Média/dia',
            value: '${avgHours.toStringAsFixed(1)}h',
            icon: Icons.access_time,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryCard(
            label: 'Total sestas',
            value: metrics.napCountLast24h.toString(),
            icon: Icons.brightness_5,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryCard(
            label: 'Dias registados',
            value: daysWithData.toString(),
            icon: Icons.calendar_today,
          ),
        ),
      ],
    );
  }

  Widget _buildBabyInfo(String name, DateTime? birthDate) {
    String ageText = '';
    if (birthDate != null) {
      final now = DateTime.now();
      final months = (now.year - birthDate.year) * 12 + now.month - birthDate.month;
      if (months < 12) {
        ageText = '$months meses';
      } else {
        final years = months ~/ 12;
        final remainingMonths = months % 12;
        ageText = remainingMonths > 0 
            ? '$years ano${years > 1 ? 's' : ''} e $remainingMonths mês${remainingMonths > 1 ? 'es' : ''}'
            : '$years ano${years > 1 ? 's' : ''}';
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NightTheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: NightTheme.secondary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.child_care,
              color: NightTheme.secondary,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: NightTheme.textPrimary,
                ),
              ),
              if (ageText.isNotEmpty)
                Text(
                  ageText,
                  style: const TextStyle(
                    fontSize: 13,
                    color: NightTheme.textSecondary,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Map<DateTime, Duration> _calculateDailyTotals(List<SleepSession> sessions, int days) {
    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month, now.day).subtract(Duration(days: days - 1));
    
    final totals = <DateTime, Duration>{};
    
    for (final session in sessions) {
      if (session.duration == null) continue;
      
      final day = DateTime(
        session.startEvent.timestamp.year,
        session.startEvent.timestamp.month,
        session.startEvent.timestamp.day,
      );
      
      if (day.isBefore(startDate)) continue;
      
      totals[day] = (totals[day] ?? Duration.zero) + session.duration!;
    }
    
    return totals;
  }

  // Insights were moved to InsightsPage to keep Stats focused on charts/summary.
}

class _ToggleButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? NightTheme.primary.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? NightTheme.primary : NightTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: NightTheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: NightTheme.primary, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: NightTheme.textPrimary,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: NightTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Simple bar chart painter
class _BarChartPainter extends CustomPainter {
  final Map<DateTime, Duration> dailyTotals;
  final int days;

  _BarChartPainter({
    required this.dailyTotals,
    required this.days,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (dailyTotals.isEmpty) return;

    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month, now.day).subtract(Duration(days: days - 1));
    
    // Find max value
    double maxHours = 0;
    for (final duration in dailyTotals.values) {
      final hours = duration.inMinutes / 60.0;
      if (hours > maxHours) maxHours = hours;
    }
    maxHours = max(maxHours, 12); // Minimum 12h scale
    
    final barWidth = (size.width - 40) / days;
    final chartHeight = size.height - 30;
    
    // Draw bars
    for (int i = 0; i < days; i++) {
      final date = startDate.add(Duration(days: i));
      final duration = dailyTotals[date];
      
      if (duration != null) {
        final hours = duration.inMinutes / 60.0;
        final barHeight = (hours / maxHours) * chartHeight;
        
        final x = 20 + i * barWidth + barWidth * 0.2;
        final y = chartHeight - barHeight;
        
        final paint = Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [NightTheme.primary, NightTheme.secondary],
          ).createShader(Rect.fromLTWH(x, y, barWidth * 0.6, barHeight));
        
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth * 0.6, barHeight),
          const Radius.circular(4),
        );
        
        canvas.drawRRect(rect, paint);
      }
    }
    
    // Draw x-axis labels
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );
    
    for (int i = 0; i < days; i += (days > 7 ? 5 : 1)) {
      final date = startDate.add(Duration(days: i));
      final x = 20 + i * barWidth + barWidth * 0.3;
      
      textPainter.text = TextSpan(
        text: '${date.day}',
        style: const TextStyle(
          fontSize: 10,
          color: NightTheme.textSecondary,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x, size.height - 15));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
