import 'dart:math' as math;

import 'package:temp_flutter/core/utils/local_time_utils.dart';
import 'package:temp_flutter/domain/analysis/next_sleep_prediction.dart';
import 'package:temp_flutter/domain/stats/daily_sleep_aggregate.dart';
import 'package:temp_flutter/domain/stats/data_quality_assessment.dart';
import 'package:temp_flutter/domain/value_objects/sleep_session.dart';

/// Sleep type classification (Night vs Nap)
enum SleepKind {
  night,
  nap,
}

/// An awake gap between two consecutive sleep sessions
class AwakeGap {
  /// Duration of the gap in minutes
  final int gapMinutes;

  /// Kind of the PRECEDING sleep (what the baby woke up from)
  final SleepKind precedingSleepKind;

  /// End time of the preceding sleep (wake time)
  final DateTime wakeTimeUtc;

  const AwakeGap({
    required this.gapMinutes,
    required this.precedingSleepKind,
    required this.wakeTimeUtc,
  });

  @override
  String toString() =>
      'AwakeGap(${gapMinutes}m, after $precedingSleepKind, wake: $wakeTimeUtc)';
}

/// Predictor for the next sleep time
///
/// Uses median of recent awake gaps with MAD/IQR outlier handling.
class NextSleepPredictor {
  /// Minimum samples required to show prediction
  static const _minSamplesForPrediction = 5;

  /// Lookback days for gap collection
  static const _lookbackDays = 14;

  /// Default night window (19:00-07:00)
  static const _defaultNightWindow = NightWindow();

  /// Minimum gap window half-width (minutes)
  static const _minWindowHalfWidth = 15;

  /// Maximum gap window half-width (minutes)
  static const _maxWindowHalfWidth = 60;

  /// Minimum valid gap (minutes) - filter out very short gaps
  static const _minValidGapMinutes = 15;

  /// Maximum gap for safety (permissive, only applied with low quality)
  static const _maxGapMinutesPermissive = 14 * 60; // 14 hours

  /// High variability threshold for low confidence (minutes)
  static const _highVariabilityThreshold = 90;

  /// Medium variability threshold (minutes)
  static const _mediumVariabilityThreshold = 45;

  /// Prediction too far ahead threshold (hours)
  static const _tooFarAheadHours = 6;

  const NextSleepPredictor._();

