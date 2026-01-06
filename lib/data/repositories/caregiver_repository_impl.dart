import '../../core/types/result.dart';
import '../../core/errors/failures.dart';
import '../../domain/entities/caregiver.dart';
import '../../domain/repositories/caregiver_repository.dart';
import '../datasources/local/caregiver_local_datasource.dart';
import '../datasources/remote/caregiver_remote_datasource.dart';
import '../mappers/caregiver_mapper.dart';

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
  Future<Result<List<Caregiver>, Failure>> getCaregiversForBaby(String babyId) async {
    // Return local data immediately (offline-first)
    final localResult = await localDataSource.getCaregiversForBaby(babyId);
    if (localResult.isError) {
      return Error(localResult.failureOrNull!);
    }

    final localCaregivers = localResult.dataOrNull ?? [];
    return Success(CaregiverMapper.toDomainList(localCaregivers));
  }

  @override
  Future<Result<Caregiver?, Failure>> getCaregiverById(String caregiverId) async {
    // Return local data immediately (offline-first)
    final localResult = await localDataSource.getCaregiverById(caregiverId);
    if (localResult.isError) {
      return Error(localResult.failureOrNull!);
    }

    final localCaregiver = localResult.dataOrNull;
    if (localCaregiver != null) {
      return Success(localCaregiver.toDomain());
    }

    // Not found locally, return null
    return const Success(null);
  }

  @override
  Future<Result<Caregiver?, Failure>> getCurrentUserCaregiverForBaby(String babyId) async {
    // Get all caregivers for baby
    final caregiversResult = await getCaregiversForBaby(babyId);
    if (caregiversResult.isError) {
      return Error(caregiversResult.failureOrNull!);
    }

    final caregivers = caregiversResult.dataOrNull ?? [];

    // Find current user's caregiver
    // Note: This requires current user ID, which should be injected
    // For now, returning first caregiver (implementation detail)
    // TODO: Inject current user ID to filter correctly
    if (caregivers.isEmpty) {
      return const Success(null);
    }

    return Success(caregivers.first);
  }
}

