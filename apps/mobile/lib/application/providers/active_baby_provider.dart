import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:temp_flutter/domain/entities/baby.dart';
import 'package:temp_flutter/data/datasources/local/baby_local_datasource_impl.dart';
import 'package:temp_flutter/core/types/result.dart';

part 'active_baby_provider.g.dart';

/// Key for storing active baby ID in SharedPreferences
const String _activeBabyIdKey = 'active_baby_id';

/// Active baby provider
/// 
/// Manages currently selected baby (device-scoped)
/// Other providers depend on this to filter data
/// Persistence: SharedPreferences (local, not synced)
@riverpod
class ActiveBaby extends _$ActiveBaby {
  @override
  Baby? build() {
    // Load from local preferences asynchronously
    _loadFromPreferences();
    return null;
  }

  /// Loads active baby from SharedPreferences
  Future<void> _loadFromPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final babyId = prefs.getString(_activeBabyIdKey);
      
      if (babyId != null) {
        // Load baby from SQLite
        final localDataSource = BabyLocalDataSourceImpl();
        final result = await localDataSource.getBabyById(babyId);
        
        switch (result) {
          case Success(:final data):
            if (data != null) {
              state = data.toDomain();
            } else {
              // Baby not found locally - clear preference
              await prefs.remove(_activeBabyIdKey);
            }
          case Error():
            // Error loading - leave as null
            break;
        }
      }
    } catch (e) {
      // Ignore errors during load
    }
  }

  /// Sets active baby and persists to SharedPreferences
  Future<void> setBaby(Baby? baby) async {
    state = baby;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      if (baby != null) {
        await prefs.setString(_activeBabyIdKey, baby.id);
      } else {
        await prefs.remove(_activeBabyIdKey);
      }
    } catch (e) {
      // Ignore persistence errors
    }
  }

  /// Clears active baby
  Future<void> clearBaby() async {
    await setBaby(null);
  }
}

