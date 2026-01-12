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

  /// Groups events into sessions
  /// 
  /// Algorithm:
  /// 1. Filter valid events (isCorrected = false)
  /// 2. Sort by timestamp ASC
  /// 3. Group consecutive SleepStart/SleepEnd pairs
  /// 4. If last event is SleepStart without SleepEnd: incomplete session
  static List<SleepSession> fromEventList(List<SleepEvent> events) {
    // Filter valid events and sort by timestamp ASC
    final validEvents = events
        .where((e) => e.isValid)
        .toList()
      ..sort((a, b) {
        final timestampCompare = a.timestamp.compareTo(b.timestamp);
        if (timestampCompare != 0) return timestampCompare;
        return a.createdAt.compareTo(b.createdAt);
      });

    final sessions = <SleepSession>[];
    SleepEvent? currentStart;

    for (final event in validEvents) {
      if (event.type == SleepEventType.sleepStart) {
        // If we have a pending start, it's an incomplete session
        if (currentStart != null) {
          sessions.add(SleepSession.fromEvents(startEvent: currentStart));
        }
        currentStart = event;
      } else if (event.type == SleepEventType.sleepEnd) {
        if (currentStart != null) {
          // Complete session
          sessions.add(SleepSession.fromEvents(
            startEvent: currentStart,
            endEvent: event,
          ));
          currentStart = null;
        }
        // If no start, ignore orphaned SleepEnd
      }
    }

    // Add incomplete session if exists
    if (currentStart != null) {
      sessions.add(SleepSession.fromEvents(startEvent: currentStart));
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

