import '../../../core/types/result.dart';
import '../../../core/errors/failures.dart';
import '../../entities/baby.dart';
import '../../repositories/baby_repository.dart';

/// Use case: Get accessible babies
/// 
/// Gets all babies where current user is active caregiver
/// RLS ensures only accessible babies are returned
class GetAccessibleBabies {
  final BabyRepository babyRepository;

  GetAccessibleBabies({required this.babyRepository});

  /// Executes the use case
  /// 
  /// Returns list of accessible babies or failure
  Future<Result<List<Baby>, Failure>> execute() async {
    return await babyRepository.getAccessibleBabies();
  }
}

