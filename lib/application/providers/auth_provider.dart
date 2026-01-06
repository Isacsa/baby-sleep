import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../domain/entities/user.dart';

part 'auth_provider.g.dart';

/// Auth provider
/// 
/// Manages authenticated user state
/// Source of truth: Supabase Auth
@riverpod
class Auth extends _$Auth {
  @override
  User? build() {
    // TODO: Initialize from Supabase Auth
    return null;
  }

  /// Sets authenticated user
  void setUser(User user) {
    state = user;
  }

  /// Clears authenticated user (logout)
  void clearUser() {
    state = null;
  }
}

