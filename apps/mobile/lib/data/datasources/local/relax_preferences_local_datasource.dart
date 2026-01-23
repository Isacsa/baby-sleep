import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:temp_flutter/domain/relax/relax.dart';

/// Local data source for relax preferences (volume, last config, favorites).
class RelaxPreferencesLocalDataSource {
  static const _volumeKey = 'relax_device_volume';
  static const _lastConfigPrefix = 'relax_last_config_';
  static const _favoritesPrefix = 'relax_favorites_';
  static const _volumeWarningShownKey = 'relax_volume_warning_shown_session';
  static const _timerEndAtPrefix = 'relax_timer_end_at_';
  static const maxFavorites = 6;

  final SharedPreferences _prefs;

  RelaxPreferencesLocalDataSource(this._prefs);

  // ─────────────────────────────────────────────────────────────────────────
  // Volume (per device, not per baby)
  // ─────────────────────────────────────────────────────────────────────────

  double getVolume() {
    return _prefs.getDouble(_volumeKey) ?? 0.5;
  }

  Future<void> setVolume(double volume) async {
    await _prefs.setDouble(_volumeKey, volume.clamp(0.0, 1.0));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Volume warning cooldown (per session)
  // ─────────────────────────────────────────────────────────────────────────

  bool hasVolumeWarningBeenShown() {
    return _prefs.getBool(_volumeWarningShownKey) ?? false;
  }

  Future<void> markVolumeWarningShown() async {
    await _prefs.setBool(_volumeWarningShownKey, true);
  }

  Future<void> resetVolumeWarningForNewSession() async {
    await _prefs.remove(_volumeWarningShownKey);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Last config (per baby)
  // ─────────────────────────────────────────────────────────────────────────

  RelaxLastConfig? getLastConfig(String babyId) {
    final key = '$_lastConfigPrefix$babyId';
    final jsonStr = _prefs.getString(key);
    if (jsonStr == null) return null;

    try {
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      return RelaxLastConfig.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<void> setLastConfig(String babyId, RelaxLastConfig config) async {
    final key = '$_lastConfigPrefix$babyId';
    await _prefs.setString(key, jsonEncode(config.toJson()));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Timer persistence (per baby)
  // ─────────────────────────────────────────────────────────────────────────

  DateTime? getTimerEndAt(String babyId) {
    final key = '$_timerEndAtPrefix$babyId';
    final timestamp = _prefs.getString(key);
    if (timestamp == null) return null;
    try {
      return DateTime.parse(timestamp);
    } catch (_) {
      return null;
    }
  }

  Future<void> setTimerEndAt(String babyId, DateTime? endAt) async {
    final key = '$_timerEndAtPrefix$babyId';
    if (endAt == null) {
      await _prefs.remove(key);
    } else {
      await _prefs.setString(key, endAt.toIso8601String());
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Favorites (per baby)
  // ─────────────────────────────────────────────────────────────────────────

  List<RelaxFavorite> getFavorites(String babyId) {
    final key = '$_favoritesPrefix$babyId';
    final jsonStr = _prefs.getString(key);
    if (jsonStr == null) return [];

    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list
          .map((e) => RelaxFavorite.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> addFavorite(String babyId, RelaxFavorite favorite) async {
    final favorites = getFavorites(babyId);

    // Remove duplicate if exists
    favorites.removeWhere((f) => f.uniqueKey == favorite.uniqueKey);

    // Add to beginning
    favorites.insert(0, favorite);

    // Limit to max
    while (favorites.length > maxFavorites) {
      favorites.removeLast();
    }

    await _saveFavorites(babyId, favorites);
  }

  Future<void> removeFavorite(String babyId, RelaxFavorite favorite) async {
    final favorites = getFavorites(babyId);
    favorites.removeWhere((f) => f.uniqueKey == favorite.uniqueKey);
    await _saveFavorites(babyId, favorites);
  }

  Future<void> _saveFavorites(String babyId, List<RelaxFavorite> favorites) async {
    final key = '$_favoritesPrefix$babyId';
    final jsonList = favorites.map((f) => f.toJson()).toList();
    await _prefs.setString(key, jsonEncode(jsonList));
  }
}

/// Last used configuration (per baby).
class RelaxLastConfig {
  final String soundId;
  final int timerPreset;
  final bool fadeOutEnabled;
  final bool nightScreenEnabled;

  const RelaxLastConfig({
    required this.soundId,
    required this.timerPreset,
    required this.fadeOutEnabled,
    required this.nightScreenEnabled,
  });

  factory RelaxLastConfig.fromJson(Map<String, dynamic> json) {
    return RelaxLastConfig(
      soundId: json['soundId'] as String,
      timerPreset: json['timerPreset'] as int? ?? -1,
      fadeOutEnabled: json['fadeOutEnabled'] as bool? ?? true,
      nightScreenEnabled: json['nightScreenEnabled'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'soundId': soundId,
      'timerPreset': timerPreset,
      'fadeOutEnabled': fadeOutEnabled,
      'nightScreenEnabled': nightScreenEnabled,
    };
  }
}
