import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:temp_flutter/core/types/result.dart' as core;
import 'package:temp_flutter/sync/sync_state.dart';
import 'package:temp_flutter/sync/sync_pull_engine.dart';
import 'package:temp_flutter/sync/layered_sync_orchestrator.dart';
import 'package:temp_flutter/data/datasources/local/sleep_event_local_datasource_impl.dart';
import 'package:temp_flutter/data/datasources/local/baby_local_datasource_impl.dart';
import 'package:temp_flutter/data/datasources/local/caregiver_local_datasource_impl.dart';
import 'package:temp_flutter/data/datasources/remote/sleep_event_remote_datasource_impl.dart';
import 'package:temp_flutter/data/datasources/remote/baby_remote_datasource_impl.dart';
import 'package:temp_flutter/data/datasources/remote/caregiver_remote_datasource_impl.dart';
import 'package:temp_flutter/application/providers/babies_provider.dart';
import 'package:temp_flutter/application/providers/caregivers_provider.dart';
import 'package:temp_flutter/application/providers/sleep_events_provider.dart';
import 'package:temp_flutter/application/providers/sleep_state_provider.dart';
import 'package:temp_flutter/application/providers/caregiver_context_provider.dart';

part 'sync_provider.g.dart';

/// Sync provider
/// 
/// Manages synchronization state and operations
/// Exposes sync state to UI (idle/syncing/success/error)
/// 
/// LAYERED SYNC STRATEGY:
/// Push operations use LayeredSyncOrchestrator which syncs in order:
/// 1. Babies first (must exist before caregivers)
/// 2. Caregivers second (must exist before events can reference them)
/// 3. SleepEvents last (depend on caregiver existing remotely)
/// 
/// This ensures FK integrity in the backend and prevents the error:
/// "Caregiver does not exist, is inactive, or does not belong to this baby"
@riverpod
class Sync extends _$Sync {
  LayeredSyncOrchestrator? _layeredSyncOrchestrator;
  SyncPullEngine? _pullEngine;

  @override
  SyncState build() {
    return SyncState.initial();
  }

  /// Gets or creates the layered sync orchestrator
  LayeredSyncOrchestrator get _orchestrator {
    _layeredSyncOrchestrator ??= LayeredSyncOrchestrator(
      babyLocalDataSource: BabyLocalDataSourceImpl(),
      babyRemoteDataSource: BabyRemoteDataSourceImpl(),
      caregiverLocalDataSource: CaregiverLocalDataSourceImpl(),
      caregiverRemoteDataSource: CaregiverRemoteDataSourceImpl(),
      eventLocalDataSource: SleepEventLocalDataSourceImpl(),
      eventRemoteDataSource: SleepEventRemoteDataSourceImpl(),
    );
    return _layeredSyncOrchestrator!;
  }

  /// Gets or creates the pull engine
  SyncPullEngine get _pull {
    _pullEngine ??= SyncPullEngine(
      localDataSource: SleepEventLocalDataSourceImpl(),
      remoteDataSource: SleepEventRemoteDataSourceImpl(),
      babyDataSource: BabyLocalDataSourceImpl(),
    );
    return _pullEngine!;
  }

  /// Pushes unsynced entities for a specific baby (layered)
  /// 
  /// Uses LAYERED SYNC: Baby → Caregivers → SleepEvents
  /// This ensures all dependencies exist remotely before pushing events
  Future<void> pushForBaby(String babyId) async {
    state = SyncState.syncing(pendingEventsCount: 0);

    final result = await _orchestrator.syncForBaby(babyId);

    switch (result) {
      case core.Error(:final failure):
        state = SyncState.error(
          errorMessage: failure.message,
          lastSyncedAt: state.lastSyncedAt,
        );
      case core.Success(:final data):
        if (data.hasTransientError) {
          state = SyncState.error(
            errorMessage: data.errorMessage ?? 'Network error - will retry',
            lastSyncedAt: state.lastSyncedAt,
          );
        } else if (data.totalErrors > 0) {
          state = SyncState.success(
            lastSyncedAt: DateTime.now().toUtc(),
          ).copyWith(
            errorMessage: '${data.totalErrors} items failed to sync',
          );
        } else {
          state = SyncState.success(
            lastSyncedAt: DateTime.now().toUtc(),
          );
        }
        // ignore: avoid_print
        print('[SyncProvider] Layered push complete: '
            '${data.babiesPushed} babies, '
            '${data.caregiversPushed} caregivers, '
            '${data.eventsPushed} events');
    }

    // Invalidate caches ONCE at the end (not inside loops)
    _invalidateAfterSync();
  }

