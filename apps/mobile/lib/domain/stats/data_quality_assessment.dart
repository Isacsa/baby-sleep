import 'package:flutter/foundation.dart';
import 'package:temp_flutter/domain/stats/daily_sleep_aggregate.dart';

/// Data quality status for a stats period.
enum DataQualityStatus {
  /// All data looks complete and valid
  good,
  
  /// Some minor issues that may cause underestimation
  partial,
  
  /// Significant issues that make data unreliable
  incomplete,
}

/// Types of data quality issues.
enum DataQualityIssueType {
  /// Days without any sleep records
  missingDays,
  
  /// Ongoing sleep session that is unusually long
  ongoingSleepTooLong,
  
  /// Sleep sessions with improbable durations
  improbableDurations,
  
  /// Overlapping sessions detected
  overlapsDetected,
}

/// A specific data quality issue with context.
@immutable
class DataQualityIssue {
  /// Type of issue
  final DataQualityIssueType type;
  
  /// Severity: higher = more important
  final int severity;
  
  /// Affected dates (for navigation)
  final List<DateTime> affectedDates;
  
  /// Issue-specific details
  final Map<String, dynamic>? details;

  const DataQualityIssue({
    required this.type,
    required this.severity,
    this.affectedDates = const [],
    this.details,
  });

  /// Number of affected items (days, sessions, etc.)
  int get count => affectedDates.length;
}

/// Assessment of data quality for a stats period.
@immutable
class DataQualityAssessment {
  /// Overall status
  final DataQualityStatus status;
  
  /// List of specific issues
  final List<DataQualityIssue> issues;
  
  /// Total days in period
  final int totalDays;
  
  /// Days with sleep data
  final int daysWithData;
  
  /// Days without any sleep data
  final int missingDaysCount;
  
  /// Whether there's an ongoing sleep that's too long (> 18h)
  final bool hasOngoingSleepTooLong;
  
  /// Duration of ongoing sleep if too long (in minutes)
  final int? ongoingSleepDurationMinutes;
  
  /// Count of sessions with improbable durations (< 2min or > 20h)
  final int improbableDurationsCount;
  
  /// Count of overlaps detected
  final int overlapsDetectedCount;

  const DataQualityAssessment({
    required this.status,
    required this.issues,
    required this.totalDays,
    required this.daysWithData,
    required this.missingDaysCount,
    required this.hasOngoingSleepTooLong,
    this.ongoingSleepDurationMinutes,
    required this.improbableDurationsCount,
    required this.overlapsDetectedCount,
  });

  /// Creates an empty/good assessment
  factory DataQualityAssessment.empty() {
    return const DataQualityAssessment(
      status: DataQualityStatus.good,
      issues: [],
      totalDays: 0,
      daysWithData: 0,
      missingDaysCount: 0,
      hasOngoingSleepTooLong: false,
      improbableDurationsCount: 0,
      overlapsDetectedCount: 0,
    );
  }

  /// Whether there are any issues
  bool get hasIssues => issues.isNotEmpty;

  /// Data completeness percentage (0.0-1.0)
  double get completeness =>
      totalDays > 0 ? daysWithData / totalDays : 0.0;

  /// Issues sorted by severity (highest first)
  List<DataQualityIssue> get sortedIssues =>
      List.from(issues)..sort((a, b) => b.severity.compareTo(a.severity));
}

/// Calculator for data quality assessment.
class DataQualityAssessmentCalculator {
  /// Maximum ongoing sleep duration before flagging (18 hours)
  static const _maxOngoingSleepHours = 18;
  
  /// Minimum valid session duration (2 minutes)
  static const _minSessionMinutes = 2;
  
  /// Maximum valid session duration (20 hours)
  static const _maxSessionMinutes = 20 * 60;
  
  /// Threshold for missing days to be "partial" (> 10%)
  static const _partialMissingThreshold = 0.1;
  
  /// Threshold for missing days to be "incomplete" (> 30%)
  static const _incompleteMissingThreshold = 0.3;

