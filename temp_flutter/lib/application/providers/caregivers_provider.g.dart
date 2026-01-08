// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'caregivers_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$caregiversNotifierHash() =>
    r'1cfd50f85d780c73c97839cee8e0f9d50b7507f2';

/// Caregivers provider
///
/// Provides list of caregivers for the active baby
/// Reads from SQLite (offline-first)
///
/// Copied from [CaregiversNotifier].
@ProviderFor(CaregiversNotifier)
final caregiversNotifierProvider =
    AutoDisposeAsyncNotifierProvider<
      CaregiversNotifier,
      List<Caregiver>
    >.internal(
      CaregiversNotifier.new,
      name: r'caregiversNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$caregiversNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$CaregiversNotifier = AutoDisposeAsyncNotifier<List<Caregiver>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