  /// Pushes all unsynced entities (global layered sync)
  /// 
  /// Uses LAYERED SYNC: All Babies → All Caregivers → All SleepEvents
  Future<void> pushAll() async {
    state = SyncState.syncing(pendingEventsCount: 0);

    final result = await _orchestrator.syncAll();

    switch (result) {
      case core.Error(:final failure):
        state = SyncState.error(
          errorMessage: failure.message,
          lastSyncedAt: state.lastSyncedAt,
        );
      case core.Success(:final data):
        if (data.hasTransientError) {
          state = SyncState.error(
            errorMessage: data.errorMessage ?? 'Network error - will retry',
            lastSyncedAt: state.lastSyncedAt,
          );
        } else if (data.totalErrors > 0) {
          state = SyncState.success(
            lastSyncedAt: DateTime.now().toUtc(),
          ).copyWith(
            errorMessage: '${data.totalErrors} items failed to sync',
          );
        } else {
          state = SyncState.success(
            lastSyncedAt: DateTime.now().toUtc(),
          );
        }
        // ignore: avoid_print
        print('[SyncProvider] Layered push complete: '
            '${data.babiesPushed} babies, '
            '${data.caregiversPushed} caregivers, '
            '${data.eventsPushed} events');
    }

    // Invalidate caches ONCE at the end (not inside loops)
    _invalidateAfterSync();
  }

  /// Gets count of pending events for a baby
  /// 
  /// Note: This only counts SleepEvents, not unsynced babies/caregivers
  Future<int> getPendingCount(String babyId) async {
    final localDataSource = SleepEventLocalDataSourceImpl();
    final result = await localDataSource.getUnsyncedEvents(babyId);
    return result.isSuccess ? (result.dataOrNull?.length ?? 0) : 0;
  }

  /// Gets count of all pending events
  Future<int> getAllPendingCount() async {
    final localDataSource = SleepEventLocalDataSourceImpl();
    final result = await localDataSource.getAllUnsyncedEvents();
    return result.isSuccess ? (result.dataOrNull?.length ?? 0) : 0;
  }

  /// Pulls new remote events for a specific baby
  /// 
  /// Use this when you want to receive events created by other devices/caregivers
  Future<void> pullForBaby(String babyId) async {
    state = SyncState.syncing(pendingEventsCount: 0);

    final result = await _pull.pullForBaby(babyId);

    switch (result) {
      case core.Error(:final failure):
        state = SyncState.error(
          errorMessage: failure.message,
          lastSyncedAt: state.lastSyncedAt,
        );
      case core.Success():
        state = SyncState.success(
          lastSyncedAt: DateTime.now().toUtc(),
        );
    }

    // Invalidate caches ONCE at the end (not inside loops)
    _invalidateAfterSync();
  }

  /// Pulls events for all accessible babies
  /// 
  /// Use this when you want to receive all new events regardless of baby
  Future<void> pullAll() async {
    state = SyncState.syncing(pendingEventsCount: 0);

    final result = await _pull.pullAll();

    switch (result) {
      case core.Error(:final failure):
        state = SyncState.error(
          errorMessage: failure.message,
          lastSyncedAt: state.lastSyncedAt,
        );
      case core.Success():
        state = SyncState.success(
          lastSyncedAt: DateTime.now().toUtc(),
        );
    }

    // Invalidate caches ONCE at the end (not inside loops)
    _invalidateAfterSync();
  }

  /// Full sync: push then pull (layered)
  /// 
  /// Uses LAYERED SYNC for push, then pulls remote events
  Future<void> syncFull(String babyId) async {
    await pushForBaby(babyId);
    
    // Only pull if push succeeded (no transient error)
    if (state.status != SyncStatus.error) {
      await pullForBaby(babyId);
    }
  }

  // ========== SYNC NOW (UI Single Operation) ==========
  //
  // Guardrail 2: UI should call a SINGLE method for sync, not separate push/pull.
  // This ensures consistent SyncState transitions and avoids confusing the user
  // with multiple states.

