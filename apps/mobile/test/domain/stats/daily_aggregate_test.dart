import 'package:flutter_test/flutter_test.dart';
import 'package:temp_flutter/domain/entities/sleep_event.dart';
import 'package:temp_flutter/domain/stats/daily_sleep_aggregate.dart';
import 'package:temp_flutter/domain/value_objects/sleep_session.dart';

void main() {
  group('DailySleepAggregateCalculator', () {
    group('basic calculations', () {
      test('calculates total minutes for a single session', () {
        // Session from 22:00 to 06:00 (8 hours)
        final sessions = [
          _createSession(
            startHour: 22,
            startMinute: 0,
            endHour: 6,
            endMinute: 0,
            crossesMidnight: true,
          ),
        ];

        final aggregates = DailySleepAggregateCalculator.calculate(
          sessions: sessions,
          startLocal: DateTime(2024, 1, 1),
          endExclusiveLocal: DateTime(2024, 1, 3),
        );

        // Day 1: 22:00 to 00:00 = 2 hours = 120 min
        // Day 2: 00:00 to 06:00 = 6 hours = 360 min
        expect(aggregates.length, 2);
        expect(aggregates[0].totalMinutes, 120);
        expect(aggregates[1].totalMinutes, 360);
      });

      test('splits night vs nap correctly', () {
        // Session during day (nap): 14:00 to 15:30
        final sessions = [
          _createSession(
            startHour: 14,
            startMinute: 0,
            endHour: 15,
            endMinute: 30,
            dayOffset: 1,
          ),
        ];

        final aggregates = DailySleepAggregateCalculator.calculate(
          sessions: sessions,
          startLocal: DateTime(2024, 1, 1),
          endExclusiveLocal: DateTime(2024, 1, 2),
        );

        expect(aggregates.length, 1);
        expect(aggregates[0].napMinutes, 90); // All 90 min are nap
        expect(aggregates[0].nightMinutes, 0);
      });

      test('classifies night sleep correctly', () {
        // Session during night: 21:00 to 22:30
        final sessions = [
          _createSession(
            startHour: 21,
            startMinute: 0,
            endHour: 22,
            endMinute: 30,
            dayOffset: 1,
          ),
        ];

        final aggregates = DailySleepAggregateCalculator.calculate(
          sessions: sessions,
          startLocal: DateTime(2024, 1, 1),
          endExclusiveLocal: DateTime(2024, 1, 2),
        );

        expect(aggregates.length, 1);
        expect(aggregates[0].nightMinutes, 90); // All 90 min are night
        expect(aggregates[0].napMinutes, 0);
      });
    });

    group('cross-midnight sessions', () {
      test('clips session to each day correctly', () {
        // Session from 23:00 Day 1 to 07:00 Day 2
        final sessions = [
          _createSession(
            startHour: 23,
            startMinute: 0,
            endHour: 7,
            endMinute: 0,
            crossesMidnight: true,
          ),
        ];

        final aggregates = DailySleepAggregateCalculator.calculate(
          sessions: sessions,
          startLocal: DateTime(2024, 1, 1),
          endExclusiveLocal: DateTime(2024, 1, 3),
        );

        expect(aggregates.length, 2);
        // Day 1: 23:00-00:00 = 60 min
        expect(aggregates[0].totalMinutes, 60);
        // Day 2: 00:00-07:00 = 420 min
        expect(aggregates[1].totalMinutes, 420);
      });
    });

    group('ongoing sessions', () {
      test('handles ongoing session with now as end time', () {
        final now = DateTime.now();
        final startTime = now.subtract(const Duration(hours: 2));

        final startEvent = SleepEvent(
          id: 'start-1',
          babyId: 'baby-1',
          type: SleepEventType.sleepStart,
          timestamp: startTime.toUtc(),
          createdAt: startTime.toUtc(),
          caregiverId: 'cg-1',
          deviceId: 'dev-1',
        );

        final sessions = [
          SleepSession.fromEvents(startEvent: startEvent),
        ];

        final todayStart = DateTime(now.year, now.month, now.day);
        final tomorrowStart = todayStart.add(const Duration(days: 1));

        final aggregates = DailySleepAggregateCalculator.calculate(
          sessions: sessions,
          startLocal: todayStart,
          endExclusiveLocal: tomorrowStart,
        );

        expect(aggregates.length, 1);
        expect(aggregates[0].hasOngoingSleep, true);
        // Should have approximately 2 hours (give or take a few minutes)
        expect(aggregates[0].totalMinutes, greaterThanOrEqualTo(118));
        expect(aggregates[0].totalMinutes, lessThanOrEqualTo(125));
      });
    });

    group('bedtime detection', () {
      test('detects bedtime for sessions starting 19:00-02:00', () {
        // Bedtime session starting at 20:30
        final sessions = [
          _createSession(
            startHour: 20,
            startMinute: 30,
            endHour: 6,
            endMinute: 0,
            crossesMidnight: true,
          ),
        ];

        final aggregates = DailySleepAggregateCalculator.calculate(
          sessions: sessions,
          startLocal: DateTime(2024, 1, 1),
          endExclusiveLocal: DateTime(2024, 1, 3),
        );

        // Day 1 should have bedtime at 20:30
        expect(aggregates[0].bedtimeStartLocal, isNotNull);
        expect(aggregates[0].bedtimeStartLocal!.hour, 20);
        expect(aggregates[0].bedtimeStartLocal!.minute, 30);
      });

      test('ignores short sessions for bedtime', () {
        // Short session (25 min) - should not count as bedtime
        final sessions = [
          _createSession(
            startHour: 20,
            startMinute: 0,
            endHour: 20,
            endMinute: 25,
            dayOffset: 1,
          ),
        ];

        final aggregates = DailySleepAggregateCalculator.calculate(
          sessions: sessions,
          startLocal: DateTime(2024, 1, 1),
          endExclusiveLocal: DateTime(2024, 1, 2),
        );

        // Should not have bedtime (session too short)
        expect(aggregates[0].bedtimeStartLocal, isNull);
      });
    });

    group('empty periods', () {
      test('returns aggregates with zero minutes for days without data', () {
        final sessions = <SleepSession>[];

        final aggregates = DailySleepAggregateCalculator.calculate(
          sessions: sessions,
          startLocal: DateTime(2024, 1, 1),
          endExclusiveLocal: DateTime(2024, 1, 4),
        );

        expect(aggregates.length, 3);
        for (final agg in aggregates) {
          expect(agg.totalMinutes, 0);
          expect(agg.nightMinutes, 0);
          expect(agg.napMinutes, 0);
        }
      });
    });
  });

  group('NightWindow', () {
    test('containsHour works for window crossing midnight', () {
      const window = NightWindow(startHour: 19, endHour: 7);

      // Night hours (should be true)
      expect(window.containsHour(19), true);
      expect(window.containsHour(22), true);
      expect(window.containsHour(0), true);
      expect(window.containsHour(3), true);
      expect(window.containsHour(6), true);

      // Day hours (should be false)
      expect(window.containsHour(7), false);
      expect(window.containsHour(12), false);
      expect(window.containsHour(18), false);
    });
  });
}

