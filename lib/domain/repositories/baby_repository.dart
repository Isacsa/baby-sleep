import '../../core/types/result.dart';
import '../../core/errors/failures.dart';
import '../entities/baby.dart';

/// Baby repository interface
/// 
/// Abstracts data source for babies
/// Returns domain entities, not data models
abstract class BabyRepository {
  /// Gets all babies accessible to current user
  /// 
  /// Returns babies where user is active caregiver
  /// RLS ensures only accessible babies are returned
  Future<Result<List<Baby>, Failure>> getAccessibleBabies();

  /// Gets baby by ID
  /// 
  /// Validates user has access via RLS
  /// Returns null if baby doesn't exist or user doesn't have access
  Future<Result<Baby?, Failure>> getBabyById(String babyId);

  /// Creates a new baby
  /// 
  /// Backend automatically creates first caregiver (owner) via trigger
  /// Returns created baby with caregiver relationship
  Future<Result<Baby, Failure>> createBaby({
    required String name,
    DateTime? birthDate,
  });

  /// Updates baby
  /// 
  /// Only owner/editor can update
  /// Immutable fields (createdBy, createdAt) cannot be changed
  Future<Result<Baby, Failure>> updateBaby(Baby baby);
}

