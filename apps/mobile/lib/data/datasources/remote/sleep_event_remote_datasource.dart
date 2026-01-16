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

  /// Gets new remote events (GetNewRemoteEvents) - LEGACY
  /// 
  /// Returns events where created_at > lastSyncedAt
  /// @deprecated Use getNewRemoteEventsByCursor for reliable incremental sync
  Future<Result<List<SleepEventModel>, Failure>> getNewRemoteEvents({
    required String babyId,
    required DateTime lastSyncedAt,
    int? limit,
  });

  /// Gets new remote events using composite cursor (synced_at, id)
  /// 
  /// Uses server-generated synced_at for reliable incremental pull:
  /// - Filters: (synced_at > cursorSyncedAt) OR (synced_at = cursorSyncedAt AND id > cursorId)
  /// - Orders: synced_at ASC, id ASC
  /// - Eliminates clock-skew issues since synced_at is server-generated
  Future<Result<List<SleepEventModel>, Failure>> getNewRemoteEventsByCursor({
    required String babyId,
    DateTime? cursorSyncedAt,
    String? cursorId,
    int limit = 200,
  });

  /// Creates sleep event (CreateSleepStart/CreateSleepEnd)
  /// 
  /// ID must be generated locally before calling
  Future<Result<SleepEventModel, Failure>> createSleepEvent(SleepEventModel event);

  /// Updates sleep event (MarkEventAsCorrected)
  /// 
  /// Only mutable fields can be updated
  Future<Result<SleepEventModel, Failure>> updateSleepEvent(SleepEventModel event);

  /// Gets event by ID
  /// 
  /// Validates access via RLS
  Future<Result<SleepEventModel?, Failure>> getEventById(String eventId);
}

