import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:temp_flutter/core/types/result.dart';
import 'package:temp_flutter/domain/entities/baby.dart';
import 'package:temp_flutter/data/datasources/local/baby_local_datasource_impl.dart';

part 'babies_provider.g.dart';

/// Babies provider
/// 
/// Provides list of accessible babies for current user
/// Reads from SQLite (offline-first)
/// Updates when sync completes or baby is created
@riverpod
class BabiesNotifier extends _$BabiesNotifier {
  late final BabyLocalDataSourceImpl _localDataSource;

  @override
  Future<List<Baby>> build() async {
    _localDataSource = BabyLocalDataSourceImpl();
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
}
