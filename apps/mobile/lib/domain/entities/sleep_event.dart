/// Sleep event type enum
enum SleepEventType {
  sleepStart,
  sleepEnd,
}

/// SleepEvent entity
/// 
/// Base unit of data in the system.
/// Represents an event recorded in time.
/// Events are the base unit, not final states.
/// Events can be imprecise or corrected later.
/// Corrections are always new events (never edit original).
/// History is never silently deleted.
class SleepEvent {
  final String id; // Generated locally before sync
  final String babyId;
  final SleepEventType type;
  final DateTime timestamp; // UTC, when event occurred (source of truth for order)
  final String caregiverId;
  final String deviceId;
  final DateTime createdAt; // UTC, when created locally on device
  final bool isCorrected; // If invalidated by correction
  final DateTime? syncedAt; // NULL = not synced
  final String? correctedBy; // Reference to correction event
  final Map<String, dynamic>? metadata; // Flexible structure for additional data

  const SleepEvent({
    required this.id,
    required this.babyId,
    required this.type,
    required this.timestamp,
    required this.caregiverId,
    required this.deviceId,
    required this.createdAt,
    this.isCorrected = false,
    this.syncedAt,
    this.correctedBy,
    this.metadata,
  });

  /// Creates a copy with updated fields
  SleepEvent copyWith({
    String? id,
    String? babyId,
    SleepEventType? type,
    DateTime? timestamp,
    String? caregiverId,
    String? deviceId,
    DateTime? createdAt,
    bool? isCorrected,
    DateTime? syncedAt,
    String? correctedBy,
    Map<String, dynamic>? metadata,
  }) {
    return SleepEvent(
      id: id ?? this.id,
      babyId: babyId ?? this.babyId,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      caregiverId: caregiverId ?? this.caregiverId,
      deviceId: deviceId ?? this.deviceId,
      createdAt: createdAt ?? this.createdAt,
      isCorrected: isCorrected ?? this.isCorrected,
      syncedAt: syncedAt ?? this.syncedAt,
      correctedBy: correctedBy ?? this.correctedBy,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Checks if event is synced
  bool get isSynced => syncedAt != null;

  /// Checks if event is valid (not corrected)
  bool get isValid => !isCorrected;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SleepEvent &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'SleepEvent(id: $id, type: $type, timestamp: $timestamp, isCorrected: $isCorrected)';
}