  /// Predicts the next sleep window
  ///
  /// [sessions] - All sleep sessions (complete and incomplete)
  /// [dataQuality] - Optional data quality assessment
  /// [now] - Current time (for testing, defaults to DateTime.now())
  static NextSleepPrediction predict({
    required List<SleepSession> sessions,
    DataQualityStatus? dataQuality,
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now();

    // Check if currently sleeping
    final isCurrentlySleeping = sessions.any((s) => !s.isComplete);
    if (isCurrentlySleeping) {
      return NextSleepPrediction.sleepingNow();
    }

    // Check if data quality is too low
    if (dataQuality == DataQualityStatus.incomplete) {
      return NextSleepPrediction.dataQualityTooLow();
    }

    // Get complete sessions only
    final completeSessions =
        sessions.where((s) => s.isComplete).toList()
          ..sort((a, b) => a.startEvent.timestamp.compareTo(b.startEvent.timestamp));

    if (completeSessions.length < 2) {
      return NextSleepPrediction.collectingPattern(
        sampleCount: completeSessions.length,
      );
    }

    // Extract awake gaps
    final gaps = _extractGaps(completeSessions, currentTime);

    if (gaps.isEmpty) {
      return NextSleepPrediction.collectingPattern(sampleCount: 0);
    }

    // Filter gaps with outlier handling
    final isLowQuality = dataQuality == DataQualityStatus.partial;
    final filteredGaps = _filterGapsWithOutlierHandling(gaps, isLowQuality);

    if (filteredGaps.length < _minSamplesForPrediction) {
      return NextSleepPrediction.collectingPattern(
        sampleCount: filteredGaps.length,
      );
    }

    // Get the last wake time
    final lastSession = completeSessions.last;
    final lastWakeTimeUtc = lastSession.endEvent!.timestamp;
    final lastWakeTimeLocal = LocalTimeUtils.toLocal(lastWakeTimeUtc);

    // Classify the last sleep to filter relevant gaps
    final lastSleepKind = _classifySleep(lastSession);

    // Filter gaps by context (same preceding sleep kind)
    var relevantGaps =
        filteredGaps.where((g) => g.precedingSleepKind == lastSleepKind).toList();

    // Fallback to all gaps if too few context-specific gaps
    if (relevantGaps.length < _minSamplesForPrediction) {
      relevantGaps = filteredGaps;
    }

    // Calculate median gap
    final gapValues = relevantGaps.map((g) => g.gapMinutes).toList()..sort();
    final medianGap = _median(gapValues);

    // Calculate variability (MAD)
    final variability = _calculateMAD(gapValues, medianGap);

    // Calculate window half-width
    final windowHalfWidth = _clamp(
      (variability / 2).round(),
      _minWindowHalfWidth,
      _maxWindowHalfWidth,
    );

    // Predict center time
    final predictedCenterLocal =
        lastWakeTimeLocal.add(Duration(minutes: medianGap.round()));

    // Calculate window
    final windowStartLocal =
        predictedCenterLocal.subtract(Duration(minutes: windowHalfWidth));
    final windowEndLocal =
        predictedCenterLocal.add(Duration(minutes: windowHalfWidth));

    // Check if window has passed
    if (windowEndLocal.isBefore(currentTime)) {
      return NextSleepPrediction.windowPassed();
    }

    // Check if prediction is too far ahead
    final hoursAhead = predictedCenterLocal.difference(currentTime).inHours;
    if (hoursAhead > _tooFarAheadHours &&
        variability > _mediumVariabilityThreshold) {
      return NextSleepPrediction(
        windowStartLocal: windowStartLocal,
        windowEndLocal: windowEndLocal,
        confidence: ConfidenceLevel.low,
        sampleCount: relevantGaps.length,
        variabilityMinutes: variability.round(),
        reason: PredictionReason.tooFarAhead,
      );
    }

    // Determine confidence
    final confidence = _determineConfidence(
      sampleCount: relevantGaps.length,
      variabilityMinutes: variability.round(),
      dataQuality: dataQuality,
    );

    return NextSleepPrediction(
      windowStartLocal: windowStartLocal,
      windowEndLocal: windowEndLocal,
      confidence: confidence,
      sampleCount: relevantGaps.length,
      variabilityMinutes: variability.round(),
      reason: PredictionReason.hasData,
    );
  }

  /// Extracts awake gaps from sessions
  static List<AwakeGap> _extractGaps(
    List<SleepSession> sessions,
    DateTime now,
  ) {
    final gaps = <AwakeGap>[];
    final cutoffDate = now.subtract(Duration(days: _lookbackDays));

    for (var i = 0; i < sessions.length - 1; i++) {
      final current = sessions[i];
      final next = sessions[i + 1];

      // Skip if session is too old
      if (current.endEvent!.timestamp.isBefore(cutoffDate)) {
        continue;
      }

      // Calculate gap
      final gapDuration =
          next.startEvent.timestamp.difference(current.endEvent!.timestamp);
      final gapMinutes = gapDuration.inMinutes;

      // Skip invalid gaps
      if (gapMinutes <= 0) continue;

      // Classify the preceding sleep
      final precedingKind = _classifySleep(current);

      gaps.add(AwakeGap(
        gapMinutes: gapMinutes,
        precedingSleepKind: precedingKind,
        wakeTimeUtc: current.endEvent!.timestamp,
      ));
    }

    return gaps;
  }

  /// Classifies a sleep session as Night or Nap using NightWindow (>50% overlap rule)
  static SleepKind _classifySleep(SleepSession session) {
    final startUtc = session.startEvent.timestamp;
    final endUtc = session.endEvent?.timestamp ?? DateTime.now().toUtc();

    final nightOverlapMinutes =
        _calculateNightOverlapMinutes(startUtc, endUtc, _defaultNightWindow);
    final totalMinutes = endUtc.difference(startUtc).inMinutes;

    if (totalMinutes <= 0) return SleepKind.nap;

    final nightRatio = nightOverlapMinutes / totalMinutes;
    return nightRatio > 0.5 ? SleepKind.night : SleepKind.nap;
  }

  /// Calculates how many minutes of a session fall within the night window
  static int _calculateNightOverlapMinutes(
    DateTime startUtc,
    DateTime endUtc,
    NightWindow nightWindow,
  ) {
    final startLocal = LocalTimeUtils.toLocal(startUtc);
    final endLocal = LocalTimeUtils.toLocal(endUtc);

    int overlapMinutes = 0;

    // Iterate through each day the session touches
    var currentDay = DateTime(startLocal.year, startLocal.month, startLocal.day);
    final lastDay = DateTime(endLocal.year, endLocal.month, endLocal.day);

    while (!currentDay.isAfter(lastDay)) {
      // Build night window for this day (e.g., 19:00 today to 07:00 tomorrow)
      final nightStart = DateTime(
        currentDay.year,
        currentDay.month,
        currentDay.day,
        nightWindow.startHour,
      );
      final nextDay = currentDay.add(const Duration(days: 1));
      final nightEnd = DateTime(
        nextDay.year,
        nextDay.month,
        nextDay.day,
        nightWindow.endHour,
      );

      // Calculate overlap with this night window
      final overlapStart = _maxDateTime(startLocal, nightStart);
      final overlapEnd = _minDateTime(endLocal, nightEnd);

      if (overlapEnd.isAfter(overlapStart)) {
        overlapMinutes += overlapEnd.difference(overlapStart).inMinutes;
      }

      currentDay = nextDay;
    }

    return overlapMinutes;
  }

  /// Filters gaps using MAD/IQR outlier handling
  static List<AwakeGap> _filterGapsWithOutlierHandling(
    List<AwakeGap> gaps,
    bool isLowQuality,
  ) {
    if (gaps.isEmpty) return [];

    // Step 1: Basic filters (always apply)
    var filtered = gaps.where((g) => g.gapMinutes >= _minValidGapMinutes).toList();

    if (filtered.isEmpty) return [];

    // Step 2: Calculate statistics
    final gapValues = filtered.map((g) => g.gapMinutes).toList()..sort();
    final medianGap = _median(gapValues);
    final mad = _calculateMAD(gapValues, medianGap);

    // Step 3: MAD-based filtering (k=3)
    // Only filter if MAD is meaningful (> 0)
    if (mad > 0) {
      final lowerBound = medianGap - 3 * mad;
      final upperBound = medianGap + 3 * mad;

      filtered = filtered
          .where((g) => g.gapMinutes >= lowerBound && g.gapMinutes <= upperBound)
          .toList();
    }

    // Step 4: Permissive upper limit (only with low quality)
    if (isLowQuality) {
      filtered =
          filtered.where((g) => g.gapMinutes <= _maxGapMinutesPermissive).toList();
    }

    return filtered;
  }

  /// Determines confidence level based on sample count and variability
  static ConfidenceLevel _determineConfidence({
    required int sampleCount,
    required int variabilityMinutes,
    DataQualityStatus? dataQuality,
  }) {
    // Degrade confidence if data quality is partial
    final degradeOnce = dataQuality == DataQualityStatus.partial;

    // High: >= 10 samples and variability < 45min
    if (sampleCount >= 10 && variabilityMinutes < _mediumVariabilityThreshold) {
      return degradeOnce ? ConfidenceLevel.medium : ConfidenceLevel.high;
    }

    // Medium: 5-9 samples and variability 45-90min
    if (sampleCount >= 5 && variabilityMinutes <= _highVariabilityThreshold) {
      return degradeOnce ? ConfidenceLevel.low : ConfidenceLevel.medium;
    }

    // Low: < 5 samples or variability > 90min
    return ConfidenceLevel.low;
  }

  /// Calculates median of a sorted list
  static double _median(List<int> sorted) {
    if (sorted.isEmpty) return 0;
    final mid = sorted.length ~/ 2;
    if (sorted.length % 2 == 0) {
      return (sorted[mid - 1] + sorted[mid]) / 2;
    }
    return sorted[mid].toDouble();
  }

  /// Calculates Median Absolute Deviation (MAD)
  static double _calculateMAD(List<int> values, double median) {
    if (values.isEmpty) return 0;
    final deviations = values.map((v) => (v - median).abs()).toList()..sort();
    return _median(deviations.map((d) => d.round()).toList());
  }

  /// Clamps a value between min and max
  static int _clamp(int value, int min, int max) {
    return math.max(min, math.min(max, value));
  }

  /// Returns the maximum of two DateTimes
  static DateTime _maxDateTime(DateTime a, DateTime b) {
    return a.isAfter(b) ? a : b;
  }

  /// Returns the minimum of two DateTimes
  static DateTime _minDateTime(DateTime a, DateTime b) {
    return a.isBefore(b) ? a : b;
  }
}
