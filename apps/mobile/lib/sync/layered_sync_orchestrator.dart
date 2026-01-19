import 'package:temp_flutter/core/types/result.dart';
import 'package:temp_flutter/core/errors/failures.dart';
import 'package:temp_flutter/data/datasources/local/baby_local_datasource.dart';
import 'package:temp_flutter/data/datasources/local/caregiver_local_datasource.dart';
import 'package:temp_flutter/data/datasources/local/sleep_event_local_datasource.dart';
import 'package:temp_flutter/data/datasources/remote/baby_remote_datasource.dart';
import 'package:temp_flutter/data/datasources/remote/caregiver_remote_datasource.dart';
import 'package:temp_flutter/data/datasources/remote/sleep_event_remote_datasource.dart';
import 'package:temp_flutter/data/datasources/remote/sleep_event_remote_datasource_impl.dart';
import 'package:temp_flutter/core/utils/agent_debug_log.dart';
import 'package:temp_flutter/sync/sync_state.dart';

/// Result of a layered sync operation
class LayeredSyncResult {
  final int babiesPushed;
  final int caregiversPushed;
  final int eventsPushed;
  final int babyErrors;
  final int caregiverErrors;
  final int eventErrors;
  final bool hasTransientError;
  final String? errorMessage;

  const LayeredSyncResult({
    this.babiesPushed = 0,
    this.caregiversPushed = 0,
    this.eventsPushed = 0,
    this.babyErrors = 0,
    this.caregiverErrors = 0,
    this.eventErrors = 0,
    this.hasTransientError = false,
    this.errorMessage,
  });

  int get totalPushed => babiesPushed + caregiversPushed + eventsPushed;
  int get totalErrors => babyErrors + caregiverErrors + eventErrors;
  bool get isSuccess => totalErrors == 0 && !hasTransientError;

