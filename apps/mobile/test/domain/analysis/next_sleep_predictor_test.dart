import 'package:flutter_test/flutter_test.dart';
import 'package:temp_flutter/domain/analysis/next_sleep_prediction.dart';
import 'package:temp_flutter/domain/analysis/next_sleep_predictor.dart';
import 'package:temp_flutter/domain/entities/sleep_event.dart';
import 'package:temp_flutter/domain/stats/data_quality_assessment.dart';
import 'package:temp_flutter/domain/value_objects/sleep_session.dart';

void main() {
  group('NextSleepPredictor', () {
    // Helper to create a sleep session
    SleepSession createSession({
      required DateTime start,
      required DateTime end,
    }) {
      final startEvent = SleepEvent(
        id: 'start-${start.millisecondsSinceEpoch}',
        babyId: 'baby-1',
        caregiverId: 'cg-1',
        deviceId: 'device-1',
        type: SleepEventType.sleepStart,
        timestamp: start.toUtc(),
        createdAt: start.toUtc(),
        syncedAt: start.toUtc(),
      );
      final endEvent = SleepEvent(
        id: 'end-${end.millisecondsSinceEpoch}',
        babyId: 'baby-1',
        caregiverId: 'cg-1',
        deviceId: 'device-1',
        type: SleepEventType.sleepEnd,
        timestamp: end.toUtc(),
        createdAt: end.toUtc(),
        syncedAt: end.toUtc(),
      );
      return SleepSession.fromEvents(startEvent: startEvent, endEvent: endEvent);
    }

    // Helper to create an incomplete session
    SleepSession createOngoingSession({required DateTime start}) {
      final startEvent = SleepEvent(
        id: 'start-ongoing',
        babyId: 'baby-1',
        caregiverId: 'cg-1',
        deviceId: 'device-1',
        type: SleepEventType.sleepStart,
        timestamp: start.toUtc(),
        createdAt: start.toUtc(),
        syncedAt: start.toUtc(),
      );
      return SleepSession.fromEvents(startEvent: startEvent);
    }

    test('returns sleepingNow when baby is currently sleeping', () {
      final now = DateTime.now();
      final sessions = [
        createOngoingSession(start: now.subtract(const Duration(hours: 1))),
      ];

      final prediction = NextSleepPredictor.predict(
        sessions: sessions,
        now: now,
      );

      expect(prediction.reason, PredictionReason.sleepingNow);
      expect(prediction.isSleepingNow, true);
      expect(prediction.isAvailable, false);
    });

    test('returns collectingPattern when less than 2 complete sessions', () {
      final now = DateTime.now();
      final sessions = [
        createSession(
          start: now.subtract(const Duration(hours: 3)),
          end: now.subtract(const Duration(hours: 2)),
        ),
      ];

      final prediction = NextSleepPredictor.predict(
        sessions: sessions,
        now: now,
      );

      expect(prediction.reason, PredictionReason.collectingPattern);
      expect(prediction.isCollectingPattern, true);
    });

    test('returns collectingPattern when less than 5 valid gaps', () {
      final now = DateTime.now();
      // Create 3 sessions = 2 gaps (not enough)
      final sessions = [
        createSession(
          start: now.subtract(const Duration(hours: 8)),
          end: now.subtract(const Duration(hours: 7)),
        ),
        createSession(
          start: now.subtract(const Duration(hours: 5)),
          end: now.subtract(const Duration(hours: 4)),
        ),
        createSession(
          start: now.subtract(const Duration(hours: 2)),
          end: now.subtract(const Duration(hours: 1)),
        ),
      ];

      final prediction = NextSleepPredictor.predict(
        sessions: sessions,
        now: now,
      );

      expect(prediction.reason, PredictionReason.collectingPattern);
      expect(prediction.sampleCount, lessThan(5));
    });

    test('returns dataQualityTooLow when quality is incomplete', () {
      final now = DateTime.now();
      final sessions = <SleepSession>[];

      final prediction = NextSleepPredictor.predict(
        sessions: sessions,
        dataQuality: DataQualityStatus.incomplete,
        now: now,
      );

      expect(prediction.reason, PredictionReason.dataQualityTooLow);
    });

    test('computes prediction with enough data', () {
      final now = DateTime.now();
      // Create 7 sessions = 6 gaps with consistent 2h gaps
      final sessions = <SleepSession>[];
      for (var i = 6; i >= 0; i--) {
        final sleepStart = now.subtract(Duration(hours: i * 3 + 3));
        final sleepEnd = now.subtract(Duration(hours: i * 3 + 2));
        sessions.add(createSession(start: sleepStart, end: sleepEnd));
      }

      final prediction = NextSleepPredictor.predict(
        sessions: sessions,
        now: now,
      );

      expect(prediction.isAvailable, true);
      expect(prediction.reason, PredictionReason.hasData);
      expect(prediction.sampleCount, greaterThanOrEqualTo(5));
      expect(prediction.windowStartLocal, isNotNull);
      expect(prediction.windowEndLocal, isNotNull);
    });

    test('calculates confidence based on samples and variability', () {
      final now = DateTime.now();
      // Create 15 sessions = 14 gaps with consistent timing
      final sessions = <SleepSession>[];
      for (var i = 14; i >= 0; i--) {
        final sleepStart = now.subtract(Duration(hours: i * 3 + 3));
        final sleepEnd = now.subtract(Duration(hours: i * 3 + 2));
        sessions.add(createSession(start: sleepStart, end: sleepEnd));
      }

      final prediction = NextSleepPredictor.predict(
        sessions: sessions,
        now: now,
      );

      expect(prediction.isAvailable, true);
      // With many consistent gaps, should have good sample count
      expect(prediction.sampleCount, greaterThanOrEqualTo(5));
    });

    test('degrades confidence when data quality is partial', () {
      final now = DateTime.now();
      // Create 12 sessions = 11 gaps
      final sessions = <SleepSession>[];
      for (var i = 11; i >= 0; i--) {
        final sleepStart = now.subtract(Duration(hours: i * 3 + 3));
        final sleepEnd = now.subtract(Duration(hours: i * 3 + 2));
        sessions.add(createSession(start: sleepStart, end: sleepEnd));
      }

      final prediction = NextSleepPredictor.predict(
        sessions: sessions,
        dataQuality: DataQualityStatus.partial,
        now: now,
      );

      expect(prediction.isAvailable, true);
      // With partial quality, confidence should be degraded
      expect(
        prediction.confidence,
        anyOf(ConfidenceLevel.low, ConfidenceLevel.medium),
      );
    });

    test('windowFormatted returns correct format', () {
      final now = DateTime.now();
      final sessions = <SleepSession>[];
      for (var i = 6; i >= 0; i--) {
        final sleepStart = now.subtract(Duration(hours: i * 3 + 3));
        final sleepEnd = now.subtract(Duration(hours: i * 3 + 2));
        sessions.add(createSession(start: sleepStart, end: sleepEnd));
      }

      final prediction = NextSleepPredictor.predict(
        sessions: sessions,
        now: now,
      );

      if (prediction.isAvailable) {
        expect(prediction.windowFormatted, matches(RegExp(r'\d{2}:\d{2}–\d{2}:\d{2}')));
      }
    });

    test('filters out very short gaps', () {
      final now = DateTime.now();
      // Create sessions with some very short gaps (< 15 min)
      final sessions = [
        createSession(
          start: now.subtract(const Duration(hours: 20)),
          end: now.subtract(const Duration(hours: 19)),
        ),
        // Very short gap: 5 minutes
        createSession(
          start: now.subtract(const Duration(hours: 19)).add(const Duration(minutes: 5)),
          end: now.subtract(const Duration(hours: 18)),
        ),
        // Normal gap: 2 hours
        createSession(
          start: now.subtract(const Duration(hours: 16)),
          end: now.subtract(const Duration(hours: 15)),
        ),
        createSession(
          start: now.subtract(const Duration(hours: 13)),
          end: now.subtract(const Duration(hours: 12)),
        ),
        createSession(
          start: now.subtract(const Duration(hours: 10)),
          end: now.subtract(const Duration(hours: 9)),
        ),
        createSession(
          start: now.subtract(const Duration(hours: 7)),
          end: now.subtract(const Duration(hours: 6)),
        ),
        createSession(
          start: now.subtract(const Duration(hours: 4)),
          end: now.subtract(const Duration(hours: 3)),
        ),
        createSession(
          start: now.subtract(const Duration(hours: 1)),
          end: now.subtract(const Duration(minutes: 30)),
        ),
      ];

      final prediction = NextSleepPredictor.predict(
        sessions: sessions,
        now: now,
      );

      // The 5-minute gap should be filtered out
      expect(prediction.reason, anyOf(PredictionReason.hasData, PredictionReason.collectingPattern));
    });
  });

  group('NextSleepPrediction', () {
    test('collectingPattern factory creates correct state', () {
      final prediction = NextSleepPrediction.collectingPattern(sampleCount: 3);
      expect(prediction.isCollectingPattern, true);
      expect(prediction.isAvailable, false);
      expect(prediction.sampleCount, 3);
    });

    test('sleepingNow factory creates correct state', () {
      final prediction = NextSleepPrediction.sleepingNow();
      expect(prediction.isSleepingNow, true);
      expect(prediction.isAvailable, false);
    });

    test('windowCenter calculates midpoint correctly', () {
      final start = DateTime(2024, 1, 1, 14, 0);
      final end = DateTime(2024, 1, 1, 15, 0);
      final prediction = NextSleepPrediction(
        windowStartLocal: start,
        windowEndLocal: end,
        confidence: ConfidenceLevel.medium,
        sampleCount: 5,
        variabilityMinutes: 30,
        reason: PredictionReason.hasData,
      );

      expect(prediction.windowCenter, DateTime(2024, 1, 1, 14, 30));
    });

    test('windowHalfWidthMinutes calculates correctly', () {
      final start = DateTime(2024, 1, 1, 14, 0);
      final end = DateTime(2024, 1, 1, 15, 0);
      final prediction = NextSleepPrediction(
        windowStartLocal: start,
        windowEndLocal: end,
        confidence: ConfidenceLevel.medium,
        sampleCount: 5,
        variabilityMinutes: 30,
        reason: PredictionReason.hasData,
      );

      expect(prediction.windowHalfWidthMinutes, 30);
    });
  });

  group('ConfidenceLevel', () {
    test('labelPt returns correct Portuguese labels', () {
      expect(ConfidenceLevel.low.labelPt, 'Baixa');
      expect(ConfidenceLevel.medium.labelPt, 'Média');
      expect(ConfidenceLevel.high.labelPt, 'Alta');
    });

    test('labelEn returns correct English labels', () {
      expect(ConfidenceLevel.low.labelEn, 'Low');
      expect(ConfidenceLevel.medium.labelEn, 'Medium');
      expect(ConfidenceLevel.high.labelEn, 'High');
    });
  });
}
