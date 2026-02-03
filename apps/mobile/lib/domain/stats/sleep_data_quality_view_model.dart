import 'package:temp_flutter/domain/analysis/next_sleep_prediction.dart';
import 'package:temp_flutter/domain/stats/data_quality_assessment.dart';

/// View model for sleep data quality in the cockpit
///
/// Combines DataQualityAssessment with prediction-specific information
/// for UI display.
class SleepDataQualityViewModel {
  /// The underlying quality assessment
  final DataQualityAssessment assessment;

  /// Number of samples used in prediction (for confidence display)
  final int predictionSampleCount;

  /// The prediction's confidence level
  final ConfidenceLevel predictionConfidence;

  const SleepDataQualityViewModel({
    required this.assessment,
    required this.predictionSampleCount,
    required this.predictionConfidence,
  });

  /// Overall status
  DataQualityStatus get status => assessment.status;

  /// Whether data quality is good
  bool get isGood => status == DataQualityStatus.good;

  /// Whether data quality is partial
  bool get isPartial => status == DataQualityStatus.partial;

  /// Whether data quality is incomplete
  bool get isIncomplete => status == DataQualityStatus.incomplete;

  /// Whether to show the data quality warning badge
  bool get showWarningBadge => !isGood;

  /// Status label in Portuguese
  String get statusLabelPt {
    switch (status) {
      case DataQualityStatus.good:
        return 'Boa';
      case DataQualityStatus.partial:
        return 'Parcial';
      case DataQualityStatus.incomplete:
        return 'Incompleta';
    }
  }

  /// Status label in English
  String get statusLabelEn {
    switch (status) {
      case DataQualityStatus.good:
        return 'Good';
      case DataQualityStatus.partial:
        return 'Partial';
      case DataQualityStatus.incomplete:
        return 'Incomplete';
    }
  }

  /// Short warning message for prediction (Portuguese)
  String? get predictionWarningPt {
    if (isGood) return null;
    return 'A previsão pode ser menos precisa hoje.';
  }

  /// Short warning message for prediction (English)
  String? get predictionWarningEn {
    if (isGood) return null;
    return 'Prediction may be less accurate today.';
  }

  /// Whether there are any issues to show
  bool get hasIssues => assessment.hasIssues;

  /// Issues formatted for display
  List<DataQualityIssueDisplay> get issuesForDisplay {
    return assessment.sortedIssues.map(_formatIssue).toList();
  }

  /// Formats an issue for display
  DataQualityIssueDisplay _formatIssue(DataQualityIssue issue) {
    switch (issue.type) {
      case DataQualityIssueType.missingDays:
        final count = issue.count;
        return DataQualityIssueDisplay(
          titlePt: '$count dia${count > 1 ? 's' : ''} sem registo',
          titleEn: '$count day${count > 1 ? 's' : ''} without data',
          impactPt: 'Pode subestimar o total semanal.',
          impactEn: 'May underestimate weekly totals.',
          actionPt: 'Adiciona registos dos dias em falta.',
          actionEn: 'Add records for missing days.',
          severity: issue.severity,
          affectedDates: issue.affectedDates,
        );

      case DataQualityIssueType.ongoingSleepTooLong:
        final minutes = issue.details?['durationMinutes'] as int? ?? 0;
        final hours = minutes ~/ 60;
        return DataQualityIssueDisplay(
          titlePt: 'Sono em curso há ${hours}h',
          titleEn: 'Ongoing sleep for ${hours}h',
          impactPt: 'A previsão fica indisponível.',
          impactEn: 'Prediction becomes unavailable.',
          actionPt: 'Termina o sono se já acordou.',
          actionEn: 'End sleep if already awake.',
          severity: issue.severity,
          affectedDates: issue.affectedDates,
        );

      case DataQualityIssueType.improbableDurations:
        final count = issue.details?['count'] as int? ?? issue.count;
        return DataQualityIssueDisplay(
          titlePt: '$count sessão${count > 1 ? 'ões' : ''} com duração improvável',
          titleEn: '$count session${count > 1 ? 's' : ''} with improbable duration',
          impactPt: 'Pode afetar médias e previsões.',
          impactEn: 'May affect averages and predictions.',
          actionPt: 'Revê e corrige os registos.',
          actionEn: 'Review and correct the records.',
          severity: issue.severity,
          affectedDates: issue.affectedDates,
        );

      case DataQualityIssueType.overlapsDetected:
        final count = issue.count;
        return DataQualityIssueDisplay(
          titlePt: '$count sobreposição${count > 1 ? 'ões' : ''} detectada${count > 1 ? 's' : ''}',
          titleEn: '$count overlap${count > 1 ? 's' : ''} detected',
          impactPt: 'O total pode estar duplicado.',
          impactEn: 'Totals may be duplicated.',
          actionPt: 'Corrige as sessões sobrepostas.',
          actionEn: 'Correct the overlapping sessions.',
          severity: issue.severity,
          affectedDates: issue.affectedDates,
        );
    }
  }

  @override
  String toString() =>
      'SleepDataQualityViewModel(status: $status, issues: ${assessment.issues.length}, predictionSamples: $predictionSampleCount)';
}

/// Display-ready data quality issue
class DataQualityIssueDisplay {
  /// Title in Portuguese
  final String titlePt;

  /// Title in English
  final String titleEn;

  /// Impact description in Portuguese
  final String impactPt;

  /// Impact description in English
  final String impactEn;

  /// Suggested action in Portuguese
  final String actionPt;

  /// Suggested action in English
  final String actionEn;

  /// Severity level (higher = more important)
  final int severity;

  /// Dates affected by this issue
  final List<DateTime> affectedDates;

  const DataQualityIssueDisplay({
    required this.titlePt,
    required this.titleEn,
    required this.impactPt,
    required this.impactEn,
    required this.actionPt,
    required this.actionEn,
    required this.severity,
    required this.affectedDates,
  });
}
