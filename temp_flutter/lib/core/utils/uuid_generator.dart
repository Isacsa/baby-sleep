import 'package:uuid/uuid.dart';

/// Generates UUIDs for events
/// 
/// Uses UUID v4 for global uniqueness
/// IDs are generated locally before any backend communication
class UuidGenerator {
  UuidGenerator._();

  static const _uuid = Uuid();

  /// Generates a new UUID v4
  /// 
  /// This ID is generated locally in Flutter before sync
  /// Backend validates uniqueness via UNIQUE constraint
  static String generate() {
    return _uuid.v4();
  }
}

