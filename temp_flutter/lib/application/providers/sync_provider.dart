import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:temp_flutter/core/types/result.dart' as core;
import 'package:temp_flutter/sync/sync_state.dart';
import 'package:temp_flutter/sync/sync_push_engine.dart';
import 'package:temp_flutter/sync/sync_pull_engine.dart';
import 'package:temp_flutter/data/datasources/local/sleep_event_local_datasource_impl.dart';
import 'package:temp_flutter/data/datasources/local/baby_local_datasource_impl.dart';
import 'package:temp_flutter/data/datasources/remote/sleep_event_remote_datasource_impl.dart';

part 'sync_provider.g.dart';

/// Sync provider
/// 
/// Manages synchronization state and operations
/// Exposes sync state to UI (idle/syncing/success/error)
@riverpod
class Sync extends _$Sync {
  late final SyncPushEngine _pushEngine;
  late final SyncPullEngine _pullEngine;
  bool _initialized = false;

  @override
  SyncState build() {
    _initializeEngines();
    return SyncState.initial();
  }

  /// Initializes the sync engines
  void _initializeEngines() {
    if (_initialized) return;
    
    final localDataSource = SleepEventLocalDataSourceImpl();
    final remoteDataSource = SleepEventRemoteDataSourceImpl();
    final babyDataSource = BabyLocalDataSourceImpl();
    
    _pushEngine = SyncPushEngine(
      localDataSource: localDataSource,
      remoteDataSource: remoteDataSource,
    );
    
    _pullEngine = SyncPullEngine(
      localDataSource: localDataSource,
      remoteDataSource: remoteDataSource,
      babyDataSource: babyDataSource,
    );
    
    // Listen to state changes from both engines
    _pushEngine.onStateChanged = (newState) {
      state = newState;
    };
    
    _pullEngine.onStateChanged = (newState) {
      state = newState;
    };
    
    _initialized = true;
  }

  /// Pushes unsynced events for a specific baby
  /// 
  /// Use this when you want to sync events for the active baby only
  Future<void> pushForBaby(String babyId) async {
    _initializeEngines();
    
    // Update state to syncing
    state = SyncState.syncing(pendingEventsCount: 0);
    
    final result = await _pushEngine.pushForBaby(babyId);
    
    // State is updated via callback, but ensure final state is set
    switch (result) {
      case core.Error(:final failure):
        state = SyncState.error(
          errorMessage: failure.message,
          lastSyncedAt: state.lastSyncedAt,
        );
      case core.Success():
        // State already updated via callback
        break;
    }
  }

  /// Pushes all unsynced events (global sync)
  /// 
  /// Use this when you want to sync all pending events regardless of baby
  Future<void> pushAll() async {
    _initializeEngines();
    
    state = SyncState.syncing(pendingEventsCount: 0);
    
    final result = await _pushEngine.pushAll();
    
    switch (result) {
      case core.Error(:final failure):
        state = SyncState.error(
          errorMessage: failure.message,
          lastSyncedAt: state.lastSyncedAt,
        );
      case core.Success():
        // State already updated via callback
        break;
    }
  }

  /// Gets count of pending events for a baby
  Future<int> getPendingCount(String babyId) async {
    _initializeEngines();
    return await _pushEngine.getPendingCount(babyId);
  }

  /// Gets count of all pending events
  Future<int> getAllPendingCount() async {
    _initializeEngines();
    return await _pushEngine.getAllPendingCount();
  }

  /// Pulls new remote events for a specific baby
  /// 
  /// Use this when you want to receive events created by other devices/caregivers
  Future<void> pullForBaby(String babyId) async {
    _initializeEngines();
    
    state = SyncState.syncing(pendingEventsCount: 0);
    
    final result = await _pullEngine.pullForBaby(babyId);
    
    switch (result) {
      case core.Error(:final failure):
        state = SyncState.error(
          errorMessage: failure.message,
          lastSyncedAt: state.lastSyncedAt,
        );
      case core.Success():
        // State already updated via callback
        break;
    }
  }

  /// Pulls events for all accessible babies
  /// 
  /// Use this when you want to receive all new events regardless of baby
  Future<void> pullAll() async {
    _initializeEngines();
    
    state = SyncState.syncing(pendingEventsCount: 0);
    
    final result = await _pullEngine.pullAll();
    
    switch (result) {
      case core.Error(:final failure):
        state = SyncState.error(
          errorMessage: failure.message,
          lastSyncedAt: state.lastSyncedAt,
        );
      case core.Success():
        // State already updated via callback
        break;
    }
  }

  /// Full sync: push then pull
  /// 
  /// Pushes local events first, then pulls remote events
  Future<void> syncFull(String babyId) async {
    await pushForBaby(babyId);
    await pullForBaby(babyId);
  }

  /// Full sync for all babies
  Future<void> syncAll() async {
    await pushAll();
    await pullAll();
  }

  /// Resets sync state to idle
  void reset() {
    state = SyncState.initial();
  }
}
