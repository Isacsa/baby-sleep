import 'sleep_expectations.dart';
import 'sleep_metrics.dart';
import 'sleep_routine_suggestion.dart';

/// Suggester for sleep routine based on wake windows
///
/// Pure function-based suggester. No side effects, no network.
/// Takes metrics, expectations, and current time to generate suggestions.
class SleepRoutineSuggester {
  const SleepRoutineSuggester._();

  /// Generates a sleep routine suggestion
  ///
  /// [metrics] - Calculated sleep metrics (includes lastWakeTime)
  /// [expectations] - Age-based expectations (for wake windows)
  /// [now] - Current time for calculations
  ///
  /// Returns a [SleepRoutineSuggestion] with:
  /// - Next nap window and suggested time
  /// - Bedtime window and suggested time
  /// - Explanation of how it was calculated
  static SleepRoutineSuggestion suggest({
    required SleepMetrics metrics,
    SleepExpectations? expectations,
    DateTime? now,
  }) {
    final referenceTime = now ?? DateTime.now();

    // If baby is currently sleeping
    if (metrics.isCurrentlySleeping) {
      return _suggestWhileSleeping(
        metrics: metrics,
        expectations: expectations,
        now: referenceTime,
      );
    }

    // If no last wake time, can't suggest
    if (metrics.lastWakeTime == null) {
      return SleepRoutineSuggestion.noData(
        reason: 'Ainda não há dados suficientes para sugerir uma rotina.',
      );
    }

    // If no expectations (no birthDate), use generic wake windows
    if (expectations == null) {
      return _suggestGeneric(
        metrics: metrics,
        now: referenceTime,
      );
    }

    // Full suggestion with age-based wake windows
    return _suggestWithExpectations(
      metrics: metrics,
      expectations: expectations,
      now: referenceTime,
    );
  }

  static SleepRoutineSuggestion _suggestWhileSleeping({
    required SleepMetrics metrics,
    SleepExpectations? expectations,
    required DateTime now,
  }) {
    // Can still suggest bedtime based on patterns
    final medianBedtime = metrics.medianBedtime;

    if (medianBedtime != null && expectations != null) {
      final bedtimeStart = expectations.bedtimeStartTime;
      final bedtimeEnd = expectations.bedtimeEndTime;

      DateTime? windowStart;
      DateTime? windowEnd;

      if (bedtimeStart != null && bedtimeEnd != null) {
        windowStart = DateTime(
          now.year,
          now.month,
          now.day,
          bedtimeStart.hour,
          bedtimeStart.minute,
        );
        windowEnd = DateTime(
          now.year,
          now.month,
          now.day,
          bedtimeEnd.hour,
          bedtimeEnd.minute,
        );
      }

      return SleepRoutineSuggestion.sleeping(
        bedtimeWindowStart: windowStart,
        bedtimeWindowEnd: windowEnd,
        bedtimeSuggested: medianBedtime,
        explanationPt:
            'Baseado nos últimos dias, o horário de deitar típico é ${SleepRoutineSuggestion.formatTime(medianBedtime)}.',
      );
    }

    return SleepRoutineSuggestion.sleeping();
  }

  static SleepRoutineSuggestion _suggestGeneric({
    required SleepMetrics metrics,
    required DateTime now,
  }) {
    final lastWakeTime = metrics.lastWakeTime!;

    // Generic wake windows (conservative)
    const wakeWindowMin = Duration(hours: 2);
    const wakeWindowMax = Duration(hours: 3);

    final napWindowStart = lastWakeTime.add(wakeWindowMin);
    final napWindowEnd = lastWakeTime.add(wakeWindowMax);
    final napSuggested = lastWakeTime.add(
      Duration(minutes: (wakeWindowMin.inMinutes + wakeWindowMax.inMinutes) ~/ 2),
    );

    // Check if nap window has passed
    final napPassed = napWindowEnd.isBefore(now);

    // Bedtime suggestion (generic: 19:00-20:30 window)
    final bedtimeWindowStart = DateTime(now.year, now.month, now.day, 19, 0);
    final bedtimeWindowEnd = DateTime(now.year, now.month, now.day, 20, 30);
    final bedtimeSuggested = metrics.medianBedtime ??
        DateTime(now.year, now.month, now.day, 19, 30);

    return SleepRoutineSuggestion(
      nextNapWindowStart: napPassed ? null : napWindowStart,
      nextNapWindowEnd: napPassed ? null : napWindowEnd,
      nextNapSuggested: napPassed ? null : napSuggested,
      bedtimeWindowStart: bedtimeWindowStart,
      bedtimeWindowEnd: bedtimeWindowEnd,
      bedtimeSuggested: bedtimeSuggested,
      explanationPt: _buildGenericExplanation(
        lastWakeTime: lastWakeTime,
        napPassed: napPassed,
        medianBedtime: metrics.medianBedtime,
      ),
      hasSufficientData: true,
      isCurrentlySleeping: false,
      lastWakeTime: lastWakeTime,
      wakeWindowUsedMinutes: (wakeWindowMin.inMinutes + wakeWindowMax.inMinutes) ~/ 2,
    );
  }

