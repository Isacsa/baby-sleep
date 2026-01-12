import 'package:temp_flutter/domain/common/result.dart';
import 'package:temp_flutter/domain/entities/caregiver.dart';
import 'package:temp_flutter/domain/repositories/caregiver_repository.dart';

/// Use case: Get caregivers for baby
/// 
/// Gets all active caregivers for a baby
/// User must be caregiver of the baby to access
class GetCaregiversForBaby {
  final CaregiverRepository caregiverRepository;

  GetCaregiversForBaby({required this.caregiverRepository});

  /// Executes the use case
  /// 
  /// [babyId] - Baby ID
  /// 
  /// Returns list of caregivers or failure
  Future<DomainResult<List<Caregiver>>> execute(String babyId) async {
    return await caregiverRepository.getCaregiversForBaby(babyId);
  }
}
