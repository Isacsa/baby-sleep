import '../../core/types/result.dart';
import '../../core/errors/failures.dart';
import '../../domain/entities/sleep_event.dart';
import '../../domain/repositories/sleep_event_repository.dart';
import '../datasources/local/sleep_event_local_datasource.dart';
import '../datasources/remote/sleep_event_remote_datasource.dart';
import '../mappers/sleep_event_mapper.dart';

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
  Future<Result<List<SleepEvent>, Failure>> getSleepEventsTimeline({
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

    if (localResult.isError) {
      return Error(localResult.failureOrNull!);
    }

    final localEvents = localResult.dataOrNull ?? [];
    return Success(SleepEventMapper.toDomainList(localEvents));
  }

  @override
  Future<Result<List<SleepEvent>, Failure>> getUnsyncedEvents(String babyId) async {
    // Return local unsynced events
    final localResult = await localDataSource.getUnsyncedEvents(babyId);
    if (localResult.isError) {
      return Error(localResult.failureOrNull!);
    }

    final localEvents = localResult.dataOrNull ?? [];
    return Success(SleepEventMapper.toDomainList(localEvents));
  }

  @override
  Future<Result<List<SleepEvent>, Failure>> getNewRemoteEvents({
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

    if (remoteResult.isError) {
      return Error(remoteResult.failureOrNull!);
    }

    final remoteEvents = remoteResult.dataOrNull ?? [];
    return Success(SleepEventMapper.toDomainList(remoteEvents));
  }

  @override
  Future<Result<SleepEvent, Failure>> createSleepEvent(SleepEvent event) async {
    final model = SleepEventMapper.toModel(event);

    // Save locally first (offline-first)
    final localResult = await localDataSource.saveEvent(model);
    if (localResult.isError) {
      return Error(localResult.failureOrNull!);
    }

    // Return immediately (sync will happen in background)
    return Success(event);
  }

  @override
  Future<Result<SleepEvent, Failure>> updateSleepEvent(SleepEvent event) async {
    final model = SleepEventMapper.toModel(event);

    // Update locally first (offline-first)
    final localResult = await localDataSource.updateEvent(model);
    if (localResult.isError) {
      return Error(localResult.failureOrNull!);
    }

    // Return immediately (sync will happen in background)
    return Success(event);
  }

  @override
  Future<Result<SleepEvent?, Failure>> getEventById(String eventId) async {
    // Return local data immediately (offline-first)
    final localResult = await localDataSource.getEventById(eventId);
    if (localResult.isError) {
      return Error(localResult.failureOrNull!);
    }

    final localEvent = localResult.dataOrNull;
    if (localEvent != null) {
      return Success(localEvent.toDomain());
    }

    // Not found locally, return null
    return const Success(null);
  }
}