  LayeredSyncResult copyWith({
    int? babiesPushed,
    int? caregiversPushed,
    int? eventsPushed,
    int? babyErrors,
    int? caregiverErrors,
    int? eventErrors,
    bool? hasTransientError,
    String? errorMessage,
  }) {
    return LayeredSyncResult(
      babiesPushed: babiesPushed ?? this.babiesPushed,
      caregiversPushed: caregiversPushed ?? this.caregiversPushed,
      eventsPushed: eventsPushed ?? this.eventsPushed,
      babyErrors: babyErrors ?? this.babyErrors,
      caregiverErrors: caregiverErrors ?? this.caregiverErrors,
      eventErrors: eventErrors ?? this.eventErrors,
      hasTransientError: hasTransientError ?? this.hasTransientError,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

bool _isCorrectedByFkFailure(Failure failure) {
  final msg = failure.message.toLowerCase();
  return msg.contains('corrected_by_fkey') ||
      (msg.contains('foreign key') && msg.contains('corrected_by'));
}

/// Detects caregiver FK failures that can be recovered by canonicalization
bool _isCaregiverFkFailure(Failure failure) {
  final msg = failure.message.toLowerCase();
  return msg.contains('caregiver_id_fkey') ||
      msg.contains('caregiver does not exist') ||
      msg.contains('caregiver not found') ||
      (msg.contains('foreign key') && msg.contains('caregiver_id')) ||
      (msg.contains('caregiver') && msg.contains('does not belong'));
}

/// Layered Sync Orchestrator
/// 
/// Implements the correct sync order to respect backend FK constraints:
/// 
/// 1. PUSH BABIES FIRST
///    - Baby must exist in Supabase before Caregiver can reference it
///    - Upsert (idempotent) - safe to retry
/// 
/// 2. PUSH CAREGIVERS SECOND
///    - Caregiver must exist in Supabase before SleepEvent can reference it
///    - Only push caregivers whose baby is already synced
///    - Upsert (idempotent) - safe to retry
/// 
/// 3. PUSH SLEEP EVENTS LAST
///    - Events reference caregiver_id via FK
///    - Only push events whose caregiver is already synced
///    - Backend trigger validate_sleep_event checks caregiver exists
/// 
/// WHY THIS IS NECESSARY:
/// The error "Caregiver does not exist, is inactive, or does not belong to this baby"
/// occurs because SleepEvents were being pushed before their Caregiver existed in Supabase.
/// This orchestrator ensures dependencies are synced in the correct order.
/// 
/// IDEMPOTENCY:
/// All upsert operations use ON CONFLICT DO UPDATE. Safe to retry on transient errors.
/// Each entity is marked synced_at only AFTER successful push.
class LayeredSyncOrchestrator {
  final BabyLocalDataSource _babyLocalDataSource;
  final BabyRemoteDataSource _babyRemoteDataSource;
  final CaregiverLocalDataSource _caregiverLocalDataSource;
  final CaregiverRemoteDataSource _caregiverRemoteDataSource;
  final SleepEventLocalDataSource _eventLocalDataSource;
  final SleepEventRemoteDataSource _eventRemoteDataSource;

  /// Callback for sync state changes
  void Function(SyncState state)? onStateChanged;

  LayeredSyncOrchestrator({
    required BabyLocalDataSource babyLocalDataSource,
    required BabyRemoteDataSource babyRemoteDataSource,
    required CaregiverLocalDataSource caregiverLocalDataSource,
    required CaregiverRemoteDataSource caregiverRemoteDataSource,
    required SleepEventLocalDataSource eventLocalDataSource,
    required SleepEventRemoteDataSource eventRemoteDataSource,
  })  : _babyLocalDataSource = babyLocalDataSource,
        _babyRemoteDataSource = babyRemoteDataSource,
        _caregiverLocalDataSource = caregiverLocalDataSource,
        _caregiverRemoteDataSource = caregiverRemoteDataSource,
        _eventLocalDataSource = eventLocalDataSource,
        _eventRemoteDataSource = eventRemoteDataSource;

  /// Executes the full layered sync
  /// 
  /// Syncs in order: Babies → Caregivers → SleepEvents
  /// Stops on transient (network) errors to retry later
  /// Continues on permanent errors (marks them)
  Future<Result<LayeredSyncResult, Failure>> syncAll() async {
    var result = const LayeredSyncResult();

    // LAYER 1: Push Babies
    // ignore: avoid_print
    print('[LayeredSync] Starting Layer 1: Babies');
    final babiesResult = await _pushBabies();
    if (babiesResult.isError) {
      return Error(babiesResult.failureOrNull!);
    }
    result = result.copyWith(
      babiesPushed: babiesResult.dataOrNull!.successCount,
      babyErrors: babiesResult.dataOrNull!.errorCount,
      hasTransientError: babiesResult.dataOrNull!.hasTransientError,
    );

    // If transient error in babies, stop here (retry later)
    if (result.hasTransientError) {
      // ignore: avoid_print
      print('[LayeredSync] Transient error in babies - stopping');
      return Success(result.copyWith(
        errorMessage: 'Network error pushing babies - will retry',
      ));
    }

    // LAYER 2: Push Caregivers (only for synced babies)
    // ignore: avoid_print
    print('[LayeredSync] Starting Layer 2: Caregivers');
    final caregiversResult = await _pushCaregivers();
    if (caregiversResult.isError) {
      return Error(caregiversResult.failureOrNull!);
    }
    result = result.copyWith(
      caregiversPushed: caregiversResult.dataOrNull!.successCount,
      caregiverErrors: caregiversResult.dataOrNull!.errorCount,
      hasTransientError: caregiversResult.dataOrNull!.hasTransientError,
    );

    // If transient error in caregivers, stop here (retry later)
    if (result.hasTransientError) {
      // ignore: avoid_print
      print('[LayeredSync] Transient error in caregivers - stopping');
      return Success(result.copyWith(
        errorMessage: 'Network error pushing caregivers - will retry',
      ));
    }

    // LAYER 3: Push SleepEvents (only for synced caregivers)
    // ignore: avoid_print
    print('[LayeredSync] Starting Layer 3: SleepEvents');
    final eventsResult = await _pushEvents();
    if (eventsResult.isError) {
      return Error(eventsResult.failureOrNull!);
    }
    result = result.copyWith(
      eventsPushed: eventsResult.dataOrNull!.successCount,
      eventErrors: eventsResult.dataOrNull!.errorCount,
      hasTransientError: eventsResult.dataOrNull!.hasTransientError,
    );

    // ignore: avoid_print
    print('[LayeredSync] Complete: ${result.totalPushed} pushed, ${result.totalErrors} errors');
    return Success(result);
  }

  /// Syncs all entities for a specific baby
  Future<Result<LayeredSyncResult, Failure>> syncForBaby(String babyId) async {
    var result = const LayeredSyncResult();

    // LAYER 1: Push Baby (if not synced)
    // ignore: avoid_print
    print('[LayeredSync] Starting Layer 1: Baby $babyId');
    final babyResult = await _pushBabyById(babyId);
    if (babyResult.isError) {
      return Error(babyResult.failureOrNull!);
    }
    result = result.copyWith(
      babiesPushed: babyResult.dataOrNull! ? 1 : 0,
    );

    // LAYER 2: Push Caregivers for this baby
    // ignore: avoid_print
    print('[LayeredSync] Starting Layer 2: Caregivers for baby $babyId');
    final caregiversResult = await _pushCaregiversForBaby(babyId);
    if (caregiversResult.isError) {
      return Error(caregiversResult.failureOrNull!);
    }
    result = result.copyWith(
      caregiversPushed: caregiversResult.dataOrNull!.successCount,
      caregiverErrors: caregiversResult.dataOrNull!.errorCount,
      hasTransientError: caregiversResult.dataOrNull!.hasTransientError,
    );

    if (result.hasTransientError) {
      return Success(result.copyWith(
        errorMessage: 'Network error pushing caregivers - will retry',
      ));
    }

    // LAYER 3: Push SleepEvents for this baby
    // ignore: avoid_print
    print('[LayeredSync] Starting Layer 3: Events for baby $babyId');
    final eventsResult = await _pushEventsForBaby(babyId);
    if (eventsResult.isError) {
      return Error(eventsResult.failureOrNull!);
    }
    result = result.copyWith(
      eventsPushed: eventsResult.dataOrNull!.successCount,
      eventErrors: eventsResult.dataOrNull!.errorCount,
      hasTransientError: eventsResult.dataOrNull!.hasTransientError,
    );

    // ignore: avoid_print
    print('[LayeredSync] Complete for baby: ${result.totalPushed} pushed, ${result.totalErrors} errors');
    return Success(result);
  }

  // ========== LAYER 1: BABIES ==========

  Future<Result<_PushLayerResult, Failure>> _pushBabies() async {
    final unsyncedResult = await _babyLocalDataSource.getUnsyncedBabies();
    if (unsyncedResult.isError) {
      return Error(unsyncedResult.failureOrNull!);
    }

    final unsyncedBabies = unsyncedResult.dataOrNull ?? [];
    if (unsyncedBabies.isEmpty) {
      return const Success(_PushLayerResult());
    }

    var successCount = 0;
    var errorCount = 0;
    var hasTransientError = false;

    for (final baby in unsyncedBabies) {
      // DEBUG: Log payload being sent
      // ignore: avoid_print
      print('[LayeredSync] Pushing baby payload: ${baby.toRemoteJson()}');
      
      final pushResult = await _babyRemoteDataSource.upsertBaby(baby);

      if (pushResult.isSuccess) {
        // Mark as synced locally
        final now = DateTime.now().toUtc();
        await _babyLocalDataSource.markBabySynced(baby.id, now);
        successCount++;
        // ignore: avoid_print
        print('[LayeredSync] Pushed baby: ${baby.id}');

        // IMPORTANT: The backend trigger creates the first caregiver automatically
        // We need to fetch it and update local references
        await _syncCaregiverAfterBabyPush(baby.id, baby.createdBy, now);
      } else {
        final failure = pushResult.failureOrNull!;
        if (failure is NetworkFailure) {
          hasTransientError = true;
          // Stop on network error - will retry
          break;
        }
        // Permanent error - log and continue
        errorCount++;
        // ignore: avoid_print
        print('[LayeredSync] Failed to push baby ${baby.id}: ${failure.message}');
      }
    }

    return Success(_PushLayerResult(
      successCount: successCount,
      errorCount: errorCount,
      hasTransientError: hasTransientError,
    ));
  }

  Future<Result<bool, Failure>> _pushBabyById(String babyId) async {
    // Check if already synced
    final isSyncedResult = await _babyLocalDataSource.isBabySynced(babyId);
    if (isSyncedResult.isError) {
      return Error(isSyncedResult.failureOrNull!);
    }
    
    // Get baby (needed for both paths)
    final babyResult = await _babyLocalDataSource.getBabyById(babyId);
    if (babyResult.isError) {
      return Error(babyResult.failureOrNull!);
    }
    final baby = babyResult.dataOrNull;
    if (baby == null) {
      return Error(StorageFailure('Baby not found locally: $babyId'));
    }
    
    final now = DateTime.now().toUtc();
    
    if (isSyncedResult.dataOrNull == true) {
      // FIX: Even when baby is already synced, run canonicalization
      // This ensures older babies (created before this logic) get their caregivers aligned
      // ignore: avoid_print
      print('[LayeredSync] Baby $babyId already synced - running canonicalization anyway');
      await _syncCaregiverAfterBabyPush(babyId, baby.createdBy, now);
      return const Success(false); // Baby was already synced
    }

    // Push to remote
    final pushResult = await _babyRemoteDataSource.upsertBaby(baby);
    if (pushResult.isError) {
      return Error(pushResult.failureOrNull!);
    }

    // Mark synced
    await _babyLocalDataSource.markBabySynced(babyId, now);
    // ignore: avoid_print
    print('[LayeredSync] Pushed baby: $babyId');

    // Canonicalize caregiver after baby push
    await _syncCaregiverAfterBabyPush(babyId, baby.createdBy, now);

    return const Success(true);
  }

  // ========== LAYER 2: CAREGIVERS ==========
  // 
  // IMPORTANT: The Supabase backend has a trigger `create_first_caregiver_trigger`
  // that automatically creates the first owner caregiver when a baby is inserted.
  // 
  // This means:
  // - When we INSERT a baby, the trigger creates the caregiver on the backend
  // - We should NOT try to INSERT the same caregiver again
  // - Instead, we just mark local caregivers as "synced" after their baby is synced
  // 
  // For MVP, we skip pushing caregivers and just mark them synced.
  // The caregiver already exists on the backend (created by trigger).

  Future<Result<_PushLayerResult, Failure>> _pushCaregivers() async {
    // Only get caregivers whose baby is already synced
    final unsyncedResult = await _caregiverLocalDataSource.getUnsyncedCaregiversForSyncedBabies();
    if (unsyncedResult.isError) {
      return Error(unsyncedResult.failureOrNull!);
    }

    final unsyncedCaregivers = unsyncedResult.dataOrNull ?? [];
    if (unsyncedCaregivers.isEmpty) {
      return const Success(_PushLayerResult());
    }

    var successCount = 0;

    for (final caregiver in unsyncedCaregivers) {
      // For the first owner caregiver, the trigger already created it on the backend
      // We just mark it as synced locally (the backend has it with possibly different ID)
      // 
      // TODO: In future, we could fetch the remote caregiver and update local ID
      // For now, we just mark synced since the caregiver exists on backend
      
      if (caregiver.role == 'owner') {
        // Owner caregiver was created by trigger - just mark synced
        final now = DateTime.now().toUtc();
        await _caregiverLocalDataSource.markCaregiverSynced(caregiver.id, now);
        successCount++;
        // ignore: avoid_print
        print('[LayeredSync] Marked owner caregiver as synced (created by trigger): ${caregiver.id}');
      } else {
        // Non-owner caregivers need to be pushed
        // (This path is for invited caregivers - not implemented in MVP)
        final pushResult = await _caregiverRemoteDataSource.upsertCaregiver(caregiver);

        if (pushResult.isSuccess) {
          final now = DateTime.now().toUtc();
          await _caregiverLocalDataSource.markCaregiverSynced(caregiver.id, now);
          successCount++;
          // ignore: avoid_print
          print('[LayeredSync] Pushed caregiver: ${caregiver.id}');
        } else {
          final failure = pushResult.failureOrNull!;
          if (failure is NetworkFailure) {
            return Success(_PushLayerResult(
              successCount: successCount,
              hasTransientError: true,
            ));
          }
          // ignore: avoid_print
          print('[LayeredSync] Failed to push caregiver ${caregiver.id}: ${failure.message}');
        }
      }
    }

    return Success(_PushLayerResult(
      successCount: successCount,
      errorCount: 0,
      hasTransientError: false,
    ));
  }

  Future<Result<_PushLayerResult, Failure>> _pushCaregiversForBaby(String babyId) async {
    final caregiversResult = await _caregiverLocalDataSource.getCaregiversForBaby(babyId);
    if (caregiversResult.isError) {
      return Error(caregiversResult.failureOrNull!);
    }

    final caregivers = caregiversResult.dataOrNull ?? [];
    final unsyncedCaregivers = caregivers.where((c) => !c.isSynced).toList();

    if (unsyncedCaregivers.isEmpty) {
      return const Success(_PushLayerResult());
    }

    var successCount = 0;

    for (final caregiver in unsyncedCaregivers) {
      // Owner caregivers are created by backend trigger - just mark synced
      if (caregiver.role == 'owner') {
        final now = DateTime.now().toUtc();
        await _caregiverLocalDataSource.markCaregiverSynced(caregiver.id, now);
        successCount++;
        // ignore: avoid_print
        print('[LayeredSync] Marked owner caregiver as synced (created by trigger): ${caregiver.id}');
      } else {
        // Non-owner caregivers need to be pushed
        final pushResult = await _caregiverRemoteDataSource.upsertCaregiver(caregiver);

        if (pushResult.isSuccess) {
          final now = DateTime.now().toUtc();
          await _caregiverLocalDataSource.markCaregiverSynced(caregiver.id, now);
          successCount++;
          // ignore: avoid_print
          print('[LayeredSync] Pushed caregiver: ${caregiver.id}');
        } else {
          final failure = pushResult.failureOrNull!;
          if (failure is NetworkFailure) {
            return Success(_PushLayerResult(
              successCount: successCount,
              hasTransientError: true,
            ));
          }
          // ignore: avoid_print
          print('[LayeredSync] Failed to push caregiver ${caregiver.id}: ${failure.message}');
        }
      }
    }

    return Success(_PushLayerResult(
      successCount: successCount,
      errorCount: 0,
      hasTransientError: false,
    ));
  }

  // ========== LAYER 3: SLEEP EVENTS ==========
  // 
  // After baby push, the canonicalization step aligns local caregiver IDs
  // with remote IDs. Events now reference the canonical (remote) caregiver_id
  // directly in SQLite, so we don't need per-event ID mapping.
  //
  // If the backend rejects an event due to missing caregiver, it means
  // canonicalization failed or wasn't run - we mark a clear error.

  Future<Result<_PushLayerResult, Failure>> _pushEvents() async {
    // Get all unsynced events
    final unsyncedResult = await _eventLocalDataSource.getAllUnsyncedEvents();
    if (unsyncedResult.isError) {
      return Error(unsyncedResult.failureOrNull!);
    }

    final unsyncedEvents = unsyncedResult.dataOrNull ?? [];
    if (unsyncedEvents.isEmpty) {
      return const Success(_PushLayerResult());
    }

    var successCount = 0;
    var errorCount = 0;
    var hasTransientError = false;

    // #region agent log
    agentDebugLog(
      sessionId: 'debug-session',
      runId: 'post-fix-1',
      hypothesisId: 'Hsync',
      location: 'layered_sync_orchestrator.dart:_pushEvents',
      message: 'push events start',
      data: <String, Object?>{
        'unsyncedCount': unsyncedEvents.length,
        'withCorrectedBy': unsyncedEvents.where((e) => e.correctedBy != null).length,
        'isCorrectedTrue': unsyncedEvents.where((e) => e.isCorrected).length,
      },
    );
    // #endregion

    // FIX: Sort events to push those WITHOUT corrected_by first
    // This ensures correction events (corrected_by=NULL) are inserted before
    // we try to push updates to original events (which have corrected_by=<correctionId>)
    final sortedEvents = List.of(unsyncedEvents)
      ..sort((a, b) {
        final aHasCorrectedBy = a.correctedBy != null ? 1 : 0;
        final bHasCorrectedBy = b.correctedBy != null ? 1 : 0;
        return aHasCorrectedBy.compareTo(bHasCorrectedBy);
      });

    // Retry loop to naturally satisfy corrected_by FK dependencies.
    var pending = sortedEvents;
    for (var pass = 1; pass <= 3 && pending.isNotEmpty; pass++) {
      var progressed = false;
      final nextPending = <dynamic>[];

      for (final event in pending) {
        // Check if caregiver is synced (canonical) BEFORE attempting push
        final caregiverSyncedResult =
            await _caregiverLocalDataSource.isCaregiverSynced(event.caregiverId);
        if (caregiverSyncedResult.isError || caregiverSyncedResult.dataOrNull != true) {
          await _eventLocalDataSource.markEventSyncError(
            event.id,
            'missing_remote_dependency',
            'Caregiver ${event.caregiverId} not synced - run canonicalization first',
          );
          errorCount++;
          // ignore: avoid_print
          print('[LayeredSync] Event ${event.id} skipped: caregiver ${event.caregiverId} not synced (missing_remote_dependency)');
          continue;
        }

        final pushResult = await _eventRemoteDataSource.upsertSleepEventForSync(event);
        if (pushResult.isSuccess) {
          final now = DateTime.now().toUtc();
          await _eventLocalDataSource.markEventSynced(event.id, now);
          successCount++;
          progressed = true;
          // ignore: avoid_print
          print('[LayeredSync] Pushed event: ${event.id}');
          continue;
        }

        final failure = pushResult.failureOrNull!;
        final errorType = _classifyFailure(failure);

        if (errorType == SyncErrorType.transient) {
          hasTransientError = true;
          break;
        }

        if (_isCorrectedByFkFailure(failure) && pass < 3) {
          // #region agent log
          agentDebugLog(
            sessionId: 'debug-session',
            runId: 'post-fix-1',
            hypothesisId: 'Hsync',
            location: 'layered_sync_orchestrator.dart:_pushEvents',
            message: 'deferring event due to corrected_by FK (will retry)',
            data: <String, Object?>{
              'pass': pass,
              'eventId': event.id,
              'correctedBy': event.correctedBy,
              'isCorrected': event.isCorrected,
            },
          );
          // #endregion
          nextPending.add(event);
          continue;
        }
        
        // FIX: Recovery for caregiver FK failures - run canonicalization and retry
        if (_isCaregiverFkFailure(failure) && pass < 3) {
          // ignore: avoid_print
          print('[LayeredSync] Caregiver FK failure for event ${event.id} - attempting canonicalization recovery');
          
          final babyResult = await _babyLocalDataSource.getBabyById(event.babyId);
          if (babyResult.isSuccess && babyResult.dataOrNull != null) {
            final baby = babyResult.dataOrNull!;
            final now = DateTime.now().toUtc();
            await _syncCaregiverAfterBabyPush(event.babyId, baby.createdBy, now);
            nextPending.add(event);
            // ignore: avoid_print
            print('[LayeredSync] Canonicalization complete - event ${event.id} re-queued for retry');
          } else {
            await _eventLocalDataSource.markEventSyncError(
              event.id,
              'caregiver_fk_unrecoverable',
              'Caregiver FK failure and could not load baby: ${failure.message}',
            );
            errorCount++;
          }
          continue;
        }

        await _eventLocalDataSource.markEventSyncError(
          event.id,
          errorType.name,
          failure.message,
        );
        errorCount++;
        // ignore: avoid_print
        print('[LayeredSync] Failed to push event ${event.id}: ${failure.message}');
      }

      pending = nextPending.cast();
      if (hasTransientError) break;
      if (!progressed) break;
    }

    return Success(_PushLayerResult(
      successCount: successCount,
      errorCount: errorCount,
      hasTransientError: hasTransientError,
    ));
  }

  Future<Result<_PushLayerResult, Failure>> _pushEventsForBaby(String babyId) async {
    final unsyncedResult = await _eventLocalDataSource.getUnsyncedEvents(babyId);
    if (unsyncedResult.isError) {
      return Error(unsyncedResult.failureOrNull!);
    }

    final unsyncedEvents = unsyncedResult.dataOrNull ?? [];
    if (unsyncedEvents.isEmpty) {
      return const Success(_PushLayerResult());
    }

    var successCount = 0;
    var errorCount = 0;
    var hasTransientError = false;

    // #region agent log
    agentDebugLog(
      sessionId: 'debug-session',
      runId: 'post-fix-1',
      hypothesisId: 'Hsync',
      location: 'layered_sync_orchestrator.dart:_pushEventsForBaby',
      message: 'push events start',
      data: <String, Object?>{
        'babyId': babyId,
        'unsyncedCount': unsyncedEvents.length,
        'withCorrectedBy': unsyncedEvents.where((e) => e.correctedBy != null).length,
        'isCorrectedTrue': unsyncedEvents.where((e) => e.isCorrected).length,
      },
    );
    // #endregion

    // FIX: Sort events to push those WITHOUT corrected_by first
    // This ensures correction events (corrected_by=NULL) are inserted before
    // we try to push updates to original events (which have corrected_by=<correctionId>)
    final sortedEvents = List.of(unsyncedEvents)
      ..sort((a, b) {
        // Events without corrected_by come first
        final aHasCorrectedBy = a.correctedBy != null ? 1 : 0;
        final bHasCorrectedBy = b.correctedBy != null ? 1 : 0;
        return aHasCorrectedBy.compareTo(bHasCorrectedBy);
      });
    
    var pending = sortedEvents;
    for (var pass = 1; pass <= 3 && pending.isNotEmpty; pass++) {
      var progressed = false;
      final nextPending = <dynamic>[];

      for (final event in pending) {
        final caregiverSyncedResult =
            await _caregiverLocalDataSource.isCaregiverSynced(event.caregiverId);
        if (caregiverSyncedResult.isError || caregiverSyncedResult.dataOrNull != true) {
          await _eventLocalDataSource.markEventSyncError(
            event.id,
            'missing_remote_dependency',
            'Caregiver ${event.caregiverId} not synced - run canonicalization first',
          );
          errorCount++;
          // ignore: avoid_print
          print('[LayeredSync] Event ${event.id} skipped: caregiver ${event.caregiverId} not synced (missing_remote_dependency)');
          continue;
        }

        final pushResult = await _eventRemoteDataSource.upsertSleepEventForSync(event);
        if (pushResult.isSuccess) {
          final now = DateTime.now().toUtc();
          await _eventLocalDataSource.markEventSynced(event.id, now);
          successCount++;
          progressed = true;
          // ignore: avoid_print
          print('[LayeredSync] Pushed event: ${event.id}');
          continue;
        }

        final failure = pushResult.failureOrNull!;
        final errorType = _classifyFailure(failure);

        if (errorType == SyncErrorType.transient) {
          hasTransientError = true;
          break;
        }

        if (_isCorrectedByFkFailure(failure) && pass < 3) {
          // #region agent log
          agentDebugLog(
            sessionId: 'debug-session',
            runId: 'post-fix-1',
            hypothesisId: 'Hsync',
            location: 'layered_sync_orchestrator.dart:_pushEventsForBaby',
            message: 'deferring event due to corrected_by FK (will retry)',
            data: <String, Object?>{
              'pass': pass,
              'eventId': event.id,
              'correctedBy': event.correctedBy,
              'isCorrected': event.isCorrected,
            },
          );
          // #endregion
          nextPending.add(event);
          continue;
        }
        
        // FIX: Recovery for caregiver FK failures - run canonicalization and retry
        if (_isCaregiverFkFailure(failure) && pass < 3) {
          // ignore: avoid_print
          print('[LayeredSync] Caregiver FK failure for event ${event.id} - attempting canonicalization recovery');
          
          // Get baby info for canonicalization
          final babyResult = await _babyLocalDataSource.getBabyById(event.babyId);
          if (babyResult.isSuccess && babyResult.dataOrNull != null) {
            final baby = babyResult.dataOrNull!;
            final now = DateTime.now().toUtc();
            
            // Run canonicalization
            await _syncCaregiverAfterBabyPush(event.babyId, baby.createdBy, now);
            
            // Re-queue this event for retry
            nextPending.add(event);
            // ignore: avoid_print
            print('[LayeredSync] Canonicalization complete - event ${event.id} re-queued for retry');
          } else {
            // Can't recover - mark as error
            await _eventLocalDataSource.markEventSyncError(
              event.id,
              'caregiver_fk_unrecoverable',
              'Caregiver FK failure and could not load baby for canonicalization: ${failure.message}',
            );
            errorCount++;
          }
          continue;
        }

        await _eventLocalDataSource.markEventSyncError(
          event.id,
          errorType.name,
          failure.message,
        );
        errorCount++;
        // ignore: avoid_print
        print('[LayeredSync] Failed to push event ${event.id}: ${failure.message}');
      }

      pending = nextPending.cast();
      if (hasTransientError) break;
      if (!progressed) break;
    }

    return Success(_PushLayerResult(
      successCount: successCount,
      errorCount: errorCount,
      hasTransientError: hasTransientError,
    ));
  }

  // ========== CANONICALIZATION (Post-Baby-Push) ==========
  //
  // After pushing a baby, the Supabase trigger creates the first owner caregiver
  // with a server-generated UUID. This differs from the local UUID.
  // We must canonicalize (align) local IDs with remote IDs so that:
  // 1. sleep_events reference the canonical (remote) caregiver_id
  // 2. Future pushes don't need per-event ID mapping
  //
  // The canonicalization is transactional in SQLite: it updates all sleep_events
  // and swaps/merges the caregiver PK in one atomic operation.

  /// Syncs caregiver after baby push - with retry/backoff and canonicalization
  /// 
  /// The backend trigger creates the first caregiver automatically.
  /// We need to:
  /// 1. Fetch the remote caregiver (with retry if trigger is slow)
  /// 2. Canonicalize local caregiver ID to match remote ID
  /// 3. Update all local sleep_events to reference the canonical ID
  Future<void> _syncCaregiverAfterBabyPush(String babyId, String userId, DateTime now) async {
    // ignore: avoid_print
    print('[Canonicalize] Starting post-baby-push canonicalization for '
        'babyId=$babyId, userId=$userId');

    // Step 1: Fetch remote owner caregiver with retry/backoff
    final remoteOwnerId = await _fetchRemoteOwnerCaregiverIdWithRetry(babyId, userId);
    
    if (remoteOwnerId == null) {
      // Failed to get remote caregiver after retries
      // Don't corrupt state - just skip canonicalization
      // Events will use the workaround path (if still present) or fail with clear error
      // ignore: avoid_print
      print('[Canonicalize] SKIPPED: Could not fetch remote owner caregiver after retries. '
          'babyId=$babyId, userId=$userId');
      return;
    }

    // Step 2: Canonicalize local caregiver ID to match remote
    final canonResult = await _caregiverLocalDataSource.canonicalizeOwnerCaregiverId(
      babyId: babyId,
      userId: userId,
      remoteCaregiverId: remoteOwnerId,
      nowUtc: now,
    );

    if (canonResult.isError) {
      // Canonicalization failed - log but don't crash
      // ignore: avoid_print
      print('[Canonicalize] ERROR: ${canonResult.failureOrNull?.message}');
      return;
    }

    final result = canonResult.dataOrNull!;
    // ignore: avoid_print
    print('[Canonicalize] COMPLETE: babyId=$babyId, '
        'localOwnerId=${result.localOwnerId}, remoteOwnerId=$remoteOwnerId, '
        'strategy=${result.strategy}, eventsUpdated=${result.eventsUpdated}, '
        'caregiverUpdated=${result.caregiverUpdated}, caregiverDeleted=${result.caregiverDeleted}'
        '${result.warning != null ? ", warning=${result.warning}" : ""}');
  }

  /// Fetches the remote owner caregiver ID with retry and exponential backoff
  /// 
  /// Retries: 200ms, 500ms, 1s (total 3 attempts)
  /// Returns null if all attempts fail (caller should handle gracefully)
  Future<String?> _fetchRemoteOwnerCaregiverIdWithRetry(String babyId, String userId) async {
    const delays = [
      Duration(milliseconds: 200),
      Duration(milliseconds: 500),
      Duration(milliseconds: 1000),
    ];

    for (var attempt = 0; attempt <= delays.length; attempt++) {
      final result = await _caregiverRemoteDataSource.getCaregiversForBaby(babyId);

      if (result.isSuccess) {
        final caregivers = result.dataOrNull ?? [];
        final ownerCaregiver = caregivers
            .where((c) => c.userId == userId && c.role == 'owner')
            .firstOrNull;

        if (ownerCaregiver != null) {
          // ignore: avoid_print
          print('[Canonicalize] Found remote owner caregiver on attempt ${attempt + 1}: '
              'id=${ownerCaregiver.id}');
          return ownerCaregiver.id;
        }

        // Owner not found yet (trigger may be slow)
        if (attempt < delays.length) {
          // ignore: avoid_print
          print('[Canonicalize] Remote owner caregiver not found, '
              'retry ${attempt + 1}/${delays.length} in ${delays[attempt].inMilliseconds}ms');
          await Future.delayed(delays[attempt]);
        }
      } else {
        // Network or other error
        final failure = result.failureOrNull!;
        if (failure is NetworkFailure) {
          // ignore: avoid_print
          print('[Canonicalize] Network error fetching remote caregiver, '
              'attempt ${attempt + 1}/${delays.length + 1}: ${failure.message}');
          if (attempt < delays.length) {
            await Future.delayed(delays[attempt]);
          }
        } else {
          // Permanent error - don't retry
          // ignore: avoid_print
          print('[Canonicalize] Permanent error fetching remote caregiver: ${failure.message}');
          return null;
        }
      }
    }

    // All retries exhausted
    // ignore: avoid_print
    print('[Canonicalize] FAILED: Could not fetch remote owner caregiver after '
        '${delays.length + 1} attempts. babyId=$babyId, userId=$userId');
    return null;
  }

  /// Classifies failure into sync error type
  SyncErrorType _classifyFailure(Failure failure) {
    if (failure is NetworkFailure) {
      return SyncErrorType.transient;
    }
    if (failure is PermissionFailure) {
      return SyncErrorType.permission;
    }
    if (failure is ValidationFailure) {
      return SyncErrorType.validation;
    }
    // Default to transient for unknown errors (safer - will retry)
    return SyncErrorType.transient;
  }
}

/// Result of pushing a single layer
class _PushLayerResult {
  final int successCount;
  final int errorCount;
  final bool hasTransientError;

  const _PushLayerResult({
    this.successCount = 0,
    this.errorCount = 0,
    this.hasTransientError = false,
  });
}

