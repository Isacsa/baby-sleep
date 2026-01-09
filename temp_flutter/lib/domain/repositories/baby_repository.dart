import 'package:temp_flutter/domain/common/result.dart';
import 'package:temp_flutter/domain/entities/baby.dart';

/// Baby repository interface
/// 
/// Abstracts data source for babies
/// Returns domain entities, not data models
abstract class BabyRepository {
  /// Gets all babies accessible to current user
  /// 
  /// Returns babies where user is active caregiver
  /// RLS ensures only accessible babies are returned
  Future<DomainResult<List<Baby>>> getAccessibleBabies();

  /// Gets baby by ID
  /// 
  /// Validates user has access via RLS
  /// Returns null if baby doesn't exist or user doesn't have access
  Future<DomainResult<Baby?>> getBabyById(String babyId);

  /// Creates a new baby
  /// 
  /// Backend automatically creates first caregiver (owner) via trigger
  /// Returns created baby with caregiver relationship
  Future<DomainResult<Baby>> createBaby({
    required String name,
    DateTime? birthDate,
  });

  /// Updates baby
  /// 
  /// Only owner/editor can update
  /// Immutable fields (createdBy, createdAt) cannot be changed
  Future<DomainResult<Baby>> updateBaby(Baby baby);

  /// Creates a baby locally (offline-first)
  /// 
  /// Persists baby to local SQLite storage only
  /// Does NOT call remote backend
  /// Used for offline-first baby creation
  Future<DomainResult<Baby>> createLocal(Baby baby);
}

