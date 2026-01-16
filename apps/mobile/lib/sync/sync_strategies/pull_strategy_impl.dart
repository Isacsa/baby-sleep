import 'package:temp_flutter/core/types/result.dart';
import 'package:temp_flutter/core/errors/failures.dart';
import 'package:temp_flutter/data/datasources/local/sleep_event_local_datasource.dart';
import 'package:temp_flutter/data/datasources/remote/sleep_event_remote_datasource.dart';

/// Result of a pull operation
class PullResult {
  final int eventsReceived;
  final SyncCursor? newCursor;
  final bool hasError;

  const PullResult({
    required this.eventsReceived,
    this.newCursor,
    this.hasError = false,
  });

  PullResult.withError()
      : eventsReceived = 0,
        newCursor = null,
        hasError = true;

  /// Legacy accessor for backwards compatibility
  DateTime? get newLastSyncedAt => newCursor?.syncedAt;
}

/// Pull strategy implementation
/// 
/// Handles receiving remote events from Supabase backend
/// Uses composite cursor (synced_at, id) with server-generated synced_at
/// 
/// KEY DESIGN DECISIONS:
/// 1. synced_at is server-generated (via trigger) - eliminates clock-skew issues
/// 2. Composite cursor (synced_at, id) ensures deterministic ordering
/// 3. Pagination loops until no more events (not just one batch)
/// 4. Upsert is idempotent - duplicates are safe
class PullStrategyImpl {
  final SleepEventLocalDataSource _localDataSource;
  final SleepEventRemoteDataSource _remoteDataSource;
  
  /// Maximum events per batch/page
  static const int _pageSize = 200;

  PullStrategyImpl({
    required SleepEventLocalDataSource localDataSource,
    required SleepEventRemoteDataSource remoteDataSource,
  })  : _localDataSource = localDataSource,
        _remoteDataSource = remoteDataSource;

  /// Pulls new remote events for a specific baby using composite cursor
  /// 
  /// [babyId] - Baby ID to pull events for
  /// 
  /// Returns number of events received and new cursor
  /// Paginates until all events are fetched
  /// Stops on transient errors (network)
  Future<Result<PullResult, Failure>> pullEventsForBaby(String babyId) async {
    void dbg(String msg) {
      assert(() {
        // ignore: avoid_print
        print(msg);
        return true;
      }());
    }
    
    // Get current cursor
    final cursorResult = await _localDataSource.getSyncCursor(babyId);
    
    if (cursorResult.isError) {
      return Error(cursorResult.failureOrNull!);
    }

    var cursor = cursorResult.dataOrNull ?? SyncCursor.initial();
    
    // === DEBUG LOG H1: Pull cursor info ===
    dbg('[PullStrategy][H1-DEBUG] ===== PULL START (composite cursor) =====');
    dbg('[PullStrategy][H1-DEBUG] babyId: $babyId');
    dbg('[PullStrategy][H1-DEBUG] cursor: $cursor');

    int totalEventsReceived = 0;
    int pageCount = 0;

    // Paginate until no more events
    while (true) {
      pageCount++;
      
      dbg('[PullStrategy][H1-DEBUG] Page $pageCount: cursorSyncedAt=${cursor.syncedAt}, cursorId=${cursor.eventId}');

      // Fetch page of events from remote using composite cursor
      final remoteResult = await _remoteDataSource.getNewRemoteEventsByCursor(
        babyId: babyId,
        cursorSyncedAt: cursor.syncedAt,
        cursorId: cursor.eventId,
        limit: _pageSize,
      );

      if (remoteResult.isError) {
        dbg('[PullStrategy][H1-DEBUG] Remote fetch FAILED: ${remoteResult.failureOrNull?.message}');
        return Error(remoteResult.failureOrNull!);
      }

      final remoteEvents = remoteResult.dataOrNull ?? [];
      
      dbg('[PullStrategy][H1-DEBUG] Page $pageCount: received ${remoteEvents.length} events');
      
      if (remoteEvents.isEmpty) {
        // No more events to fetch
        break;
      }

      // Log first and last events for debugging
      if (remoteEvents.isNotEmpty) {
        final firstEvent = remoteEvents.first;
        final lastEvent = remoteEvents.last;
        dbg('[PullStrategy][H1-DEBUG] firstKey: synced_at=${firstEvent.syncedAt}, id=${firstEvent.id.substring(0, 8)}');
        dbg('[PullStrategy][H1-DEBUG] lastKey: synced_at=${lastEvent.syncedAt}, id=${lastEvent.id.substring(0, 8)}');
      }

      // Upsert events into local storage (idempotent)
      final upsertResult = await _localDataSource.upsertRemoteEvents(remoteEvents);
      
      if (upsertResult.isError) {
        dbg('[PullStrategy][H1-DEBUG] Upsert FAILED: ${upsertResult.failureOrNull?.message}');
        return Error(upsertResult.failureOrNull!);
      }

      totalEventsReceived += remoteEvents.length;

      // Update cursor to last event's (synced_at, id)
      // Events are ordered by synced_at ASC, id ASC, so last event has the highest cursor
      final lastEvent = remoteEvents.last;
      cursor = SyncCursor(
        syncedAt: lastEvent.syncedAt != null 
            ? DateTime.parse(lastEvent.syncedAt!).toUtc() 
            : null,
        eventId: lastEvent.id,
      );

      // Persist cursor after each page (resume-safe)
      final setCursorResult = await _localDataSource.setSyncCursor(babyId, cursor);
      if (setCursorResult.isError) {
        dbg('[PullStrategy][H1-DEBUG] Set cursor FAILED: ${setCursorResult.failureOrNull?.message}');
        // Continue anyway - we've upserted the events
      }

      // If we got less than a full page, we've reached the end
      if (remoteEvents.length < _pageSize) {
        break;
      }
    }

    dbg('[PullStrategy][H1-DEBUG] Pull complete: $totalEventsReceived events in $pageCount pages');
    dbg('[PullStrategy][H1-DEBUG] Final cursor: $cursor');
    dbg('[PullStrategy][H1-DEBUG] ===== PULL END =====');

    return Success(PullResult(
      eventsReceived: totalEventsReceived,
      newCursor: cursor,
    ));
  }

  /// Pulls events for all accessible babies
  /// 
  /// Requires list of baby IDs (from local storage or repository)
  Future<Result<PullResult, Failure>> pullEventsForBabies(List<String> babyIds) async {
    int totalEvents = 0;
    SyncCursor? latestCursor;

    for (final babyId in babyIds) {
      final result = await pullEventsForBaby(babyId);
      
      if (result.isError) {
        // Stop on transient errors
        return Error(result.failureOrNull!);
      }

      final pullResult = result.dataOrNull!;
      totalEvents += pullResult.eventsReceived;
      
      // Track the latest cursor across all babies (for logging/debugging)
      if (pullResult.newCursor != null && pullResult.newCursor!.syncedAt != null) {
        if (latestCursor == null || 
            latestCursor.syncedAt == null ||
            pullResult.newCursor!.syncedAt!.isAfter(latestCursor.syncedAt!)) {
          latestCursor = pullResult.newCursor;
        }
      }
    }

    return Success(PullResult(
      eventsReceived: totalEvents,
      newCursor: latestCursor,
    ));
  }
}
