import '../../core/types/result.dart';
import '../../core/errors/failures.dart';
import '../../domain/entities/sleep_event.dart';
import '../../domain/repositories/sleep_event_repository.dart';
import 'sync_state.dart';
import 'sync_strategies/push_strategy.dart';
import 'sync_strategies/pull_strategy.dart';
import 'conflict_resolution/conflict_resolver_impl.dart';

/// Sync engine
/// 
/// Orchestrates synchronization between local and remote
/// Handles push (local -> remote) and pull (remote -> local)
/// Resolves conflicts using last-write-wins
abstract class SyncEngine {
  /// Syncs events for a baby
  /// 
  /// 1. Push: Sends unsynced local events to backend
  /// 2. Pull: Receives new remote events from backend
  /// 3. Merge: Combines local and remote events
  /// 4. Resolve: Applies conflict resolution
  /// 
  /// Returns sync state
  Future<Result<SyncState, Failure>> sync(String babyId);

  /// Gets current sync state
  SyncState getCurrentState();

  /// Sets last synced timestamp
  Future<void> setLastSyncedAt(String babyId, DateTime timestamp);

  /// Gets last synced timestamp
  Future<DateTime?> getLastSyncedAt(String babyId);
}