  /// Assesses data quality from daily aggregates.
  static DataQualityAssessment assess(List<DailySleepAggregate> aggregates) {
    if (aggregates.isEmpty) {
      return DataQualityAssessment.empty();
    }

    final totalDays = aggregates.length;
    final issues = <DataQualityIssue>[];
    
    // Count days with data
    final daysWithData = aggregates.where((a) => a.totalMinutes > 0).length;
    final missingDaysCount = totalDays - daysWithData;
    
    // Find missing days
    if (missingDaysCount > 0) {
      final missingDates = aggregates
          .where((a) => a.totalMinutes == 0)
          .map((a) => a.dateLocal)
          .toList();
      
      issues.add(DataQualityIssue(
        type: DataQualityIssueType.missingDays,
        severity: missingDaysCount > totalDays * _incompleteMissingThreshold ? 3 : 2,
        affectedDates: missingDates,
        details: {'count': missingDaysCount},
      ));
    }
    
    // Check for ongoing sleep that's too long
    bool hasOngoingSleepTooLong = false;
    int? ongoingSleepDurationMinutes;
    final nowUtc = DateTime.now().toUtc();
    
    for (final aggregate in aggregates) {
      for (final session in aggregate.sessions) {
        if (!session.isComplete) {
          final duration = nowUtc.difference(session.startEvent.timestamp);
          if (duration.inHours >= _maxOngoingSleepHours) {
            hasOngoingSleepTooLong = true;
            ongoingSleepDurationMinutes = duration.inMinutes;
            
            issues.add(DataQualityIssue(
              type: DataQualityIssueType.ongoingSleepTooLong,
              severity: 3,
              affectedDates: [aggregate.dateLocal],
              details: {'durationMinutes': duration.inMinutes},
            ));
            break;
          }
        }
      }
      if (hasOngoingSleepTooLong) break;
    }
    
    // Check for improbable durations
    int improbableDurationsCount = 0;
    final improbableDates = <DateTime>[];
    
    for (final aggregate in aggregates) {
      for (final session in aggregate.sessions) {
        if (session.isComplete) {
          final durationMinutes = session.duration!.inMinutes;
          if (durationMinutes < _minSessionMinutes || durationMinutes > _maxSessionMinutes) {
            improbableDurationsCount++;
            if (!improbableDates.contains(aggregate.dateLocal)) {
              improbableDates.add(aggregate.dateLocal);
            }
          }
        }
      }
    }
    
    if (improbableDurationsCount > 0) {
      issues.add(DataQualityIssue(
        type: DataQualityIssueType.improbableDurations,
        severity: 1,
        affectedDates: improbableDates,
        details: {'count': improbableDurationsCount},
      ));
    }
    
    // Note: Overlap detection would require access to raw events
    // For now, we'll just check the hasOverlaps flag on aggregates
    int overlapsDetectedCount = 0;
    final overlapsDetectedDates = <DateTime>[];
    
    for (final aggregate in aggregates) {
      if (aggregate.hasOverlaps) {
        overlapsDetectedCount++;
        overlapsDetectedDates.add(aggregate.dateLocal);
      }
    }
    
    if (overlapsDetectedCount > 0) {
      issues.add(DataQualityIssue(
        type: DataQualityIssueType.overlapsDetected,
        severity: 2,
        affectedDates: overlapsDetectedDates,
        details: {'count': overlapsDetectedCount},
      ));
    }
    
    // Determine overall status
    final status = _determineStatus(
      missingDaysCount: missingDaysCount,
      totalDays: totalDays,
      hasOngoingSleepTooLong: hasOngoingSleepTooLong,
      overlapsDetectedCount: overlapsDetectedCount,
    );
    
    return DataQualityAssessment(
      status: status,
      issues: issues,
      totalDays: totalDays,
      daysWithData: daysWithData,
      missingDaysCount: missingDaysCount,
      hasOngoingSleepTooLong: hasOngoingSleepTooLong,
      ongoingSleepDurationMinutes: ongoingSleepDurationMinutes,
      improbableDurationsCount: improbableDurationsCount,
      overlapsDetectedCount: overlapsDetectedCount,
    );
  }
  
  /// Determines overall status based on issues.
  static DataQualityStatus _determineStatus({
    required int missingDaysCount,
    required int totalDays,
    required bool hasOngoingSleepTooLong,
    required int overlapsDetectedCount,
  }) {
    // Incomplete if: > 30% missing, ongoing too long, or multiple overlaps
    if (missingDaysCount > totalDays * _incompleteMissingThreshold ||
        hasOngoingSleepTooLong ||
        overlapsDetectedCount > 2) {
      return DataQualityStatus.incomplete;
    }
    
    // Partial if: > 10% missing or any overlaps
    if (missingDaysCount > totalDays * _partialMissingThreshold ||
        overlapsDetectedCount > 0) {
      return DataQualityStatus.partial;
    }
    
    return DataQualityStatus.good;
  }
}
