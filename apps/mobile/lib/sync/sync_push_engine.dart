import 'package:temp_flutter/core/types/result.dart';
import 'package:temp_flutter/core/errors/failures.dart';
import 'package:temp_flutter/sync/sync_state.dart';
import 'package:temp_flutter/sync/sync_strategies/push_strategy_impl.dart';
import 'package:temp_flutter/data/datasources/local/sleep_event_local_datasource.dart';
import 'package:temp_flutter/data/datasources/remote/sleep_event_remote_datasource.dart';

/// Callback for sync state changes
typedef SyncStateCallback = void Function(SyncState state);

/// Sync Push Engine
/// 
/// Handles pushing local events to Supabase backend
/// Only implements PUSH - no PULL in this phase
/// 
/// Features:
/// - Ordered push (created_at ASC)
/// - Idempotent (re-running is safe)
/// - Transient error handling (stops and retries later)
/// - Permanent error handling (marks in metadata)
/// - State reporting (idle/syncing/success/error)
class SyncPushEngine {
  final SleepEventLocalDataSource _localDataSource;
  final SleepEventRemoteDataSource _remoteDataSource;
  
  late final PushStrategyImpl _pushStrategy;
  
  SyncState _currentState = SyncState.initial();
  SyncStateCallback? _onStateChanged;

  SyncPushEngine({
    required SleepEventLocalDataSource localDataSource,
    required SleepEventRemoteDataSource remoteDataSource,
  })  : _localDataSource = localDataSource,
        _remoteDataSource = remoteDataSource {
    _pushStrategy = PushStrategyImpl(
      localDataSource: _localDataSource,
      remoteDataSource: _remoteDataSource,
    );
  }

  /// Gets current sync state
  SyncState get currentState => _currentState;

  /// Sets callback for state changes
  set onStateChanged(SyncStateCallback? callback) {
    _onStateChanged = callback;
  }

  /// Pushes unsynced events for a specific baby
  /// 
  /// [babyId] - Baby ID to sync events for
  /// 
  /// Returns sync result with state
  Future<Result<SyncState, Failure>> pushForBaby(String babyId) async {
    // Get pending count for state
    final unsyncedResult = await _localDataSource.getUnsyncedEvents(babyId);
    final pendingCount = unsyncedResult.isSuccess 
        ? (unsyncedResult.dataOrNull?.length ?? 0) 
        : 0;

    if (pendingCount == 0) {
      _updateState(SyncState.success(lastSyncedAt: DateTime.now().toUtc()));
      return Success(_currentState);
    }

    // Update state to syncing
    _updateState(SyncState.syncing(pendingEventsCount: pendingCount));

    // Execute push
    final pushResult = await _pushStrategy.pushEventsForBaby(babyId);

    if (pushResult.isError) {
      final errorState = SyncState.error(
        errorMessage: pushResult.failureOrNull!.message,
        lastSyncedAt: _currentState.lastSyncedAt,
      );
      _updateState(errorState);
      return Error(pushResult.failureOrNull!);
    }

    final batchResult = pushResult.dataOrNull!;
    
    // Determine final state
    if (batchResult.hasTransientError) {
      // Transient error - will retry later
      _updateState(SyncState.error(
        errorMessage: 'Network error - will retry',
        lastSyncedAt: _currentState.lastSyncedAt,
      ).copyWith(
        pendingEventsCount: pendingCount - batchResult.successCount,
      ));
    } else if (batchResult.permanentErrorCount > 0) {
      // Some permanent errors but push completed
      _updateState(SyncState.success(
        lastSyncedAt: DateTime.now().toUtc(),
      ).copyWith(
        errorMessage: '${batchResult.permanentErrorCount} events failed permanently',
      ));
    } else {
      // Full success
      _updateState(SyncState.success(
        lastSyncedAt: DateTime.now().toUtc(),
      ));
    }

    return Success(_currentState);
  }

  /// Pushes all unsynced events (global sync)
  /// 
  /// Used when syncing all data regardless of baby
  Future<Result<SyncState, Failure>> pushAll() async {
    // Get all pending count
    final unsyncedResult = await _localDataSource.getAllUnsyncedEvents();
    final pendingCount = unsyncedResult.isSuccess 
        ? (unsyncedResult.dataOrNull?.length ?? 0) 
        : 0;

    if (pendingCount == 0) {
      _updateState(SyncState.success(lastSyncedAt: DateTime.now().toUtc()));
      return Success(_currentState);
    }

    // Update state to syncing
    _updateState(SyncState.syncing(pendingEventsCount: pendingCount));

    // Execute push
    final pushResult = await _pushStrategy.pushAllUnsyncedEvents();

    if (pushResult.isError) {
      final errorState = SyncState.error(
        errorMessage: pushResult.failureOrNull!.message,
        lastSyncedAt: _currentState.lastSyncedAt,
      );
      _updateState(errorState);
      return Error(pushResult.failureOrNull!);
    }

    final batchResult = pushResult.dataOrNull!;
    
    // Determine final state
    if (batchResult.hasTransientError) {
      _updateState(SyncState.error(
        errorMessage: 'Network error - will retry',
        lastSyncedAt: _currentState.lastSyncedAt,
      ).copyWith(
        pendingEventsCount: pendingCount - batchResult.successCount,
      ));
    } else if (batchResult.permanentErrorCount > 0) {
      _updateState(SyncState.success(
        lastSyncedAt: DateTime.now().toUtc(),
      ).copyWith(
        errorMessage: '${batchResult.permanentErrorCount} events failed permanently',
      ));
    } else {
      _updateState(SyncState.success(
        lastSyncedAt: DateTime.now().toUtc(),
      ));
    }

    return Success(_currentState);
  }

  /// Gets count of pending (unsynced) events for a baby
  Future<int> getPendingCount(String babyId) async {
    final result = await _localDataSource.getUnsyncedEvents(babyId);
    return result.isSuccess ? (result.dataOrNull?.length ?? 0) : 0;
  }

  /// Gets count of all pending (unsynced) events
  Future<int> getAllPendingCount() async {
    final result = await _localDataSource.getAllUnsyncedEvents();
    return result.isSuccess ? (result.dataOrNull?.length ?? 0) : 0;
  }

  /// Updates state and notifies listener
  void _updateState(SyncState newState) {
    _currentState = newState;
    _onStateChanged?.call(newState);
  }
}

