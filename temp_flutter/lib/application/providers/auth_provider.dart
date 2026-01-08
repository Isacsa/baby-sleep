import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:temp_flutter/domain/entities/user.dart';

part 'auth_provider.g.dart';

/// Auth provider
/// 
/// Manages authenticated user state
/// Source of truth: Supabase Auth
@riverpod
class Auth extends _$Auth {
  @override
  User? build() {
    // Try to restore session from Supabase
    _initFromSupabase();
    return null;
  }

  /// Initializes from Supabase Auth (restore session)
  void _initFromSupabase() {
    try {
      final supabaseUser = supabase.Supabase.instance.client.auth.currentUser;
      if (supabaseUser != null) {
        state = User(
          id: supabaseUser.id,
          email: supabaseUser.email,
        );
      }
      
      // Listen to auth state changes
      supabase.Supabase.instance.client.auth.onAuthStateChange.listen((data) {
        final session = data.session;
        if (session != null) {
          state = User(
            id: session.user.id,
            email: session.user.email,
          );
        } else {
          state = null;
        }
      });
    } catch (e) {
      // Supabase not initialized yet - will be null
      state = null;
    }
  }

  /// Sets authenticated user
  void setUser(User user) {
    state = user;
  }

  /// Clears authenticated user (logout)
  Future<void> clearUser() async {
    try {
      await supabase.Supabase.instance.client.auth.signOut();
    } catch (e) {
      // Ignore errors, just clear local state
    }
    state = null;
  }

  /// Sends magic link to email
  Future<void> sendMagicLink(String email) async {
    try {
      await supabase.Supabase.instance.client.auth.signInWithOtp(
        email: email,
      );
    } catch (e) {
      // Handle error - for smoke test, just log
      // ignore: avoid_print
      print('Magic link error: $e');
    }
  }
}

