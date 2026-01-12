import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:temp_flutter/core/types/result.dart';
import 'package:temp_flutter/domain/entities/caregiver.dart';
import 'package:temp_flutter/data/datasources/local/caregiver_local_datasource_impl.dart';
import 'active_baby_provider.dart';

part 'caregivers_provider.g.dart';

/// Caregivers provider
/// 
/// Provides list of caregivers for the active baby
/// Reads from SQLite (offline-first)
@riverpod
class CaregiversNotifier extends _$CaregiversNotifier {
  // Use getter instead of late final to avoid re-initialization error
  CaregiverLocalDataSourceImpl get _localDataSource => CaregiverLocalDataSourceImpl();

  @override
  Future<List<Caregiver>> build() async {
    final activeBaby = ref.watch(activeBabyProvider);
    
    if (activeBaby == null) {
      return [];
    }

    return _loadCaregivers(activeBaby.id);
  }

  /// Loads caregivers from SQLite
  Future<List<Caregiver>> _loadCaregivers(String babyId) async {
    final result = await _localDataSource.getCaregiversForBaby(babyId);
    
    switch (result) {
      case Success(:final data):
        return data.map((model) => model.toDomain()).toList();
      case Error(:final failure):
        throw Exception(failure.message);
    }
  }

  /// Refreshes caregivers list from local database
  Future<void> refresh() async {
    final activeBaby = ref.read(activeBabyProvider);
    if (activeBaby == null) {
      state = const AsyncData([]);
      return;
    }
    
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _loadCaregivers(activeBaby.id));
  }
}
