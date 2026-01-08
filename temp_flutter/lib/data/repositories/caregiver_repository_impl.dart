import 'package:temp_flutter/domain/entities/caregiver.dart';
import 'package:temp_flutter/domain/repositories/caregiver_repository.dart';
import 'package:temp_flutter/domain/common/result.dart';
import 'package:temp_flutter/core/types/result.dart' as core;
import 'package:temp_flutter/data/datasources/local/caregiver_local_datasource.dart';
import 'package:temp_flutter/data/datasources/remote/caregiver_remote_datasource.dart';
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
}

