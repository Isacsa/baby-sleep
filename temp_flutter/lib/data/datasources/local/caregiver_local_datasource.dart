import 'package:temp_flutter/core/types/result.dart';
import 'package:temp_flutter/core/errors/failures.dart';
import 'package:temp_flutter/data/models/caregiver_model.dart';

/// Local data source for caregivers
/// 
/// Handles local persistence of caregivers
/// Used for offline-first access
abstract class CaregiverLocalDataSource {
  /// Gets all caregivers for a baby from local storage
  Future<Result<List<CaregiverModel>, Failure>> getCaregiversForBaby(String babyId);

  /// Gets caregiver by ID from local storage
  Future<Result<CaregiverModel?, Failure>> getCaregiverById(String caregiverId);

  /// Saves caregiver to local storage
  Future<Result<void, Failure>> saveCaregiver(CaregiverModel caregiver);

  /// Saves multiple caregivers to local storage
  Future<Result<void, Failure>> saveCaregivers(List<CaregiverModel> caregivers);

  /// Deletes caregiver from local storage
  Future<Result<void, Failure>> deleteCaregiver(String caregiverId);
}

