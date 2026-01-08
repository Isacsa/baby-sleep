// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$syncHash() => r'e4fc21db4a655097b4d9115b82326898b5ca6b3a';

/// Sync provider
///
/// Manages synchronization state and operations
/// Exposes sync state to UI (idle/syncing/success/error)
///
/// Copied from [Sync].
@ProviderFor(Sync)
final syncProvider = AutoDisposeNotifierProvider<Sync, SyncState>.internal(
  Sync.new,
  name: r'syncProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$syncHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$Sync = AutoDisposeNotifier<SyncState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
