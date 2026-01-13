import 'package:temp_flutter/domain/common/result.dart';
import 'package:temp_flutter/domain/entities/caregiver.dart';

/// Caregiver repository interface
/// 
/// Abstracts data source for caregivers
/// Returns domain entities, not data models
abstract class CaregiverRepository {
  /// Gets all caregivers for a baby
  /// 
  /// Returns active caregivers (deleted_at IS NULL)
  /// User must be caregiver of the baby to access
  Future<DomainResult<List<Caregiver>>> getCaregiversForBaby(String babyId);

  /// Gets caregiver by ID
  /// 
  /// Validates user has access via RLS
  Future<DomainResult<Caregiver?>> getCaregiverById(String caregiverId);

  /// Gets caregiver relationship for a specific user and baby
  /// 
  /// Returns caregiver where (babyId, userId) match
  /// Used to get caregiver_id for creating events
  /// 
  /// IMPORTANT: Always pass the actual userId, never assume "current user"
  Future<DomainResult<Caregiver?>> getCaregiverForBabyAndUser({
    required String babyId,
    required String userId,
  });

  /// Ensures a local owner caregiver exists for the given baby and user
  /// 
  /// If caregiver already exists for (babyId, userId) -> returns existing (idempotent)
  /// If not -> creates new owner caregiver locally
  /// Does NOT call remote backend
  Future<DomainResult<Caregiver>> ensureLocalOwnerCaregiver({
    required String babyId,
    required String userId,
    required DateTime nowUtc,
  });
}

