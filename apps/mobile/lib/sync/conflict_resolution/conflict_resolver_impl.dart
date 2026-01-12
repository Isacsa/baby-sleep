import 'package:temp_flutter/domain/entities/sleep_event.dart';
import 'package:temp_flutter/domain/services/conflict_resolver.dart';

/// Conflict resolver implementation
/// 
/// Implements last-write-wins strategy
/// All events are kept (history preserved)
class ConflictResolverImpl implements ConflictResolver {
  @override
  List<ConflictGroup> detectConflicts(List<SleepEvent> events) {
    final groups = <ConflictGroup>[];
    final processed = <String>{};

    for (final event in events) {
      if (processed.contains(event.id)) continue;

      // Find events with same timestamp (within 1 second)
      final conflicting = events.where((e) {
        if (processed.contains(e.id)) return false;
        final timeDiff = e.timestamp.difference(event.timestamp).abs();
        return timeDiff.inSeconds < 1;
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

