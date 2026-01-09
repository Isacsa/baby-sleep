import 'package:temp_flutter/core/types/result.dart';
import 'package:temp_flutter/core/errors/failures.dart';
import 'package:temp_flutter/data/models/baby_model.dart';

/// Remote data source for babies
/// 
/// Handles communication with Supabase backend
/// Implements backend contract queries
/// 
/// LAYERED SYNC: Babies must be synced FIRST before caregivers/events.
abstract class BabyRemoteDataSource {
  /// Gets accessible babies (GetAccessibleBabies)
  /// 
  /// Returns babies where user is active caregiver
  Future<Result<List<BabyModel>, Failure>> getAccessibleBabies();

  /// Gets baby by ID (SelectActiveBaby)
  /// 
  /// Validates access via RLS
  Future<Result<BabyModel?, Failure>> getBabyById(String babyId);

  /// Creates baby (CreateBaby)
  /// 
  /// Backend automatically creates first caregiver (owner) via trigger
  Future<Result<BabyModel, Failure>> createBaby({
    required String name,
    DateTime? birthDate,
  });

  /// Updates baby
  /// 
  /// Only owner/editor can update
  Future<Result<BabyModel, Failure>> updateBaby(BabyModel baby);

  // ========== SYNC PUSH METHODS (Layered Sync) ==========

  /// Upserts a baby to the remote backend (idempotent)
  /// 
  /// Used by LayeredSyncOrchestrator to push locally-created babies
  /// Uses ON CONFLICT DO UPDATE to be idempotent (safe to retry)
  /// 
  /// IMPORTANT: This is a sync push operation - the baby was already created
  /// locally with a client-generated UUID. We're pushing it to Supabase.
  Future<Result<void, Failure>> upsertBaby(BabyModel baby);
}