  /// Performs complete sync for a baby: push local changes, then pull remote updates
  /// 
  /// THIS IS THE MAIN METHOD THE UI SHOULD CALL FOR "SYNC NOW".
  /// 
  /// Flow:
  /// 1. Set state = syncing
  /// 2. Push local entities (baby/caregivers/events) via layered sync
  /// 3. If push fails with transient error, stop and report error
  /// 4. If push ok, pull caregivers + events from remote
  /// 5. Set final state (success/error)
  /// 6. Invalidate caches ONCE at the end
  /// 
  /// The UI only needs to observe SyncState and call this single method.
  Future<void> syncNowForBaby(String babyId) async {
    state = SyncState.syncing(pendingEventsCount: 0);
    // ignore: avoid_print
    print('[SyncProvider] syncNowForBaby START: babyId=$babyId');

    // Step 1: Push local changes
    final pushResult = await _orchestrator.syncForBaby(babyId);

    switch (pushResult) {
      case core.Error(:final failure):
        state = SyncState.error(
          errorMessage: 'Push failed: ${failure.message}',
          lastSyncedAt: state.lastSyncedAt,
        );
        // ignore: avoid_print
        print('[SyncProvider] syncNowForBaby FAILED (push): ${failure.message}');
        return;

      case core.Success(:final data):
        if (data.hasTransientError) {
          state = SyncState.error(
            errorMessage: 'Network error during push - try again later',
            lastSyncedAt: state.lastSyncedAt,
          );
          // ignore: avoid_print
          print('[SyncProvider] syncNowForBaby FAILED (transient): ${data.errorMessage}');
          return;
        }
        // ignore: avoid_print
        print('[SyncProvider] syncNowForBaby push complete: '
            '${data.babiesPushed} babies, '
            '${data.caregiversPushed} caregivers, '
            '${data.eventsPushed} events');
    }

    // Step 2: Pull remote updates (caregivers + events)
    // Using internal implementation to avoid double state transitions
    final caregiverRemoteDataSource = CaregiverRemoteDataSourceImpl();
    final caregiverLocalDataSource = CaregiverLocalDataSourceImpl();

    // Pull caregivers
    final fetchCaregiversResult = await caregiverRemoteDataSource.getCaregiversForBaby(babyId);
    if (fetchCaregiversResult.isError) {
      state = SyncState.error(
        errorMessage: 'Pull caregivers failed: ${fetchCaregiversResult.failureOrNull?.message}',
        lastSyncedAt: state.lastSyncedAt,
      );
      // ignore: avoid_print
      print('[SyncProvider] syncNowForBaby FAILED (pull caregivers): ${fetchCaregiversResult.failureOrNull?.message}');
      return;
    }

    final remoteCaregivers = fetchCaregiversResult.dataOrNull ?? [];
    final upsertCaregiversResult = await caregiverLocalDataSource.upsertCaregiversFromRemote(remoteCaregivers);
    if (upsertCaregiversResult.isSuccess) {
      // ignore: avoid_print
      print('[SyncProvider] syncNowForBaby: caregiversUpserted=${upsertCaregiversResult.dataOrNull!.caregiversUpserted}');
    }

    // Pull events
    final pullEventsResult = await _pull.pullForBaby(babyId);
    if (pullEventsResult.isError) {
      state = SyncState.error(
        errorMessage: 'Pull events failed: ${pullEventsResult.failureOrNull?.message}',
        lastSyncedAt: state.lastSyncedAt,
      );
      // ignore: avoid_print
      print('[SyncProvider] syncNowForBaby FAILED (pull events): ${pullEventsResult.failureOrNull?.message}');
      return;
    }

    // Success!
    state = SyncState.success(
      lastSyncedAt: DateTime.now().toUtc(),
    );

    // Invalidate caches ONCE at the end
    _invalidateAfterSync();
    // ignore: avoid_print
    print('[SyncProvider] syncNowForBaby SUCCESS: babyId=$babyId');
  }

  /// Full sync for all babies (layered)
  Future<void> syncAll() async {
    await pushAll();
    
    if (state.status != SyncStatus.error) {
      await pullAll();
    }
  }

  /// Resets sync state to idle
  void reset() {
    state = SyncState.initial();
  }

  // ========== GLOBAL PULL (Device New) ==========
  //
  // These methods solve the "catch-22" problem on a new device:
  // - ActiveBabyId is device-scoped and may be null on a new device
  // - pullAll() depends on babies already existing in SQLite
  // - Without babies in SQLite, there's nothing to pull
  //
  // Solution: separate pull operations:
  // 1. pullBabiesGlobal() - fetches babies from remote (no ActiveBabyId needed)
  // 2. pullActiveBabyData() - fetches caregivers + events for a specific baby

