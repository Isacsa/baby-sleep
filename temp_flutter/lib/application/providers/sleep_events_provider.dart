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
  late final SleepEventLocalDataSourceImpl _localDataSource;
  late final CreateSleepStart _createSleepStartUseCase;
  late final CreateSleepEnd _createSleepEndUseCase;

  @override
  Future<List<SleepEvent>> build() async {
    _initDependencies();
    
    final activeBaby = ref.watch(activeBabyProvider);
    
    if (activeBaby == null) {
      return [];
    }

    return _loadEvents(activeBaby.id);
  }

  /// Initializes dependencies (use cases, repositories)
  void _initDependencies() {
    _localDataSource = SleepEventLocalDataSourceImpl();
    
    // Create repositories for use cases
    final sleepEventRepository = SleepEventRepositoryImpl(
      localDataSource: _localDataSource,
      remoteDataSource: SleepEventRemoteDataSourceImpl(),
    );
    
    final caregiverRepository = CaregiverRepositoryImpl(
      localDataSource: CaregiverLocalDataSourceImpl(),
      remoteDataSource: CaregiverRemoteDataSourceImpl(),
    );
    
    _createSleepStartUseCase = CreateSleepStart(
      sleepEventRepository: sleepEventRepository,
      caregiverRepository: caregiverRepository,
    );
    
    _createSleepEndUseCase = CreateSleepEnd(
      sleepEventRepository: sleepEventRepository,
      caregiverRepository: caregiverRepository,
    );
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

  /// Creates a SleepStart event (offline-first)
  /// 
  /// Preconditions (checked in UI, validated in use case):
  /// - User is authenticated
  /// - Active baby is selected
  /// - User has write permission (owner/editor)
  Future<void> createSleepStart() async {
    final user = ref.read(authProvider);
    final activeBaby = ref.read(activeBabyProvider);
    
    if (user == null || activeBaby == null) {
      return;
    }
    
    final now = DateTime.now().toUtc();
    final eventId = UuidGenerator.generate();
    final deviceId = await DeviceIdManager.getDeviceId();
    
    final result = await _createSleepStartUseCase.execute(
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
        // ignore: avoid_print
        print('Error creating SleepStart: ${failure.message}');
    }
  }

  /// Creates a SleepEnd event (offline-first)
  /// 
  /// Preconditions (checked in UI, validated in use case):
  /// - User is authenticated
  /// - Active baby is selected
  /// - User has write permission (owner/editor)
  Future<void> createSleepEnd() async {
    final user = ref.read(authProvider);
    final activeBaby = ref.read(activeBabyProvider);
    
    if (user == null || activeBaby == null) {
      return;
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
        // ignore: avoid_print
        print('Error creating SleepEnd: ${failure.message}');
    }
  }
}
