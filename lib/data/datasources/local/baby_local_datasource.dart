import '../../../core/types/result.dart';
import '../../../core/errors/failures.dart';
import '../../models/baby_model.dart';

/// Local data source for babies
/// 
/// Handles local persistence of babies
/// Used for offline-first access
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
}

