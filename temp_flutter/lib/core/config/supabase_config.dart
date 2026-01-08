import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Supabase configuration
/// 
/// Loads configuration from environment variables (.env file)
/// Never hardcode credentials in source code
class SupabaseConfig {
  SupabaseConfig._();

  static bool _initialized = false;

  /// Initialize configuration from .env file
  /// Must be called before accessing any config values
  static Future<void> initialize() async {
    if (_initialized) return;
    
    await dotenv.load(fileName: '.env');
    _initialized = true;
  }

  /// Supabase project URL
  /// Example: https://xxxxx.supabase.co
  static String get url {
    _ensureInitialized();
    final url = dotenv.env['SUPABASE_URL'];
    if (url == null || url.isEmpty) {
      throw StateError('SUPABASE_URL not configured in .env file');
    }
    return url;
  }

  /// Supabase anonymous key (public)
  /// Used for client-side auth and RLS
  static String get anonKey {
    _ensureInitialized();
    final key = dotenv.env['SUPABASE_ANON_KEY'];
    if (key == null || key.isEmpty) {
      throw StateError('SUPABASE_ANON_KEY not configured in .env file');
    }
    return key;
  }

  /// Check if all required config is present
  static bool get isConfigured {
    if (!_initialized) return false;
    
    final url = dotenv.env['SUPABASE_URL'];
    final key = dotenv.env['SUPABASE_ANON_KEY'];
    
    return url != null && url.isNotEmpty && 
           key != null && key.isNotEmpty;
  }

  static void _ensureInitialized() {
    if (!_initialized) {
      throw StateError(
        'SupabaseConfig not initialized. '
        'Call SupabaseConfig.initialize() before accessing config values.',
      );
    }
  }
}

