import 'package:flutter/foundation.dart';

/// Confidence level for the sleep prediction
enum ConfidenceLevel {
  /// Low confidence: few samples or high variability
  low,

  /// Medium confidence: moderate samples and variability
  medium,

  /// High confidence: many samples with low variability
  high,
}

/// Extension for ConfidenceLevel
extension ConfidenceLevelExtension on ConfidenceLevel {
  String get labelPt {
    switch (this) {
      case ConfidenceLevel.low:
        return 'Baixa';
      case ConfidenceLevel.medium:
        return 'Média';
      case ConfidenceLevel.high:
        return 'Alta';
    }
  }

  String get labelEn {
    switch (this) {
      case ConfidenceLevel.low:
        return 'Low';
      case ConfidenceLevel.medium:
        return 'Medium';
      case ConfidenceLevel.high:
        return 'High';
    }
  }
}

/// Reason why prediction is unavailable or limited
enum PredictionReason {
  /// Normal prediction with data
  hasData,

  /// Not enough data to make prediction
  collectingPattern,

  /// Baby is currently sleeping
  sleepingNow,

  /// Data quality is too low
  dataQualityTooLow,

  /// Prediction window has passed
  windowPassed,

  /// Prediction would be unrealistically far
  tooFarAhead,
}

/// Result of the next sleep prediction
@immutable
class NextSleepPrediction {
  /// Start of the predicted sleep window (local time)
  final DateTime? windowStartLocal;

  /// End of the predicted sleep window (local time)
  final DateTime? windowEndLocal;

  /// Confidence level of the prediction
  final ConfidenceLevel confidence;

  /// Number of samples used for the prediction
  final int sampleCount;

  /// Variability in minutes (IQR or MAD based)
  final int variabilityMinutes;

  /// Reason for the prediction state
  final PredictionReason reason;

  /// Whether the prediction is available
  bool get isAvailable =>
      reason == PredictionReason.hasData &&
      windowStartLocal != null &&
      windowEndLocal != null;

  /// Whether we're in "collecting pattern" mode
  bool get isCollectingPattern => reason == PredictionReason.collectingPattern;

  /// Whether baby is currently sleeping
  bool get isSleepingNow => reason == PredictionReason.sleepingNow;

  const NextSleepPrediction({
    this.windowStartLocal,
    this.windowEndLocal,
    required this.confidence,
    required this.sampleCount,
    required this.variabilityMinutes,
    required this.reason,
  });

  /// Creates a "collecting pattern" prediction (not enough data)
  factory NextSleepPrediction.collectingPattern({int sampleCount = 0}) {
    return NextSleepPrediction(
      confidence: ConfidenceLevel.low,
      sampleCount: sampleCount,
      variabilityMinutes: 0,
      reason: PredictionReason.collectingPattern,
    );
  }

  /// Creates a "sleeping now" prediction
  factory NextSleepPrediction.sleepingNow() {
    return const NextSleepPrediction(
      confidence: ConfidenceLevel.low,
      sampleCount: 0,
      variabilityMinutes: 0,
      reason: PredictionReason.sleepingNow,
    );
  }

  /// Creates a "data quality too low" prediction
  factory NextSleepPrediction.dataQualityTooLow({int sampleCount = 0}) {
    return NextSleepPrediction(
      confidence: ConfidenceLevel.low,
      sampleCount: sampleCount,
      variabilityMinutes: 0,
      reason: PredictionReason.dataQualityTooLow,
    );
  }

  /// Creates a "window passed" prediction
  factory NextSleepPrediction.windowPassed() {
    return const NextSleepPrediction(
      confidence: ConfidenceLevel.low,
      sampleCount: 0,
      variabilityMinutes: 0,
      reason: PredictionReason.windowPassed,
    );
  }

  /// Formatted window (e.g., "14:30–15:15")
  String? get windowFormatted {
    if (windowStartLocal == null || windowEndLocal == null) return null;

    String format(DateTime dt) {
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }

    return '${format(windowStartLocal!)}–${format(windowEndLocal!)}';
  }

  /// Center of the prediction window
  DateTime? get windowCenter {
    if (windowStartLocal == null || windowEndLocal == null) return null;
    final midMs = (windowStartLocal!.millisecondsSinceEpoch +
            windowEndLocal!.millisecondsSinceEpoch) ~/
        2;
    return DateTime.fromMillisecondsSinceEpoch(midMs);
  }

  /// Window half-width in minutes
  int? get windowHalfWidthMinutes {
    if (windowStartLocal == null || windowEndLocal == null) return null;
    return windowEndLocal!.difference(windowStartLocal!).inMinutes ~/ 2;
  }

  @override
  String toString() =>
      'NextSleepPrediction(window: $windowFormatted, confidence: $confidence, samples: $sampleCount, reason: $reason)';
}
