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
/// 
/// CLOCK SKEW ROBUSTNESS:
/// Uses clamp + buffer strategy to handle devices with different clock times:
/// 1. Clamp lastSyncedAt to max(now) to prevent "future cursor" issues
/// 2. Apply safety buffer (5 min) to re-fetch recent events
/// 3. Upsert is idempotent - duplicates are safe
/// 4. Update cursor to min(maxCreatedAt, now) to prevent future jumps
class PullStrategyImpl {
  final SleepEventLocalDataSource _localDataSource;
  final SleepEventRemoteDataSource _remoteDataSource;
  
  /// Maximum events per batch
  static const int _batchSize = 50;
  
  /// Safety buffer for clock skew tolerance
  /// Re-fetch events from this many minutes before lastSyncedAt
  /// This ensures we don't miss events due to clock differences between devices
  static const Duration _clockSkewBuffer = Duration(minutes: 5);

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
    final nowUtc = DateTime.now().toUtc();
    
    // Get last synced timestamp
    final lastSyncedResult = await _localDataSource.getLastSyncedAt(babyId);
    
    if (lastSyncedResult.isError) {
      return Error(lastSyncedResult.failureOrNull!);
    }

    // Use epoch if never synced
    final rawLastSyncedAt = lastSyncedResult.dataOrNull ?? 
        DateTime.fromMillisecondsSinceEpoch(0).toUtc();
    
    // === CLOCK SKEW ROBUSTNESS ===
    // Step 1: Clamp lastSyncedAt to max(now) - prevent "future cursor" issues
    final isFutureCursor = rawLastSyncedAt.isAfter(nowUtc);
    final clampedLastSyncedAt = isFutureCursor ? nowUtc : rawLastSyncedAt;
    
    // Step 2: Apply safety buffer - re-fetch recent events to handle clock skew
    // This is safe because upsert is idempotent
    final lastSyncedAt = clampedLastSyncedAt.subtract(_clockSkewBuffer);

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
      // No new events:
      // Do NOT advance the cursor to local "now" because created_at is client-provided
      // and local clocks may be ahead (clock skew). Advancing to a future cursor can
      // make us miss events created on other devices.
      //
      // Keep last_synced_at unchanged (or only clamp down if it's in the future relative to this device).
      if (rawLastSyncedAt.isAfter(nowUtc)) {
        await _localDataSource.setLastSyncedAt(babyId, nowUtc);
      }
      return Success(PullResult(
        eventsReceived: 0,
        newLastSyncedAt: rawLastSyncedAt.isAfter(nowUtc) ? nowUtc : rawLastSyncedAt,
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

    // === CLOCK SKEW ROBUSTNESS ===
    // Step 3: Update lastSyncedAt to min(maxCreatedAt, now) to prevent future jumps
    // This ensures that even if an event has a future created_at (from a device with wrong clock),
    // we don't set our cursor to the future and miss events from other devices
    if (latestCreatedAt != null) {
      final currentNow = DateTime.now().toUtc();
      final safeCursor = latestCreatedAt.isAfter(currentNow) ? currentNow : latestCreatedAt;
      await _localDataSource.setLastSyncedAt(babyId, safeCursor);
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

