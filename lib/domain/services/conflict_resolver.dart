import '../entities/sleep_event.dart';

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

