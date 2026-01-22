import 'package:temp_flutter/core/types/result.dart';
import 'package:temp_flutter/core/errors/failures.dart';
import 'package:temp_flutter/data/models/baby_model.dart';

/// Local data source for babies
/// 
/// Handles local persistence of babies
/// Used for offline-first access
/// 
/// LAYERED SYNC: Babies are synced FIRST, before caregivers and events.
/// This ensures FK integrity in the backend (Baby must exist before Caregiver).
abstract class BabyLocalDataSource {
  /// Gets all babies from local storage
  Future<Result<List<BabyModel>, Failure>> getBabies();

  /// Gets baby by ID from local storage
  Future<Result<BabyModel?, Failure>> getBabyById(String babyId);

  /// Saves baby to local storage
  Future<Result<void, Failure>> saveBaby(BabyModel baby);

  /// Saves multiple babies to local storage
  Future<Result<void, Failure>> saveBabies(List<BabyModel> babies);

  /// Deletes baby from local storage
  Future<Result<void, Failure>> deleteBaby(String babyId);

  /// Updates baby in local storage and marks for re-sync
  /// 
  /// Clears synced_at to NULL so baby appears in getUnsyncedBabies()
  /// and will be pushed to Supabase on next sync
  Future<Result<void, Failure>> updateBabyAndMarkForSync(BabyModel baby);

  // ========== SYNC METHODS (Layered Sync) ==========

  /// Gets babies that have not been synced to remote
  /// 
  /// Returns babies where synced_at IS NULL
  /// Used by LayeredSyncOrchestrator to push babies BEFORE caregivers/events
  Future<Result<List<BabyModel>, Failure>> getUnsyncedBabies();

  /// Marks a baby as synced after successful push to remote
  /// 
  /// [babyId] - The baby ID
  /// [syncedAt] - Timestamp of successful sync
  Future<Result<void, Failure>> markBabySynced(String babyId, DateTime syncedAt);

  /// Checks if a baby exists remotely (synced_at is not null)
  /// 
  /// [babyId] - The baby ID to check
  /// Returns true if baby has been synced to remote
  Future<Result<bool, Failure>> isBabySynced(String babyId);

  // ========== PULL METHODS (Global Pull) ==========

  /// Upserts babies from remote into local SQLite
  /// 
  /// Used by pullBabiesGlobal() to populate SQLite with remote babies
  /// Returns the number of babies upserted (for logging)
  /// 
  /// Marks all upserted babies as synced (synced_at = now)
  Future<Result<BabyUpsertResult, Failure>> upsertBabiesFromRemote(List<BabyModel> babies);
}

/// Result of baby upsert operation (for logging counts)
class BabyUpsertResult {
  /// Number of babies upserted (inserted or updated)
  final int babiesUpserted;

  const BabyUpsertResult({required this.babiesUpserted});

  @override
  String toString() => 'BabyUpsertResult(babiesUpserted: $babiesUpserted)';
}

