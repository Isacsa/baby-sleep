import 'package:shared_preferences/shared_preferences.dart';

/// Local storage for insight impressions (cooldown tracking)
///
/// Tracks when each insight was last shown to implement cooldown logic.
/// Uses SharedPreferences for simple key-value storage.
class InsightImpressionsLocalDataSource {
  static const String _prefix = 'insight_impression_';
  static const String _favoritesKey = 'insight_favorites';

  /// Records that an insight was shown
  Future<void> recordImpression(String babyId, String insightId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _impressionKey(babyId, insightId);
    await prefs.setInt(key, DateTime.now().toUtc().millisecondsSinceEpoch);
  }

  /// Gets the last impression time for an insight
  Future<DateTime?> getLastImpression(String babyId, String insightId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _impressionKey(babyId, insightId);
    final timestamp = prefs.getInt(key);
    if (timestamp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true);
  }

  /// Checks if an insight is in cooldown
  Future<bool> isInCooldown(String babyId, String insightId, int cooldownHours) async {
    final lastImpression = await getLastImpression(babyId, insightId);
    if (lastImpression == null) return false;
    
    final now = DateTime.now().toUtc();
    final cooldownEnd = lastImpression.add(Duration(hours: cooldownHours));
    return now.isBefore(cooldownEnd);
  }

  /// Gets hours remaining in cooldown (0 if not in cooldown)
  Future<int> hoursUntilCooldownEnd(String babyId, String insightId, int cooldownHours) async {
    final lastImpression = await getLastImpression(babyId, insightId);
    if (lastImpression == null) return 0;
    
    final now = DateTime.now().toUtc();
    final cooldownEnd = lastImpression.add(Duration(hours: cooldownHours));
    if (now.isAfter(cooldownEnd)) return 0;
    
    return cooldownEnd.difference(now).inHours;
  }

  /// Clears all impressions for a baby (e.g., for testing)
  Future<void> clearImpressionsForBaby(String babyId) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('$_prefix${babyId}_'));
    for (final key in keys) {
      await prefs.remove(key);
    }
  }

  // === FAVORITES ===

  /// Saves an insight as favorite
  Future<void> saveFavorite(String babyId, String insightId) async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = await getFavorites(babyId);
    if (!favorites.contains(insightId)) {
      favorites.add(insightId);
      await prefs.setStringList(_favoritesKeyForBaby(babyId), favorites);
    }
  }

  /// Removes an insight from favorites
  Future<void> removeFavorite(String babyId, String insightId) async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = await getFavorites(babyId);
    favorites.remove(insightId);
    await prefs.setStringList(_favoritesKeyForBaby(babyId), favorites);
  }

  /// Gets all favorite insight IDs for a baby
  Future<List<String>> getFavorites(String babyId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_favoritesKeyForBaby(babyId)) ?? [];
  }

  /// Checks if an insight is a favorite
  Future<bool> isFavorite(String babyId, String insightId) async {
    final favorites = await getFavorites(babyId);
    return favorites.contains(insightId);
  }

  // === HELPERS ===

  String _impressionKey(String babyId, String insightId) =>
      '$_prefix${babyId}_$insightId';

  String _favoritesKeyForBaby(String babyId) =>
      '${_favoritesKey}_$babyId';
}
