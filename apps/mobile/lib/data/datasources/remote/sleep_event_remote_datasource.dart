import 'package:temp_flutter/core/types/result.dart';
import 'package:temp_flutter/core/errors/failures.dart';
import 'package:temp_flutter/data/models/sleep_event_model.dart';

/// Remote data source for sleep events
/// 
/// Handles communication with Supabase backend
/// Implements backend contract queries
abstract class SleepEventRemoteDataSource {
  /// Gets sleep events timeline (GetSleepEventsTimeline)
  /// 
  /// Returns events ordered by timestamp DESC, createdAt DESC
  Future<Result<List<SleepEventModel>, Failure>> getSleepEventsTimeline({
    required String babyId,
    bool includeCorrected = false,
    int? limit,
    int? offset,
  });

  /// Gets unsynced events (GetUnsyncedEvents)
  /// 
  /// Returns events where syncedAt IS NULL
  Future<Result<List<SleepEventModel>, Failure>> getUnsyncedEvents(String babyId);

  /// Gets new remote events (GetNewRemoteEvents)
  /// 
  /// Returns events where syncedAt > lastSyncedAt
  Future<Result<List<SleepEventModel>, Failure>> getNewRemoteEvents({
    required String babyId,
    required DateTime lastSyncedAt,
    int? limit,
  });

  /// Creates sleep event (CreateSleepStart/CreateSleepEnd)
  /// 
  /// ID must be generated locally before calling
  Future<Result<SleepEventModel, Failure>> createSleepEvent(SleepEventModel event);

  /// Upserts a sleep event for sync:
  /// - Tries INSERT first (idempotent)
  /// - If the row already exists remotely, performs UPDATE of mutable fields
  ///
  /// This is required to propagate corrections (`is_corrected`, `corrected_by`) across devices.
  Future<Result<SleepEventModel, Failure>> upsertSleepEventForSync(SleepEventModel event);

  /// Updates sleep event (MarkEventAsCorrected)
  /// 
  /// Only mutable fields can be updated
  Future<Result<SleepEventModel, Failure>> updateSleepEvent(SleepEventModel event);

  /// Gets event by ID
  /// 
  /// Validates access via RLS
  Future<Result<SleepEventModel?, Failure>> getEventById(String eventId);
}

