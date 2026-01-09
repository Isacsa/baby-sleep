import 'package:temp_flutter/core/types/result.dart';
import 'package:temp_flutter/core/errors/failures.dart';
import 'package:temp_flutter/data/models/caregiver_model.dart';

/// Local data source for caregivers
/// 
/// Handles local persistence of caregivers
/// Used for offline-first access
/// 
/// LAYERED SYNC: Caregivers are synced AFTER babies, BEFORE events.
/// This ensures FK integrity in the backend:
/// - Baby must exist before Caregiver can be created
/// - Caregiver must exist before SleepEvent can reference it
abstract class CaregiverLocalDataSource {
  /// Gets all caregivers for a baby from local storage
  Future<Result<List<CaregiverModel>, Failure>> getCaregiversForBaby(String babyId);

  /// Gets caregiver by ID from local storage
  Future<Result<CaregiverModel?, Failure>> getCaregiverById(String caregiverId);

  /// Saves caregiver to local storage
  Future<Result<void, Failure>> saveCaregiver(CaregiverModel caregiver);

  /// Saves multiple caregivers to local storage
  Future<Result<void, Failure>> saveCaregivers(List<CaregiverModel> caregivers);

  /// Deletes caregiver from local storage
  Future<Result<void, Failure>> deleteCaregiver(String caregiverId);

  /// Gets caregiver by user ID for a specific baby
  /// 
  /// Used for idempotency check before creating caregiver
  /// Returns null if no caregiver exists for this (userId, babyId) pair
  Future<Result<CaregiverModel?, Failure>> getCaregiverByUserIdForBaby({
    required String userId,
    required String babyId,
  });

  // ========== SYNC METHODS (Layered Sync) ==========

  /// Gets caregivers that have not been synced to remote
  /// 
  /// Returns caregivers where synced_at IS NULL
  /// Used by LayeredSyncOrchestrator to push caregivers AFTER babies
  Future<Result<List<CaregiverModel>, Failure>> getUnsyncedCaregivers();

  /// Gets unsynced caregivers for babies that ARE synced
  /// 
  /// Only returns caregivers where:
  /// - caregiver.synced_at IS NULL
  /// - AND baby.synced_at IS NOT NULL (baby exists remotely)
  /// 
  /// This ensures we only try to push caregivers when their baby exists
  Future<Result<List<CaregiverModel>, Failure>> getUnsyncedCaregiversForSyncedBabies();

  /// Marks a caregiver as synced after successful push to remote
  /// 
  /// [caregiverId] - The caregiver ID
  /// [syncedAt] - Timestamp of successful sync
  Future<Result<void, Failure>> markCaregiverSynced(String caregiverId, DateTime syncedAt);

  /// Checks if a caregiver exists remotely (synced_at is not null)
  /// 
  /// [caregiverId] - The caregiver ID to check
  /// Returns true if caregiver has been synced to remote
  Future<Result<bool, Failure>> isCaregiverSynced(String caregiverId);
}

