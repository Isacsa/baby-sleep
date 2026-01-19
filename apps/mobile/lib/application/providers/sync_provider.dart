import 'dart:async';
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
import 'package:temp_flutter/application/providers/active_baby_provider.dart';
import 'package:temp_flutter/application/providers/babies_provider.dart';
import 'package:temp_flutter/application/providers/caregivers_provider.dart';
import 'package:temp_flutter/application/providers/sleep_events_provider.dart';
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
  
  // FIX P4: Auto-sync after local changes
  Timer? _autoSyncTimer;
  bool _autoSyncInProgress = false;
  
  // AUTO-PULL: Polling periódico para receber eventos de outros devices
  Timer? _autoPullTimer;
  bool _autoPullInProgress = false;
  String? _autoPullBabyId;
  static const Duration _autoPullBaseInterval = Duration(seconds: 20);
  static const Duration _autoPullMaxInterval = Duration(minutes: 2);
  Duration _autoPullCurrentInterval = _autoPullBaseInterval;

  @override
  SyncState build() {
    // Cancel timers on dispose
    ref.onDispose(() {
      _autoSyncTimer?.cancel();
      _autoPullTimer?.cancel();
    });
    return SyncState.initial();
  }
  
  // ========== AUTO-SYNC (FIX P4) ==========
  
  /// Schedules an automatic sync after a local change (debounced, non-blocking)
  /// 
  /// Called automatically after addEvent() to propagate changes to other devices.
  /// Uses a 2-second debounce to batch multiple rapid changes into one sync.
  /// Does NOT block UI or change state to "syncing" (runs silently in background).
  void scheduleSyncAfterLocalChange(String babyId) {
    // Cancel any pending auto-sync
    _autoSyncTimer?.cancel();
    
    // Schedule new sync with 2-second debounce
    _autoSyncTimer = Timer(const Duration(seconds: 2), () {
      _syncInBackground(babyId);
    });
    
    // ignore: avoid_print
    print('[SyncProvider] Auto-sync scheduled for babyId=$babyId (2s debounce)');
  }
  
  /// Performs sync in background without changing UI state
  /// 
  /// Does not set state to "syncing" to avoid UI spinner disruption.
  /// Errors are logged but not surfaced (will retry on next action).
  Future<void> _syncInBackground(String babyId) async {
    if (_autoSyncInProgress) {
      // ignore: avoid_print
      print('[SyncProvider] Auto-sync skipped: already in progress');
      return;
    }
    
    _autoSyncInProgress = true;
    // ignore: avoid_print
    print('[SyncProvider] Auto-sync START: babyId=$babyId');
    
    try {
      // Push local changes
      final pushResult = await _orchestrator.syncForBaby(babyId);
      
      if (pushResult.isError) {
        // ignore: avoid_print
        print('[SyncProvider] Auto-sync push FAILED: ${pushResult.failureOrNull?.message}');
        return;
      }
      
      final pushData = pushResult.dataOrNull!;
      if (pushData.hasTransientError) {
        // ignore: avoid_print
        print('[SyncProvider] Auto-sync push FAILED (network): ${pushData.errorMessage}');
        return;
      }
      
      // ignore: avoid_print
      print('[SyncProvider] Auto-sync pushed: '
          '${pushData.babiesPushed} babies, '
          '${pushData.caregiversPushed} caregivers, '
          '${pushData.eventsPushed} events');
      
      // Pull remote updates
      final pullResult = await _pull.pullForBaby(babyId);
      
      if (pullResult.isError) {
        // ignore: avoid_print
        print('[SyncProvider] Auto-sync pull FAILED: ${pullResult.failureOrNull?.message}');
        return;
      }
      
      // Invalidate caches to refresh UI with new data
      _invalidateAfterSync();
      
      // ignore: avoid_print
      print('[SyncProvider] Auto-sync COMPLETE: babyId=$babyId');
    } catch (e) {
      // ignore: avoid_print
      print('[SyncProvider] Auto-sync ERROR: $e');
    } finally {
      _autoSyncInProgress = false;
    }
  }
  
  // ========== AUTO-PULL (Polling para receber eventos de outros devices) ==========
  
  /// Inicia o polling automático de eventos para o bebé ativo
  /// 
  /// Chamado pelo MainScaffold quando a app está em foreground.
  /// Faz pull imediato + timer periódico (20s base, backoff em erro).
  void startAutoPull({required String babyId}) {
    // Se já está a correr para o mesmo baby, não reiniciar
    if (_autoPullBabyId == babyId && _autoPullTimer != null) {
      // ignore: avoid_print
      print('[SyncProvider] Auto-pull already running for babyId=$babyId');
      return;
    }
    
    // Parar polling anterior (se existir)
    stopAutoPull();
    
    _autoPullBabyId = babyId;
    _autoPullCurrentInterval = _autoPullBaseInterval;
    
    // ignore: avoid_print
    print('[SyncProvider] Auto-pull START: babyId=$babyId, interval=${_autoPullCurrentInterval.inSeconds}s');
    
    // Pull imediato ao iniciar
    _pullInBackground(babyId);
    
    // Iniciar timer periódico
    _startAutoPullTimer();
  }
  
  /// Para o polling automático
  /// 
  /// Chamado quando a app vai para background ou não há baby ativo.
  void stopAutoPull() {
    _autoPullTimer?.cancel();
    _autoPullTimer = null;
    
    if (_autoPullBabyId != null) {
      // ignore: avoid_print
      print('[SyncProvider] Auto-pull STOP: babyId=$_autoPullBabyId');
    }
    _autoPullBabyId = null;
  }
  
  /// Chamado quando a app volta ao foreground (resume)
  /// 
  /// Faz pull imediato + reinicia timer.
  void onAppResumed() {
    final babyId = _autoPullBabyId;
    if (babyId == null) {
      // ignore: avoid_print
      print('[SyncProvider] onAppResumed: no active baby, skipping');
      return;
    }
    
    // ignore: avoid_print
    print('[SyncProvider] onAppResumed: babyId=$babyId, pulling now + restarting timer');
    
    // Reset backoff ao voltar
    _autoPullCurrentInterval = _autoPullBaseInterval;
    
    // Pull imediato
    _pullInBackground(babyId);
    
    // Reiniciar timer
    _startAutoPullTimer();
  }
  
  /// Chamado quando a app vai para background (paused/inactive/detached)
  /// 
  /// Para o timer mas mantém o babyId para retomar no resume.
  void onAppPaused() {
    _autoPullTimer?.cancel();
    _autoPullTimer = null;
    // ignore: avoid_print
    print('[SyncProvider] onAppPaused: timer stopped (babyId=$_autoPullBabyId preserved)');
  }
  
  /// Inicia/reinicia o timer periódico
  void _startAutoPullTimer() {
    _autoPullTimer?.cancel();
    _autoPullTimer = Timer.periodic(_autoPullCurrentInterval, (_) {
      final babyId = _autoPullBabyId;
      if (babyId != null) {
        _pullInBackground(babyId);
      }
    });
  }
  
  /// Faz pull em background sem alterar SyncState (UI não vê spinner)
  /// 
  /// Inclui gating de concorrência para evitar conflitos com:
  /// - Auto-sync em progresso
  /// - Outro auto-pull em progresso
  /// - Sync manual em progresso
  Future<void> _pullInBackground(String babyId) async {
    // Gating: não correr se outra operação está em progresso
    if (_autoPullInProgress) {
      // ignore: avoid_print
      print('[SyncProvider] Auto-pull skipped: already in progress');
      return;
    }
    
    if (_autoSyncInProgress) {
      // ignore: avoid_print
      print('[SyncProvider] Auto-pull skipped: auto-sync in progress');
      return;
    }
    
    if (state.status == SyncStatus.syncing) {
      // ignore: avoid_print
      print('[SyncProvider] Auto-pull skipped: manual sync in progress');
      return;
    }
    
    _autoPullInProgress = true;
    // ignore: avoid_print
    print('[SyncProvider] Auto-pull START: babyId=$babyId');
    
    try {
      // Pull direto (não usa pullForBaby() para não alterar SyncState)
      final result = await _pull.pullForBaby(babyId);
      
      if (result.isError) {
        // Backoff: aumentar intervalo (máx 2min)
        _autoPullCurrentInterval = Duration(
          seconds: (_autoPullCurrentInterval.inSeconds * 2)
              .clamp(0, _autoPullMaxInterval.inSeconds),
        );
        // ignore: avoid_print
        print('[SyncProvider] Auto-pull FAILED: ${result.failureOrNull?.message}, '
            'next interval=${_autoPullCurrentInterval.inSeconds}s');
        
        // Reiniciar timer com novo intervalo
        _startAutoPullTimer();
        return;
      }
      
      // Sucesso: reset backoff
      if (_autoPullCurrentInterval != _autoPullBaseInterval) {
        _autoPullCurrentInterval = _autoPullBaseInterval;
        _startAutoPullTimer(); // Reiniciar com intervalo base
        // ignore: avoid_print
        print('[SyncProvider] Auto-pull: backoff reset to ${_autoPullBaseInterval.inSeconds}s');
      }
      
      // Invalidar caches para atualizar UI
      _invalidateAfterSync();
      // ignore: avoid_print
      print('[SyncProvider] Auto-pull SUCCESS: babyId=$babyId');
      
    } catch (e) {
      // ignore: avoid_print
      print('[SyncProvider] Auto-pull ERROR: $e');
    } finally {
      _autoPullInProgress = false;
    }
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
  // in-memory provider caches may hold stale IDs. We refresh them at the END
  // of each sync operation to ensure UI has fresh data.
  //
  // IMPORTANT: Only call this ONCE at the end of a sync operation, NOT inside loops.
  // This prevents excessive rebuilds and potential loops.
  //
  // FIX UI FLICKER: Use refresh() instead of invalidate() for sleepEvents.
  // refresh() uses copyWithPrevious to preserve UI state during loading,
  // preventing the momentary "isSleeping=false" flicker.
  // sleepStateNotifierProvider auto-reacts to sleepEvents, no separate invalidate needed.

  /// Refreshes provider caches after sync to ensure UI has fresh data
  /// 
  /// This is called ONCE at the end of push/pull operations, not per-event.
  /// Actions:
  /// - caregiversNotifierProvider: invalidate (no refresh method)
  /// - sleepEventsNotifierProvider: refresh() with copyWithPrevious (prevents flicker)
  /// - sleepStateNotifierProvider: NOT touched (auto-derives from sleepEvents)
  /// - caregiverContextProvider: invalidate
  void _invalidateAfterSync() {
    void dbg(String msg) {
      assert(() {
        // ignore: avoid_print
        print(msg);
        return true;
      }());
    }
    // === DEBUG LOG H3: Provider refresh ===
    dbg('[SyncProvider][H3-DEBUG] ===== REFRESHING PROVIDERS =====');
    dbg('[SyncProvider][H3-DEBUG] About to refresh: caregivers(inv), sleepEvents(refresh), caregiverContext(inv)');
    
    ref.invalidate(caregiversNotifierProvider);
    dbg('[SyncProvider][H3-DEBUG] Invalidated: caregiversNotifierProvider');
    
    // FIX UI FLICKER: Use refresh() instead of invalidate()
    // refresh() preserves previous state during loading (copyWithPrevious)
    // preventing UI from momentarily showing "Dormir agora" (isSleeping=false)
    ref.read(sleepEventsNotifierProvider.notifier).refresh();
    dbg('[SyncProvider][H3-DEBUG] Called refresh() on sleepEventsNotifierProvider');
    
    // NOTE: sleepStateNotifierProvider auto-reacts to sleepEventsNotifierProvider
    // No need to invalidate it separately (and doing so would cause extra rebuilds)
    
    ref.invalidate(caregiverContextProvider);
    dbg('[SyncProvider][H3-DEBUG] Invalidated: caregiverContextProvider');
    
    dbg('[SyncProvider][H3-DEBUG] ===== REFRESH COMPLETE =====');
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

/// Provider for pending sync count for active baby
/// 
/// FIX P5: Used to show badge on sync icon in UI
@riverpod
class PendingSyncCount extends _$PendingSyncCount {
  @override
  Future<int> build() async {
    final activeBaby = ref.watch(activeBabyProvider);
    if (activeBaby == null) return 0;
    
    final localDataSource = SleepEventLocalDataSourceImpl();
    final result = await localDataSource.getUnsyncedEvents(activeBaby.id);
    return result.isSuccess ? (result.dataOrNull?.length ?? 0) : 0;
  }
}
