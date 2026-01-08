import 'package:temp_flutter/domain/entities/sleep_event.dart';

/// Sync queue
/// 
/// Manages queue of events pending synchronization
/// Events are added when created locally (syncedAt = NULL)
/// Events are removed after successful sync
abstract class SyncQueue {
  /// Adds event to queue
  Future<void> enqueue(SleepEvent event);

  /// Removes event from queue (after successful sync)
  Future<void> dequeue(String eventId);

  /// Gets all pending events
  Future<List<SleepEvent>> getPendingEvents();

  /// Gets count of pending events
  Future<int> getPendingCount();

  /// Clears queue (for testing/reset)
  Future<void> clear();
}

