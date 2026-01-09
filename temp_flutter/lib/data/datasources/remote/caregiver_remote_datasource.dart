import 'package:temp_flutter/core/types/result.dart';
import 'package:temp_flutter/core/errors/failures.dart';
import 'package:temp_flutter/data/models/caregiver_model.dart';

/// Remote data source for caregivers
/// 
/// Handles communication with Supabase backend
/// Implements backend contract queries
/// 
/// LAYERED SYNC: Caregivers must be synced AFTER babies, BEFORE events.
/// The backend trigger validate_sleep_event checks caregiver exists.
abstract class CaregiverRemoteDataSource {
  /// Gets caregivers for baby (GetCaregiversForBaby)
  /// 
  /// Returns active caregivers
  Future<Result<List<CaregiverModel>, Failure>> getCaregiversForBaby(String babyId);

  /// Gets caregiver by ID
  /// 
  /// Validates access via RLS
  Future<Result<CaregiverModel?, Failure>> getCaregiverById(String caregiverId);

  // ========== SYNC PUSH METHODS (Layered Sync) ==========

  /// Upserts a caregiver to the remote backend (idempotent)
  /// 
  /// Used by LayeredSyncOrchestrator to push locally-created caregivers
  /// Uses ON CONFLICT DO UPDATE to be idempotent (safe to retry)
  /// 
  /// IMPORTANT: This is a sync push operation - the caregiver was already created
  /// locally with a client-generated UUID. We're pushing it to Supabase.
  /// 
  /// PREREQUISITE: Baby MUST exist remotely before calling this.
  /// The LayeredSyncOrchestrator ensures this by syncing babies first.
  Future<Result<void, Failure>> upsertCaregiver(CaregiverModel caregiver);
}