  /// Pulls accessible babies from remote (global pull)
  /// 
  /// DOES NOT require ActiveBabyId - works on new devices!
  /// 
  /// Uses GetAccessibleBabies (backend contract 4.1) to discover babies
  /// the user has access to via RLS (as caregiver).
  /// 
  /// Logs: remoteBabiesFetched, babiesUpserted
  Future<void> pullBabiesGlobal() async {
    state = SyncState.syncing(pendingEventsCount: 0);

    final babyRemoteDataSource = BabyRemoteDataSourceImpl();
    final babyLocalDataSource = BabyLocalDataSourceImpl();

    // Step 1: Fetch accessible babies from remote
    final fetchResult = await babyRemoteDataSource.getAccessibleBabies();

    if (fetchResult.isError) {
      final failure = fetchResult.failureOrNull!;
      state = SyncState.error(
        errorMessage: failure.message,
        lastSyncedAt: state.lastSyncedAt,
      );
      // ignore: avoid_print
      print('[SyncProvider] pullBabiesGlobal FAILED: ${failure.message}');
      return;
    }

    final remoteBabies = fetchResult.dataOrNull ?? [];
    final remoteBabiesFetched = remoteBabies.length;
    // ignore: avoid_print
    print('[SyncProvider] pullBabiesGlobal: remoteBabiesFetched=$remoteBabiesFetched');

    // Step 2: Upsert babies into SQLite (mark as synced)
    final upsertResult = await babyLocalDataSource.upsertBabiesFromRemote(remoteBabies);

    if (upsertResult.isError) {
      final failure = upsertResult.failureOrNull!;
      state = SyncState.error(
        errorMessage: failure.message,
        lastSyncedAt: state.lastSyncedAt,
      );
      // ignore: avoid_print
      print('[SyncProvider] pullBabiesGlobal FAILED (upsert): ${failure.message}');
      return;
    }

    final babiesUpserted = upsertResult.dataOrNull!.babiesUpserted;
    // ignore: avoid_print
    print('[SyncProvider] pullBabiesGlobal: babiesUpserted=$babiesUpserted');

    state = SyncState.success(
      lastSyncedAt: DateTime.now().toUtc(),
    );

    // Invalidate babies provider ONCE at the end
    ref.invalidate(babiesNotifierProvider);
    // ignore: avoid_print
    print('[SyncProvider] pullBabiesGlobal SUCCESS: '
        'remoteBabiesFetched=$remoteBabiesFetched, babiesUpserted=$babiesUpserted');
  }

  /// Pulls caregivers + events for a specific baby
  /// 
  /// REQUIRES ActiveBabyId (or any valid babyId)
  /// 
  /// 1. Fetches caregivers from remote and upserts into SQLite
  /// 2. Fetches events via existing SyncPullEngine
  /// 
  /// Logs: caregiversFetched, caregiversUpserted, eventsFetched
  Future<void> pullActiveBabyData(String babyId) async {
    state = SyncState.syncing(pendingEventsCount: 0);

    final caregiverRemoteDataSource = CaregiverRemoteDataSourceImpl();
    final caregiverLocalDataSource = CaregiverLocalDataSourceImpl();

    // Step 1: Fetch caregivers from remote
    final fetchCaregiversResult = await caregiverRemoteDataSource.getCaregiversForBaby(babyId);

    if (fetchCaregiversResult.isError) {
      final failure = fetchCaregiversResult.failureOrNull!;
      state = SyncState.error(
        errorMessage: failure.message,
        lastSyncedAt: state.lastSyncedAt,
      );
      // ignore: avoid_print
      print('[SyncProvider] pullActiveBabyData FAILED (caregivers): ${failure.message}');
      return;
    }

    final remoteCaregivers = fetchCaregiversResult.dataOrNull ?? [];
    final caregiversFetched = remoteCaregivers.length;
    // ignore: avoid_print
    print('[SyncProvider] pullActiveBabyData: caregiversFetched=$caregiversFetched');

    // Step 2: Upsert caregivers into SQLite
    final upsertCaregiversResult = await caregiverLocalDataSource.upsertCaregiversFromRemote(remoteCaregivers);

    int caregiversUpserted = 0;
    if (upsertCaregiversResult.isSuccess) {
      caregiversUpserted = upsertCaregiversResult.dataOrNull!.caregiversUpserted;
      // ignore: avoid_print
      print('[SyncProvider] pullActiveBabyData: caregiversUpserted=$caregiversUpserted');
    } else {
      // Log warning but continue with events
      // ignore: avoid_print
      print('[SyncProvider] pullActiveBabyData WARNING (caregiver upsert): '
          '${upsertCaregiversResult.failureOrNull?.message}');
    }

    // Step 3: Pull events via existing engine
    // Note: PullStrategyImpl logs eventsReceived internally
    final pullEventsResult = await _pull.pullForBaby(babyId);

    if (pullEventsResult.isError) {
      final failure = pullEventsResult.failureOrNull!;
      state = SyncState.error(
        errorMessage: failure.message,
        lastSyncedAt: state.lastSyncedAt,
      );
      // ignore: avoid_print
      print('[SyncProvider] pullActiveBabyData FAILED (events): ${failure.message}');
      return;
    }
    // ignore: avoid_print
    print('[SyncProvider] pullActiveBabyData: events pull completed (see PullStrategyImpl logs for count)');

    state = SyncState.success(
      lastSyncedAt: DateTime.now().toUtc(),
    );

    // Invalidate caches ONCE at the end
    _invalidateAfterSync();
    // ignore: avoid_print
    print('[SyncProvider] pullActiveBabyData SUCCESS: '
        'caregiversFetched=$caregiversFetched, caregiversUpserted=$caregiversUpserted');
  }

