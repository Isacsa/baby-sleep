import 'package:temp_flutter/domain/entities/caregiver.dart';
import 'package:temp_flutter/domain/repositories/caregiver_repository.dart';
import 'package:temp_flutter/domain/common/result.dart';
import 'package:temp_flutter/core/types/result.dart' as core;
import 'package:temp_flutter/core/utils/uuid_generator.dart';
import 'package:temp_flutter/data/datasources/local/caregiver_local_datasource.dart';
import 'package:temp_flutter/data/datasources/remote/caregiver_remote_datasource.dart';
import 'package:temp_flutter/data/models/caregiver_model.dart';
import 'package:temp_flutter/data/mappers/caregiver_mapper.dart';
import 'package:temp_flutter/data/adapters/result_adapter.dart';

/// Caregiver repository implementation
/// 
/// Combines local and remote data sources
/// Returns local data immediately (offline-first)
class CaregiverRepositoryImpl implements CaregiverRepository {
  final CaregiverLocalDataSource localDataSource;
  final CaregiverRemoteDataSource remoteDataSource;

  CaregiverRepositoryImpl({
    required this.localDataSource,
    required this.remoteDataSource,
  });

  @override
  Future<DomainResult<List<Caregiver>>> getCaregiversForBaby(String babyId) async {
    // Return local data immediately (offline-first)
    final localResult = await localDataSource.getCaregiversForBaby(babyId);
    
    return switch (localResult) {
      core.Success(:final data) => DomainSuccess(CaregiverMapper.toDomainList(data)),
      core.Error(:final failure) => DomainError(ResultAdapter.failureToDomain(failure)),
    };
  }

  @override
  Future<DomainResult<Caregiver?>> getCaregiverById(String caregiverId) async {
    // Return local data immediately (offline-first)
    final localResult = await localDataSource.getCaregiverById(caregiverId);
    
    return switch (localResult) {
      core.Success(:final data) => DomainSuccess(data?.toDomain()),
      core.Error(:final failure) => DomainError(ResultAdapter.failureToDomain(failure)),
    };
  }

  @override
  Future<DomainResult<Caregiver?>> getCurrentUserCaregiverForBaby(String babyId) async {
    // Get all caregivers for baby
    final caregiversResult = await getCaregiversForBaby(babyId);
    
    return switch (caregiversResult) {
      DomainSuccess(:final data) => () {
          // Find current user's caregiver
          // Note: This requires current user ID, which should be injected
          // For now, returning first caregiver (implementation detail)
          // TODO: Inject current user ID to filter correctly
          if (data.isEmpty) {
            return const DomainSuccess<Caregiver?>(null);
          }
          return DomainSuccess<Caregiver?>(data.first);
        }(),
      DomainError(:final failure) => DomainError<Caregiver?>(failure),
    };
  }

  @override
  Future<DomainResult<Caregiver>> ensureLocalOwnerCaregiver({
    required String babyId,
    required String userId,
    required DateTime nowUtc,
  }) async {
    // Check if caregiver already exists (idempotency)
    final existingResult = await localDataSource.getCaregiverByUserIdForBaby(
      userId: userId,
      babyId: babyId,
    );

    switch (existingResult) {
      case core.Success(:final data):
        if (data != null) {
          // Already exists - return it (idempotent)
          return DomainSuccess(data.toDomain());
        }
        // Doesn't exist - create new owner caregiver
        break;
      case core.Error(:final failure):
        return DomainError(ResultAdapter.failureToDomain(failure));
    }

    // Create new owner caregiver
    final caregiverId = UuidGenerator.generate();
    final caregiverModel = CaregiverModel(
      id: caregiverId,
      babyId: babyId,
      userId: userId,
      role: 'owner',
      createdAt: nowUtc.toIso8601String(),
      updatedAt: nowUtc.toIso8601String(),
      invitedBy: null, // Owner is not invited
    );

    final saveResult = await localDataSource.saveCaregiver(caregiverModel);

    return switch (saveResult) {
      core.Success() => DomainSuccess(caregiverModel.toDomain()),
      core.Error(:final failure) => DomainError(ResultAdapter.failureToDomain(failure)),
    };
  }
}

