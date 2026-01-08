import 'package:temp_flutter/domain/entities/sleep_event.dart';
import 'package:temp_flutter/domain/repositories/sleep_event_repository.dart';
import 'package:temp_flutter/domain/common/result.dart';
import 'package:temp_flutter/core/types/result.dart' as core;
import 'package:temp_flutter/data/datasources/local/sleep_event_local_datasource.dart';
import 'package:temp_flutter/data/datasources/remote/sleep_event_remote_datasource.dart';
import 'package:temp_flutter/data/mappers/sleep_event_mapper.dart';
import 'package:temp_flutter/data/adapters/result_adapter.dart';

/// Sleep event repository implementation
/// 
/// Combines local and remote data sources
/// Returns local data immediately (offline-first)
/// Syncs with remote in background
class SleepEventRepositoryImpl implements SleepEventRepository {
  final SleepEventLocalDataSource localDataSource;
  final SleepEventRemoteDataSource remoteDataSource;

  SleepEventRepositoryImpl({
    required this.localDataSource,
    required this.remoteDataSource,
  });

  @override
  Future<DomainResult<List<SleepEvent>>> getSleepEventsTimeline({
    required String babyId,
    bool includeCorrected = false,
    int? limit,
    int? offset,
  }) async {
    // Return local data immediately (offline-first)
    final localResult = await localDataSource.getEventsTimeline(
      babyId: babyId,
      includeCorrected: includeCorrected,
      limit: limit,
      offset: offset,
    );

    return switch (localResult) {
      core.Success(:final data) => DomainSuccess(SleepEventMapper.toDomainList(data)),
      core.Error(:final failure) => DomainError(ResultAdapter.failureToDomain(failure)),
    };
  }

  @override
  Future<DomainResult<List<SleepEvent>>> getUnsyncedEvents(String babyId) async {
    // Return local unsynced events
    final localResult = await localDataSource.getUnsyncedEvents(babyId);
    
    return switch (localResult) {
      core.Success(:final data) => DomainSuccess(SleepEventMapper.toDomainList(data)),
      core.Error(:final failure) => DomainError(ResultAdapter.failureToDomain(failure)),
    };
  }

  @override
  Future<DomainResult<List<SleepEvent>>> getNewRemoteEvents({
    required String babyId,
    required DateTime lastSyncedAt,
    int? limit,
  }) async {
    // Get from remote
    final remoteResult = await remoteDataSource.getNewRemoteEvents(
      babyId: babyId,
      lastSyncedAt: lastSyncedAt,
      limit: limit,
    );

    return switch (remoteResult) {
      core.Success(:final data) => DomainSuccess(SleepEventMapper.toDomainList(data)),
      core.Error(:final failure) => DomainError(ResultAdapter.failureToDomain(failure)),
    };
  }

  @override
  Future<DomainResult<SleepEvent>> createSleepEvent(SleepEvent event) async {
    final model = SleepEventMapper.toModel(event);

    // Save locally first (offline-first)
    final localResult = await localDataSource.saveEvent(model);
    
    return switch (localResult) {
      core.Success() => DomainSuccess(event),
      core.Error(:final failure) => DomainError(ResultAdapter.failureToDomain(failure)),
    };
  }

  @override
  Future<DomainResult<SleepEvent>> updateSleepEvent(SleepEvent event) async {
    final model = SleepEventMapper.toModel(event);

    // Update locally first (offline-first)
    final localResult = await localDataSource.updateEvent(model);
    
    return switch (localResult) {
      core.Success() => DomainSuccess(event),
      core.Error(:final failure) => DomainError(ResultAdapter.failureToDomain(failure)),
    };
  }

  @override
  Future<DomainResult<SleepEvent?>> getEventById(String eventId) async {
    // Return local data immediately (offline-first)
    final localResult = await localDataSource.getEventById(eventId);
    
    return switch (localResult) {
      core.Success(:final data) => DomainSuccess(data?.toDomain()),
      core.Error(:final failure) => DomainError(ResultAdapter.failureToDomain(failure)),
    };
  }
}

