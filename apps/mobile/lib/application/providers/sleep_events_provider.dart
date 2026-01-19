import 'dart:convert';
import 'dart:io';
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
import 'sync_provider.dart';

part 'sleep_events_provider.g.dart';

// #region agent log helper
void _providerDebugLog(String hypothesisId, String location, String message, Map<String, dynamic> data) {
  try {
    final logEntry = jsonEncode({
      'sessionId': 'debug-session',
      'runId': 'post-fix-1',
      'hypothesisId': hypothesisId,
      'location': location,
      'message': message,
      'data': data,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    // Try to write to log file
    final file = File('/Users/isacsa/baby_sleep_monitor/baby-sleep/.cursor/debug.log');
    file.writeAsStringSync('$logEntry\n', mode: FileMode.append, flush: true);
  } catch (_) {
    // Fallback to print
    // ignore: avoid_print
    print('[DEBUG-$hypothesisId] $location: $message | $data');
  }
}
// #endregion

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

  /// Marks an existing event as corrected locally in a way that will actually sync.
  ///
  /// - Always sets `isCorrected=true`
  /// - Always clears `syncedAt` (so LayeredSync will push it again)
  /// - Only sets `correctedBy = correctionEventId` if the event was previously synced.
  ///   If the event was never synced, we avoid setting `correctedBy` to prevent
  ///   corrected_by FK cycles on first push; the correction event still points to the original.
  SleepEvent _markOriginalCorrectedForLocal({
    required SleepEvent original,
    required String correctionEventId,
  }) {
    final attachCorrectedBy = original.syncedAt != null;
    return SleepEvent(
      id: original.id,
      babyId: original.babyId,
      type: original.type,
      timestamp: original.timestamp,
      caregiverId: original.caregiverId,
      deviceId: original.deviceId,
      createdAt: original.createdAt,
      isCorrected: true,
      syncedAt: null,
      correctedBy: attachCorrectedBy ? correctionEventId : null,
      metadata: original.metadata,
    );
  }

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
    
    void dbg(String msg) {
      assert(() {
        // ignore: avoid_print
        print(msg);
        return true;
      }());
    }
    // === DEBUG LOG H3: Refresh sequence tracking ===
    dbg('[SleepEventsProvider][H3-DEBUG] ===== REFRESH CALLED =====');
    dbg('[SleepEventsProvider][H3-DEBUG] activeBaby: ${activeBaby?.id ?? 'null'}');
    dbg('[SleepEventsProvider][H3-DEBUG] currentBabyId: $_currentBabyId');
    dbg('[SleepEventsProvider][H3-DEBUG] currentSeq: $_refreshSeq');
    dbg('[SleepEventsProvider][H3-DEBUG] stateBeforeCount: ${state.value?.length ?? 'null (loading/error)'}');
    
    if (activeBaby == null) {
      state = const AsyncData([]);
      _currentBabyId = null;
      dbg('[SleepEventsProvider][H3-DEBUG] No active baby, reset to empty');
      return;
    }
    
    // Increment seq to invalidate any previous refresh in flight
    final mySeq = ++_refreshSeq;
    
    // Check if this is same baby (for copyWithPrevious decision)
    final isSameBaby = _currentBabyId == activeBaby.id;
    _currentBabyId = activeBaby.id;
    
    dbg('[SleepEventsProvider][H3-DEBUG] isSameBaby: $isSameBaby, mySeq: $mySeq');
    
    if (isSameBaby) {
      // Same baby: preserve previous data during loading (no flicker)
      state = const AsyncLoading<List<SleepEvent>>().copyWithPrevious(state);
    } else {
      // Different baby: clean loading (don't show events from previous baby)
      state = const AsyncLoading();
    }
    
    final result = await AsyncValue.guard(() => _loadEvents(activeBaby.id));
    
    // #region agent log H2 - Refresh load result
    if (result.hasValue) {
      final loadedEvents = result.value!;
      final validLoaded = loadedEvents.where((e) => e.isValid).length;
      // ignore: avoid_print
      print('[DEBUG-H2] refresh() loaded: total=${loadedEvents.length}, valid=$validLoaded');
      // Show most recent events
      final sorted = List<SleepEvent>.from(loadedEvents)..sort((a, b) {
        final ts = b.timestamp.compareTo(a.timestamp);
        if (ts != 0) return ts;
        return b.createdAt.compareTo(a.createdAt);
      });
      for (var i = 0; i < sorted.length && i < 5; i++) {
        final e = sorted[i];
        // ignore: avoid_print
        print('[DEBUG-H2]   [$i] id=${e.id.substring(0, 8)}, type=${e.type.name}, ts=${e.timestamp}, isCorrected=${e.isCorrected}');
      }
    }
    // #endregion
    
    // Only apply result if we're still the most recent refresh
    // (addEvent or another refresh may have updated state since we started)
    if (_refreshSeq == mySeq) {
      state = result;
      dbg('[SleepEventsProvider][H3-DEBUG] Applied result: ${result.value?.length ?? 'error/loading'} events');
    } else {
      dbg('[SleepEventsProvider][H3-DEBUG] STALE refresh (mySeq=$mySeq, current=$_refreshSeq) - result DISCARDED');
    }
    
    dbg('[SleepEventsProvider][H3-DEBUG] stateAfterCount: ${state.value?.length ?? 'null'}');
    dbg('[SleepEventsProvider][H3-DEBUG] ===== REFRESH END =====');
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
    
    // FIX P4: Trigger auto-sync after local change
    ref.read(syncProvider.notifier).scheduleSyncAfterLocalChange(event.babyId);
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
    
    // FIX P4: Trigger auto-sync after transaction
    ref.read(syncProvider.notifier).scheduleSyncAfterLocalChange(activeBaby.id);
    
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
    
    // #region agent log H1 - Entry point
    // ignore: avoid_print
    print('[DEBUG-H1] overwriteAndCreateStart ENTRY: sessions=${overlappingSessions.length}, newStartTime=$newStartTime');
    final entryNow = DateTime.now();
    final diffMin = entryNow.difference(newStartTime).inMinutes;
    _providerDebugLog('H10', 'sleep_events_provider:overwriteAndCreateStart:entry', 'Provider received newStartTime', {'newStartTime': newStartTime.toIso8601String(), 'newStartTimeUtc': newStartTime.toUtc().toIso8601String(), 'now': entryNow.toIso8601String(), 'diffMinutes': diffMin, 'diffHours': diffMin ~/ 60, 'overlappingSessions': overlappingSessions.length});
    // #endregion
    
    final user = ref.read(authProvider);
    final activeBaby = ref.read(activeBabyProvider);
    
    // #region agent log H1 - Check for orphan events in interval
    final currentEvents = state.value ?? [];
    final startUtc = newStartTime.toUtc();
    final nowUtc = DateTime.now().toUtc();
    final validEvents = currentEvents.where((e) => e.isValid).toList();
    
    // Find ALL events in the interval [newStart, now] - not just sessions
    final eventsInInterval = validEvents.where((e) {
      final ts = e.timestamp;
      return (ts.isAfter(startUtc) || ts.isAtSameMomentAs(startUtc)) &&
             (ts.isBefore(nowUtc) || ts.isAtSameMomentAs(nowUtc));
    }).toList()..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    
    // Collect all event IDs that will be corrected (from sessions)
    final sessionEventIds = <String>{};
    for (final session in overlappingSessions) {
      sessionEventIds.add(session.startEvent.id);
      if (session.endEvent != null) sessionEventIds.add(session.endEvent!.id);
    }
    
    // Find orphan events that are in interval but NOT in any detected session
    final orphanEvents = eventsInInterval.where((e) => !sessionEventIds.contains(e.id)).toList();
    
    // ignore: avoid_print
    print('[DEBUG-H1-ORPHAN] Events in interval [$startUtc, $nowUtc]: ${eventsInInterval.length}');
    for (final e in eventsInInterval) {
      // ignore: avoid_print
      print('[DEBUG-H1-ORPHAN]   ${e.id.substring(0, 8)} ${e.type.name} ts=${e.timestamp} inSession=${sessionEventIds.contains(e.id)}');
    }
    if (orphanEvents.isNotEmpty) {
      // ignore: avoid_print
      print('[DEBUG-H1-ORPHAN] *** ORPHAN EVENTS NOT BEING CORRECTED: ${orphanEvents.length} ***');
      for (final e in orphanEvents) {
        // ignore: avoid_print
        print('[DEBUG-H1-ORPHAN]   ORPHAN: ${e.id.substring(0, 8)} ${e.type.name} ts=${e.timestamp}');
      }
    }
    // #endregion
    
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
      updates.add(SleepEventModel.fromDomain(_markOriginalCorrectedForLocal(
        original: session.startEvent,
        correctionEventId: startCorrectionId,
      )));
      
      // Create correction event for start (as domain then convert)
      // FIX: correction events have corrected_by=NULL to avoid FK dependencies in push
      // The reference to the original is stored in metadata.corrects_event_id
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
        correctedBy: null, // No FK dependency - original points to us, not vice versa
        metadata: {
          'correction_reason': 'replaced_by_user',
          'corrects_event_id': session.startEvent.id,
        },
      );
      inserts.add(SleepEventModel.fromDomain(startCorrectionEvent));
      
      // If session has end event, mark it and create correction too
      if (session.endEvent != null) {
        final endCorrectionId = UuidGenerator.generate();
        updates.add(SleepEventModel.fromDomain(_markOriginalCorrectedForLocal(
          original: session.endEvent!,
          correctionEventId: endCorrectionId,
        )));
        
        // FIX: correction events have corrected_by=NULL to avoid FK dependencies
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
          correctedBy: null, // No FK dependency
          metadata: {
            'correction_reason': 'replaced_by_user',
            'corrects_event_id': session.endEvent!.id,
          },
        );
        inserts.add(SleepEventModel.fromDomain(endCorrectionEvent));
      }
    }
    
    // FIX P1: Also correct orphan events in the interval [newStart, now]
    for (final orphan in orphanEvents) {
      final correctionId = UuidGenerator.generate();
      updates.add(SleepEventModel.fromDomain(_markOriginalCorrectedForLocal(
        original: orphan,
        correctionEventId: correctionId,
      )));
      
      // Create correction event for the orphan
      // FIX: correction events have corrected_by=NULL to avoid FK dependencies
      final orphanCorrectionEvent = SleepEvent(
        id: correctionId,
        babyId: activeBaby.id,
        type: orphan.type,
        timestamp: orphan.timestamp,
        caregiverId: orphan.caregiverId,
        deviceId: deviceId,
        createdAt: now,
        isCorrected: true,
        syncedAt: null,
        correctedBy: null, // No FK dependency
        metadata: {
          'correction_reason': 'orphan_in_overwrite_interval',
          'corrects_event_id': orphan.id,
        },
      );
      inserts.add(SleepEventModel.fromDomain(orphanCorrectionEvent));
      // ignore: avoid_print
      print('[DEBUG-H1-ORPHAN] CORRECTING orphan: ${orphan.id.substring(0, 8)} -> correction: ${correctionId.substring(0, 8)}');
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
    
    // #region agent log H1 - Pre-transaction details
    // ignore: avoid_print
    print('[DEBUG-H1] INSERTS:');
    for (final ins in inserts) {
      // ignore: avoid_print
      print('[DEBUG-H1]   id=${ins.id}, type=${ins.type}, isCorrected=${ins.isCorrected}, correctedBy=${ins.correctedBy}, timestamp=${ins.timestamp}');
    }
    // ignore: avoid_print
    print('[DEBUG-H1] UPDATES (marking as corrected):');
    for (final upd in updates) {
      // ignore: avoid_print
      print('[DEBUG-H1]   id=${upd.id}, type=${upd.type}, isCorrected=${upd.isCorrected}, correctedBy=${upd.correctedBy}');
    }
    // #endregion
    
    final saveResult = await _localDataSource.saveAndUpdateEventsInTransaction(
      inserts: inserts,
      updates: updates,
    );
    
    switch (saveResult) {
      case Success():
        // ignore: avoid_print
        print('[SleepEventsProvider] Overwrite transaction committed');
        // #region agent log H1 - Post-transaction
        // ignore: avoid_print
        print('[DEBUG-H1] Transaction SUCCESS - new SleepStart id=${newStartResult.dataOrNull!.id}');
        final createdEvent = newStartResult.dataOrNull!;
        final nowPost = DateTime.now();
        final diffMinPost = nowPost.difference(createdEvent.timestamp).inMinutes;
        _providerDebugLog('H10', 'sleep_events_provider:overwriteAndCreateStart:postTransaction', 'New SleepStart event created', {'eventId': createdEvent.id, 'timestamp': createdEvent.timestamp.toIso8601String(), 'createdAt': createdEvent.createdAt.toIso8601String(), 'now': nowPost.toIso8601String(), 'diffMinutes': diffMinPost, 'diffHours': diffMinPost ~/ 60});
        // #endregion
      case Error(:final failure):
        // ignore: avoid_print
        print('[DEBUG-H1] Transaction FAILED: ${failure.message}');
        throw SleepEventException(failure.message);
    }
    
    // #region agent log H2 - Pre-refresh state
    // ignore: avoid_print
    print('[DEBUG-H2] Before refresh - current state events: ${state.value?.length ?? 0}');
    // #endregion
    
    // Refresh state
    await refresh();
    
    // #region agent log H2 - Post-refresh state
    final postRefreshEvents = state.value ?? [];
    final postValidEvents = postRefreshEvents.where((e) => e.isValid).toList();
    // ignore: avoid_print
    print('[DEBUG-H2] After refresh - total events: ${postRefreshEvents.length}, valid events: ${postValidEvents.length}');
    if (postValidEvents.isNotEmpty) {
      final sorted = List<SleepEvent>.from(postValidEvents)..sort((a, b) {
        final ts = b.timestamp.compareTo(a.timestamp);
        if (ts != 0) return ts;
        return b.createdAt.compareTo(a.createdAt);
      });
      final mostRecent = sorted.first;
      // ignore: avoid_print
      print('[DEBUG-H2] Most recent valid event: id=${mostRecent.id}, type=${mostRecent.type.name}, timestamp=${mostRecent.timestamp}');
      // ignore: avoid_print
      print('[DEBUG-H2] Derived isSleeping: ${mostRecent.type == SleepEventType.sleepStart}');
    }
    // #endregion
    
    // FIX P4: Trigger auto-sync after transaction
    ref.read(syncProvider.notifier).scheduleSyncAfterLocalChange(activeBaby.id);
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
    
    // FIX P1: Find ALL events in interval [startUtc, endUtc] to detect orphans
    final currentEvents = state.value ?? [];
    final validEvents = currentEvents.where((e) => e.isValid).toList();
    final eventsInInterval = validEvents.where((e) {
      final ts = e.timestamp;
      return (ts.isAfter(startUtc) || ts.isAtSameMomentAs(startUtc)) &&
             (ts.isBefore(endUtc) || ts.isAtSameMomentAs(endUtc));
    }).toList();
    
    // Collect session event IDs
    final sessionEventIds = <String>{};
    for (final session in overlappingSessions) {
      sessionEventIds.add(session.startEvent.id);
      if (session.endEvent != null) sessionEventIds.add(session.endEvent!.id);
    }
    
    // Find orphan events
    final orphanEvents = eventsInInterval.where((e) => !sessionEventIds.contains(e.id)).toList();
    // ignore: avoid_print
    print('[DEBUG-H1-SESSION] Events in interval [$startUtc, $endUtc]: ${eventsInInterval.length}, orphans: ${orphanEvents.length}');
    
    final inserts = <SleepEventModel>[];
    final updates = <SleepEventModel>[];
    
    // Process each overlapping session (same as overwriteAndCreateStart)
    for (final session in overlappingSessions) {
      final startCorrectionId = UuidGenerator.generate();
      updates.add(SleepEventModel.fromDomain(_markOriginalCorrectedForLocal(
        original: session.startEvent,
        correctionEventId: startCorrectionId,
      )));
      
      // FIX: correction events have corrected_by=NULL to avoid FK dependencies
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
        correctedBy: null, // No FK dependency
        metadata: {
          'correction_reason': 'replaced_by_user',
          'corrects_event_id': session.startEvent.id,
        },
      );
      inserts.add(SleepEventModel.fromDomain(startCorrectionEvent));
      
      if (session.endEvent != null) {
        final endCorrectionId = UuidGenerator.generate();
        updates.add(SleepEventModel.fromDomain(_markOriginalCorrectedForLocal(
          original: session.endEvent!,
          correctionEventId: endCorrectionId,
        )));
        
        // FIX: correction events have corrected_by=NULL to avoid FK dependencies
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
          correctedBy: null, // No FK dependency
          metadata: {
            'correction_reason': 'replaced_by_user',
            'corrects_event_id': session.endEvent!.id,
          },
        );
        inserts.add(SleepEventModel.fromDomain(endCorrectionEvent));
      }
    }
    
    // FIX P1: Also correct orphan events in the interval [startUtc, endUtc]
    for (final orphan in orphanEvents) {
      final correctionId = UuidGenerator.generate();
      updates.add(SleepEventModel.fromDomain(_markOriginalCorrectedForLocal(
        original: orphan,
        correctionEventId: correctionId,
      )));
      
      // FIX: correction events have corrected_by=NULL to avoid FK dependencies
      final orphanCorrectionEvent = SleepEvent(
        id: correctionId,
        babyId: activeBaby.id,
        type: orphan.type,
        timestamp: orphan.timestamp,
        caregiverId: orphan.caregiverId,
        deviceId: deviceId,
        createdAt: now,
        isCorrected: true,
        syncedAt: null,
        correctedBy: null, // No FK dependency
        metadata: {
          'correction_reason': 'orphan_in_overwrite_interval',
          'corrects_event_id': orphan.id,
        },
      );
      inserts.add(SleepEventModel.fromDomain(orphanCorrectionEvent));
      // ignore: avoid_print
      print('[DEBUG-H1-SESSION] CORRECTING orphan: ${orphan.id.substring(0, 8)} -> correction: ${correctionId.substring(0, 8)}');
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
    
    // FIX P4: Trigger auto-sync after transaction
    ref.read(syncProvider.notifier).scheduleSyncAfterLocalChange(activeBaby.id);
  }

  // ========== DELETE SESSION (as correction) ==========

  /// Deletes a complete sleep session by marking both events as corrected.
  /// 
  /// This is NOT a hard delete - it follows the event-based correction model:
  /// 1. Marks startEvent and endEvent as isCorrected=true
  /// 2. Creates correction events with metadata: correction_reason='deleted_by_user'
  /// 3. Persists atomically via transaction
  /// 
  /// The session will no longer appear in derived sessions (SleepSession.fromEventList)
  /// but is kept for audit/sync purposes.
  /// 
  /// Throws [SleepEventException] if deletion fails.
  Future<void> deleteSleepSession({required SleepSession session}) async {
    // ignore: avoid_print
    print('[SleepEventsProvider] deleteSleepSession: startId=${session.startEvent.id}, endId=${session.endEvent?.id}');
    
    if (!session.isComplete) {
      throw const SleepEventException('Apenas sessões completas podem ser eliminadas');
    }
    
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
    
    final inserts = <SleepEventModel>[];
    final updates = <SleepEventModel>[];
    
    // Mark start event as corrected and create correction event
    final startCorrectionId = UuidGenerator.generate();
    updates.add(SleepEventModel.fromDomain(_markOriginalCorrectedForLocal(
      original: session.startEvent,
      correctionEventId: startCorrectionId,
    )));
    
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
      correctedBy: null, // No FK dependency
      metadata: {
        'correction_reason': 'deleted_by_user',
        'corrects_event_id': session.startEvent.id,
      },
    );
    inserts.add(SleepEventModel.fromDomain(startCorrectionEvent));
    
    // Mark end event as corrected and create correction event
    final endCorrectionId = UuidGenerator.generate();
    updates.add(SleepEventModel.fromDomain(_markOriginalCorrectedForLocal(
      original: session.endEvent!,
      correctionEventId: endCorrectionId,
    )));
    
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
      correctedBy: null, // No FK dependency
      metadata: {
        'correction_reason': 'deleted_by_user',
        'corrects_event_id': session.endEvent!.id,
      },
    );
    inserts.add(SleepEventModel.fromDomain(endCorrectionEvent));
    
    // Execute atomically
    // ignore: avoid_print
    print('[SleepEventsProvider] deleteSleepSession: committing ${inserts.length} inserts, ${updates.length} updates');
    
    final saveResult = await _localDataSource.saveAndUpdateEventsInTransaction(
      inserts: inserts,
      updates: updates,
    );
    
    switch (saveResult) {
      case Success():
        // ignore: avoid_print
        print('[SleepEventsProvider] deleteSleepSession: transaction committed');
      case Error(:final failure):
        throw SleepEventException(failure.message);
    }
    
    await refresh();
    
    // Trigger auto-sync after deletion
    ref.read(syncProvider.notifier).scheduleSyncAfterLocalChange(activeBaby.id);
  }

  // ========== EDIT SESSION ==========

  /// Edits a complete sleep session by correcting the original and creating new events.
  /// 
  /// Algorithm:
  /// 1. Validate new times (end > start in local and UTC)
  /// 2. Check for overlaps with OTHER sessions (excluding the original)
  /// 3. If overlaps exist and extraSessionsToOverwrite is empty, throw OverlapException
  /// 4. Otherwise, correct original + any extra sessions, and create new session
  /// 
  /// [original] - The session being edited
  /// [newStartTime] - New start time (local or UTC)
  /// [newEndTime] - New end time (local or UTC)
  /// [extraSessionsToOverwrite] - Additional sessions to overwrite if user confirmed
  /// 
  /// Throws [SleepEventException] for validation errors.
  /// Throws [OverlapException] if overlapping sessions exist and not confirmed.
  Future<void> editSleepSession({
    required SleepSession original,
    required DateTime newStartTime,
    required DateTime newEndTime,
    List<SleepSession> extraSessionsToOverwrite = const [],
  }) async {
    // ignore: avoid_print
    print('[SleepEventsProvider] editSleepSession: original.start=${original.startEvent.id}, newStart=$newStartTime, newEnd=$newEndTime');
    
    if (!original.isComplete) {
      throw const SleepEventException('Apenas sessões completas podem ser editadas');
    }
    
    // Normalize to UTC
    final startUtc = newStartTime.toUtc();
    final endUtc = newEndTime.toUtc();
    
    // Validate order in both local AND UTC
    if (!newEndTime.isAfter(newStartTime)) {
      throw const SleepEventException('A hora de fim deve ser depois da hora de início');
    }
    
    if (!endUtc.isAfter(startUtc)) {
      throw const SleepEventException('As horas ficaram inconsistentes. Confirma o dia do fim.');
    }

    final user = ref.read(authProvider);
    final activeBaby = ref.read(activeBabyProvider);
    
    if (user == null) {
      throw const SleepEventException('Utilizador não autenticado');
    }
    
    if (activeBaby == null) {
      throw const SleepEventException('Nenhum bebé selecionado');
    }

    // Load events and check for overlaps with OTHER sessions
    List<SleepEvent> eventsToCheck = state.value ?? [];
    if (eventsToCheck.isEmpty) {
      try {
        eventsToCheck = await _loadEvents(activeBaby.id);
      } catch (e) {
        // ignore: avoid_print
        print('[SleepEventsProvider] editSleepSession: failed to load events: $e');
      }
    }
    
    // Filter out the original session's events for overlap check
    final originalEventIds = {original.startEvent.id, original.endEvent!.id};
    final eventsFiltered = eventsToCheck.where((e) => !originalEventIds.contains(e.id)).toList();
    
    final overlappingSessions = _findOverlappingSessions(
      startUtc: startUtc,
      endUtc: endUtc,
      events: eventsFiltered,
    );
    
    if (overlappingSessions.isNotEmpty && extraSessionsToOverwrite.isEmpty) {
      // User hasn't confirmed to overwrite - throw exception with overlapping sessions
      final sessionStr = overlappingSessions.map(_formatSleepSession).join(', ');
      // ignore: avoid_print
      print('[SleepEventsProvider] editSleepSession: overlap detected: $sessionStr');
      throw OverlapException(
        message: 'Já existe sono registado nesse período ($sessionStr)',
        overlappingSessions: overlappingSessions,
      );
    }
    
    // Combine original session with any extra sessions to overwrite
    final allSessionsToOverwrite = [original, ...extraSessionsToOverwrite];
    
    // Use overwriteAndCreateSession which handles all the correction logic
    await overwriteAndCreateSession(
      overlappingSessions: allSessionsToOverwrite,
      newStartTime: newStartTime,
      newEndTime: newEndTime,
    );
  }

  // ========== MULTI-DEVICE CONFLICT DETECTION AND RESOLUTION ==========

  /// Detects duplicate SleepStart conflicts in the current events
  /// 
  /// A conflict is when a SleepStart appears while there is already an open SleepStart
  /// (no SleepEnd in between). This indicates multi-device double-start or a correction.
  /// 
  /// Returns list of conflict groups (empty if no conflicts).
  List<DuplicateStartConflict> detectDuplicateStartConflicts() {
    final events = state.value ?? [];
    
    // #region agent log H3/H5 - Conflict detection entry
    // ignore: avoid_print
    print('[DEBUG-H3] detectDuplicateStartConflicts CALLED - total events: ${events.length}');
    // #endregion
    
    final validEvents = events
        .where((e) => e.isValid)
        .toList()
      ..sort((a, b) {
        final timestampCompare = a.timestamp.compareTo(b.timestamp);
        if (timestampCompare != 0) return timestampCompare;
        return a.createdAt.compareTo(b.createdAt);
      });
    
    // #region agent log H3 - Valid events for conflict check
    // ignore: avoid_print
    print('[DEBUG-H3] Valid events for conflict check: ${validEvents.length}');
    for (final e in validEvents) {
      // ignore: avoid_print
      print('[DEBUG-H3]   id=${e.id.substring(0, 8)}, type=${e.type.name}, ts=${e.timestamp}, isCorrected=${e.isCorrected}');
    }
    // #endregion
    
    final conflicts = <DuplicateStartConflict>[];
    
    SleepEvent? currentStart;
    List<SleepEvent>? conflictStarts;
    
    for (final event in validEvents) {
      if (event.type == SleepEventType.sleepStart) {
        if (currentStart == null) {
          currentStart = event;
          continue;
        }
        
        // Start while already open -> conflict group
        conflictStarts ??= [currentStart];
        conflictStarts.add(event);
        
        // Winner for pairing is the most recent start (later timestamp, then createdAt)
        currentStart = event;
      } else if (event.type == SleepEventType.sleepEnd) {
        // Close any conflict group when we see the end
        if (conflictStarts != null && conflictStarts.length > 1) {
          // Sort by createdAt DESC to suggest keeping the most recent action
          final sorted = List<SleepEvent>.from(conflictStarts)
            ..sort((a, b) {
              final ts = b.timestamp.compareTo(a.timestamp);
              if (ts != 0) return ts;
              return b.createdAt.compareTo(a.createdAt);
            });
          
          conflicts.add(DuplicateStartConflict(
            events: sorted,
            conflictTimestamp: sorted.last.timestamp, // earliest timestamp in group
          ));
        }
        
        conflictStarts = null;
        currentStart = null;
      }
    }
    
    // If timeline ended with an open conflict group (no end yet), still surface it
    if (conflictStarts != null && conflictStarts.length > 1) {
      final sorted = List<SleepEvent>.from(conflictStarts)
        ..sort((a, b) {
          final ts = b.timestamp.compareTo(a.timestamp);
          if (ts != 0) return ts;
          return b.createdAt.compareTo(a.createdAt);
        });
      
      conflicts.add(DuplicateStartConflict(
        events: sorted,
        conflictTimestamp: sorted.last.timestamp,
      ));
    }
    
    // ignore: avoid_print
    print('[SleepEventsProvider] detectDuplicateStartConflicts: found ${conflicts.length} conflicts');
    
    // #region agent log H3 - Conflict detection result
    if (conflicts.isNotEmpty) {
      // ignore: avoid_print
      print('[DEBUG-H3] CONFLICTS FOUND:');
      for (final c in conflicts) {
        // ignore: avoid_print
        print('[DEBUG-H3]   conflictTimestamp=${c.conflictTimestamp}, events=${c.events.map((e) => e.id.substring(0, 8)).toList()}');
      }
    } else {
      // ignore: avoid_print
      print('[DEBUG-H3] No conflicts detected');
    }
    // #endregion
    
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
      updates.add(SleepEventModel.fromDomain(_markOriginalCorrectedForLocal(
        original: loser,
        correctionEventId: correctionId,
      )));
      
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
    
    // FIX P4: Trigger auto-sync after conflict resolution
    ref.read(syncProvider.notifier).scheduleSyncAfterLocalChange(activeBaby.id);
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
