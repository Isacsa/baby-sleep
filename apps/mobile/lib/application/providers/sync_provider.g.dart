// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$syncHash() => r'a4c2502c1fd17d0a7bd2f9a101992732b16165c4';

/// Sync provider
///
/// Manages synchronization state and operations
/// Exposes sync state to UI (idle/syncing/success/error)
///
/// LAYERED SYNC STRATEGY:
/// Push operations use LayeredSyncOrchestrator which syncs in order:
/// 1. Babies first (must exist before caregivers)
/// 2. Caregivers second (must exist before events can reference them)
/// 3. SleepEvents last (depend on caregiver existing remotely)
///
/// This ensures FK integrity in the backend and prevents the error:
/// "Caregiver does not exist, is inactive, or does not belong to this baby"
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
String _$pendingSyncCountHash() => r'fe2bd7fa25672510d1729c1b2b6c950138f7a299';

/// Provider for pending sync count for active baby
///
/// FIX P5: Used to show badge on sync icon in UI
///
/// Copied from [PendingSyncCount].
@ProviderFor(PendingSyncCount)
final pendingSyncCountProvider =
    AutoDisposeAsyncNotifierProvider<PendingSyncCount, int>.internal(
      PendingSyncCount.new,
      name: r'pendingSyncCountProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$pendingSyncCountHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$PendingSyncCount = AutoDisposeAsyncNotifier<int>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
