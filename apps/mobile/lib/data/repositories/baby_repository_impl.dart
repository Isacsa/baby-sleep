import 'package:temp_flutter/domain/entities/baby.dart';
import 'package:temp_flutter/domain/repositories/baby_repository.dart';
import 'package:temp_flutter/domain/common/result.dart';
import 'package:temp_flutter/core/types/result.dart' as core;
import 'package:temp_flutter/data/datasources/local/baby_local_datasource.dart';
import 'package:temp_flutter/data/datasources/remote/baby_remote_datasource.dart';
import 'package:temp_flutter/data/mappers/baby_mapper.dart';
import 'package:temp_flutter/data/adapters/result_adapter.dart';

/// Baby repository implementation
/// 
/// Combines local and remote data sources
/// Returns local data immediately (offline-first)
/// Syncs with remote in background
class BabyRepositoryImpl implements BabyRepository {
  final BabyLocalDataSource localDataSource;
  final BabyRemoteDataSource remoteDataSource;

  BabyRepositoryImpl({
    required this.localDataSource,
    required this.remoteDataSource,
  });

  @override
  Future<DomainResult<List<Baby>>> getAccessibleBabies() async {
    // Return local data immediately (offline-first)
    final localResult = await localDataSource.getBabies();
    
    return switch (localResult) {
      core.Success(:final data) => DomainSuccess(BabyMapper.toDomainList(data)),
      core.Error(:final failure) => DomainError(ResultAdapter.failureToDomain(failure)),
    };
  }

  @override
  Future<DomainResult<Baby?>> getBabyById(String babyId) async {
    // Return local data immediately (offline-first)
    final localResult = await localDataSource.getBabyById(babyId);
    
    return switch (localResult) {
      core.Success(:final data) => DomainSuccess(data?.toDomain()),
      core.Error(:final failure) => DomainError(ResultAdapter.failureToDomain(failure)),
    };
  }

  @override
  Future<DomainResult<Baby>> createBaby({
    required String name,
    DateTime? birthDate,
  }) async {
    // Create via remote (backend creates first caregiver via trigger)
    final remoteResult = await remoteDataSource.createBaby(
      name: name,
      birthDate: birthDate,
    );

    return switch (remoteResult) {
      core.Success(:final data) => () {
          // Save locally (don't wait for result, offline-first)
          localDataSource.saveBaby(data);
          return DomainSuccess(data.toDomain());
        }(),
      core.Error(:final failure) => DomainError(ResultAdapter.failureToDomain(failure)),
    };
  }

  @override
  Future<DomainResult<Baby>> updateBaby(Baby baby) async {
    final model = BabyMapper.toModel(baby);

    // Update via remote
    final remoteResult = await remoteDataSource.updateBaby(model);
    
    return switch (remoteResult) {
      core.Success(:final data) => () {
          // Update locally (don't wait for result, offline-first)
          localDataSource.saveBaby(data);
          return DomainSuccess(data.toDomain());
        }(),
      core.Error(:final failure) => DomainError(ResultAdapter.failureToDomain(failure)),
    };
  }

  @override
  Future<DomainResult<Baby>> createLocal(Baby baby) async {
    // Persist locally only (offline-first, no remote call)
    final model = BabyMapper.toModel(baby);
    final localResult = await localDataSource.saveBaby(model);
    
    return switch (localResult) {
      core.Success() => DomainSuccess(baby),
      core.Error(:final failure) => DomainError(ResultAdapter.failureToDomain(failure)),
    };
  }
}
