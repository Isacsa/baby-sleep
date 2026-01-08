import 'package:temp_flutter/domain/entities/sleep_event.dart';
import 'package:temp_flutter/domain/services/conflict_resolver.dart';

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

/// Default conflict detector implementation
class ConflictDetectorImpl implements ConflictDetector {
  /// Time window for conflict detection (1 second)
  static const Duration conflictTimeWindow = Duration(seconds: 1);

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
        return timeDiff < conflictTimeWindow;
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

