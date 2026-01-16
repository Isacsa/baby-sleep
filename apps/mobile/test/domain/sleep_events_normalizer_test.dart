import 'package:flutter_test/flutter_test.dart';
import 'package:temp_flutter/domain/entities/sleep_event.dart';
import 'package:temp_flutter/domain/services/sleep_events_normalizer.dart';

void main() {
  group('SleepEventsNormalizer', () {
    // Helper to create SleepEvent with minimal boilerplate
    SleepEvent createEvent({
      required String id,
      required SleepEventType type,
      required DateTime timestamp,
      DateTime? createdAt,
      bool isCorrected = false,
      String? correctedBy,
      String babyId = 'baby-1',
      String caregiverId = 'caregiver-1',
    }) {
      return SleepEvent(
        id: id,
        babyId: babyId,
        type: type,
        timestamp: timestamp,
        caregiverId: caregiverId,
        deviceId: 'device-1',
        createdAt: createdAt ?? timestamp,
        isCorrected: isCorrected,
        correctedBy: correctedBy,
      );
    }

    group('Idempotency', () {
      test('running normalize twice produces same output', () {
        final baseTime = DateTime.utc(2024, 1, 1, 12, 0);
        
        // Two conflicting starts
        final events = [
          createEvent(
            id: 'start-1',
            type: SleepEventType.sleepStart,
            timestamp: baseTime,
          ),
          createEvent(
            id: 'start-2',
            type: SleepEventType.sleepStart,
            timestamp: baseTime.add(const Duration(seconds: 30)),
          ),
        ];

        // First normalization
        final plan1 = SleepEventsNormalizer.normalize(events);
        
        expect(plan1.hasUpdates, isTrue);
        expect(plan1.updates.length, equals(1));

        // Simulate applying the plan: mark loser as corrected
        final loserUpdate = plan1.updates.first;
        final eventsAfterApply = events.map((e) {
          if (e.id == loserUpdate.eventId) {
            return e.copyWith(
              isCorrected: true,
              correctedBy: loserUpdate.setCorrectedBy,
            );
          }
          return e;
        }).toList();

        // Second normalization on already-normalized data
        final plan2 = SleepEventsNormalizer.normalize(eventsAfterApply);

        // Should produce empty plan (idempotent)
        expect(plan2.isEmpty, isTrue);
        expect(plan2.updates.length, equals(0));
      });

      test('empty event list produces empty plan', () {
        final plan = SleepEventsNormalizer.normalize([]);
        
        expect(plan.isEmpty, isTrue);
        expect(plan.logs.isNotEmpty, isTrue);
      });

      test('single start event produces empty plan', () {
        final events = [
          createEvent(
            id: 'start-1',
            type: SleepEventType.sleepStart,
            timestamp: DateTime.utc(2024, 1, 1, 12, 0),
          ),
        ];

        final plan = SleepEventsNormalizer.normalize(events);
        
        expect(plan.isEmpty, isTrue);
      });

      test('complete session (start-end) produces empty plan', () {
        final baseTime = DateTime.utc(2024, 1, 1, 12, 0);
        
        final events = [
          createEvent(
            id: 'start-1',
            type: SleepEventType.sleepStart,
            timestamp: baseTime,
          ),
          createEvent(
            id: 'end-1',
            type: SleepEventType.sleepEnd,
            timestamp: baseTime.add(const Duration(hours: 1)),
          ),
        ];

        final plan = SleepEventsNormalizer.normalize(events);
        
        expect(plan.isEmpty, isTrue);
      });
    });

    group('Start-Start Conflict Resolution', () {
      test('marks loser with is_corrected=true and corrected_by=winner.id', () {
        final baseTime = DateTime.utc(2024, 1, 1, 12, 0);
        
        // Two conflicting starts - start-2 has later timestamp, should win
        final events = [
          createEvent(
            id: 'start-1',
            type: SleepEventType.sleepStart,
            timestamp: baseTime,
          ),
          createEvent(
            id: 'start-2',
            type: SleepEventType.sleepStart,
            timestamp: baseTime.add(const Duration(minutes: 5)),
          ),
        ];

        final plan = SleepEventsNormalizer.normalize(events);
        
        expect(plan.hasUpdates, isTrue);
        expect(plan.updates.length, equals(1));
        
        final update = plan.updates.first;
        expect(update.eventId, equals('start-1')); // Loser (earlier timestamp)
        expect(update.setCorrectedBy, equals('start-2')); // Winner (later timestamp)
      });

      test('includes winner_event_id in metadata', () {
        final baseTime = DateTime.utc(2024, 1, 1, 12, 0);
        
        final events = [
          createEvent(
            id: 'start-1',
            type: SleepEventType.sleepStart,
            timestamp: baseTime,
          ),
          createEvent(
            id: 'start-2',
            type: SleepEventType.sleepStart,
            timestamp: baseTime.add(const Duration(minutes: 5)),
          ),
        ];

        final plan = SleepEventsNormalizer.normalize(events);
        
        final update = plan.updates.first;
        expect(update.metadataPatch['winner_event_id'], equals('start-2'));
        expect(update.metadataPatch['correction_reason'], equals('duplicate_multi_device'));
        expect(update.metadataPatch['policy_version'], equals('v1'));
      });

      test('winner is deterministic: later timestamp wins', () {
        final baseTime = DateTime.utc(2024, 1, 1, 12, 0);
        
        // start-1 is earlier, start-2 is later
        final events = [
          createEvent(
            id: 'start-1',
            type: SleepEventType.sleepStart,
            timestamp: baseTime,
          ),
          createEvent(
            id: 'start-2',
            type: SleepEventType.sleepStart,
            timestamp: baseTime.add(const Duration(seconds: 1)),
          ),
        ];

        final plan = SleepEventsNormalizer.normalize(events);
        
        expect(plan.updates.first.eventId, equals('start-1')); // Earlier = loser
        expect(plan.updates.first.setCorrectedBy, equals('start-2')); // Later = winner
      });

      test('winner is deterministic: tie-break by created_at', () {
        final baseTime = DateTime.utc(2024, 1, 1, 12, 0);
        
        // Same timestamp, different created_at
        final events = [
          createEvent(
            id: 'start-1',
            type: SleepEventType.sleepStart,
            timestamp: baseTime,
            createdAt: baseTime,
          ),
          createEvent(
            id: 'start-2',
            type: SleepEventType.sleepStart,
            timestamp: baseTime, // Same timestamp
            createdAt: baseTime.add(const Duration(milliseconds: 100)), // Later created_at
          ),
        ];

        final plan = SleepEventsNormalizer.normalize(events);
        
        expect(plan.updates.first.eventId, equals('start-1')); // Earlier created_at = loser
        expect(plan.updates.first.setCorrectedBy, equals('start-2')); // Later created_at = winner
      });

      test('winner is deterministic: tie-break by id (lexicographic)', () {
        final baseTime = DateTime.utc(2024, 1, 1, 12, 0);
        
        // Same timestamp and created_at, different IDs
        final events = [
          createEvent(
            id: 'aaa-start',
            type: SleepEventType.sleepStart,
            timestamp: baseTime,
            createdAt: baseTime,
          ),
          createEvent(
            id: 'zzz-start',
            type: SleepEventType.sleepStart,
            timestamp: baseTime,
            createdAt: baseTime,
          ),
        ];

        final plan = SleepEventsNormalizer.normalize(events);
        
        expect(plan.updates.first.eventId, equals('aaa-start')); // Lexicographically smaller = loser
        expect(plan.updates.first.setCorrectedBy, equals('zzz-start')); // Lexicographically larger = winner
      });

      test('handles multiple start-start conflicts', () {
        final baseTime = DateTime.utc(2024, 1, 1, 12, 0);
        
        // Three starts in sequence without ends
        final events = [
          createEvent(
            id: 'start-1',
            type: SleepEventType.sleepStart,
            timestamp: baseTime,
          ),
          createEvent(
            id: 'start-2',
            type: SleepEventType.sleepStart,
            timestamp: baseTime.add(const Duration(minutes: 5)),
          ),
          createEvent(
            id: 'start-3',
            type: SleepEventType.sleepStart,
            timestamp: baseTime.add(const Duration(minutes: 10)),
          ),
        ];

        final plan = SleepEventsNormalizer.normalize(events);
        
        // Two conflicts: start-1 vs start-2, then winner vs start-3
        expect(plan.updates.length, equals(2));
        
        // Both losers should be marked
        final loserIds = plan.updates.map((u) => u.eventId).toSet();
        expect(loserIds.contains('start-1'), isTrue);
        expect(loserIds.contains('start-2'), isTrue);
        expect(loserIds.contains('start-3'), isFalse); // Final winner
      });

      test('start-end-start-start detects conflict on second pair only', () {
        final baseTime = DateTime.utc(2024, 1, 1, 12, 0);
        
        final events = [
          createEvent(
            id: 'start-1',
            type: SleepEventType.sleepStart,
            timestamp: baseTime,
          ),
          createEvent(
            id: 'end-1',
            type: SleepEventType.sleepEnd,
            timestamp: baseTime.add(const Duration(hours: 1)),
          ),
          createEvent(
            id: 'start-2',
            type: SleepEventType.sleepStart,
            timestamp: baseTime.add(const Duration(hours: 2)),
          ),
          createEvent(
            id: 'start-3',
            type: SleepEventType.sleepStart,
            timestamp: baseTime.add(const Duration(hours: 2, minutes: 5)),
          ),
        ];

        final plan = SleepEventsNormalizer.normalize(events);
        
        // Only one conflict: start-2 vs start-3
        expect(plan.updates.length, equals(1));
        expect(plan.updates.first.eventId, equals('start-2'));
        expect(plan.updates.first.setCorrectedBy, equals('start-3'));
      });
    });

    group('Orphan SleepEnd Handling', () {
      test('orphan SleepEnd is NOT modified by normalizer v1', () {
        final baseTime = DateTime.utc(2024, 1, 1, 12, 0);
        
        // Only an end event (no start)
        final events = [
          createEvent(
            id: 'end-1',
            type: SleepEventType.sleepEnd,
            timestamp: baseTime,
          ),
        ];

        final plan = SleepEventsNormalizer.normalize(events);
        
        // Plan should be empty - orphan end is ignored
        expect(plan.isEmpty, isTrue);
      });

      test('multiple orphan ends are NOT modified', () {
        final baseTime = DateTime.utc(2024, 1, 1, 12, 0);
        
        final events = [
          createEvent(
            id: 'end-1',
            type: SleepEventType.sleepEnd,
            timestamp: baseTime,
          ),
          createEvent(
            id: 'end-2',
            type: SleepEventType.sleepEnd,
            timestamp: baseTime.add(const Duration(hours: 1)),
          ),
        ];

        final plan = SleepEventsNormalizer.normalize(events);
        
        expect(plan.isEmpty, isTrue);
      });

      test('orphan end after valid session is logged but not modified', () {
        final baseTime = DateTime.utc(2024, 1, 1, 12, 0);
        
        final events = [
          createEvent(
            id: 'start-1',
            type: SleepEventType.sleepStart,
            timestamp: baseTime,
          ),
          createEvent(
            id: 'end-1',
            type: SleepEventType.sleepEnd,
            timestamp: baseTime.add(const Duration(hours: 1)),
          ),
          createEvent(
            id: 'end-2', // Orphan end
            type: SleepEventType.sleepEnd,
            timestamp: baseTime.add(const Duration(hours: 2)),
          ),
        ];

        final plan = SleepEventsNormalizer.normalize(events);
        
        // No updates - orphan end is ignored
        expect(plan.isEmpty, isTrue);
        
        // But it should be logged
        final hasOrphanLog = plan.logs.any((log) => log.contains('Orphan End detected'));
        expect(hasOrphanLog, isTrue);
      });
    });

    group('Already Corrected Events', () {
      test('already corrected events are excluded from conflict detection', () {
        final baseTime = DateTime.utc(2024, 1, 1, 12, 0);
        
        final events = [
          createEvent(
            id: 'start-1',
            type: SleepEventType.sleepStart,
            timestamp: baseTime,
            isCorrected: true, // Already corrected
            correctedBy: 'start-2',
          ),
          createEvent(
            id: 'start-2',
            type: SleepEventType.sleepStart,
            timestamp: baseTime.add(const Duration(minutes: 5)),
          ),
        ];

        final plan = SleepEventsNormalizer.normalize(events);
        
        // No new updates - start-1 is already corrected
        expect(plan.isEmpty, isTrue);
      });
    });

    group('Logging', () {
      test('logs include conflict count and update count', () {
        final baseTime = DateTime.utc(2024, 1, 1, 12, 0);
        
        final events = [
          createEvent(
            id: 'start-1',
            type: SleepEventType.sleepStart,
            timestamp: baseTime,
          ),
          createEvent(
            id: 'start-2',
            type: SleepEventType.sleepStart,
            timestamp: baseTime.add(const Duration(minutes: 5)),
          ),
        ];

        final plan = SleepEventsNormalizer.normalize(events);
        
        expect(plan.logs.isNotEmpty, isTrue);
        
        final hasConflictLog = plan.logs.any((log) => log.contains('Conflicts detected: 1'));
        expect(hasConflictLog, isTrue);
        
        final hasUpdateLog = plan.logs.any((log) => log.contains('Updates planned: 1'));
        expect(hasUpdateLog, isTrue);
      });
    });
  });
}
