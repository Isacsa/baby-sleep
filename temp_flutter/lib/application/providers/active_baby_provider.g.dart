// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'active_baby_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$activeBabyHash() => r'539eb78f2cd503e305ef1aa7a2955779020c9941';

/// Active baby provider
///
/// Manages currently selected baby (device-scoped)
/// Other providers depend on this to filter data
/// Persistence: SharedPreferences (local, not synced)
///
/// Copied from [ActiveBaby].
@ProviderFor(ActiveBaby)
final activeBabyProvider =
    AutoDisposeNotifierProvider<ActiveBaby, Baby?>.internal(
      ActiveBaby.new,
      name: r'activeBabyProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$activeBabyHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$ActiveBaby = AutoDisposeNotifier<Baby?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
