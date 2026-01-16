import 'package:temp_flutter/core/types/result.dart';
import 'package:temp_flutter/core/errors/failures.dart';
import 'package:temp_flutter/data/models/sleep_event_model.dart';

/// Local data source for sleep events
/// 
/// Handles local persistence of sleep events
/// Used for offline-first access
abstract class SleepEventLocalDataSource {
  /// Gets all events for a baby from local storage
  Future<Result<List<SleepEventModel>, Failure>> getEventsForBaby(String babyId);

  /// Gets events ordered by timestamp DESC, createdAt DESC
  Future<Result<List<SleepEventModel>, Failure>> getEventsTimeline({
    required String babyId,
    bool includeCorrected = false,
    int? limit,
    int? offset,
  });

  /// Gets unsynced events (syncedAt IS NULL)
  Future<Result<List<SleepEventModel>, Failure>> getUnsyncedEvents(String babyId);

  /// Gets event by ID from local storage
  Future<Result<SleepEventModel?, Failure>> getEventById(String eventId);

  /// Saves event to local storage
  Future<Result<void, Failure>> saveEvent(SleepEventModel event);

  /// Saves multiple events to local storage
  Future<Result<void, Failure>> saveEvents(List<SleepEventModel> events);

  /// Saves multiple events atomically in a single SQLite transaction
  /// 
  /// GUARDRAIL 2: All events are written in a single transaction.
  /// If any fails, ALL are rolled back (no partial writes).
  /// This ensures "sono completo" never leaves Start orphaned.
  Future<Result<void, Failure>> saveEventsInTransaction(List<SleepEventModel> events);

  /// Saves AND updates events atomically in a single SQLite transaction
  /// 
  /// Used for "Substituir" flow:
  /// - [inserts]: New events to create (correction events + new sleep events)
  /// - [updates]: Existing events to mark as corrected (isCorrected=true, correctedBy=...)
  /// 
  /// All operations happen in a single transaction - if any fails, ALL are rolled back.
  Future<Result<void, Failure>> saveAndUpdateEventsInTransaction({
    required List<SleepEventModel> inserts,
    required List<SleepEventModel> updates,
  });

  /// Updates event in local storage
  Future<Result<void, Failure>> updateEvent(SleepEventModel event);

  /// Deletes event from local storage (should not be used, but available for edge cases)
  Future<Result<void, Failure>> deleteEvent(String eventId);

  /// Marks event as synced with timestamp
  /// Updates only synced_at field
  Future<Result<void, Failure>> markEventSynced(String eventId, DateTime syncedAt);

  /// Marks event with permanent sync error
  /// Stores error info in metadata for debugging
  Future<Result<void, Failure>> markEventSyncError(String eventId, String errorType, String errorMessage);

  /// Gets all unsynced events (across all babies)
  /// Used for global sync operations
  Future<Result<List<SleepEventModel>, Failure>> getAllUnsyncedEvents();

  /// Upserts remote events into local storage
  /// 
  /// If event doesn't exist locally → insert
  /// If event exists → update only mutable fields:
  ///   - isCorrected
  ///   - correctedBy
  ///   - syncedAt
  ///   - metadata
  /// 
  /// Never updates immutable fields:
  ///   - id, babyId, type, timestamp, caregiverId, createdAt, deviceId
  Future<Result<void, Failure>> upsertRemoteEvents(List<SleepEventModel> events);

  /// Gets last synced timestamp for a baby
  /// Returns null if never synced
  Future<Result<DateTime?, Failure>> getLastSyncedAt(String babyId);

  /// Sets last synced timestamp for a baby
  Future<Result<void, Failure>> setLastSyncedAt(String babyId, DateTime lastSyncedAt);

  /// Gets composite sync cursor (synced_at, id) for a baby
  /// Returns null values if never synced
  /// Used for reliable incremental pull with server-generated synced_at
  Future<Result<SyncCursor, Failure>> getSyncCursor(String babyId);

  /// Sets composite sync cursor (synced_at, id) for a baby
  /// Used after successful pull to persist the cursor for next incremental pull
  Future<Result<void, Failure>> setSyncCursor(String babyId, SyncCursor cursor);

  /// Applies normalization updates atomically in a single SQLite transaction
  /// 
  /// Each update marks an event as corrected:
  /// - Sets is_corrected = true
  /// - Sets corrected_by = winner event ID  
  /// - Merges metadata with existing metadata (preserves existing keys)
  /// 
  /// Returns list of updated event IDs for sync queue
  Future<Result<List<String>, Failure>> applyNormalizationUpdates(
    List<NormalizationUpdate> updates,
  );

  // ============================================
  // SYNC QUEUE METHODS
  // ============================================

  /// Enqueues an event for sync (insert or update)
  /// Uses REPLACE to avoid duplicates - latest action wins
  Future<Result<void, Failure>> enqueueForSync(String eventId, SyncAction action);

  /// Enqueues multiple events for sync
  Future<Result<void, Failure>> enqueueMultipleForSync(List<String> eventIds, SyncAction action);

  /// Removes an event from the sync queue after successful sync
  Future<Result<void, Failure>> dequeueAfterSync(String eventId);

  /// Gets all pending sync entries for a specific action
  Future<Result<List<SyncQueueEntry>, Failure>> getPendingSyncEntries(SyncAction action);

  /// Gets all pending sync entries (both inserts and updates)
  Future<Result<List<SyncQueueEntry>, Failure>> getAllPendingSyncEntries();
}

/// Single normalization update to apply
class NormalizationUpdate {
  final String eventId;
  final String correctedBy;
  final Map<String, dynamic> metadataPatch;

  const NormalizationUpdate({
    required this.eventId,
    required this.correctedBy,
    required this.metadataPatch,
  });
}

/// Sync queue action type
enum SyncAction {
  insert,
  update,
}

/// Entry in the sync queue
class SyncQueueEntry {
  final String eventId;
  final SyncAction action;
  final DateTime enqueuedAt;

  const SyncQueueEntry({
    required this.eventId,
    required this.action,
    required this.enqueuedAt,
  });
}

/// Composite cursor for incremental sync
/// Uses (synced_at, id) to ensure deterministic ordering and no missed events
class SyncCursor {
  final DateTime? syncedAt;
  final String? eventId;

  const SyncCursor({this.syncedAt, this.eventId});

  /// Creates cursor from epoch (never synced)
  factory SyncCursor.initial() => const SyncCursor();

  /// Check if cursor is empty (never synced)
  bool get isEmpty => syncedAt == null && eventId == null;

  @override
  String toString() => 'SyncCursor(syncedAt: $syncedAt, eventId: $eventId)';
}

