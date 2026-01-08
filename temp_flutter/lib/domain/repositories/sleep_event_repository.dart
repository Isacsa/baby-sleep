import 'package:temp_flutter/domain/common/result.dart';
import 'package:temp_flutter/domain/entities/sleep_event.dart';

/// Sleep event repository interface
/// 
/// Abstracts data source for sleep events
/// Returns domain entities, not data models
/// All queries filter by baby_id
abstract class SleepEventRepository {
  /// Gets sleep events timeline for a baby
  /// 
  /// Returns events ordered by timestamp DESC, createdAt DESC
  /// By default, only valid events (isCorrected = false) are returned
  /// 
  /// [includeCorrected] if true, includes corrected events (for history view)
  /// [limit] optional limit for pagination
  /// [offset] optional offset for pagination
  Future<DomainResult<List<SleepEvent>>> getSleepEventsTimeline({
    required String babyId,
    bool includeCorrected = false,
    int? limit,
    int? offset,
  });

  /// Gets unsynced events for a baby
  /// 
  /// Returns events where syncedAt IS NULL
  /// Ordered by createdAt ASC (oldest first)
  /// Used by sync engine for push strategy
  Future<DomainResult<List<SleepEvent>>> getUnsyncedEvents(String babyId);

  /// Gets new remote events for a baby
  /// 
  /// Returns events where syncedAt > lastSyncedAt
  /// Used by sync engine for pull strategy
  Future<DomainResult<List<SleepEvent>>> getNewRemoteEvents({
    required String babyId,
    required DateTime lastSyncedAt,
    int? limit,
  });

  /// Creates a sleep event
  /// 
  /// Event is persisted locally first (syncedAt = NULL)
  /// Sync engine will send to backend later
  /// ID must be generated locally before calling this
  Future<DomainResult<SleepEvent>> createSleepEvent(SleepEvent event);

  /// Updates a sleep event
  /// 
  /// Only mutable fields can be updated:
  /// - isCorrected
  /// - correctedBy
  /// - syncedAt
  /// - metadata
  /// 
  /// Immutable fields (id, babyId, type, timestamp, caregiverId, createdAt) cannot be changed
  Future<DomainResult<SleepEvent>> updateSleepEvent(SleepEvent event);

  /// Gets event by ID
  /// 
  /// Validates user has access via RLS
  Future<DomainResult<SleepEvent?>> getEventById(String eventId);
}

