// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'babies_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$babiesNotifierHash() => r'db6db420300c276f9f57cc9a72671ff4a7ec0384';

/// Babies provider
///
/// Provides list of accessible babies for current user
/// Reads from SQLite (offline-first)
/// Updates when sync completes or baby is created
///
/// Copied from [BabiesNotifier].
@ProviderFor(BabiesNotifier)
final babiesNotifierProvider =
    AutoDisposeAsyncNotifierProvider<BabiesNotifier, List<Baby>>.internal(
      BabiesNotifier.new,
      name: r'babiesNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$babiesNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$BabiesNotifier = AutoDisposeAsyncNotifier<List<Baby>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
