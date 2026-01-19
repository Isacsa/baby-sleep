import 'package:temp_flutter/domain/entities/sleep_event.dart';

/// SleepState value object
/// 
/// Derived state (not persisted)
/// Calculated in memory from valid events
/// Represents current sleep state of baby (sleeping or awake)
class SleepState {
  final bool isSleeping;
  final SleepEvent? lastEvent;
  final DateTime? lastEventTimestamp;

  const SleepState({
    required this.isSleeping,
    this.lastEvent,
    this.lastEventTimestamp,
  });

  /// Creates SleepState from list of valid events
  /// 
  /// Algorithm:
  /// 1. Filter events where isCorrected = false (only valid)
  /// 2. Sort by timestamp DESC, createdAt DESC (most recent first)
  /// 3. If empty: isSleeping = false
  /// 4. If first event is SleepStart: isSleeping = true
  /// 5. If first event is SleepEnd: isSleeping = false
  factory SleepState.fromEvents(List<SleepEvent> events) {
    // Filter valid events
    final validEvents = events.where((e) => e.isValid).toList();

    if (validEvents.isEmpty) {
      return const SleepState(isSleeping: false);
    }

    // Sort by timestamp DESC, createdAt DESC
    validEvents.sort((a, b) {
      final timestampCompare = b.timestamp.compareTo(a.timestamp);
      if (timestampCompare != 0) return timestampCompare;
      return b.createdAt.compareTo(a.createdAt);
    });

    final lastEvent = validEvents.first;
    final isSleeping = lastEvent.type == SleepEventType.sleepStart;
    
    // #region agent log H10 - SleepState derivation
    // ignore: avoid_print
    print('[DEBUG-H10] SleepState.fromEvents: lastEvent.id=${lastEvent.id.substring(0, 8)}, type=${lastEvent.type.name}, timestamp=${lastEvent.timestamp}, createdAt=${lastEvent.createdAt}, isSleeping=$isSleeping');
    final now = DateTime.now();
    final diffMin = now.difference(lastEvent.timestamp).inMinutes;
    // ignore: avoid_print
    print('[DEBUG-H10] SleepState.fromEvents: now=$now, diffMinutes=$diffMin, diffHours=${diffMin ~/ 60}');
    // #endregion

    return SleepState(
      isSleeping: isSleeping,
      lastEvent: lastEvent,
      lastEventTimestamp: lastEvent.timestamp,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SleepState &&
          runtimeType == other.runtimeType &&
          isSleeping == other.isSleeping &&
          lastEvent?.id == other.lastEvent?.id;

  @override
  int get hashCode => Object.hash(isSleeping, lastEvent?.id);

  @override
  String toString() => 'SleepState(isSleeping: $isSleeping, lastEvent: ${lastEvent?.id})';
}

