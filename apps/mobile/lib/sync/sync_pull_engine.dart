import 'package:temp_flutter/core/types/result.dart';
import 'package:temp_flutter/core/errors/failures.dart';
import 'package:temp_flutter/sync/sync_state.dart';
import 'package:temp_flutter/sync/sync_strategies/pull_strategy_impl.dart';
import 'package:temp_flutter/data/datasources/local/sleep_event_local_datasource.dart';
import 'package:temp_flutter/data/datasources/remote/sleep_event_remote_datasource.dart';
import 'package:temp_flutter/data/datasources/local/baby_local_datasource.dart';

/// Callback for sync state changes
typedef SyncStateCallback = void Function(SyncState state);

/// Sync Pull Engine
/// 
/// Handles pulling remote events from Supabase backend
/// Only implements PULL - no PUSH in this engine
/// 
/// Features:
/// - Incremental pull (based on lastSyncedAt)
/// - Idempotent (re-running is safe)
/// - Transient error handling (stops and retries later)
/// - State reporting (idle/syncing/success/error)
class SyncPullEngine {
  final SleepEventLocalDataSource _localDataSource;
  final SleepEventRemoteDataSource _remoteDataSource;
  final BabyLocalDataSource _babyDataSource;
  
  late final PullStrategyImpl _pullStrategy;
  
  SyncState _currentState = SyncState.initial();
  SyncStateCallback? _onStateChanged;

  SyncPullEngine({
    required SleepEventLocalDataSource localDataSource,
    required SleepEventRemoteDataSource remoteDataSource,
    required BabyLocalDataSource babyDataSource,
  })  : _localDataSource = localDataSource,
        _remoteDataSource = remoteDataSource,
        _babyDataSource = babyDataSource {
    _pullStrategy = PullStrategyImpl(
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

  /// Pulls new remote events for a specific baby
  /// 
  /// [babyId] - Baby ID to pull events for
  /// 
  /// Returns sync result with state
  Future<Result<SyncState, Failure>> pullForBaby(String babyId) async {
    // Update state to syncing
    _updateState(SyncState.syncing(pendingEventsCount: 0));

    // Execute pull
    final pullResult = await _pullStrategy.pullEventsForBaby(babyId);

    if (pullResult.isError) {
      final errorState = SyncState.error(
        errorMessage: pullResult.failureOrNull!.message,
        lastSyncedAt: _currentState.lastSyncedAt,
      );
      _updateState(errorState);
      return Error(pullResult.failureOrNull!);
    }

    final result = pullResult.dataOrNull!;
    
    // Success
    _updateState(SyncState.success(
      lastSyncedAt: result.newLastSyncedAt ?? DateTime.now().toUtc(),
    ));

    return Success(_currentState);
  }

  /// Pulls events for all accessible babies
  /// 
  /// Fetches baby list from local storage
  Future<Result<SyncState, Failure>> pullAll() async {
    // Get all accessible babies
    final babiesResult = await _babyDataSource.getBabies();
    
    if (babiesResult.isError) {
      final errorState = SyncState.error(
        errorMessage: babiesResult.failureOrNull!.message,
        lastSyncedAt: _currentState.lastSyncedAt,
      );
      _updateState(errorState);
      return Error(babiesResult.failureOrNull!);
    }

    final babies = babiesResult.dataOrNull ?? [];
    
    if (babies.isEmpty) {
      _updateState(SyncState.success(lastSyncedAt: DateTime.now().toUtc()));
      return Success(_currentState);
    }

    // Update state to syncing
    _updateState(SyncState.syncing(pendingEventsCount: babies.length));

    // Get baby IDs
    final babyIds = babies.map((baby) => baby.id).toList();

    // Execute pull for all babies
    final pullResult = await _pullStrategy.pullEventsForBabies(babyIds);

    if (pullResult.isError) {
      final errorState = SyncState.error(
        errorMessage: pullResult.failureOrNull!.message,
        lastSyncedAt: _currentState.lastSyncedAt,
      );
      _updateState(errorState);
      return Error(pullResult.failureOrNull!);
    }

    final result = pullResult.dataOrNull!;
    
    // Success
    _updateState(SyncState.success(
      lastSyncedAt: result.newLastSyncedAt ?? DateTime.now().toUtc(),
    ));

    return Success(_currentState);
  }

  /// Updates state and notifies listener
  void _updateState(SyncState newState) {
    _currentState = newState;
    _onStateChanged?.call(newState);
  }
}

