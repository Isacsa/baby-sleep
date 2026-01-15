import 'package:flutter_test/flutter_test.dart';
import 'package:temp_flutter/domain/entities/sleep_event.dart';
import 'package:temp_flutter/domain/value_objects/sleep_session.dart';

void main() {
  group('SleepSession.fromEventList - Duplicate Start Handling', () {
    final baseTime = DateTime.utc(2024, 1, 15, 10, 0); // 10:00 UTC

    SleepEvent createEvent({
      required String id,
      required SleepEventType type,
      required DateTime timestamp,
      required DateTime createdAt,
      bool isCorrected = false,
    }) {
      return SleepEvent(
        id: id,
        babyId: 'baby-1',
        type: type,
        timestamp: timestamp,
        caregiverId: 'caregiver-1',
        deviceId: 'device-1',
        createdAt: createdAt,
        isCorrected: isCorrected,
        syncedAt: null,
        correctedBy: null,
        metadata: null,
      );
    }

    test('should create 1 complete session when 2 SleepStarts have same timestamp + 1 SleepEnd', () {
      // Scenario: Two devices create SleepStart at exactly the same time
      // Device A creates at 10:00:01, Device B creates at 10:00:02
      // Then one creates SleepEnd at 10:30
      
      final events = [
        createEvent(
          id: 'start-a',
          type: SleepEventType.sleepStart,
          timestamp: baseTime, // 10:00
          createdAt: baseTime.add(const Duration(seconds: 1)), // 10:00:01
        ),
        createEvent(
          id: 'start-b',
          type: SleepEventType.sleepStart,
          timestamp: baseTime, // 10:00 (same timestamp)
          createdAt: baseTime.add(const Duration(seconds: 2)), // 10:00:02 (created later)
        ),
        createEvent(
          id: 'end-1',
          type: SleepEventType.sleepEnd,
          timestamp: baseTime.add(const Duration(minutes: 30)), // 10:30
          createdAt: baseTime.add(const Duration(minutes: 30, seconds: 1)),
        ),
      ];

      final sessions = SleepSession.fromEventList(events);

      // Should have exactly 1 session
      expect(sessions.length, 1);
      
      // The session should be complete
      expect(sessions.first.isComplete, true);
      expect(sessions.first.endEvent, isNotNull);
      
      // The winner should be start-b (latest createdAt)
      expect(sessions.first.startEvent.id, 'start-b');
      expect(sessions.first.endEvent!.id, 'end-1');
      
      // Duration should be 30 minutes
      expect(sessions.first.duration, const Duration(minutes: 30));
    });

    test('should create 1 incomplete session when 2 SleepStarts have timestamp diff < 1s', () {
      // Scenario: Two SleepStarts within 500ms of each other (still duplicates)
      
      final events = [
        createEvent(
          id: 'start-a',
          type: SleepEventType.sleepStart,
          timestamp: baseTime,
          createdAt: baseTime.add(const Duration(seconds: 1)),
        ),
        createEvent(
          id: 'start-b',
          type: SleepEventType.sleepStart,
          timestamp: baseTime.add(const Duration(milliseconds: 500)), // 500ms later
          createdAt: baseTime.add(const Duration(seconds: 2)),
        ),
      ];

      final sessions = SleepSession.fromEventList(events);

      // Should have exactly 1 incomplete session (the winner)
      expect(sessions.length, 1);
      expect(sessions.first.isComplete, false);
      expect(sessions.first.startEvent.id, 'start-b'); // Winner (latest createdAt)
    });

    test('should create 2 separate sessions when SleepStarts have timestamp diff > 5 minutes', () {
      // Scenario: Two SleepStarts 6 minutes apart (not duplicates - beyond 5min window)
      
      final events = [
        createEvent(
          id: 'start-a',
          type: SleepEventType.sleepStart,
          timestamp: baseTime,
          createdAt: baseTime.add(const Duration(seconds: 1)),
        ),
        createEvent(
          id: 'start-b',
          type: SleepEventType.sleepStart,
          timestamp: baseTime.add(const Duration(minutes: 6)), // 6 min later = different session (beyond 5min window)
          createdAt: baseTime.add(const Duration(minutes: 6, seconds: 1)),
        ),
      ];

      final sessions = SleepSession.fromEventList(events);

      // Should have 2 incomplete sessions (both are valid, not duplicates)
      expect(sessions.length, 2);
      expect(sessions[0].isComplete, false);
      expect(sessions[1].isComplete, false);
      expect(sessions[0].startEvent.id, 'start-a');
      expect(sessions[1].startEvent.id, 'start-b');
    });

    test('should ignore corrected events', () {
      // Scenario: One Start is marked as corrected
      
      final events = [
        createEvent(
          id: 'start-a',
          type: SleepEventType.sleepStart,
          timestamp: baseTime,
          createdAt: baseTime.add(const Duration(seconds: 1)),
          isCorrected: true, // This one is corrected
        ),
        createEvent(
          id: 'start-b',
          type: SleepEventType.sleepStart,
          timestamp: baseTime,
          createdAt: baseTime.add(const Duration(seconds: 2)),
        ),
        createEvent(
          id: 'end-1',
          type: SleepEventType.sleepEnd,
          timestamp: baseTime.add(const Duration(minutes: 30)),
          createdAt: baseTime.add(const Duration(minutes: 30, seconds: 1)),
        ),
      ];

      final sessions = SleepSession.fromEventList(events);

      // Should have exactly 1 complete session (start-a is filtered out)
      expect(sessions.length, 1);
      expect(sessions.first.isComplete, true);
      expect(sessions.first.startEvent.id, 'start-b');
    });

    test('should handle 3 duplicate SleepStarts correctly', () {
      // Scenario: Three devices create SleepStart at the same time
      
      final events = [
        createEvent(
          id: 'start-a',
          type: SleepEventType.sleepStart,
          timestamp: baseTime,
          createdAt: baseTime.add(const Duration(seconds: 1)),
        ),
        createEvent(
          id: 'start-b',
          type: SleepEventType.sleepStart,
          timestamp: baseTime,
          createdAt: baseTime.add(const Duration(seconds: 2)),
        ),
        createEvent(
          id: 'start-c',
          type: SleepEventType.sleepStart,
          timestamp: baseTime,
          createdAt: baseTime.add(const Duration(seconds: 3)), // Most recent
        ),
        createEvent(
          id: 'end-1',
          type: SleepEventType.sleepEnd,
          timestamp: baseTime.add(const Duration(minutes: 30)),
          createdAt: baseTime.add(const Duration(minutes: 30, seconds: 1)),
        ),
      ];

      final sessions = SleepSession.fromEventList(events);

      // Should have exactly 1 complete session
      expect(sessions.length, 1);
      expect(sessions.first.isComplete, true);
      expect(sessions.first.startEvent.id, 'start-c'); // Winner (latest createdAt)
    });

    test('should handle normal session flow without duplicates', () {
      // Scenario: Normal flow - Start, End, Start, End
      
      final events = [
        createEvent(
          id: 'start-1',
          type: SleepEventType.sleepStart,
          timestamp: baseTime,
          createdAt: baseTime,
        ),
        createEvent(
          id: 'end-1',
          type: SleepEventType.sleepEnd,
          timestamp: baseTime.add(const Duration(hours: 1)),
          createdAt: baseTime.add(const Duration(hours: 1)),
        ),
        createEvent(
          id: 'start-2',
          type: SleepEventType.sleepStart,
          timestamp: baseTime.add(const Duration(hours: 2)),
          createdAt: baseTime.add(const Duration(hours: 2)),
        ),
        createEvent(
          id: 'end-2',
          type: SleepEventType.sleepEnd,
          timestamp: baseTime.add(const Duration(hours: 3)),
          createdAt: baseTime.add(const Duration(hours: 3)),
        ),
      ];

      final sessions = SleepSession.fromEventList(events);

      // Should have 2 complete sessions
      expect(sessions.length, 2);
      expect(sessions[0].isComplete, true);
      expect(sessions[1].isComplete, true);
    });
  });
}
