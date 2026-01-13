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
}

