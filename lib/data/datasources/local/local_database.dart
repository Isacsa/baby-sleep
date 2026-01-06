/// Local database interface
/// 
/// Abstracts local storage implementation (SQLite/Hive)
/// Used for offline-first persistence
abstract class LocalDatabase {
  /// Initializes the database
  Future<void> init();

  /// Closes the database
  Future<void> close();

  /// Clears all data (for testing/reset)
  Future<void> clear();
}

