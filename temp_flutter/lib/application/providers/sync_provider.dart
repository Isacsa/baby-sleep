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
}
