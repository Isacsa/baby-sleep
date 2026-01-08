import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:temp_flutter/core/config/supabase_config.dart';
import 'package:temp_flutter/data/datasources/remote/supabase_client.dart';

/// Supabase client implementation
/// 
/// Manages Supabase client lifecycle and provides authenticated access
/// Uses singleton pattern - only one client instance per app
class SupabaseClientImpl implements SupabaseClient {
  static SupabaseClientImpl? _instance;
  static bool _initialized = false;

  SupabaseClientImpl._();

  /// Gets the singleton instance
  static SupabaseClientImpl get instance {
    _instance ??= SupabaseClientImpl._();
    return _instance!;
  }

  /// Initializes Supabase client
  /// Must be called once during app startup
  static Future<void> initialize() async {
    if (_initialized) return;

    await SupabaseConfig.initialize();
    
    if (!SupabaseConfig.isConfigured) {
      throw StateError(
        'Supabase not configured. '
        'Create .env file with SUPABASE_URL and SUPABASE_ANON_KEY.',
      );
    }

    await sb.Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );

    _initialized = true;
  }

  /// Gets raw Supabase client
  @override
  sb.SupabaseClient get client {
    _ensureInitialized();
    return sb.Supabase.instance.client;
  }

  /// Gets current user ID (auth.uid())
  @override
  String? get currentUserId {
    _ensureInitialized();
    return sb.Supabase.instance.client.auth.currentUser?.id;
  }

  /// Checks if user is authenticated
  @override
  bool get isAuthenticated {
    _ensureInitialized();
    return sb.Supabase.instance.client.auth.currentUser != null;
  }

  /// Gets current auth session
  sb.Session? get currentSession {
    _ensureInitialized();
    return sb.Supabase.instance.client.auth.currentSession;
  }

  /// Signs out current user
  Future<void> signOut() async {
    _ensureInitialized();
    await sb.Supabase.instance.client.auth.signOut();
  }

  static void _ensureInitialized() {
    if (!_initialized) {
      throw StateError(
        'SupabaseClient not initialized. '
        'Call SupabaseClientImpl.initialize() during app startup.',
      );
    }
  }
}

