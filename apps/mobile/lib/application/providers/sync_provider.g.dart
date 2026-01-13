// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$syncHash() => r'b94e975927bd802a99b7a744975f48f94bdaebea';

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
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
