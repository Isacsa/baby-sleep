import 'package:temp_flutter/domain/entities/sleep_event.dart';

/// SleepSession value object
/// 
/// Derived state (not persisted)
/// Calculated in memory from grouping consecutive events
/// Represents a sleep session (SleepStart followed by SleepEnd)
class SleepSession {
  final SleepEvent startEvent; // SleepStart
  final SleepEvent? endEvent; // SleepEnd, NULL if still sleeping
  final Duration? duration; // Calculated if endEvent exists
  final bool isComplete; // true if has endEvent

  const SleepSession({
    required this.startEvent,
    this.endEvent,
    this.duration,
    required this.isComplete,
  });

  /// Creates SleepSession from start event
  /// 
  /// If endEvent is provided, calculates duration
  factory SleepSession.fromEvents({
    required SleepEvent startEvent,
    SleepEvent? endEvent,
  }) {
    Duration? duration;
    if (endEvent != null) {
      duration = endEvent.timestamp.difference(startEvent.timestamp);
    }

    return SleepSession(
      startEvent: startEvent,
      endEvent: endEvent,
      duration: duration,
      isComplete: endEvent != null,
    );
  }

  /// When a SleepStart appears while we already have an open SleepStart (no SleepEnd yet),
  /// we treat it as a multi-device conflict/correction and NEVER emit a phantom incomplete
  /// session for the previous start (which would create permanent overlap).
  ///
  /// Winner rule (deterministic, non-blocking):
  /// - Keep the most recent start for derivation (later timestamp wins; if equal, later createdAt wins)
  ///
  /// The UI can still prompt the user to resolve/mark corrections, but derivation must stay usable.

  /// Groups events into sessions
  /// 
  /// Algorithm:
  /// 1. Filter valid events (isCorrected = false)
  /// 2. Sort by timestamp ASC, then createdAt ASC
  /// 3. Group consecutive SleepStart/SleepEnd pairs
  /// 4. If a SleepStart occurs while there is already an open SleepStart (no SleepEnd yet),
  ///    treat it as a conflict and keep a deterministic winner for derivation (most recent start).
  ///    Never emit a phantom incomplete session for the previous start.
  /// 5. If last event is SleepStart without SleepEnd: incomplete session
  static List<SleepSession> fromEventList(List<SleepEvent> events, {bool debug = false}) {
    // Filter valid events and sort by timestamp ASC, createdAt ASC
    final validEvents = events
        .where((e) => e.isValid)
        .toList()
      ..sort((a, b) {
        final timestampCompare = a.timestamp.compareTo(b.timestamp);
        if (timestampCompare != 0) return timestampCompare;
        return a.createdAt.compareTo(b.createdAt);
      });

    // === DEBUG LOG H2: Session derivation ===
    if (debug) {
      // ignore: avoid_print
      print('[SleepSession][H2-DEBUG] ===== DERIVING SESSIONS =====');
      // ignore: avoid_print
      print('[SleepSession][H2-DEBUG] Total events: ${events.length}, valid: ${validEvents.length}');
      // ignore: avoid_print
      print('[SleepSession][H2-DEBUG] Valid events (sorted):');
      for (var i = 0; i < validEvents.length && i < 10; i++) {
        final e = validEvents[i];
        // ignore: avoid_print
        print('  [$i] ${e.id.substring(0, 8)} ${e.type.name} ts=${e.timestamp} created=${e.createdAt} device=${e.deviceId.substring(0, 8)}');
      }
      if (validEvents.length > 10) {
        // ignore: avoid_print
        print('  ... and ${validEvents.length - 10} more');
      }
    }

    final sessions = <SleepSession>[];
    SleepEvent? currentStart;
    int conflictsDetected = 0;

    for (final event in validEvents) {
      if (event.type == SleepEventType.sleepStart) {
        if (currentStart != null) {
          // Conflict: SleepStart while another is still open (no SleepEnd yet).
          // Never emit a phantom incomplete session for the previous start (would cause overlap).
          conflictsDetected++;

          // Choose winner deterministically: most recent start wins (later timestamp, then createdAt)
          final shouldReplace = event.timestamp.isAfter(currentStart.timestamp) ||
              (event.timestamp.isAtSameMomentAs(currentStart.timestamp) &&
                  event.createdAt.isAfter(currentStart.createdAt));

          if (debug) {
            // ignore: avoid_print
            print('[SleepSession][H2-DEBUG] CONFLICT Start while open: ${event.id.substring(0, 8)} vs ${currentStart.id.substring(0, 8)}');
            // ignore: avoid_print
            print('[SleepSession][H2-DEBUG]   Keeping: ${(shouldReplace ? event.id.substring(0, 8) : currentStart.id.substring(0, 8))}');
          }

          if (shouldReplace) {
            currentStart = event;
          }
        } else {
          currentStart = event;
        }
      } else if (event.type == SleepEventType.sleepEnd) {
        if (currentStart != null) {
          // Complete session
          if (debug) {
            // ignore: avoid_print
            print('[SleepSession][H2-DEBUG] Complete session: ${currentStart.id.substring(0, 8)} -> ${event.id.substring(0, 8)}');
          }
          sessions.add(SleepSession.fromEvents(
            startEvent: currentStart,
            endEvent: event,
          ));
          currentStart = null;
        } else {
          // If no start, ignore orphaned SleepEnd
          if (debug) {
            // ignore: avoid_print
            print('[SleepSession][H2-DEBUG] Orphaned SleepEnd ignored: ${event.id.substring(0, 8)}');
          }
        }
      }
    }

    // Add incomplete session if exists
    if (currentStart != null) {
      if (debug) {
        // ignore: avoid_print
        print('[SleepSession][H2-DEBUG] Final incomplete session (still sleeping): ${currentStart.id.substring(0, 8)}');
      }
      sessions.add(SleepSession.fromEvents(startEvent: currentStart));
    }

    if (debug) {
      // ignore: avoid_print
      print('[SleepSession][H2-DEBUG] Sessions derived: ${sessions.length} (complete: ${sessions.where((s) => s.isComplete).length}, incomplete: ${sessions.where((s) => !s.isComplete).length})');
      // ignore: avoid_print
      print('[SleepSession][H2-DEBUG] Start-while-open conflicts detected and merged: $conflictsDetected');
      // ignore: avoid_print
      print('[SleepSession][H2-DEBUG] ===== END DERIVATION =====');
    }

    return sessions;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SleepSession &&
          runtimeType == other.runtimeType &&
          startEvent.id == other.startEvent.id &&
          endEvent?.id == other.endEvent?.id;

  @override
  int get hashCode => Object.hash(startEvent.id, endEvent?.id);

  @override
  String toString() =>
      'SleepSession(start: ${startEvent.id}, end: ${endEvent?.id}, complete: $isComplete)';
}

