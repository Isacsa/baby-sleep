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
    
    // === DEBUG LOG H1: Pull cursor info ===
    // ignore: avoid_print
    print('[PullStrategy][H1-DEBUG] ===== PULL START =====');
    // ignore: avoid_print
    print('[PullStrategy][H1-DEBUG] babyId: $babyId');
    // ignore: avoid_print
    print('[PullStrategy][H1-DEBUG] nowUtc: ${nowUtc.toIso8601String()}');
    // ignore: avoid_print
    print('[PullStrategy][H1-DEBUG] rawLastSyncedAt: ${rawLastSyncedAt.toIso8601String()}');
    
    // === CLOCK SKEW ROBUSTNESS ===
    // Step 1: Clamp lastSyncedAt to max(now) - prevent "future cursor" issues
    final isFutureCursor = rawLastSyncedAt.isAfter(nowUtc);
    final clampedLastSyncedAt = isFutureCursor ? nowUtc : rawLastSyncedAt;
    
    if (isFutureCursor) {
      // ignore: avoid_print
      print('[PullStrategy][H1-DEBUG] WARNING: lastSyncedAt was in FUTURE! Clamped to now.');
    }
    
    // Step 2: Apply safety buffer - re-fetch recent events to handle clock skew
    // This is safe because upsert is idempotent
    final lastSyncedAt = clampedLastSyncedAt.subtract(_clockSkewBuffer);
    
    // ignore: avoid_print
    print('[PullStrategy][H1-DEBUG] effectiveCursor (with ${_clockSkewBuffer.inMinutes}min buffer): ${lastSyncedAt.toIso8601String()}');

    // Fetch new events from remote
    final remoteResult = await _remoteDataSource.getNewRemoteEvents(
      babyId: babyId,
      lastSyncedAt: lastSyncedAt,
      limit: _batchSize,
    );

    if (remoteResult.isError) {
      // ignore: avoid_print
      print('[PullStrategy][H1-DEBUG] Remote fetch FAILED: ${remoteResult.failureOrNull?.message}');
      return Error(remoteResult.failureOrNull!);
    }

    final remoteEvents = remoteResult.dataOrNull ?? [];
    
    // === DEBUG LOG H1: Events received ===
    // ignore: avoid_print
    print('[PullStrategy][H1-DEBUG] eventsReceived: ${remoteEvents.length}');
    
    if (remoteEvents.isNotEmpty) {
      // Log first and last few events for debugging
      final eventsSorted = List.of(remoteEvents)
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      
      final firstEvent = eventsSorted.first;
      final lastEvent = eventsSorted.last;
      // ignore: avoid_print
      print('[PullStrategy][H1-DEBUG] min(created_at): ${firstEvent.createdAt}');
      // ignore: avoid_print
      print('[PullStrategy][H1-DEBUG] max(created_at): ${lastEvent.createdAt}');
      // ignore: avoid_print
      print('[PullStrategy][H1-DEBUG] First 3 events:');
      for (var i = 0; i < 3 && i < eventsSorted.length; i++) {
        final e = eventsSorted[i];
        // ignore: avoid_print
        print('  [${e.id.substring(0, 8)}] ${e.type} ts=${e.timestamp} created=${e.createdAt}');
      }
    }
    
    if (remoteEvents.isEmpty) {
      // No new events - update lastSyncedAt to now to avoid re-fetching
      final now = DateTime.now().toUtc();
      await _localDataSource.setLastSyncedAt(babyId, now);
      // ignore: avoid_print
      print('[PullStrategy][H1-DEBUG] No new events, updated cursor to now: ${now.toIso8601String()}');
      // ignore: avoid_print
      print('[PullStrategy][H1-DEBUG] ===== PULL END =====');
      return Success(PullResult(
        eventsReceived: 0,
        newLastSyncedAt: now,
      ));
    }

    // Upsert events into local storage (idempotent)
    final upsertResult = await _localDataSource.upsertRemoteEvents(remoteEvents);
    
    if (upsertResult.isError) {
      // ignore: avoid_print
      print('[PullStrategy][H1-DEBUG] Upsert FAILED: ${upsertResult.failureOrNull?.message}');
      return Error(upsertResult.failureOrNull!);
    }

    // ignore: avoid_print
    print('[PullStrategy] pullEventsForBaby: babyId=$babyId, eventsFetched=${remoteEvents.length}');

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
      
      if (latestCreatedAt.isAfter(currentNow)) {
        // ignore: avoid_print
        print('[PullStrategy][H1-DEBUG] WARNING: max(created_at) is in FUTURE! Clamping cursor to now.');
      }
      
      await _localDataSource.setLastSyncedAt(babyId, safeCursor);
      // ignore: avoid_print
      print('[PullStrategy][H1-DEBUG] Updated cursor to: ${safeCursor.toIso8601String()}');
    }
    
    // ignore: avoid_print
    print('[PullStrategy][H1-DEBUG] ===== PULL END =====');

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

