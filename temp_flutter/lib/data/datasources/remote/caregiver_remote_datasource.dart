import 'package:temp_flutter/core/types/result.dart';
import 'package:temp_flutter/core/errors/failures.dart';
import 'package:temp_flutter/data/models/caregiver_model.dart';

/// Remote data source for caregivers
/// 
/// Handles communication with Supabase backend
/// Implements backend contract queries
abstract class CaregiverRemoteDataSource {
  /// Gets caregivers for baby (GetCaregiversForBaby)
  /// 
  /// Returns active caregivers
  Future<Result<List<CaregiverModel>, Failure>> getCaregiversForBaby(String babyId);

  /// Gets caregiver by ID
  /// 
  /// Validates access via RLS
  Future<Result<CaregiverModel?, Failure>> getCaregiverById(String caregiverId);
}

