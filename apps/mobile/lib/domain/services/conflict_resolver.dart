import 'package:temp_flutter/domain/entities/sleep_event.dart';

/// Conflict resolution service
/// 
/// Implements last-write-wins strategy
/// Detects conflicts and resolves them
/// All events are kept (history preserved)
abstract class ConflictResolver {
  /// Detects conflicts in event list
  /// 
  /// Conflicts are:
  /// - Events with same timestamp (or very close, < 1 second)
  /// - Events with same type and identical timestamp
  List<ConflictGroup> detectConflicts(List<SleepEvent> events);

  /// Resolves conflicts using last-write-wins
  /// 
  /// Algorithm:
  /// 1. Sort by timestamp DESC (most recent first)
  /// 2. If timestamp identical: sort by createdAt DESC (created more recently first)
  /// 3. Use first event for state derivation
  /// 4. Keep all events (don't delete conflicting ones)
  /// 
  /// Returns events in resolved order (for state derivation)
  List<SleepEvent> resolveConflicts(List<SleepEvent> events);
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

/// Default conflict resolver implementation
/// 
/// Implements last-write-wins strategy
/// All events are kept (history preserved)
class ConflictResolverImpl implements ConflictResolver {
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

  @override
  List<SleepEvent> resolveConflicts(List<SleepEvent> events) {
    // Sort by timestamp DESC, createdAt DESC (last-write-wins)
    final sorted = List<SleepEvent>.from(events);
    sorted.sort((a, b) {
      final timestampCompare = b.timestamp.compareTo(a.timestamp);
      if (timestampCompare != 0) return timestampCompare;
      return b.createdAt.compareTo(a.createdAt);
    });

    // All events are kept, just return in resolved order
    return sorted;
  }
}
