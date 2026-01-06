import '../../../core/types/result.dart';
import '../../../core/errors/failures.dart';
import '../../entities/baby.dart';
import '../../repositories/baby_repository.dart';

/// Use case: Select active baby
/// 
/// Validates user has access to baby
/// Active baby state is managed in application layer (provider)
/// This use case only validates access
class SelectActiveBaby {
  final BabyRepository babyRepository;

  SelectActiveBaby({required this.babyRepository});

  /// Executes the use case
  /// 
  /// [babyId] - Baby ID to select
  /// 
  /// Returns baby if accessible, null if not accessible, or failure
  Future<Result<Baby?, Failure>> execute(String babyId) async {
    return await babyRepository.getBabyById(babyId);
  }
}