  static SleepRoutineSuggestion _suggestWithExpectations({
    required SleepMetrics metrics,
    required SleepExpectations expectations,
    required DateTime now,
  }) {
    final lastWakeTime = metrics.lastWakeTime!;

    // Use age-based wake windows
    final wakeWindowMin = expectations.wakeWindowDayMinDuration;
    final wakeWindowMax = expectations.wakeWindowDayMaxDuration;

    final napWindowStart = lastWakeTime.add(wakeWindowMin);
    final napWindowEnd = lastWakeTime.add(wakeWindowMax);
    final napSuggested = lastWakeTime.add(
      Duration(minutes: expectations.wakeWindowDayMid),
    );

    // Check if nap window has passed
    final napPassed = napWindowEnd.isBefore(now);

    // Bedtime calculation - using pre-bed wake window
    // Calculate bedtime from last wake time (if no more naps expected today)
    DateTime? bedtimeFromWakeWindow;
    final isLateAfternoon = now.hour >= 16;

    if (isLateAfternoon || napPassed) {
      // No more naps expected, calculate bedtime from last wake
      bedtimeFromWakeWindow = lastWakeTime.add(
        Duration(minutes: expectations.wakeWindowPreBedMid),
      );
    }

    // Get typical bedtime window from expectations
    final bedtimeStart = expectations.bedtimeStartTime;
    final bedtimeEnd = expectations.bedtimeEndTime;

    DateTime? bedtimeWindowStart;
    DateTime? bedtimeWindowEnd;

    if (bedtimeStart != null && bedtimeEnd != null) {
      bedtimeWindowStart = DateTime(
        now.year,
        now.month,
        now.day,
        bedtimeStart.hour,
        bedtimeStart.minute,
      );
      bedtimeWindowEnd = DateTime(
        now.year,
        now.month,
        now.day,
        bedtimeEnd.hour,
        bedtimeEnd.minute,
      );
    }

    // Combine median bedtime with wake window calculation
    DateTime bedtimeSuggested;
    if (metrics.medianBedtime != null && bedtimeFromWakeWindow != null) {
      // Average of pattern and wake window
      final patternMinutes =
          metrics.medianBedtime!.hour * 60 + metrics.medianBedtime!.minute;
      final wakeWindowMinutes =
          bedtimeFromWakeWindow.hour * 60 + bedtimeFromWakeWindow.minute;
      final avgMinutes = (patternMinutes + wakeWindowMinutes) ~/ 2;

      // Clamp to bedtime window
      int clampedMinutes = avgMinutes;
      if (bedtimeStart != null &&
          clampedMinutes < bedtimeStart.hour * 60 + bedtimeStart.minute) {
        clampedMinutes = bedtimeStart.hour * 60 + bedtimeStart.minute;
      }
      if (bedtimeEnd != null &&
          clampedMinutes > bedtimeEnd.hour * 60 + bedtimeEnd.minute) {
        clampedMinutes = bedtimeEnd.hour * 60 + bedtimeEnd.minute;
      }

      bedtimeSuggested = DateTime(
        now.year,
        now.month,
        now.day,
        clampedMinutes ~/ 60,
        clampedMinutes % 60,
      );
    } else if (metrics.medianBedtime != null) {
      bedtimeSuggested = metrics.medianBedtime!;
    } else if (bedtimeFromWakeWindow != null) {
      bedtimeSuggested = bedtimeFromWakeWindow;
    } else {
      // Fallback to midpoint of window
      bedtimeSuggested = DateTime(now.year, now.month, now.day, 19, 30);
    }

    return SleepRoutineSuggestion(
      nextNapWindowStart: napPassed ? null : napWindowStart,
      nextNapWindowEnd: napPassed ? null : napWindowEnd,
      nextNapSuggested: napPassed ? null : napSuggested,
      bedtimeWindowStart: bedtimeWindowStart,
      bedtimeWindowEnd: bedtimeWindowEnd,
      bedtimeSuggested: bedtimeSuggested,
      explanationPt: _buildExplanationWithAge(
        expectations: expectations,
        lastWakeTime: lastWakeTime,
        napPassed: napPassed,
        medianBedtime: metrics.medianBedtime,
      ),
      hasSufficientData: true,
      isCurrentlySleeping: false,
      lastWakeTime: lastWakeTime,
      wakeWindowUsedMinutes: expectations.wakeWindowDayMid,
    );
  }

  static String _buildGenericExplanation({
    required DateTime lastWakeTime,
    required bool napPassed,
    DateTime? medianBedtime,
  }) {
    final parts = <String>[];

    final wakeTimeStr = SleepRoutineSuggestion.formatTime(lastWakeTime);
    parts.add('Acordou às $wakeTimeStr.');

    if (napPassed) {
      parts.add('A janela da próxima sesta já passou.');
    } else {
      parts.add('Janela de sesta calculada com 2-3h de tempo acordado.');
    }

    if (medianBedtime != null) {
      final bedtimeStr = SleepRoutineSuggestion.formatTime(medianBedtime);
      parts.add('Horário de deitar típico: $bedtimeStr.');
    }

    return parts.join(' ');
  }

  static String _buildExplanationWithAge({
    required SleepExpectations expectations,
    required DateTime lastWakeTime,
    required bool napPassed,
    DateTime? medianBedtime,
  }) {
    final parts = <String>[];

    final wakeTimeStr = SleepRoutineSuggestion.formatTime(lastWakeTime);
    parts.add('Acordou às $wakeTimeStr.');

    final wakeWindowRange =
        '${expectations.wakeWindowDayMin}-${expectations.wakeWindowDayMax}min';
    if (napPassed) {
      parts.add('A janela da próxima sesta já passou.');
    } else {
      parts.add('Janela típica para esta idade: $wakeWindowRange de tempo acordado.');
    }

    if (medianBedtime != null) {
      final bedtimeStr = SleepRoutineSuggestion.formatTime(medianBedtime);
      parts.add('Nos últimos dias, o deitar foi às $bedtimeStr.');
    }

    return parts.join(' ');
  }
}
