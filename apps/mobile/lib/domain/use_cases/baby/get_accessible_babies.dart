import 'package:temp_flutter/domain/common/result.dart';
import 'package:temp_flutter/domain/entities/baby.dart';
import 'package:temp_flutter/domain/repositories/baby_repository.dart';

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
  Future<DomainResult<List<Baby>>> execute() async {
    return await babyRepository.getAccessibleBabies();
  }
}
