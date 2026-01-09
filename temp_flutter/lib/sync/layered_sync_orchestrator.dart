import 'package:temp_flutter/core/types/result.dart';
import 'package:temp_flutter/core/errors/failures.dart';
import 'package:temp_flutter/data/datasources/local/baby_local_datasource.dart';
import 'package:temp_flutter/data/datasources/local/caregiver_local_datasource.dart';
import 'package:temp_flutter/data/datasources/local/sleep_event_local_datasource.dart';
import 'package:temp_flutter/data/datasources/remote/baby_remote_datasource.dart';
import 'package:temp_flutter/data/datasources/remote/caregiver_remote_datasource.dart';
import 'package:temp_flutter/data/datasources/remote/sleep_event_remote_datasource.dart';
import 'package:temp_flutter/data/datasources/remote/sleep_event_remote_datasource_impl.dart';
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
    if (isSyncedResult.dataOrNull == true) {
      return const Success(false); // Already synced
    }

    // Get baby
    final babyResult = await _babyLocalDataSource.getBabyById(babyId);
    if (babyResult.isError) {
      return Error(babyResult.failureOrNull!);
    }
    final baby = babyResult.dataOrNull;
    if (baby == null) {
      return Error(StorageFailure('Baby not found locally: $babyId'));
    }

    // Push to remote
    final pushResult = await _babyRemoteDataSource.upsertBaby(baby);
    if (pushResult.isError) {
      return Error(pushResult.failureOrNull!);
    }

    // Mark synced
    final now = DateTime.now().toUtc();
    await _babyLocalDataSource.markBabySynced(babyId, now);
    // ignore: avoid_print
    print('[LayeredSync] Pushed baby: $babyId');

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
  // IMPORTANT: The local caregiver ID differs from the remote one because
  // the backend trigger creates the caregiver with its own UUID.
  // We need to fetch the remote caregiver ID and use it when pushing events.

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

    // Cache remote caregiver IDs to avoid repeated API calls
    // Map: "babyId:userId" -> remoteCaregiverId
    final remoteCaregiverCache = <String, String>{};

    var successCount = 0;
    var errorCount = 0;
    var hasTransientError = false;

    for (final event in unsyncedEvents) {
      // Check if caregiver is synced BEFORE attempting push
      final caregiverSyncedResult = await _caregiverLocalDataSource.isCaregiverSynced(event.caregiverId);
      if (caregiverSyncedResult.isError || caregiverSyncedResult.dataOrNull != true) {
        // ignore: avoid_print
        print('[LayeredSync] Skipping event ${event.id} - caregiver ${event.caregiverId} not synced');
        continue;
      }

      // Get the local caregiver to find the userId
      final localCaregiverResult = await _caregiverLocalDataSource.getCaregiverById(event.caregiverId);
      if (localCaregiverResult.isError || localCaregiverResult.dataOrNull == null) {
        // ignore: avoid_print
        print('[LayeredSync] Skipping event ${event.id} - cannot find local caregiver');
        continue;
      }
      final localCaregiver = localCaregiverResult.dataOrNull!;

      // Get remote caregiver ID (use cache if available)
      final cacheKey = '${event.babyId}:${localCaregiver.userId}';
      String? remoteCaregiverId = remoteCaregiverCache[cacheKey];
      
      if (remoteCaregiverId == null) {
        remoteCaregiverId = await _getRemoteCaregiverId(event.babyId, localCaregiver.userId);
        if (remoteCaregiverId != null) {
          remoteCaregiverCache[cacheKey] = remoteCaregiverId;
        }
      }

      if (remoteCaregiverId == null) {
        // ignore: avoid_print
        print('[LayeredSync] Skipping event ${event.id} - cannot find remote caregiver for user ${localCaregiver.userId}');
        continue;
      }

      // Create event with remote caregiver ID
      final eventToSync = event.copyWithCaregiverId(remoteCaregiverId);
      // ignore: avoid_print
      print('[LayeredSync] Pushing event with remote caregiver ID: ${event.caregiverId} -> $remoteCaregiverId');

      final pushResult = await _eventRemoteDataSource.createSleepEvent(eventToSync);

      if (pushResult.isSuccess) {
        final now = DateTime.now().toUtc();
        await _eventLocalDataSource.markEventSynced(event.id, now);
        successCount++;
        // ignore: avoid_print
        print('[LayeredSync] Pushed event: ${event.id}');
      } else {
        final failure = pushResult.failureOrNull!;
        
        // Classify error
        final errorType = _classifyFailure(failure);
        
        if (errorType == SyncErrorType.transient) {
          hasTransientError = true;
          break;
        }
        
        // Permanent error - mark in metadata
        await _eventLocalDataSource.markEventSyncError(
          event.id,
          errorType.name,
          failure.message,
        );
        errorCount++;
        // ignore: avoid_print
        print('[LayeredSync] Failed to push event ${event.id}: ${failure.message}');
      }
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

    // Cache remote caregiver IDs
    final remoteCaregiverCache = <String, String>{};

    var successCount = 0;
    var errorCount = 0;
    var hasTransientError = false;

    for (final event in unsyncedEvents) {
      // Check if caregiver is synced
      final caregiverSyncedResult = await _caregiverLocalDataSource.isCaregiverSynced(event.caregiverId);
      if (caregiverSyncedResult.isError || caregiverSyncedResult.dataOrNull != true) {
        // ignore: avoid_print
        print('[LayeredSync] Skipping event ${event.id} - caregiver ${event.caregiverId} not synced');
        continue;
      }

      // Get the local caregiver to find the userId
      final localCaregiverResult = await _caregiverLocalDataSource.getCaregiverById(event.caregiverId);
      if (localCaregiverResult.isError || localCaregiverResult.dataOrNull == null) {
        // ignore: avoid_print
        print('[LayeredSync] Skipping event ${event.id} - cannot find local caregiver');
        continue;
      }
      final localCaregiver = localCaregiverResult.dataOrNull!;

      // Get remote caregiver ID (use cache if available)
      final cacheKey = '${event.babyId}:${localCaregiver.userId}';
      String? remoteCaregiverId = remoteCaregiverCache[cacheKey];
      
      if (remoteCaregiverId == null) {
        remoteCaregiverId = await _getRemoteCaregiverId(event.babyId, localCaregiver.userId);
        if (remoteCaregiverId != null) {
          remoteCaregiverCache[cacheKey] = remoteCaregiverId;
        }
      }

      if (remoteCaregiverId == null) {
        // ignore: avoid_print
        print('[LayeredSync] Skipping event ${event.id} - cannot find remote caregiver');
        continue;
      }

      // Create event with remote caregiver ID
      final eventToSync = event.copyWithCaregiverId(remoteCaregiverId);

      final pushResult = await _eventRemoteDataSource.createSleepEvent(eventToSync);

      if (pushResult.isSuccess) {
        final now = DateTime.now().toUtc();
        await _eventLocalDataSource.markEventSynced(event.id, now);
        successCount++;
        // ignore: avoid_print
        print('[LayeredSync] Pushed event: ${event.id}');
      } else {
        final failure = pushResult.failureOrNull!;
        final errorType = _classifyFailure(failure);
        
        if (errorType == SyncErrorType.transient) {
          hasTransientError = true;
          break;
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
    }

    return Success(_PushLayerResult(
      successCount: successCount,
      errorCount: errorCount,
      hasTransientError: hasTransientError,
    ));
  }

  /// Syncs caregiver after baby push
  /// 
  /// The backend trigger creates the first caregiver automatically.
  /// We need to:
  /// 1. Mark the local caregiver as synced
  /// 2. (Future) Could update local ID to match remote, but for MVP we just mark synced
  Future<void> _syncCaregiverAfterBabyPush(String babyId, String userId, DateTime now) async {
    // Find the local caregiver for this baby/user
    final localCaregiversResult = await _caregiverLocalDataSource.getCaregiversForBaby(babyId);
    if (localCaregiversResult.isError) {
      // ignore: avoid_print
      print('[LayeredSync] Failed to get local caregivers: ${localCaregiversResult.failureOrNull}');
      return;
    }

    final localCaregivers = localCaregiversResult.dataOrNull ?? [];
    final ownerCaregiver = localCaregivers.where((c) => c.role == 'owner' && c.userId == userId).firstOrNull;

    if (ownerCaregiver != null) {
      // Mark the local caregiver as synced
      // Note: The remote caregiver has a different ID (created by trigger)
      // For MVP, we just mark synced. The sleep event push will handle ID mapping.
      await _caregiverLocalDataSource.markCaregiverSynced(ownerCaregiver.id, now);
      // ignore: avoid_print
      print('[LayeredSync] Marked owner caregiver as synced after baby push: ${ownerCaregiver.id}');
    }
  }

  /// Gets the remote caregiver ID for a user/baby combination
  /// 
  /// This is needed because the local caregiver ID differs from the remote one
  /// (backend trigger creates caregiver with its own UUID)
  Future<String?> _getRemoteCaregiverId(String babyId, String userId) async {
    final result = await _caregiverRemoteDataSource.getCaregiversForBaby(babyId);
    if (result.isError) {
      return null;
    }
    
    final caregivers = result.dataOrNull ?? [];
    final userCaregiver = caregivers.where((c) => c.userId == userId).firstOrNull;
    return userCaregiver?.id;
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

