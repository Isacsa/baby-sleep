import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:temp_flutter/core/types/result.dart';
import 'package:temp_flutter/domain/entities/sleep_event.dart';
import 'package:temp_flutter/domain/common/result.dart' as domain;
import 'package:temp_flutter/data/datasources/local/sleep_event_local_datasource_impl.dart';
import 'package:temp_flutter/data/datasources/local/caregiver_local_datasource_impl.dart';
import 'package:temp_flutter/data/repositories/sleep_event_repository_impl.dart';
import 'package:temp_flutter/data/repositories/caregiver_repository_impl.dart';
import 'package:temp_flutter/data/datasources/remote/sleep_event_remote_datasource_impl.dart';
import 'package:temp_flutter/data/datasources/remote/caregiver_remote_datasource_impl.dart';
import 'package:temp_flutter/domain/use_cases/sleep/create_sleep_start.dart';
import 'package:temp_flutter/domain/use_cases/sleep/create_sleep_end.dart';
import 'package:temp_flutter/core/utils/uuid_generator.dart';
import 'package:temp_flutter/core/utils/device_id_manager.dart';
import 'active_baby_provider.dart';
import 'auth_provider.dart';

part 'sleep_events_provider.g.dart';

/// Sleep events provider
/// 
/// Provides timeline of sleep events for active baby
/// Events are ordered by timestamp DESC, createdAt DESC
/// Updates when event is created locally or after sync
/// 
/// Also exposes actions for creating events (offline-first)
@riverpod
class SleepEventsNotifier extends _$SleepEventsNotifier {
  // Use getters to create fresh instances on each access
  // This avoids LateInitializationError when provider rebuilds
  SleepEventLocalDataSourceImpl get _localDataSource => SleepEventLocalDataSourceImpl();

  CreateSleepStart get _createSleepStartUseCase {
    final sleepEventRepository = SleepEventRepositoryImpl(
      localDataSource: _localDataSource,
      remoteDataSource: SleepEventRemoteDataSourceImpl(),
    );
    
    final caregiverRepository = CaregiverRepositoryImpl(
      localDataSource: CaregiverLocalDataSourceImpl(),
      remoteDataSource: CaregiverRemoteDataSourceImpl(),
    );
    
    return CreateSleepStart(
      sleepEventRepository: sleepEventRepository,
      caregiverRepository: caregiverRepository,
    );
  }

  CreateSleepEnd get _createSleepEndUseCase {
    final sleepEventRepository = SleepEventRepositoryImpl(
      localDataSource: _localDataSource,
      remoteDataSource: SleepEventRemoteDataSourceImpl(),
    );
    
    final caregiverRepository = CaregiverRepositoryImpl(
      localDataSource: CaregiverLocalDataSourceImpl(),
      remoteDataSource: CaregiverRemoteDataSourceImpl(),
    );
    
    return CreateSleepEnd(
      sleepEventRepository: sleepEventRepository,
      caregiverRepository: caregiverRepository,
    );
  }

  @override
  Future<List<SleepEvent>> build() async {
    final activeBaby = ref.watch(activeBabyProvider);
    
    if (activeBaby == null) {
      return [];
    }

    return _loadEvents(activeBaby.id);
  }

  /// Loads events from SQLite
  Future<List<SleepEvent>> _loadEvents(String babyId) async {
    final result = await _localDataSource.getEventsTimeline(
      babyId: babyId,
      includeCorrected: false,
      limit: 100,
    );
    
    switch (result) {
      case Success(:final data):
        return data.map((model) => model.toDomain()).toList();
      case Error(:final failure):
        throw Exception(failure.message);
    }
  }

  /// Refreshes events from local database
  Future<void> refresh() async {
    final activeBaby = ref.read(activeBabyProvider);
    if (activeBaby == null) {
      state = const AsyncData([]);
      return;
    }
    
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _loadEvents(activeBaby.id));
  }

  /// Adds a new event (after local persistence)
  void addEvent(SleepEvent event) {
    final currentEvents = state.value ?? [];
    state = AsyncData([event, ...currentEvents]);
  }

  /// Internal helper for creating SleepStart events
  /// 
  /// Validates preconditions and creates the event at the given timestamp.
  /// Used by both createSleepStart() and createSleepStartAt().
  /// 
  /// Throws [SleepEventException] if creation fails (e.g., no caregiver permission).
  Future<void> _createSleepStartInternal(DateTime timestamp) async {
    final user = ref.read(authProvider);
    final activeBaby = ref.read(activeBabyProvider);
    
    if (user == null) {
      throw const SleepEventException('Utilizador não autenticado');
    }
    
    if (activeBaby == null) {
      throw const SleepEventException('Nenhum bebé selecionado');
    }
    
    final now = DateTime.now().toUtc();
    final eventId = UuidGenerator.generate();
    final deviceId = await DeviceIdManager.getDeviceId();
    
    final result = await _createSleepStartUseCase.execute(
      babyId: activeBaby.id,
      timestamp: timestamp.toUtc(),
      userId: user.id,
      eventId: eventId,
      deviceId: deviceId,
      createdAt: now,
    );
    
    switch (result) {
      case domain.DomainSuccess(:final data):
        addEvent(data);
      case domain.DomainError(:final failure):
        throw SleepEventException(failure.message);
    }
  }

  /// Creates a SleepStart event (offline-first)
  /// 
  /// Preconditions (checked in UI, validated in use case):
  /// - User is authenticated
  /// - Active baby is selected
  /// - User has write permission (owner/editor)
  /// 
  /// Throws [SleepEventException] if creation fails (e.g., no caregiver permission).
  /// UI should catch this and display error message.
  Future<void> createSleepStart() async {
    await _createSleepStartInternal(DateTime.now().toUtc());
  }

  /// Creates a SleepStart event at a specific time (for quick chips)
  /// 
  /// Same as createSleepStart but with a custom timestamp
  /// Used for "Started 5/10/15 min ago" and "Outra hora" features
  /// 
  /// Throws [SleepEventException] if creation fails (e.g., no caregiver permission).
  /// UI should catch this and display error message.
  Future<void> createSleepStartAt(DateTime timestamp) async {
    await _createSleepStartInternal(timestamp);
  }

  /// Creates a SleepEnd event (offline-first)
  /// 
  /// Preconditions (checked in UI, validated in use case):
  /// - User is authenticated
  /// - Active baby is selected
  /// - User has write permission (owner/editor)
  /// 
  /// Throws [SleepEventException] if creation fails (e.g., no caregiver permission).
  /// UI should catch this and display error message.
  Future<void> createSleepEnd() async {
    final user = ref.read(authProvider);
    final activeBaby = ref.read(activeBabyProvider);
    
    if (user == null) {
      throw const SleepEventException('Utilizador não autenticado');
    }
    
    if (activeBaby == null) {
      throw const SleepEventException('Nenhum bebé selecionado');
    }
    
    final now = DateTime.now().toUtc();
    final eventId = UuidGenerator.generate();
    final deviceId = await DeviceIdManager.getDeviceId();
    
    final result = await _createSleepEndUseCase.execute(
      babyId: activeBaby.id,
      timestamp: now,
      userId: user.id,
      eventId: eventId,
      deviceId: deviceId,
      createdAt: now,
    );
    
    switch (result) {
      case domain.DomainSuccess(:final data):
        addEvent(data);
      case domain.DomainError(:final failure):
        throw SleepEventException(failure.message);
    }
  }
}

/// Exception thrown when sleep event creation fails
class SleepEventException implements Exception {
  final String message;
  const SleepEventException(this.message);
  
  @override
  String toString() => message;
}
