import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:temp_flutter/core/types/result.dart';
import 'package:temp_flutter/core/errors/failures.dart';
import 'package:temp_flutter/domain/entities/baby.dart';
import 'package:temp_flutter/domain/common/result.dart' as domain;
import 'package:temp_flutter/domain/use_cases/baby/create_baby_local.dart';
import 'package:temp_flutter/data/datasources/local/baby_local_datasource_impl.dart';
import 'package:temp_flutter/data/datasources/local/caregiver_local_datasource_impl.dart';
import 'package:temp_flutter/data/datasources/remote/baby_remote_datasource.dart';
import 'package:temp_flutter/data/datasources/remote/caregiver_remote_datasource_impl.dart';
import 'package:temp_flutter/data/models/baby_model.dart';
import 'package:temp_flutter/data/repositories/baby_repository_impl.dart';
import 'package:temp_flutter/data/repositories/caregiver_repository_impl.dart';
import 'auth_provider.dart';

part 'babies_provider.g.dart';

/// Babies provider
/// 
/// Provides list of accessible babies for current user
/// Reads from SQLite (offline-first)
/// Updates when sync completes or baby is created
@riverpod
class BabiesNotifier extends _$BabiesNotifier {
  // Use getter instead of late final to avoid re-initialization error on rebuild
  BabyLocalDataSourceImpl get _localDataSource => BabyLocalDataSourceImpl();

  @override
  Future<List<Baby>> build() async {
    return _loadBabies();
  }

  /// Loads babies from SQLite
  Future<List<Baby>> _loadBabies() async {
    final result = await _localDataSource.getBabies();
    
    switch (result) {
      case Success(:final data):
        return data.map((model) => model.toDomain()).toList();
      case Error(:final failure):
        throw Exception(failure.message);
    }
  }

  /// Refreshes babies list from local database
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _loadBabies());
  }

  /// Updates baby profile locally (offline-first)
  /// 
  /// Clears synced_at to mark for re-sync on next auto-sync
  /// Refreshes the babies list on success
  Future<Baby> updateBaby({
    required String babyId,
    required String name,
    DateTime? birthDate,
  }) async {
    // Get current baby
    final currentResult = await _localDataSource.getBabyById(babyId);
    if (currentResult.isError || currentResult.dataOrNull == null) {
      throw Exception('Baby not found');
    }
    
    final currentBaby = currentResult.dataOrNull!;
    final now = DateTime.now().toUtc();
    
    // Create updated model
    final updatedModel = BabyModel(
      id: currentBaby.id,
      name: name.isNotEmpty ? name : currentBaby.name,
      createdAt: currentBaby.createdAt,
      createdBy: currentBaby.createdBy,
      birthDate: birthDate?.toIso8601String(),
      updatedAt: now.toIso8601String(),
      syncedAt: null, // Will be cleared by updateBabyAndMarkForSync
    );
    
    // Save to local database (marks for re-sync)
    final result = await _localDataSource.updateBabyAndMarkForSync(updatedModel);
    
    if (result.isError) {
      throw Exception(result.failureOrNull?.message ?? 'Failed to update baby');
    }
    
    // Refresh babies list
    await refresh();
    
    // Return updated domain entity
    return updatedModel.toDomain();
  }

  /// Creates a baby locally (offline-first)
  /// 
  /// Also creates the owner caregiver automatically
  /// Refreshes the babies list on success
  Future<void> createLocalBaby({
    required String name,
    DateTime? birthDate,
  }) async {
    // Get current user from auth provider
    final user = ref.read(authProvider);
    final userId = user?.id;

    // Create repositories (local only for this flow)
    final babyRepository = BabyRepositoryImpl(
      localDataSource: _localDataSource,
      remoteDataSource: _NoopBabyRemoteDataSource(),
    );

    final caregiverRepository = CaregiverRepositoryImpl(
      localDataSource: CaregiverLocalDataSourceImpl(),
      remoteDataSource: CaregiverRemoteDataSourceImpl(),
    );

    // Execute use case
    final useCase = CreateBabyLocal(
      babyRepository: babyRepository,
      caregiverRepository: caregiverRepository,
    );

    final result = await useCase.execute(
      userId: userId,
      name: name,
      birthDate: birthDate,
    );

    switch (result) {
      case domain.DomainSuccess():
        // Refresh babies list to show the new baby
        await refresh();
      case domain.DomainError(:final failure):
        // Log error (in production, could show snackbar via another mechanism)
        // ignore: avoid_print
        print('Error creating baby: ${failure.message}');
        throw Exception(failure.message);
    }
  }
}

/// Noop implementation of BabyRemoteDataSource for local-only operations
/// 
/// All methods throw - this is never called in the local-only flow
class _NoopBabyRemoteDataSource implements BabyRemoteDataSource {
  @override
  Future<Result<List<BabyModel>, Failure>> getAccessibleBabies() {
    throw UnimplementedError('Remote not used in local-only flow');
  }

  @override
  Future<Result<BabyModel?, Failure>> getBabyById(String babyId) {
    throw UnimplementedError('Remote not used in local-only flow');
  }

  @override
  Future<Result<BabyModel, Failure>> createBaby({
    required String name,
    DateTime? birthDate,
  }) {
    throw UnimplementedError('Remote not used in local-only flow');
  }

  @override
  Future<Result<BabyModel, Failure>> updateBaby(BabyModel baby) {
    throw UnimplementedError('Remote not used in local-only flow');
  }

  @override
  Future<Result<void, Failure>> upsertBaby(BabyModel baby) {
    throw UnimplementedError('Remote not used in local-only flow');
  }
}
