import 'package:flutter_test/flutter_test.dart';
import 'package:temp_flutter/domain/analysis/sleep_metrics.dart';
import 'package:temp_flutter/domain/analysis/sleep_metrics_calculator.dart';
import 'package:temp_flutter/domain/entities/sleep_event.dart';
import 'package:temp_flutter/domain/value_objects/sleep_session.dart';
import 'package:temp_flutter/domain/value_objects/sleep_state.dart';

void main() {
  group('SleepMetricsCalculator', () {
    final now = DateTime(2026, 1, 19, 12, 0); // Noon

    SleepEvent _createEvent({
      required String id,
      required SleepEventType type,
      required DateTime timestamp,
    }) {
      return SleepEvent(
        id: id,
        babyId: 'baby1',
        caregiverId: 'cg1',
        type: type,
        timestamp: timestamp,
        createdAt: timestamp,
        syncedAt: null,
        isCorrected: false,
        deviceId: 'device1',
      );
    }

    group('empty data', () {
      test('returns empty metrics when no sessions', () {
        final metrics = SleepMetricsCalculator.calculate(
          sessions: [],
          sleepState: const SleepState(isSleeping: false),
          now: now,
        );

        expect(metrics.totalSleepLast24h, Duration.zero);
        expect(metrics.napCountLast24h, 0);
        expect(metrics.hasMinimumData, isFalse);
        expect(metrics.isCurrentlySleeping, isFalse);
      });
    });

    group('totalSleepLast24h', () {
      test('calculates total from sessions in last 24h', () {
        final events = [
          // Session 1: 2 hours sleep (last night 22:00-00:00)
          _createEvent(
            id: 'e1',
            type: SleepEventType.sleepStart,
            timestamp: now.subtract(const Duration(hours: 14)),
          ),
          _createEvent(
            id: 'e2',
            type: SleepEventType.sleepEnd,
            timestamp: now.subtract(const Duration(hours: 12)),
          ),
          // Session 2: 3 hours sleep (this morning 03:00-06:00)
          _createEvent(
            id: 'e3',
            type: SleepEventType.sleepStart,
            timestamp: now.subtract(const Duration(hours: 9)),
          ),
          _createEvent(
            id: 'e4',
            type: SleepEventType.sleepEnd,
            timestamp: now.subtract(const Duration(hours: 6)),
          ),
        ];

        final sessions = SleepSession.fromEventList(events);
        final metrics = SleepMetricsCalculator.calculate(
          sessions: sessions,
          sleepState: const SleepState(isSleeping: false),
          now: now,
        );

        // 2 + 3 = 5 hours = 300 minutes
        expect(metrics.totalSleepLast24h.inMinutes, 300);
      });

      test('clips sessions that cross 24h boundary', () {
        final events = [
          // Session starts 25 hours ago, ends 23 hours ago
          // Only 1 hour should be counted (within 24h window)
          _createEvent(
            id: 'e1',
            type: SleepEventType.sleepStart,
            timestamp: now.subtract(const Duration(hours: 25)),
          ),
          _createEvent(
            id: 'e2',
            type: SleepEventType.sleepEnd,
            timestamp: now.subtract(const Duration(hours: 23)),
          ),
        ];

        final sessions = SleepSession.fromEventList(events);
        final metrics = SleepMetricsCalculator.calculate(
          sessions: sessions,
          sleepState: const SleepState(isSleeping: false),
          now: now,
        );

        // Only 1 hour within the 24h window
        expect(metrics.totalSleepLast24h.inMinutes, 60);
      });

      test('handles incomplete session (currently sleeping)', () {
        final events = [
          // Started sleeping 2 hours ago, still sleeping
          _createEvent(
            id: 'e1',
            type: SleepEventType.sleepStart,
            timestamp: now.subtract(const Duration(hours: 2)),
          ),
        ];

        final sessions = SleepSession.fromEventList(events);
        final metrics = SleepMetricsCalculator.calculate(
          sessions: sessions,
          sleepState: const SleepState(isSleeping: true),
          now: now,
        );

        // 2 hours of ongoing sleep
        expect(metrics.totalSleepLast24h.inMinutes, 120);
        expect(metrics.isCurrentlySleeping, isTrue);
      });
    });

    group('napCountLast24h', () {
      test('counts daytime sessions as naps', () {
        final events = [
          // Nap 1: 09:00-10:00
          _createEvent(
            id: 'e1',
            type: SleepEventType.sleepStart,
            timestamp: DateTime(2026, 1, 19, 9, 0),
          ),
          _createEvent(
            id: 'e2',
            type: SleepEventType.sleepEnd,
            timestamp: DateTime(2026, 1, 19, 10, 0),
          ),
          // Nap 2: 14:00-15:00
          _createEvent(
            id: 'e3',
            type: SleepEventType.sleepStart,
            timestamp: DateTime(2026, 1, 19, 14, 0),
          ),
          _createEvent(
            id: 'e4',
            type: SleepEventType.sleepEnd,
            timestamp: DateTime(2026, 1, 19, 15, 0),
          ),
        ];

        final sessions = SleepSession.fromEventList(events);
        final metrics = SleepMetricsCalculator.calculate(
          sessions: sessions,
          sleepState: const SleepState(isSleeping: false),
          now: DateTime(2026, 1, 19, 16, 0),
        );

        expect(metrics.napCountLast24h, 2);
      });

      test('does not count night sleep as naps', () {
        final events = [
          // Night sleep: 21:00-06:00 (starts after 18:00)
          _createEvent(
            id: 'e1',
            type: SleepEventType.sleepStart,
            timestamp: DateTime(2026, 1, 18, 21, 0),
          ),
          _createEvent(
            id: 'e2',
            type: SleepEventType.sleepEnd,
            timestamp: DateTime(2026, 1, 19, 6, 0),
          ),
        ];

        final sessions = SleepSession.fromEventList(events);
        final metrics = SleepMetricsCalculator.calculate(
          sessions: sessions,
          sleepState: const SleepState(isSleeping: false),
          now: DateTime(2026, 1, 19, 12, 0),
        );

        expect(metrics.napCountLast24h, 0);
      });
    });

    group('shortNapRate', () {
      test('calculates rate of short naps correctly', () {
        final events = [
          // Short nap 1: 20 minutes
          _createEvent(
            id: 'e1',
            type: SleepEventType.sleepStart,
            timestamp: DateTime(2026, 1, 19, 9, 0),
          ),
          _createEvent(
            id: 'e2',
            type: SleepEventType.sleepEnd,
            timestamp: DateTime(2026, 1, 19, 9, 20),
          ),
          // Short nap 2: 25 minutes
          _createEvent(
            id: 'e3',
            type: SleepEventType.sleepStart,
            timestamp: DateTime(2026, 1, 19, 11, 0),
          ),
          _createEvent(
            id: 'e4',
            type: SleepEventType.sleepEnd,
            timestamp: DateTime(2026, 1, 19, 11, 25),
          ),
          // Normal nap: 60 minutes
          _createEvent(
            id: 'e5',
            type: SleepEventType.sleepStart,
            timestamp: DateTime(2026, 1, 19, 14, 0),
          ),
          _createEvent(
            id: 'e6',
            type: SleepEventType.sleepEnd,
            timestamp: DateTime(2026, 1, 19, 15, 0),
          ),
        ];

        final sessions = SleepSession.fromEventList(events);
        final metrics = SleepMetricsCalculator.calculate(
          sessions: sessions,
          sleepState: const SleepState(isSleeping: false),
          now: DateTime(2026, 1, 19, 16, 0),
        );

        // 2 out of 3 naps are short = 66.7%
        expect(metrics.shortNapRate, closeTo(0.667, 0.01));
      });
    });

    group('lastWakeTime', () {
      test('returns end time of last completed session', () {
        final events = [
          _createEvent(
            id: 'e1',
            type: SleepEventType.sleepStart,
            timestamp: DateTime(2026, 1, 19, 6, 0),
          ),
          _createEvent(
            id: 'e2',
            type: SleepEventType.sleepEnd,
            timestamp: DateTime(2026, 1, 19, 8, 30),
          ),
        ];

        final sessions = SleepSession.fromEventList(events);
        final metrics = SleepMetricsCalculator.calculate(
          sessions: sessions,
          sleepState: const SleepState(isSleeping: false),
          now: DateTime(2026, 1, 19, 12, 0),
        );

        expect(metrics.lastWakeTime, DateTime(2026, 1, 19, 8, 30));
      });

      test('returns null when currently sleeping', () {
        final events = [
          _createEvent(
            id: 'e1',
            type: SleepEventType.sleepStart,
            timestamp: DateTime(2026, 1, 19, 10, 0),
          ),
        ];

        final sessions = SleepSession.fromEventList(events);
        final metrics = SleepMetricsCalculator.calculate(
          sessions: sessions,
          sleepState: const SleepState(isSleeping: true),
          now: DateTime(2026, 1, 19, 12, 0),
        );

        expect(metrics.lastWakeTime, isNull);
        expect(metrics.isCurrentlySleeping, isTrue);
      });
    });

    group('totalSleepLast24hFormatted', () {
      test('formats hours and minutes correctly', () {
        expect(
          SleepMetrics(
            totalSleepLast24h: const Duration(hours: 12, minutes: 30),
            napCountLast24h: 0,
            shortNapRate: 0,
            fragmentationScore: 0,
            isCurrentlySleeping: false,
            totalSleepByDay: const {},
            sessionCountLast24h: 0,
            daysWithData: 1,
            calculatedAt: DateTime.now(),
          ).totalSleepLast24hFormatted,
          '12h 30m',
        );
      });

      test('formats hours only when no minutes', () {
        expect(
          SleepMetrics(
            totalSleepLast24h: const Duration(hours: 10),
            napCountLast24h: 0,
            shortNapRate: 0,
            fragmentationScore: 0,
            isCurrentlySleeping: false,
            totalSleepByDay: const {},
            sessionCountLast24h: 0,
            daysWithData: 1,
            calculatedAt: DateTime.now(),
          ).totalSleepLast24hFormatted,
          '10h',
        );
      });

      test('formats minutes only when under an hour', () {
        expect(
          SleepMetrics(
            totalSleepLast24h: const Duration(minutes: 45),
            napCountLast24h: 0,
            shortNapRate: 0,
            fragmentationScore: 0,
            isCurrentlySleeping: false,
            totalSleepByDay: const {},
            sessionCountLast24h: 0,
            daysWithData: 1,
            calculatedAt: DateTime.now(),
          ).totalSleepLast24hFormatted,
          '45m',
        );
      });
    });
  });
}
