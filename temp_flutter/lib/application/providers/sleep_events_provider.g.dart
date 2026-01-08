// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sleep_events_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$sleepEventsNotifierHash() =>
    r'0b9e2e92ad3227f9b5d9790c83da9df7a193e50a';

/// Sleep events provider
///
/// Provides timeline of sleep events for active baby
/// Events are ordered by timestamp DESC, createdAt DESC
/// Updates when event is created locally or after sync
///
/// Also exposes actions for creating events (offline-first)
///
/// Copied from [SleepEventsNotifier].
@ProviderFor(SleepEventsNotifier)
final sleepEventsNotifierProvider =
    AutoDisposeAsyncNotifierProvider<
      SleepEventsNotifier,
      List<SleepEvent>
    >.internal(
      SleepEventsNotifier.new,
      name: r'sleepEventsNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$sleepEventsNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$SleepEventsNotifier = AutoDisposeAsyncNotifier<List<SleepEvent>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
