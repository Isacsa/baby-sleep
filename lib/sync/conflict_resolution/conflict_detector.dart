import '../../../domain/entities/sleep_event.dart';
import '../../../core/constants/app_constants.dart';

/// Conflict detector
/// 
/// Detects conflicts in event lists
/// Conflicts are events with same timestamp (or very close)
abstract class ConflictDetector {
  /// Detects conflicts in event list
  /// 
  /// Returns groups of conflicting events
  List<ConflictGroup> detectConflicts(List<SleepEvent> events);
}

/// Represents a group of conflicting events
class ConflictGroup {
  final List<SleepEvent> events;
  final DateTime conflictTimestamp;

  ConflictGroup({
    required this.events,
    required this.conflictTimestamp,
  });
}

/// Default conflict detector implementation
class ConflictDetectorImpl implements ConflictDetector {
  @override
  List<ConflictGroup> detectConflicts(List<SleepEvent> events) {
    final groups = <ConflictGroup>[];
    final processed = <String>{};

    for (final event in events) {
      if (processed.contains(event.id)) continue;

      // Find events with same timestamp (within conflict window)
      final conflicting = events.where((e) {
        if (processed.contains(e.id)) return false;
        final timeDiff = e.timestamp.difference(event.timestamp).abs();
        return timeDiff < AppConstants.conflictTimeWindow;
      }).toList();

      if (conflicting.length > 1) {
        groups.add(ConflictGroup(
          events: conflicting,
          conflictTimestamp: event.timestamp,
        ));
        processed.addAll(conflicting.map((e) => e.id));
      }
    }

    return groups;
  }
}

