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
import 'package:temp_flutter/domain/value_objects/sleep_session.dart';
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
  // Concurrency guard: tracks current baby and invalidates stale refreshes
  String? _currentBabyId;
  int _refreshSeq = 0;

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
    // Use ref.watch to subscribe to baby changes and trigger rebuild
    final activeBaby = ref.watch(activeBabyProvider);
    
    if (activeBaby == null) {
      _currentBabyId = null;
      return [];
    }

    // Track the baby for this build
    final isSameBaby = _currentBabyId == activeBaby.id;
    _currentBabyId = activeBaby.id;
    
    // Increment seq for this build - makes any previous build/refresh stale
    final mySeq = ++_refreshSeq;
    
    // ignore: avoid_print
    print('[SleepEventsProvider] build() started: babyId=${activeBaby.id}, seq=$mySeq, isSameBaby=$isSameBaby');
    
    final events = await _loadEvents(activeBaby.id);
    
    // Check if we're still the most recent operation
    // If addEvent() or refresh() happened during our async load, they would have incremented seq
    if (_refreshSeq != mySeq) {
      // ignore: avoid_print
      print('[SleepEventsProvider] build() stale: seq changed from $mySeq to $_refreshSeq, using current state');
      // Someone else updated the state - use their data instead
      // This prevents build() from overwriting addEvent()'s state
      final currentValue = state.value;
      if (currentValue != null) {
        return currentValue;
      }
      // If no current value, use what we loaded
      return events;
    }
    
    // ignore: avoid_print
    print('[SleepEventsProvider] build() completed: ${events.length} events, seq=$mySeq');
    return events;
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
  /// 
  /// Uses copyWithPrevious ONLY for same baby (avoids flickering).
  /// When baby changes, shows clean loading (no stale data from previous baby).
  /// Uses _refreshSeq to ignore stale refreshes that complete after addEvent.
  Future<void> refresh() async {
    final activeBaby = ref.read(activeBabyProvider);
    
    // === DEBUG LOG H3: Refresh sequence tracking ===
    // ignore: avoid_print
    print('[SleepEventsProvider][H3-DEBUG] ===== REFRESH CALLED =====');
    // ignore: avoid_print
    print('[SleepEventsProvider][H3-DEBUG] activeBaby: ${activeBaby?.id ?? 'null'}');
    // ignore: avoid_print
    print('[SleepEventsProvider][H3-DEBUG] currentBabyId: $_currentBabyId');
    // ignore: avoid_print
    print('[SleepEventsProvider][H3-DEBUG] currentSeq: $_refreshSeq');
    // ignore: avoid_print
    print('[SleepEventsProvider][H3-DEBUG] stateBeforeCount: ${state.value?.length ?? 'null (loading/error)'}');
    
    if (activeBaby == null) {
      state = const AsyncData([]);
      _currentBabyId = null;
      // ignore: avoid_print
      print('[SleepEventsProvider][H3-DEBUG] No active baby, reset to empty');
      return;
    }
    
    // Increment seq to invalidate any previous refresh in flight
    final mySeq = ++_refreshSeq;
    
    // Check if this is same baby (for copyWithPrevious decision)
    final isSameBaby = _currentBabyId == activeBaby.id;
    _currentBabyId = activeBaby.id;
    
    // ignore: avoid_print
    print('[SleepEventsProvider][H3-DEBUG] isSameBaby: $isSameBaby, mySeq: $mySeq');
    
    if (isSameBaby) {
      // Same baby: preserve previous data during loading (no flicker)
      state = const AsyncLoading<List<SleepEvent>>().copyWithPrevious(state);
    } else {
      // Different baby: clean loading (don't show events from previous baby)
      state = const AsyncLoading();
    }
    
    final result = await AsyncValue.guard(() => _loadEvents(activeBaby.id));
    
    // Only apply result if we're still the most recent refresh
    // (addEvent or another refresh may have updated state since we started)
    if (_refreshSeq == mySeq) {
      state = result;
      // ignore: avoid_print
      print('[SleepEventsProvider][H3-DEBUG] Applied result: ${result.value?.length ?? 'error/loading'} events');
    } else {
      // ignore: avoid_print
      print('[SleepEventsProvider][H3-DEBUG] STALE refresh (mySeq=$mySeq, current=$_refreshSeq) - result DISCARDED');
    }
    
    // ignore: avoid_print
    print('[SleepEventsProvider][H3-DEBUG] stateAfterCount: ${state.value?.length ?? 'null'}');
    // ignore: avoid_print
    print('[SleepEventsProvider][H3-DEBUG] ===== REFRESH END =====');
  }

  /// Adds a new event (after local persistence)
  /// 
  /// Increments _refreshSeq to invalidate any refresh in flight.
  /// This prevents a slow refresh from overwriting the newly added event.
  void addEvent(SleepEvent event) {
    // Invalidate any refresh in progress - our data is fresher
    _refreshSeq++;
    
    final currentEvents = state.value ?? [];
    state = AsyncData([event, ...currentEvents]);
  }

  /// Finds all sessions that overlap with the given interval [startUtc, endUtc]
  /// 
  /// Uses SleepSession.fromEventList to derive sessions from events.
  /// Overlap is checked using inclusive interval intersection:
  /// aStart <= bEnd && bStart <= aEnd
  /// 
  /// Returns list of overlapping sessions (empty if none).
  List<SleepSession> _findOverlappingSessions({
    required DateTime startUtc,
    required DateTime endUtc,
    required List<SleepEvent> events,
  }) {
    if (events.isEmpty) return [];
    
    // Derive sessions using existing domain logic
    final sessions = SleepSession.fromEventList(events);
    
    final overlapping = <SleepSession>[];
    
    for (final session in sessions) {
      final sessionStart = session.startEvent.timestamp;
      // For open sessions (no end), use "now" as implicit end
      final sessionEnd = session.endEvent?.timestamp ?? DateTime.now().toUtc();
      
      // Interval intersection: aStart <= bEnd && bStart <= aEnd
      final hasOverlap = (startUtc.isBefore(sessionEnd) || startUtc.isAtSameMomentAs(sessionEnd)) &&
                         (sessionStart.isBefore(endUtc) || sessionStart.isAtSameMomentAs(endUtc));
      
      if (hasOverlap) {
        overlapping.add(session);
      }
    }
    
    return overlapping;
  }

  /// Formats a SleepSession for display in error messages
  String _formatSleepSession(SleepSession session) {
    final startLocal = session.startEvent.timestamp.toLocal();
    final startStr = '${startLocal.hour.toString().padLeft(2, '0')}:${startLocal.minute.toString().padLeft(2, '0')}';
    
    if (session.endEvent != null) {
      final endLocal = session.endEvent!.timestamp.toLocal();
      final endStr = '${endLocal.hour.toString().padLeft(2, '0')}:${endLocal.minute.toString().padLeft(2, '0')}';
      return '$startStr - $endStr';
    } else {
      return 'desde $startStr (em curso)';
    }
  }

  /// Internal helper for creating SleepStart events
  /// 
  /// Validates preconditions and creates the event at the given timestamp.
  /// Used by both createSleepStart() and createSleepStartAt().
  /// 
  /// Throws [SleepEventException] if creation fails (e.g., no caregiver permission).
  Future<void> _createSleepStartInternal(DateTime timestamp) async {
    // DEBUG LOGS: Context information for debugging
    final user = ref.read(authProvider);
    final activeBaby = ref.read(activeBabyProvider);
    final currentEvents = state.value ?? [];
    final lastEvent = currentEvents.isNotEmpty ? currentEvents.first : null;
    final isSleeping = lastEvent?.type == SleepEventType.sleepStart;
    
    // ignore: avoid_print
    print('[DEBUG] ===== _createSleepStartInternal =====');
    // ignore: avoid_print
    print('[DEBUG] activeBabyId: ${activeBaby?.id}');
    // ignore: avoid_print
    print('[DEBUG] isSleeping: $isSleeping');
    // ignore: avoid_print
    print('[DEBUG] lastEvent: ${lastEvent?.type.name} at ${lastEvent?.timestamp}');
    // ignore: avoid_print
    print('[DEBUG] requested timestamp: $timestamp');
    // ignore: avoid_print
    print('[DEBUG] events count: ${currentEvents.length}');
    // ignore: avoid_print
    print('[DEBUG] =====================================');
    
    if (user == null) {
      throw const SleepEventException('Utilizador não autenticado');
    }
    
    if (activeBaby == null) {
      throw const SleepEventException('Nenhum bebé selecionado');
    }
    
    // Load events from SQLite if state is empty (e.g., after app restart)
    List<SleepEvent> eventsToCheck = currentEvents;
    if (eventsToCheck.isEmpty) {
      // ignore: avoid_print
      print('[SleepEventsProvider] state.value is empty, loading from SQLite...');
      try {
        eventsToCheck = await _loadEvents(activeBaby.id);
        // ignore: avoid_print
        print('[SleepEventsProvider] Loaded ${eventsToCheck.length} events from SQLite');
      } catch (e) {
        // ignore: avoid_print
        print('[SleepEventsProvider] Failed to load events: $e');
        // Continue with empty list - overlap check will pass
      }
    }
    
    // Check for overlap with existing sessions using INTERVAL [start, now]
    // Quick chips create a SleepStart that implies sleep continues until now
    final startUtc = timestamp.toUtc();
    final nowUtc = DateTime.now().toUtc();
    
    final overlappingSessions = _findOverlappingSessions(
      startUtc: startUtc,
      endUtc: nowUtc,
      events: eventsToCheck,
    );
    
    if (overlappingSessions.isNotEmpty) {
      final sessionStr = overlappingSessions.map(_formatSleepSession).join(', ');
      // ignore: avoid_print
      print('[SleepEventsProvider] Overlap detected with interval [$startUtc, $nowUtc]: $sessionStr');
      throw OverlapException(
        message: 'Já existe sono registado nesse período ($sessionStr)',
        overlappingSessions: overlappingSessions,
      );
    }
    
    final now = nowUtc;
    final eventId = UuidGenerator.generate();
    final deviceId = await DeviceIdManager.getDeviceId();
    
    // ignore: avoid_print
    print('[SleepEventsProvider] Executing use case with timestamp=$startUtc');
    
    final result = await _createSleepStartUseCase.execute(
      babyId: activeBaby.id,
      timestamp: startUtc,
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

    // Check for overlap with existing sessions using INTERVAL [start, end]
    List<SleepEvent> eventsToCheck = state.value ?? [];
    if (eventsToCheck.isEmpty) {
      // ignore: avoid_print
      print('[SleepEventsProvider] createSleepSession: state.value is empty, loading from SQLite...');
      try {
        eventsToCheck = await _loadEvents(activeBaby.id);
        // ignore: avoid_print
        print('[SleepEventsProvider] Loaded ${eventsToCheck.length} events from SQLite');
      } catch (e) {
        // ignore: avoid_print
        print('[SleepEventsProvider] Failed to load events: $e');
      }
    }
    
    final overlappingSessions = _findOverlappingSessions(
      startUtc: startUtc,
      endUtc: endUtc,
      events: eventsToCheck,
    );
    
    if (overlappingSessions.isNotEmpty) {
      final sessionStr = overlappingSessions.map(_formatSleepSession).join(', ');
      // ignore: avoid_print
      print('[SleepEventsProvider] Session overlap detected [$startUtc, $endUtc]: $sessionStr');
      throw OverlapException(
        message: 'Já existe sono registado nesse período ($sessionStr)',
        overlappingSessions: overlappingSessions,
      );
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

  /// Overwrites overlapping sessions and creates a new SleepStart
  /// 
  /// 1. Creates correction events for each original event in overlapping sessions
  /// 2. Marks original events as corrected (isCorrected=true, correctedBy=correctionEventId)
  /// 3. Creates the new SleepStart event
  /// 4. All operations happen atomically in a single SQLite transaction
  Future<void> overwriteAndCreateStart({
    required List<SleepSession> overlappingSessions,
    required DateTime newStartTime,
  }) async {
    // ignore: avoid_print
    print('[SleepEventsProvider] overwriteAndCreateStart: ${overlappingSessions.length} sessions to overwrite');
    
    final user = ref.read(authProvider);
    final activeBaby = ref.read(activeBabyProvider);
    
    if (user == null) {
      throw const SleepEventException('Utilizador não autenticado');
    }
    
    if (activeBaby == null) {
      throw const SleepEventException('Nenhum bebé selecionado');
    }

    final now = DateTime.now().toUtc();
    final deviceId = await DeviceIdManager.getDeviceId();
    
    // Collect all events to insert and update
    final inserts = <SleepEventModel>[];
    final updates = <SleepEventModel>[];
    
    // Process each overlapping session
    for (final session in overlappingSessions) {
      // Mark start event as corrected
      final startCorrectionId = UuidGenerator.generate();
      updates.add(SleepEventModel.fromDomain(
        session.startEvent.copyWith(
          isCorrected: true,
          correctedBy: startCorrectionId,
        ),
      ));
      
      // Create correction event for start (as domain then convert)
      final startCorrectionEvent = SleepEvent(
        id: startCorrectionId,
        babyId: activeBaby.id,
        type: SleepEventType.sleepStart,
        timestamp: session.startEvent.timestamp,
        caregiverId: session.startEvent.caregiverId,
        deviceId: deviceId,
        createdAt: now,
        isCorrected: true,
        syncedAt: null,
        correctedBy: session.startEvent.id,
        metadata: {'correction_reason': 'replaced_by_user'},
      );
      inserts.add(SleepEventModel.fromDomain(startCorrectionEvent));
      
      // If session has end event, mark it and create correction too
      if (session.endEvent != null) {
        final endCorrectionId = UuidGenerator.generate();
        updates.add(SleepEventModel.fromDomain(
          session.endEvent!.copyWith(
            isCorrected: true,
            correctedBy: endCorrectionId,
          ),
        ));
        
        final endCorrectionEvent = SleepEvent(
          id: endCorrectionId,
          babyId: activeBaby.id,
          type: SleepEventType.sleepEnd,
          timestamp: session.endEvent!.timestamp,
          caregiverId: session.endEvent!.caregiverId,
          deviceId: deviceId,
          createdAt: now,
          isCorrected: true,
          syncedAt: null,
          correctedBy: session.endEvent!.id,
          metadata: {'correction_reason': 'replaced_by_user'},
        );
        inserts.add(SleepEventModel.fromDomain(endCorrectionEvent));
      }
    }
    
    // Create the new SleepStart event
    final newStartId = UuidGenerator.generate();
    final newStartResult = await _createSleepStartUseCase.execute(
      babyId: activeBaby.id,
      timestamp: newStartTime.toUtc(),
      userId: user.id,
      eventId: newStartId,
      deviceId: deviceId,
      createdAt: now,
      persist: false, // Validate only
    );
    
    if (newStartResult.isError) {
      throw SleepEventException(newStartResult.failureOrNull!.message);
    }
    
    inserts.add(SleepEventModel.fromDomain(newStartResult.dataOrNull!));
    
    // Execute everything atomically
    // ignore: avoid_print
    print('[SleepEventsProvider] Committing: ${inserts.length} inserts, ${updates.length} updates');
    
    final saveResult = await _localDataSource.saveAndUpdateEventsInTransaction(
      inserts: inserts,
      updates: updates,
    );
    
    switch (saveResult) {
      case Success():
        // ignore: avoid_print
        print('[SleepEventsProvider] Overwrite transaction committed');
      case Error(:final failure):
        throw SleepEventException(failure.message);
    }
    
    // Refresh state
    await refresh();
  }

  /// Overwrites overlapping sessions and creates a complete sleep session (Start + End)
  /// 
  /// Same as overwriteAndCreateStart but creates both Start and End events.
  Future<void> overwriteAndCreateSession({
    required List<SleepSession> overlappingSessions,
    required DateTime newStartTime,
    required DateTime newEndTime,
  }) async {
    // ignore: avoid_print
    print('[SleepEventsProvider] overwriteAndCreateSession: ${overlappingSessions.length} sessions to overwrite');
    
    final user = ref.read(authProvider);
    final activeBaby = ref.read(activeBabyProvider);
    
    if (user == null) {
      throw const SleepEventException('Utilizador não autenticado');
    }
    
    if (activeBaby == null) {
      throw const SleepEventException('Nenhum bebé selecionado');
    }

    // Validate order
    final startUtc = newStartTime.toUtc();
    final endUtc = newEndTime.toUtc();
    
    if (!endUtc.isAfter(startUtc)) {
      throw const SleepEventException('A hora de fim deve ser depois da hora de início');
    }

    final now = DateTime.now().toUtc();
    final deviceId = await DeviceIdManager.getDeviceId();
    
    final inserts = <SleepEventModel>[];
    final updates = <SleepEventModel>[];
    
    // Process each overlapping session (same as overwriteAndCreateStart)
    for (final session in overlappingSessions) {
      final startCorrectionId = UuidGenerator.generate();
      updates.add(SleepEventModel.fromDomain(
        session.startEvent.copyWith(
          isCorrected: true,
          correctedBy: startCorrectionId,
        ),
      ));
      
      final startCorrectionEvent = SleepEvent(
        id: startCorrectionId,
        babyId: activeBaby.id,
        type: SleepEventType.sleepStart,
        timestamp: session.startEvent.timestamp,
        caregiverId: session.startEvent.caregiverId,
        deviceId: deviceId,
        createdAt: now,
        isCorrected: true,
        syncedAt: null,
        correctedBy: session.startEvent.id,
        metadata: {'correction_reason': 'replaced_by_user'},
      );
      inserts.add(SleepEventModel.fromDomain(startCorrectionEvent));
      
      if (session.endEvent != null) {
        final endCorrectionId = UuidGenerator.generate();
        updates.add(SleepEventModel.fromDomain(
          session.endEvent!.copyWith(
            isCorrected: true,
            correctedBy: endCorrectionId,
          ),
        ));
        
        final endCorrectionEvent = SleepEvent(
          id: endCorrectionId,
          babyId: activeBaby.id,
          type: SleepEventType.sleepEnd,
          timestamp: session.endEvent!.timestamp,
          caregiverId: session.endEvent!.caregiverId,
          deviceId: deviceId,
          createdAt: now,
          isCorrected: true,
          syncedAt: null,
          correctedBy: session.endEvent!.id,
          metadata: {'correction_reason': 'replaced_by_user'},
        );
        inserts.add(SleepEventModel.fromDomain(endCorrectionEvent));
      }
    }
    
    // Create the new Start and End events
    final newStartId = UuidGenerator.generate();
    final newEndId = UuidGenerator.generate();
    
    final startResult = await _createSleepStartUseCase.execute(
      babyId: activeBaby.id,
      timestamp: startUtc,
      userId: user.id,
      eventId: newStartId,
      deviceId: deviceId,
      createdAt: now,
      persist: false,
    );
    
    if (startResult.isError) {
      throw SleepEventException(startResult.failureOrNull!.message);
    }
    
    final endResult = await _createSleepEndUseCase.execute(
      babyId: activeBaby.id,
      timestamp: endUtc,
      userId: user.id,
      eventId: newEndId,
      deviceId: deviceId,
      createdAt: now,
      persist: false,
    );
    
    if (endResult.isError) {
      throw SleepEventException(endResult.failureOrNull!.message);
    }
    
    inserts.add(SleepEventModel.fromDomain(startResult.dataOrNull!));
    inserts.add(SleepEventModel.fromDomain(endResult.dataOrNull!));
    
    // Execute everything atomically
    // ignore: avoid_print
    print('[SleepEventsProvider] Committing session: ${inserts.length} inserts, ${updates.length} updates');
    
    final saveResult = await _localDataSource.saveAndUpdateEventsInTransaction(
      inserts: inserts,
      updates: updates,
    );
    
    switch (saveResult) {
      case Success():
        // ignore: avoid_print
        print('[SleepEventsProvider] Overwrite session transaction committed');
      case Error(:final failure):
        throw SleepEventException(failure.message);
    }
    
    await refresh();
  }

  // ========== MULTI-DEVICE CONFLICT DETECTION AND RESOLUTION ==========

  /// Time window for detecting duplicate SleepStart events (multi-device)
  /// 
  /// Must match SleepSession.duplicateTimeWindow for consistency.
  /// Set to 5 minutes to handle realistic multi-device scenarios where users
  /// might tap "Start sleep" on different devices with some delay.
  static const Duration _duplicateTimeWindow = Duration(minutes: 5);

  /// Detects duplicate SleepStart conflicts in the current events
  /// 
  /// A conflict is when there are 2+ valid SleepStart events with timestamps
  /// within the duplicate time window (likely from multiple devices).
  /// 
  /// Returns list of conflict groups (empty if no conflicts).
  List<DuplicateStartConflict> detectDuplicateStartConflicts() {
    final events = state.value ?? [];
    final validStarts = events
        .where((e) => e.isValid && e.type == SleepEventType.sleepStart)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    
    if (validStarts.length < 2) return [];
    
    final conflicts = <DuplicateStartConflict>[];
    final processed = <String>{};
    
    for (var i = 0; i < validStarts.length; i++) {
      final event = validStarts[i];
      if (processed.contains(event.id)) continue;
      
      // Find all events within the time window
      final duplicates = <SleepEvent>[event];
      
      for (var j = i + 1; j < validStarts.length; j++) {
        final other = validStarts[j];
        if (processed.contains(other.id)) continue;
        
        final timeDiff = other.timestamp.difference(event.timestamp).abs();
        if (timeDiff < _duplicateTimeWindow) {
          duplicates.add(other);
        }
      }
      
      if (duplicates.length > 1) {
        // Sort by createdAt DESC to suggest keeping the most recent
        duplicates.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        
        conflicts.add(DuplicateStartConflict(
          events: duplicates,
          conflictTimestamp: event.timestamp,
        ));
        
        for (final dup in duplicates) {
          processed.add(dup.id);
        }
      }
    }
    
    // ignore: avoid_print
    print('[SleepEventsProvider] detectDuplicateStartConflicts: found ${conflicts.length} conflicts');
    
    return conflicts;
  }

  /// Resolves a duplicate conflict by keeping one event and marking others as corrected
  /// 
  /// [keepEventId] - The event ID to keep (winner)
  /// [conflictEvents] - All events in the conflict group (including the winner)
  /// 
  /// Algorithm:
  /// 1. For each loser event: mark as isCorrected=true, set correctedBy to correction event ID
  /// 2. Create correction events for losers with metadata: correction_reason='duplicate_multi_device'
  /// 3. Persist atomically via transaction
  /// 
  /// Throws [SleepEventException] if resolution fails.
  Future<void> resolveDuplicateConflict({
    required String keepEventId,
    required List<SleepEvent> conflictEvents,
  }) async {
    // ignore: avoid_print
    print('[SleepEventsProvider] resolveDuplicateConflict: keep=$keepEventId, total=${conflictEvents.length}');
    
    final user = ref.read(authProvider);
    final activeBaby = ref.read(activeBabyProvider);
    
    if (user == null) {
      throw const SleepEventException('Utilizador não autenticado');
    }
    
    if (activeBaby == null) {
      throw const SleepEventException('Nenhum bebé selecionado');
    }
    
    // Validate that keepEventId is in conflictEvents
    if (!conflictEvents.any((e) => e.id == keepEventId)) {
      throw const SleepEventException('Evento a manter não encontrado');
    }
    
    final losers = conflictEvents.where((e) => e.id != keepEventId).toList();
    
    if (losers.isEmpty) {
      // No losers means no conflict to resolve
      return;
    }
    
    final now = DateTime.now().toUtc();
    final deviceId = await DeviceIdManager.getDeviceId();
    
    final inserts = <SleepEventModel>[];
    final updates = <SleepEventModel>[];
    
    for (final loser in losers) {
      // Create correction event for loser
      final correctionId = UuidGenerator.generate();
      
      // Mark loser as corrected
      updates.add(SleepEventModel.fromDomain(
        loser.copyWith(
          isCorrected: true,
          correctedBy: correctionId,
        ),
      ));
      
      // Create correction event (marks the original as invalid, points to it)
      final correctionEvent = SleepEvent(
        id: correctionId,
        babyId: activeBaby.id,
        type: SleepEventType.sleepStart,
        timestamp: loser.timestamp,
        caregiverId: loser.caregiverId,
        deviceId: deviceId,
        createdAt: now,
        isCorrected: true,
        syncedAt: null,
        correctedBy: loser.id,
        metadata: {'correction_reason': 'duplicate_multi_device', 'kept_event': keepEventId},
      );
      inserts.add(SleepEventModel.fromDomain(correctionEvent));
    }
    
    // ignore: avoid_print
    print('[SleepEventsProvider] resolveDuplicateConflict: ${inserts.length} inserts, ${updates.length} updates');
    
    final saveResult = await _localDataSource.saveAndUpdateEventsInTransaction(
      inserts: inserts,
      updates: updates,
    );
    
    switch (saveResult) {
      case Success():
        // ignore: avoid_print
        print('[SleepEventsProvider] Duplicate conflict resolved: kept $keepEventId');
      case Error(:final failure):
        throw SleepEventException(failure.message);
    }
    
    // Refresh to update UI
    await refresh();
  }
}

/// Represents a group of duplicate SleepStart events from multiple devices
class DuplicateStartConflict {
  /// List of duplicate events (sorted by createdAt DESC - first is suggested winner)
  final List<SleepEvent> events;
  
  /// The timestamp where the conflict was detected
  final DateTime conflictTimestamp;
  
  const DuplicateStartConflict({
    required this.events,
    required this.conflictTimestamp,
  });
  
  /// The suggested winner (most recently created)
  SleepEvent get suggestedWinner => events.first;
  
  @override
  String toString() => 'DuplicateStartConflict(timestamp: $conflictTimestamp, count: ${events.length})';
}

/// Exception thrown when sleep event creation fails
class SleepEventException implements Exception {
  final String message;
  const SleepEventException(this.message);
  
  @override
  String toString() => message;
}

/// Exception thrown when an overlap is detected with existing sleep sessions.
/// Contains the list of overlapping sessions for UI to offer "Substituir" option.
class OverlapException extends SleepEventException {
  final List<SleepSession> overlappingSessions;
  
  const OverlapException({
    required String message,
    required this.overlappingSessions,
  }) : super(message);
}
