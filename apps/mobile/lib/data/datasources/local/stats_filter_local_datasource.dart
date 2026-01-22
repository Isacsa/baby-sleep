import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:temp_flutter/domain/stats/stats_filter_state.dart';

/// Local datasource for persisting stats filter preferences per baby.
///
/// Uses SharedPreferences with baby-scoped keys.
class StatsFilterLocalDataSource {
  static const _keyPrefix = 'stats_filter_';

  /// Gets the preference key for a specific baby
  static String _keyForBaby(String babyId) => '$_keyPrefix$babyId';

  /// Loads the stats filter state for a baby.
  ///
  /// Returns default state if not found or on error.
  Future<StatsFilterState> load(String babyId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_keyForBaby(babyId));
      
      if (jsonStr == null) {
        return const StatsFilterState();
      }
      
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      return StatsFilterState.fromJson(json);
    } catch (e) {
      // Return default on any error
      return const StatsFilterState();
    }
  }

  /// Saves the stats filter state for a baby.
  Future<void> save(String babyId, StatsFilterState state) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(state.toJson());
      await prefs.setString(_keyForBaby(babyId), jsonStr);
    } catch (e) {
      // Ignore save errors - not critical
    }
  }

  /// Clears the stats filter state for a baby.
  Future<void> clear(String babyId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyForBaby(babyId));
    } catch (e) {
      // Ignore clear errors
    }
  }
}
