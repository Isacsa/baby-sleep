import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../sync/sync_state.dart';
import '../../sync/sync_engine.dart';

part 'sync_provider.g.dart';

/// Sync provider
/// 
/// Manages synchronization state
/// Updates during sync operations
@riverpod
class Sync extends _$Sync {
  @override
  SyncState build() {
    return SyncState.initial();
  }

  /// Starts sync for active baby
  Future<void> sync(String babyId) async {
    state = SyncState.syncing(pendingEventsCount: 0);
    
    // TODO: Inject SyncEngine
    // final engine = ref.read(syncEngineProvider);
    // final result = await engine.sync(babyId);
    // 
    // result.when(
    //   success: (newState) => state = newState,
    //   error: (failure) => state = SyncState.error(
    //     errorMessage: failure.message,
    //     lastSyncedAt: state.lastSyncedAt,
    //   ),
    // );
  }

  /// Updates sync state
  void updateState(SyncState newState) {
    state = newState;
  }
}

