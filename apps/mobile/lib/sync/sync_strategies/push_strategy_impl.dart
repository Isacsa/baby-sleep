import 'package:temp_flutter/core/types/result.dart';
import 'package:temp_flutter/core/errors/failures.dart';
import 'package:temp_flutter/data/models/sleep_event_model.dart';
import 'package:temp_flutter/data/datasources/local/sleep_event_local_datasource.dart';
import 'package:temp_flutter/data/datasources/remote/sleep_event_remote_datasource.dart';
import 'package:temp_flutter/data/datasources/remote/sleep_event_remote_datasource_impl.dart';

/// Result of a single push operation
class PushEventResult {
  final String eventId;
  final bool success;
  final SyncErrorType? errorType;
  final String? errorMessage;

  const PushEventResult({
    required this.eventId,
    required this.success,
    this.errorType,
    this.errorMessage,
  });

  bool get isTransientError => errorType == SyncErrorType.transient;
  bool get isPermanentError => 
      errorType == SyncErrorType.permission || 
      errorType == SyncErrorType.validation;
}

/// Result of push batch operation
class PushBatchResult {
  final List<PushEventResult> results;
  final bool hasTransientError;
  final int successCount;
  final int permanentErrorCount;

  PushBatchResult({required this.results})
      : hasTransientError = results.any((r) => r.isTransientError),
        successCount = results.where((r) => r.success).length,
        permanentErrorCount = results.where((r) => r.isPermanentError).length;
}

/// Push strategy implementation
/// 
/// Handles sending local events to Supabase backend
/// Processes events in batches with proper error handling
class PushStrategyImpl {
  final SleepEventLocalDataSource _localDataSource;
  final SleepEventRemoteDataSource _remoteDataSource;
  
  /// Maximum events per batch
  static const int _batchSize = 10;

  PushStrategyImpl({
    required SleepEventLocalDataSource localDataSource,
    required SleepEventRemoteDataSource remoteDataSource,
  })  : _localDataSource = localDataSource,
        _remoteDataSource = remoteDataSource;

  /// Pushes unsynced events for a specific baby
  /// 
  /// Returns list of successfully synced event IDs
  /// Stops on transient errors (network)
  /// Continues on permanent errors (marks them)
  Future<Result<PushBatchResult, Failure>> pushEventsForBaby(String babyId) async {
    // Get unsynced events ordered by created_at ASC
    final unsyncedResult = await _localDataSource.getUnsyncedEvents(babyId);
    
    if (unsyncedResult.isError) {
      return Error(unsyncedResult.failureOrNull!);
    }

    final unsyncedEvents = unsyncedResult.dataOrNull ?? [];
    
    if (unsyncedEvents.isEmpty) {
      return Success(PushBatchResult(results: []));
    }

    return _pushEventsBatch(unsyncedEvents);
  }

  /// Pushes all unsynced events (global)
  /// 
  /// Used when syncing all data regardless of baby
  Future<Result<PushBatchResult, Failure>> pushAllUnsyncedEvents() async {
    final unsyncedResult = await _localDataSource.getAllUnsyncedEvents();
    
    if (unsyncedResult.isError) {
      return Error(unsyncedResult.failureOrNull!);
    }

    final unsyncedEvents = unsyncedResult.dataOrNull ?? [];
    
    if (unsyncedEvents.isEmpty) {
      return Success(PushBatchResult(results: []));
    }

    return _pushEventsBatch(unsyncedEvents);
  }

  /// Processes a batch of events
  Future<Result<PushBatchResult, Failure>> _pushEventsBatch(
    List<SleepEventModel> events,
  ) async {
    final results = <PushEventResult>[];

    // Process in smaller batches
    for (var i = 0; i < events.length; i += _batchSize) {
      final batchEnd = (i + _batchSize < events.length) ? i + _batchSize : events.length;
      final batch = events.sublist(i, batchEnd);

      for (final event in batch) {
        final result = await _pushSingleEvent(event);
        results.add(result);

        // Stop on transient error - don't process more events
        if (result.isTransientError) {
          return Success(PushBatchResult(results: results));
        }
      }
    }

    return Success(PushBatchResult(results: results));
  }

  /// Pushes a single event to remote
  Future<PushEventResult> _pushSingleEvent(SleepEventModel event) async {
    final remoteResult = await _remoteDataSource.createSleepEvent(event);

    if (remoteResult.isSuccess) {
      // Mark as synced locally
      final syncedAt = DateTime.now().toUtc();
      await _localDataSource.markEventSynced(event.id, syncedAt);

      return PushEventResult(
        eventId: event.id,
        success: true,
      );
    }

    // Handle error
    final failure = remoteResult.failureOrNull!;
    final errorType = _classifyFailure(failure);
    
    // Mark permanent errors in metadata
    if (errorType == SyncErrorType.permission || errorType == SyncErrorType.validation) {
      await _localDataSource.markEventSyncError(
        event.id,
        errorType.name,
        failure.message,
      );
    }

    return PushEventResult(
      eventId: event.id,
      success: false,
      errorType: errorType,
      errorMessage: failure.message,
    );
  }

  /// Classifies failure into sync error type
  SyncErrorType _classifyFailure(Failure failure) {
    if (failure is NetworkFailure) {
      return SyncErrorType.transient;
    }
    if (failure is PermissionFailure) {
      return SyncErrorType.permission;
    }
    if (failure is ValidationFailure) {
      return SyncErrorType.validation;
    }
    // Default to transient for unknown errors (safer - will retry)
    return SyncErrorType.transient;
  }
}

