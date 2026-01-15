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

  /// Time window for detecting duplicate SleepStart from multiple devices
  /// 
  /// IMPORTANT: Set to a generous window (5 minutes) to handle multi-device scenarios
  /// where users might tap "Start sleep" on different devices with some delay.
  /// A 1-second window was too narrow for realistic multi-device conflicts.
  static const Duration duplicateTimeWindow = Duration(minutes: 5);

  /// Groups events into sessions
  /// 
  /// Algorithm:
  /// 1. Filter valid events (isCorrected = false)
  /// 2. Sort by timestamp ASC, then createdAt ASC
  /// 3. Group consecutive SleepStart/SleepEnd pairs
  /// 4. Handle duplicate SleepStart (multi-device): if two SleepStart have
  ///    timestamps within 1 second, keep the one with latest createdAt (winner)
  ///    and ignore the other for session derivation (avoids phantom incomplete sessions)
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
    int duplicatesDetected = 0;

    for (final event in validEvents) {
      if (event.type == SleepEventType.sleepStart) {
        if (currentStart != null) {
          // Check if this is a duplicate from multi-device (timestamps within 1 second)
          final timeDiff = event.timestamp.difference(currentStart.timestamp).abs();
          
          if (timeDiff < duplicateTimeWindow) {
            duplicatesDetected++;
            // Duplicate detected: keep the one with latest createdAt (winner)
            // This prevents phantom incomplete sessions from multi-device conflicts
            if (debug) {
              // ignore: avoid_print
              print('[SleepSession][H2-DEBUG] DUPLICATE Start detected: ${event.id.substring(0, 8)} vs ${currentStart.id.substring(0, 8)} (diff=${timeDiff.inMilliseconds}ms)');
            }
            if (event.createdAt.isAfter(currentStart.createdAt)) {
              // New event is the winner - replace currentStart
              if (debug) {
                // ignore: avoid_print
                print('[SleepSession][H2-DEBUG]   Winner: ${event.id.substring(0, 8)} (newer createdAt)');
              }
              currentStart = event;
            } else {
              if (debug) {
                // ignore: avoid_print
                print('[SleepSession][H2-DEBUG]   Winner: ${currentStart.id.substring(0, 8)} (older event kept)');
              }
            }
            // Otherwise keep currentStart (it's the winner)
            // Either way, we DON'T create an incomplete session for the loser
          } else {
            // Not a duplicate - previous start is truly incomplete
            if (debug) {
              // ignore: avoid_print
              print('[SleepSession][H2-DEBUG] Incomplete session (no End before next Start): ${currentStart.id.substring(0, 8)}');
            }
            sessions.add(SleepSession.fromEvents(startEvent: currentStart));
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
      print('[SleepSession][H2-DEBUG] Duplicates detected and merged: $duplicatesDetected');
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

