import '../../../core/types/result.dart';
import '../../../core/errors/failures.dart';
import '../../models/baby_model.dart';

/// Remote data source for babies
/// 
/// Handles communication with Supabase backend
/// Implements backend contract queries
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
}

