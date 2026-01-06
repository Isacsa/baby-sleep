import '../../core/types/result.dart';
import '../../core/errors/failures.dart';
import '../../domain/entities/baby.dart';
import '../../domain/repositories/baby_repository.dart';
import '../datasources/local/baby_local_datasource.dart';
import '../datasources/remote/baby_remote_datasource.dart';
import '../mappers/baby_mapper.dart';

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
  Future<Result<List<Baby>, Failure>> getAccessibleBabies() async {
    // Return local data immediately (offline-first)
    final localResult = await localDataSource.getBabies();
    if (localResult.isError) {
      return Error(localResult.failureOrNull!);
    }

    final localBabies = localResult.dataOrNull ?? [];
    return Success(BabyMapper.toDomainList(localBabies));
  }

  @override
  Future<Result<Baby?, Failure>> getBabyById(String babyId) async {
    // Return local data immediately (offline-first)
    final localResult = await localDataSource.getBabyById(babyId);
    if (localResult.isError) {
      return Error(localResult.failureOrNull!);
    }

    final localBaby = localResult.dataOrNull;
    if (localBaby != null) {
      return Success(localBaby.toDomain());
    }

    // Not found locally, return null
    return const Success(null);
  }

  @override
  Future<Result<Baby, Failure>> createBaby({
    required String name,
    DateTime? birthDate,
  }) async {
    // Create via remote (backend creates first caregiver via trigger)
    final remoteResult = await remoteDataSource.createBaby(
      name: name,
      birthDate: birthDate,
    );

    if (remoteResult.isError) {
      return Error(remoteResult.failureOrNull!);
    }

    final remoteBaby = remoteResult.dataOrNull!;

    // Save locally
    await localDataSource.saveBaby(remoteBaby);

    return Success(remoteBaby.toDomain());
  }

  @override
  Future<Result<Baby, Failure>> updateBaby(Baby baby) async {
    final model = BabyMapper.toModel(baby);

    // Update via remote
    final remoteResult = await remoteDataSource.updateBaby(model);
    if (remoteResult.isError) {
      return Error(remoteResult.failureOrNull!);
    }

    final updatedBaby = remoteResult.dataOrNull!;

    // Update locally
    await localDataSource.saveBaby(updatedBaby);

    return Success(updatedBaby.toDomain());
  }
}