/// Helper to create a test session
SleepSession _createSession({
  required int startHour,
  required int startMinute,
  required int endHour,
  required int endMinute,
  bool crossesMidnight = false,
  int dayOffset = 1,
}) {
  final baseDate = DateTime(2024, 1, dayOffset);
  final startLocal = DateTime(
    baseDate.year,
    baseDate.month,
    baseDate.day,
    startHour,
    startMinute,
  );

  DateTime endLocal;
  if (crossesMidnight) {
    endLocal = DateTime(
      baseDate.year,
      baseDate.month,
      baseDate.day + 1,
      endHour,
      endMinute,
    );
  } else {
    endLocal = DateTime(
      baseDate.year,
      baseDate.month,
      baseDate.day,
      endHour,
      endMinute,
    );
  }

  final startEvent = SleepEvent(
    id: 'start-${startLocal.hashCode}',
    babyId: 'baby-1',
    type: SleepEventType.sleepStart,
    timestamp: startLocal.toUtc(),
    createdAt: startLocal.toUtc(),
    caregiverId: 'cg-1',
    deviceId: 'dev-1',
  );

  final endEvent = SleepEvent(
    id: 'end-${endLocal.hashCode}',
    babyId: 'baby-1',
    type: SleepEventType.sleepEnd,
    timestamp: endLocal.toUtc(),
    createdAt: endLocal.toUtc(),
    caregiverId: 'cg-1',
    deviceId: 'dev-1',
  );

  return SleepSession.fromEvents(startEvent: startEvent, endEvent: endEvent);
}
