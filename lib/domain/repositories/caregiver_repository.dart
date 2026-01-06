import '../../core/types/result.dart';
import '../../core/errors/failures.dart';
import '../entities/caregiver.dart';

/// Caregiver repository interface
/// 
/// Abstracts data source for caregivers
/// Returns domain entities, not data models
abstract class CaregiverRepository {
  /// Gets all caregivers for a baby
  /// 
  /// Returns active caregivers (deleted_at IS NULL)
  /// User must be caregiver of the baby to access
  Future<Result<List<Caregiver>, Failure>> getCaregiversForBaby(String babyId);

  /// Gets caregiver by ID
  /// 
  /// Validates user has access via RLS
  Future<Result<Caregiver?, Failure>> getCaregiverById(String caregiverId);

  /// Gets current user's caregiver relationship for a baby
  /// 
  /// Returns caregiver where userId = current user
  /// Used to get caregiver_id for creating events
  Future<Result<Caregiver?, Failure>> getCurrentUserCaregiverForBaby(String babyId);
}

