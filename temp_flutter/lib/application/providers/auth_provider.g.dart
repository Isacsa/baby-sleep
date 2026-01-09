// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$authHash() => r'd82d84457939722601d92cff0593974df94ffaab';

/// Auth provider
///
/// Manages authenticated user state
/// Source of truth: Supabase Auth
///
/// Note: Supabase must be initialized in main() before this provider is used
///
/// Copied from [Auth].
@ProviderFor(Auth)
final authProvider = AutoDisposeNotifierProvider<Auth, User?>.internal(
  Auth.new,
  name: r'authProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$authHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$Auth = AutoDisposeNotifier<User?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
