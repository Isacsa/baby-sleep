import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:temp_flutter/application/providers/active_baby_provider.dart';
import 'package:temp_flutter/application/providers/sleep_events_provider.dart';
import 'package:temp_flutter/domain/value_objects/sleep_session.dart';
import 'package:temp_flutter/presentation/theme/night_theme.dart';
import 'package:temp_flutter/presentation/widgets/insight_card.dart';

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

    if (activeBaby == null) {
      return const Center(
        child: Text('Seleciona um bebé', style: TextStyle(color: NightTheme.textSecondary)),
      );
    }

    final events = eventsAsync.value ?? [];
    final sessions = SleepSession.fromEventList(events);
    final days = _isWeekly ? 7 : 30;
    final dailyTotals = _calculateDailyTotals(sessions, days);
    final insights = _generateInsights(sessions, dailyTotals, activeBaby.name);

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
            _buildSummaryRow(dailyTotals, sessions),
            
            const SizedBox(height: 24),
            
            // Insights
            const Text(
              'Insights',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: NightTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            
            if (insights.isEmpty)
              const InsightCard(
                icon: Icons.lightbulb_outline,
                text: 'Regista mais algumas noites para ver insights personalizados.',
              )
            else
              ...insights.map((insight) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InsightCard(
                  icon: insight.icon,
                  text: insight.text,
                ),
              )),
              
            const SizedBox(height: 24),
            
            // Baby info
            _buildBabyInfo(activeBaby.name, activeBaby.birthDate),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(Map<DateTime, Duration> dailyTotals, List<SleepSession> sessions) {
    // Calculate averages
    Duration totalSleep = Duration.zero;
    for (final duration in dailyTotals.values) {
      totalSleep += duration;
    }
    final avgHours = dailyTotals.isNotEmpty 
        ? totalSleep.inMinutes / dailyTotals.length / 60.0
        : 0.0;
    
    // Count naps (sessions < 3h)
    final naps = sessions.where((s) => 
      s.duration != null && s.duration!.inHours < 3
    ).length;
    
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
            value: naps.toString(),
            icon: Icons.brightness_5,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryCard(
            label: 'Dias registados',
            value: dailyTotals.length.toString(),
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

  List<_Insight> _generateInsights(
    List<SleepSession> sessions,
    Map<DateTime, Duration> dailyTotals,
    String babyName,
  ) {
    final insights = <_Insight>[];
    
    if (dailyTotals.length < 3) {
      return insights;
    }

    // Average sleep
    final totalMinutes = dailyTotals.values.fold<int>(0, (sum, d) => sum + d.inMinutes);
    final avgMinutes = totalMinutes / dailyTotals.length;
    final avgHours = avgMinutes / 60;
    
    if (avgHours >= 10) {
      insights.add(_Insight(
        icon: Icons.check_circle_outline,
        text: 'O $babyName está a dormir bem! Média de ${avgHours.toStringAsFixed(1)}h por dia.',
      ));
    } else if (avgHours < 8) {
      insights.add(_Insight(
        icon: Icons.info_outline,
        text: 'O $babyName está a dormir menos que o esperado. Considera ajustar a rotina.',
      ));
    }
    
    // Consistency
    if (dailyTotals.length >= 5) {
      final values = dailyTotals.values.map((d) => d.inMinutes.toDouble()).toList();
      final mean = values.reduce((a, b) => a + b) / values.length;
      final variance = values.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) / values.length;
      final stdDev = sqrt(variance);
      
      if (stdDev < 60) {
        insights.add(_Insight(
          icon: Icons.timeline,
          text: 'O sono está muito consistente. Bom trabalho!',
        ));
      } else if (stdDev > 120) {
        insights.add(_Insight(
          icon: Icons.show_chart,
          text: 'O sono tem variado bastante. Uma rotina mais regular pode ajudar.',
        ));
      }
    }
    
    // Nap count
    final recentNaps = sessions.where((s) {
      if (s.duration == null || s.duration!.inHours >= 3) return false;
      final daysAgo = DateTime.now().difference(s.startEvent.timestamp).inDays;
      return daysAgo < 7;
    }).length;
    
    if (recentNaps > 0) {
      final avgNapsPerDay = recentNaps / min(7, dailyTotals.length);
      insights.add(_Insight(
        icon: Icons.brightness_5,
        text: 'Média de ${avgNapsPerDay.toStringAsFixed(1)} sestas por dia esta semana.',
      ));
    }
    
    return insights;
  }
}

class _Insight {
  final IconData icon;
  final String text;
  
  const _Insight({required this.icon, required this.text});
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