  // ========== CACHE INVALIDATION ==========
  //
  // After sync operations (especially canonicalization which swaps caregiver PKs),
  // in-memory provider caches may hold stale IDs. We invalidate them at the END
  // of each sync operation to force a fresh read from SQLite.
  //
  // IMPORTANT: Only call this ONCE at the end of a sync operation, NOT inside loops.
  // This prevents excessive rebuilds and potential loops.

  /// Invalidates provider caches after sync to ensure UI has fresh data
  /// 
  /// This is called ONCE at the end of push/pull operations, not per-event.
  /// Invalidates:
  /// - caregiversNotifierProvider (may have swapped IDs after canonicalization)
  /// - sleepEventsNotifierProvider (events may have new caregiver_id references)
  /// - sleepStateNotifierProvider (derived from events, needs refresh)
  /// - caregiverContextProvider (needs to re-verify after sync)
  void _invalidateAfterSync() {
    ref.invalidate(caregiversNotifierProvider);
    ref.invalidate(sleepEventsNotifierProvider);
    ref.invalidate(sleepStateNotifierProvider);
    ref.invalidate(caregiverContextProvider);
    // ignore: avoid_print
    print('[SyncProvider] Invalidated provider caches after sync');
  }

  // ========== PULL CAREGIVERS ONLY ==========
  //
  // Lightweight pull that only fetches caregivers (not events).
  // Used by ensureCaregiverContext when we only need to verify permissions.

  /// Pulls only caregivers for a specific baby (no events)
  /// 
  /// Lighter than pullActiveBabyData - useful for verifying permissions
  /// without pulling the full event history.
  /// 
  /// Returns true if successful, false if failed.
  Future<bool> pullCaregiversOnly(String babyId) async {
    final caregiverRemoteDataSource = CaregiverRemoteDataSourceImpl();
    final caregiverLocalDataSource = CaregiverLocalDataSourceImpl();

    // ignore: avoid_print
    print('[SyncProvider] pullCaregiversOnly: babyId=$babyId');

    // Fetch caregivers from remote
    final fetchResult = await caregiverRemoteDataSource.getCaregiversForBaby(babyId);

    if (fetchResult.isError) {
      // ignore: avoid_print
      print('[SyncProvider] pullCaregiversOnly FAILED: ${fetchResult.failureOrNull?.message}');
      return false;
    }

    final remoteCaregivers = fetchResult.dataOrNull ?? [];
    // ignore: avoid_print
    print('[SyncProvider] pullCaregiversOnly: fetched ${remoteCaregivers.length} caregivers');

    if (remoteCaregivers.isEmpty) {
      return true; // Success but no caregivers (user may not be caregiver)
    }

    // Upsert into SQLite
    final upsertResult = await caregiverLocalDataSource.upsertCaregiversFromRemote(remoteCaregivers);

    if (upsertResult.isSuccess) {
      // ignore: avoid_print
      print('[SyncProvider] pullCaregiversOnly: upserted ${upsertResult.dataOrNull!.caregiversUpserted} caregivers');
      ref.invalidate(caregiversNotifierProvider);
      ref.invalidate(caregiverContextProvider);
      return true;
    } else {
      // ignore: avoid_print
      print('[SyncProvider] pullCaregiversOnly FAILED (upsert): ${upsertResult.failureOrNull?.message}');
      return false;
    }
  }
}
