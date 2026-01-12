/// Supabase client wrapper
/// 
/// Abstracts Supabase client initialization and configuration
/// Provides access to authenticated Supabase instance
abstract class SupabaseClient {
  /// Gets authenticated Supabase client
  /// 
  /// Returns null if not authenticated
  dynamic get client;

  /// Gets current user ID (auth.uid())
  String? get currentUserId;

  /// Checks if user is authenticated
  bool get isAuthenticated;
}

