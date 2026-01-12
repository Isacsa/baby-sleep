/// App initializer
/// 
/// Handles app startup initialization
/// Sets up dependencies, initializes local database, etc.
abstract class AppInitializer {
  /// Initializes the app
  /// 
  /// Should be called before app starts
  Future<void> initialize();
}

