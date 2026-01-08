// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sleep_state_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$sleepStateNotifierHash() =>
    r'c22f0b423959b9b1368c777aaa1a2c7f82aaf763';

/// Sleep state provider
///
/// Provides derived sleep state from events
/// Recalculates when events change
///
/// Copied from [SleepStateNotifier].
@ProviderFor(SleepStateNotifier)
final sleepStateNotifierProvider =
    AutoDisposeNotifierProvider<SleepStateNotifier, SleepState>.internal(
      SleepStateNotifier.new,
      name: r'sleepStateNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$sleepStateNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$SleepStateNotifier = AutoDisposeNotifier<SleepState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
