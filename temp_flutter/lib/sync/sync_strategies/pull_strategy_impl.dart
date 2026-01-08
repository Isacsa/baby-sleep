import 'package:temp_flutter/core/types/result.dart';
import 'package:temp_flutter/core/errors/failures.dart';
import 'package:temp_flutter/data/datasources/local/sleep_event_local_datasource.dart';
import 'package:temp_flutter/data/datasources/remote/sleep_event_remote_datasource.dart';

/// Result of a pull operation
class PullResult {
  final int eventsReceived;
  final DateTime? newLastSyncedAt;
  final bool hasError;

  const PullResult({
    required this.eventsReceived,
    this.newLastSyncedAt,
    this.hasError = false,
  });

  PullResult.withError()
      : eventsReceived = 0,
        newLastSyncedAt = null,
        hasError = true;
}

/// Pull strategy implementation
/// 
/// Handles receiving remote events from Supabase backend
/// Processes events in batches with proper error handling
/// Idempotent - safe to re-run
class PullStrategyImpl {
  final SleepEventLocalDataSource _localDataSource;
  final SleepEventRemoteDataSource _remoteDataSource;
  
  /// Maximum events per batch
  static const int _batchSize = 50;

  PullStrategyImpl({
    required SleepEventLocalDataSource localDataSource,
    required SleepEventRemoteDataSource remoteDataSource,
  })  : _localDataSource = localDataSource,
        _remoteDataSource = remoteDataSource;

  /// Pulls new remote events for a specific baby
  /// 
  /// [babyId] - Baby ID to pull events for
  /// 
  /// Returns number of events received and new lastSyncedAt
  /// Stops on transient errors (network)
  /// Continues on permanent errors (marks them)
  Future<Result<PullResult, Failure>> pullEventsForBaby(String babyId) async {
    // Get last synced timestamp
    final lastSyncedResult = await _localDataSource.getLastSyncedAt(babyId);
    
    if (lastSyncedResult.isError) {
      return Error(lastSyncedResult.failureOrNull!);
    }

    // Use epoch if never synced
    final lastSyncedAt = lastSyncedResult.dataOrNull ?? 
        DateTime.fromMillisecondsSinceEpoch(0).toUtc();

    // Fetch new events from remote
    final remoteResult = await _remoteDataSource.getNewRemoteEvents(
      babyId: babyId,
      lastSyncedAt: lastSyncedAt,
      limit: _batchSize,
    );

    if (remoteResult.isError) {
      return Error(remoteResult.failureOrNull!);
    }

    final remoteEvents = remoteResult.dataOrNull ?? [];
    
    if (remoteEvents.isEmpty) {
      // No new events - update lastSyncedAt to now to avoid re-fetching
      final now = DateTime.now().toUtc();
      await _localDataSource.setLastSyncedAt(babyId, now);
      return Success(PullResult(
        eventsReceived: 0,
        newLastSyncedAt: now,
      ));
    }

    // Upsert events into local storage (idempotent)
    final upsertResult = await _localDataSource.upsertRemoteEvents(remoteEvents);
    
    if (upsertResult.isError) {
      return Error(upsertResult.failureOrNull!);
    }

    // Find the latest created_at from received events
    DateTime? latestCreatedAt;
    for (final event in remoteEvents) {
      final createdAt = DateTime.parse(event.createdAt).toUtc();
      if (latestCreatedAt == null || createdAt.isAfter(latestCreatedAt)) {
        latestCreatedAt = createdAt;
      }
    }

    // Update lastSyncedAt to the latest created_at
    // This ensures we don't miss events if multiple are created at the same timestamp
    if (latestCreatedAt != null) {
      await _localDataSource.setLastSyncedAt(babyId, latestCreatedAt);
    }

    return Success(PullResult(
      eventsReceived: remoteEvents.length,
      newLastSyncedAt: latestCreatedAt,
    ));
  }

  /// Pulls events for all accessible babies
  /// 
  /// Requires list of baby IDs (from local storage or repository)
  Future<Result<PullResult, Failure>> pullEventsForBabies(List<String> babyIds) async {
    int totalEvents = 0;
    DateTime? latestSyncedAt;

    for (final babyId in babyIds) {
      final result = await pullEventsForBaby(babyId);
      
      if (result.isError) {
        // Stop on transient errors
        return Error(result.failureOrNull!);
      }

      final pullResult = result.dataOrNull!;
      totalEvents += pullResult.eventsReceived;
      
      // Track the latest synced timestamp across all babies
      if (pullResult.newLastSyncedAt != null) {
        if (latestSyncedAt == null || 
            pullResult.newLastSyncedAt!.isAfter(latestSyncedAt)) {
          latestSyncedAt = pullResult.newLastSyncedAt;
        }
      }
    }

    return Success(PullResult(
      eventsReceived: totalEvents,
      newLastSyncedAt: latestSyncedAt,
    ));
  }
}

