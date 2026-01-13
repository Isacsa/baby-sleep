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
import 'package:temp_flutter/data/models/sleep_event_model.dart';
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
    // ignore: avoid_print
    print('[SleepEventsProvider] _createSleepStartInternal called with: $timestamp');
    
    final user = ref.read(authProvider);
    final activeBaby = ref.read(activeBabyProvider);
    
    // ignore: avoid_print
    print('[SleepEventsProvider] user=${user?.id}, baby=${activeBaby?.id}');
    
    if (user == null) {
      throw const SleepEventException('Utilizador não autenticado');
    }
    
    if (activeBaby == null) {
      throw const SleepEventException('Nenhum bebé selecionado');
    }
    
    final now = DateTime.now().toUtc();
    final eventId = UuidGenerator.generate();
    final deviceId = await DeviceIdManager.getDeviceId();
    
    // ignore: avoid_print
    print('[SleepEventsProvider] Executing use case with timestamp=${timestamp.toUtc()}');
    
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
        // ignore: avoid_print
        print('[SleepEventsProvider] SleepStart created successfully: ${data.id}');
        addEvent(data);
      case domain.DomainError(:final failure):
        // ignore: avoid_print
        print('[SleepEventsProvider] SleepStart failed: ${failure.message}');
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

  /// Internal helper for creating SleepEnd events
  /// 
  /// Validates preconditions and creates the event at the given timestamp.
  /// Used by both createSleepEnd() and createSleepEndAt().
  /// 
  /// Throws [SleepEventException] if creation fails (e.g., no caregiver permission).
  Future<void> _createSleepEndInternal(DateTime timestamp) async {
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
    await _createSleepEndInternal(DateTime.now().toUtc());
  }

  /// Creates a SleepEnd event at a specific time (for retroactive logging)
  /// 
  /// Same as createSleepEnd but with a custom timestamp
  /// Used for "Registar sono completo" feature
  /// 
  /// Throws [SleepEventException] if creation fails (e.g., no caregiver permission).
  /// UI should catch this and display error message.
  Future<void> createSleepEndAt(DateTime timestamp) async {
    await _createSleepEndInternal(timestamp);
  }

  /// Creates a complete sleep session (both SleepStart and SleepEnd) atomically
  /// 
  /// GUARDRAIL 2: Uses real SQLite transaction - both events succeed or both fail.
  /// This prevents orphaned SleepStart if SleepEnd creation fails.
  /// 
  /// Validates:
  /// - end > start (order) in BOTH local and UTC
  /// - Both timestamps converted to UTC before persistence
  /// 
  /// Throws [SleepEventException] if either creation fails.
  Future<void> createSleepSession({
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    // ignore: avoid_print
    print('[SleepEventsProvider] createSleepSession: start=$startTime, end=$endTime');
    
    // Normalize timestamps to UTC first
    final startUtc = startTime.toUtc();
    final endUtc = endTime.toUtc();
    
    // GUARDRAIL 2: Validate order in both local AND UTC
    if (!endTime.isAfter(startTime)) {
      // ignore: avoid_print
      print('[SleepEventsProvider] Error: end <= start (local)');
      throw const SleepEventException('A hora de fim deve ser depois da hora de início');
    }
    
    if (!endUtc.isAfter(startUtc)) {
      // ignore: avoid_print
      print('[SleepEventsProvider] Error: endUtc <= startUtc');
      throw const SleepEventException('As horas ficaram inconsistentes. Confirma o dia do fim.');
    }

    final user = ref.read(authProvider);
    final activeBaby = ref.read(activeBabyProvider);
    
    // ignore: avoid_print
    print('[SleepEventsProvider] Session: user=${user?.id}, baby=${activeBaby?.id}');
    
    if (user == null) {
      throw const SleepEventException('Utilizador não autenticado');
    }
    
    if (activeBaby == null) {
      throw const SleepEventException('Nenhum bebé selecionado');
    }

    final now = DateTime.now().toUtc();
    final deviceId = await DeviceIdManager.getDeviceId();
    
    // Generate UUIDs for both events
    final startEventId = UuidGenerator.generate();
    final endEventId = UuidGenerator.generate();
    
    // ignore: avoid_print
    print('[SleepEventsProvider] Validating Start event: $startEventId at $startUtc');

    // STEP 1: Execute use cases with persist=false to VALIDATE only
    final startResult = await _createSleepStartUseCase.execute(
      babyId: activeBaby.id,
      timestamp: startUtc,
      userId: user.id,
      eventId: startEventId,
      deviceId: deviceId,
      createdAt: now,
      persist: false, // GUARDRAIL 2: validate only, don't persist yet
    );
    
    if (startResult.isError) {
      // ignore: avoid_print
      print('[SleepEventsProvider] Start validation failed: ${startResult.failureOrNull!.message}');
      throw SleepEventException(startResult.failureOrNull!.message);
    }
    
    // ignore: avoid_print
    print('[SleepEventsProvider] Validating End event: $endEventId at $endUtc');

    final endResult = await _createSleepEndUseCase.execute(
      babyId: activeBaby.id,
      timestamp: endUtc,
      userId: user.id,
      eventId: endEventId,
      deviceId: deviceId,
      createdAt: now,
      persist: false, // GUARDRAIL 2: validate only, don't persist yet
    );
    
    if (endResult.isError) {
      // ignore: avoid_print
      print('[SleepEventsProvider] End validation failed: ${endResult.failureOrNull!.message}');
      throw SleepEventException(endResult.failureOrNull!.message);
    }

    // STEP 2: Both validated - now persist ATOMICALLY in a single transaction
    final startEvent = startResult.dataOrNull!;
    final endEvent = endResult.dataOrNull!;
    
    // ignore: avoid_print
    print('[SleepEventsProvider] Persisting both events in transaction...');
    
    final saveResult = await _localDataSource.saveEventsInTransaction([
      SleepEventModel.fromDomain(startEvent),
      SleepEventModel.fromDomain(endEvent),
    ]);
    
    switch (saveResult) {
      case Success():
        // ignore: avoid_print
        print('[SleepEventsProvider] Transaction committed successfully');
      case Error(:final failure):
        // ignore: avoid_print
        print('[SleepEventsProvider] Transaction failed: ${failure.message}');
        throw SleepEventException(failure.message);
    }
    
    // STEP 3: Refresh to update UI and SleepState
    await refresh();
    
    // ignore: avoid_print
    print('[SleepEventsProvider] Session complete');
  }
}

/// Exception thrown when sleep event creation fails
class SleepEventException implements Exception {
  final String message;
  const SleepEventException(this.message);
  
  @override
  String toString() => message;
}
