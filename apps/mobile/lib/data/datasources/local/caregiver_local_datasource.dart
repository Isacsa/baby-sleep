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

  // ========== PULL METHODS (Pull Active Baby Data) ==========

  /// Upserts caregivers from remote into local SQLite
  /// 
  /// Used by pullActiveBabyData() to populate SQLite with remote caregivers
  /// Returns the number of caregivers upserted (for logging)
  /// 
  /// Marks all upserted caregivers as synced (synced_at = now)
  Future<Result<CaregiverUpsertResult, Failure>> upsertCaregiversFromRemote(List<CaregiverModel> caregivers);

  // ========== CANONICALIZATION (Post-Baby-Push) ==========
  //
  // WHY: The Supabase backend trigger creates the first owner caregiver 
  // automatically when a baby is inserted, using a server-generated UUID.
  // The local SQLite has a different UUID for the same caregiver.
  // This method aligns local IDs with remote IDs so that sleep_events
  // can reference the canonical (remote) caregiver_id during push.
  //
  // IMPORTANT: Currently, only the `sleep_events` table references 
  // `caregivers.id` in the local SQLite schema. If new tables with FK 
  // to caregivers are added in the future, update canonicalizeOwnerCaregiverId
  // to include those tables in the same transaction.

  /// Canonicalizes the local owner caregiver ID to match the remote ID
  /// 
  /// This method:
  /// 1. Finds the local owner caregiver for (babyId, userId)
  /// 2. Updates all sleep_events.caregiver_id references to the remote ID
  /// 3. Either swaps the caregiver PK (if remote ID doesn't exist locally)
  ///    or merges (if remote ID already exists locally with matching fields)
  /// 
  /// All operations run in a single transaction to ensure consistency.
  /// 
  /// Returns [CanonicalizationResult] with strategy used and counts of updated rows.
  Future<Result<CanonicalizationResult, Failure>> canonicalizeOwnerCaregiverId({
    required String babyId,
    required String userId,
    required String remoteCaregiverId,
    required DateTime nowUtc,
  });
}

/// Result of caregiver upsert operation (for logging counts)
class CaregiverUpsertResult {
  /// Number of caregivers upserted (inserted or updated)
  final int caregiversUpserted;

  const CaregiverUpsertResult({required this.caregiversUpserted});

  @override
  String toString() => 'CaregiverUpsertResult(caregiversUpserted: $caregiversUpserted)';
}

/// Result of caregiver canonicalization operation
class CanonicalizationResult {
  /// The strategy used: 'swap_pk', 'merge_existing', 'already_canonical', 'skipped', 'aborted'
  final String strategy;
  
  /// The local owner caregiver ID before canonicalization (null if not found)
  final String? localOwnerId;
  
  /// Number of sleep_events updated to use the new caregiver_id
  final int eventsUpdated;
  
  /// Number of caregivers updated (1 for swap_pk, 0 otherwise)
  final int caregiverUpdated;
  
  /// Number of caregivers deleted (1 for merge_existing, 0 otherwise)
  final int caregiverDeleted;
  
  /// Warning message if any
  final String? warning;

  const CanonicalizationResult({
    required this.strategy,
    this.localOwnerId,
    this.eventsUpdated = 0,
    this.caregiverUpdated = 0,
    this.caregiverDeleted = 0,
    this.warning,
  });

  @override
  String toString() {
    return 'CanonicalizationResult(strategy: $strategy, localOwnerId: $localOwnerId, '
        'eventsUpdated: $eventsUpdated, caregiverUpdated: $caregiverUpdated, '
        'caregiverDeleted: $caregiverDeleted, warning: $warning)';
  }
}

