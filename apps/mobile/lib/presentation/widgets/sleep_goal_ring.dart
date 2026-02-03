import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:temp_flutter/domain/analysis/sleep_goal.dart';
import 'package:temp_flutter/presentation/theme/night_theme.dart';

/// A circular progress ring showing sleep goal progress
///
/// Features:
/// - Track (base ring) with low opacity
/// - Progress arc up to MIN (primary color)
/// - Soft zone from MIN to MAX (gradient halo)
/// - "OK" marker at MIN position
/// - Overflow sub-arc when above MAX (very soft)
class SleepGoalRing extends StatelessWidget {
  /// The computed sleep goal state
  final SleepGoalComputed goal;

  /// Size of the ring (diameter)
  final double size;

  /// Stroke width of the ring
  final double strokeWidth;

  const SleepGoalRing({
    super.key,
    required this.goal,
    this.size = 140,
    this.strokeWidth = 12,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _SleepGoalRingPainter(
          goal: goal,
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}

class _SleepGoalRingPainter extends CustomPainter {
  final SleepGoalComputed goal;
  final double strokeWidth;

  _SleepGoalRingPainter({
    required this.goal,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Start from top (270 degrees = -90 degrees in radians)
    const startAngle = -math.pi / 2;
    const sweepAngle = 2 * math.pi;

    // Draw track (background ring)
    final trackPaint = Paint()
      ..color = NightTheme.textSecondary.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, startAngle, sweepAngle, false, trackPaint);

    // If no data or no birthdate, just show track
    if (!goal.status.hasData) {
      return;
    }

    // Calculate progress angles
    final progressToMin = goal.progressToMin.clamp(0.0, 1.0);
    final progressToMax = goal.progressToMax.clamp(0.0, 1.5); // Allow overflow

    // Draw progress arc up to MIN (or actual if below)
    final progressAngle = progressToMin * sweepAngle;
    final progressPaint = Paint()
      ..color = NightTheme.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    if (progressAngle > 0) {
      canvas.drawArc(rect, startAngle, progressAngle, false, progressPaint);
    }

    // Draw soft zone from MIN to current (if within range)
    if (goal.progressToMin >= 1.0) {
      final extraProgress = (progressToMax - 1.0).clamp(0.0, 1.0);
      final softZoneAngle = extraProgress * (sweepAngle * (goal.goalRange.maxMinutes - goal.goalRange.minMinutes) / goal.goalRange.maxMinutes);
      
      // Soft gradient zone
      final softPaint = Paint()
        ..shader = SweepGradient(
          startAngle: startAngle + progressAngle,
          endAngle: startAngle + progressAngle + softZoneAngle + 0.01,
          colors: [
            NightTheme.primary.withValues(alpha: 0.6),
            NightTheme.secondary.withValues(alpha: 0.4),
          ],
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      if (softZoneAngle > 0.01) {
        canvas.drawArc(rect, startAngle + progressAngle, softZoneAngle, false, softPaint);
      }
    }

    // Draw overflow arc if above MAX (very subtle)
    if (progressToMax > 1.0) {
      final overflowProgress = (progressToMax - 1.0).clamp(0.0, 0.2);
      final overflowAngle = overflowProgress * sweepAngle;
      
      final overflowPaint = Paint()
        ..color = NightTheme.warning.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth * 0.6
        ..strokeCap = StrokeCap.round;

      // Draw as outer ring
      final outerRect = Rect.fromCircle(center: center, radius: radius + strokeWidth * 0.4);
      canvas.drawArc(outerRect, startAngle, overflowAngle, false, overflowPaint);
    }

    // Draw MIN marker (small dot/tick at the min position)
    final minAngle = startAngle + sweepAngle; // Full circle = 100% of min
    final markerX = center.dx + radius * math.cos(minAngle);
    final markerY = center.dy + radius * math.sin(minAngle);

    final markerPaint = Paint()
      ..color = goal.progressToMin >= 1.0
          ? NightTheme.success
          : NightTheme.textSecondary.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(markerX, markerY), strokeWidth / 2.5, markerPaint);
  }

  @override
  bool shouldRepaint(covariant _SleepGoalRingPainter oldDelegate) {
    return oldDelegate.goal.totalMinutes != goal.totalMinutes ||
        oldDelegate.goal.status != goal.status;
  }
}
