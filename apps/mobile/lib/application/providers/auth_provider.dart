import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:temp_flutter/data/datasources/remote/supabase_client_impl.dart';
import 'package:temp_flutter/domain/entities/user.dart';

part 'auth_provider.g.dart';

/// Auth provider
/// 
/// Manages authenticated user state
/// Source of truth: Supabase Auth
/// 
/// Note: Supabase must be initialized in main() before this provider is used
@riverpod
class Auth extends _$Auth {
  late final SupabaseClientImpl _supabaseClient;
  StreamSubscription? _authSubscription;

  @override
  User? build() {
    // Get Supabase client instance (initialized in main())
    _supabaseClient = SupabaseClientImpl.instance;
    
    // Check for existing session FIRST (before returning)
    // This handles session restoration on app restart
    try {
      final session = _supabaseClient.currentSession;
      if (session != null) {
        // Clean up any existing subscription before returning
        _authSubscription?.cancel();
        _setupAuthListener();
        return User(
          id: session.user.id,
          email: session.user.email,
        );
      }
      
      // Also check currentUser as fallback
      final user = _supabaseClient.client.auth.currentUser;
      if (user != null) {
        _authSubscription?.cancel();
        _setupAuthListener();
        return User(
          id: user.id,
          email: user.email,
        );
      }
      
      // Set up listener for auth state changes
      // This handles Magic Link completion and other auth events
      _setupAuthListener();
      
      // Clean up subscription when provider is disposed
      ref.onDispose(() {
        _authSubscription?.cancel();
        _authSubscription = null;
      });
      
      return null;
    } catch (e) {
      // Supabase not initialized - should not happen if main() is correct
      // ignore: avoid_print
      print('Auth init error: $e');
      return null;
    }
  }

  /// Sets up listener for auth state changes
  void _setupAuthListener() {
    _authSubscription = _supabaseClient.client.auth.onAuthStateChange.listen(
      (data) {
        final session = data.session;
        if (session != null) {
          state = User(
            id: session.user.id,
            email: session.user.email,
          );
        } else {
          state = null;
        }
      },
    );
  }

  /// Sets authenticated user
  void setUser(User user) {
    state = user;
  }

  /// Clears authenticated user (logout)
  Future<void> clearUser() async {
    try {
      await _supabaseClient.client.auth.signOut();
    } catch (e) {
      // Ignore errors, just clear local state
      // ignore: avoid_print
      print('Sign out error: $e');
    }
    state = null;
  }

  /// Sends magic link to email
  Future<void> sendMagicLink(String email) async {
    try {
      await _supabaseClient.client.auth.signInWithOtp(
        email: email,
      );
    } catch (e) {
      // Handle error - for smoke test, just log
      // ignore: avoid_print
      print('Magic link error: $e');
      rethrow; // Re-throw so UI can handle it
    }
  }
}

