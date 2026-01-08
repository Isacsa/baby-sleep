import 'package:temp_flutter/domain/entities/sleep_event.dart';

/// Sleep event data model
/// 
/// Used for JSON serialization/deserialization
/// Maps between domain entity and data representation
class SleepEventModel {
  final String id;
  final String babyId;
  final String type; // 'SleepStart' or 'SleepEnd'
  final String timestamp; // ISO 8601 string, UTC
  final String caregiverId;
  final String deviceId;
  final String createdAt; // ISO 8601 string, UTC
  final bool isCorrected;
  final String? syncedAt; // ISO 8601 string, UTC, nullable
  final String? correctedBy;
  final Map<String, dynamic>? metadata;

  SleepEventModel({
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

  /// Converts to domain entity
  SleepEvent toDomain() {
    return SleepEvent(
      id: id,
      babyId: babyId,
      type: _typeFromString(type),
      timestamp: DateTime.parse(timestamp).toUtc(),
      caregiverId: caregiverId,
      deviceId: deviceId,
      createdAt: DateTime.parse(createdAt).toUtc(),
      isCorrected: isCorrected,
      syncedAt: syncedAt != null ? DateTime.parse(syncedAt!).toUtc() : null,
      correctedBy: correctedBy,
      metadata: metadata,
    );
  }

  /// Creates from domain entity
  factory SleepEventModel.fromDomain(SleepEvent event) {
    return SleepEventModel(
      id: event.id,
      babyId: event.babyId,
      type: _typeToString(event.type),
      timestamp: event.timestamp.toIso8601String(),
      caregiverId: event.caregiverId,
      deviceId: event.deviceId,
      createdAt: event.createdAt.toIso8601String(),
      isCorrected: event.isCorrected,
      syncedAt: event.syncedAt?.toIso8601String(),
      correctedBy: event.correctedBy,
      metadata: event.metadata,
    );
  }

  /// Creates from JSON
  factory SleepEventModel.fromJson(Map<String, dynamic> json) {
    return SleepEventModel(
      id: json['id'] as String,
      babyId: json['baby_id'] as String,
      type: json['type'] as String,
      timestamp: json['timestamp'] as String,
      caregiverId: json['caregiver_id'] as String,
      deviceId: json['device_id'] as String,
      createdAt: json['created_at'] as String,
      isCorrected: json['is_corrected'] as bool? ?? false,
      syncedAt: json['synced_at'] as String?,
      correctedBy: json['corrected_by'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Converts to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'baby_id': babyId,
      'type': type,
      'timestamp': timestamp,
      'caregiver_id': caregiverId,
      'device_id': deviceId,
      'created_at': createdAt,
      'is_corrected': isCorrected,
      'synced_at': syncedAt,
      'corrected_by': correctedBy,
      'metadata': metadata,
    };
  }

  static SleepEventType _typeFromString(String type) {
    switch (type) {
      case 'SleepStart':
        return SleepEventType.sleepStart;
      case 'SleepEnd':
        return SleepEventType.sleepEnd;
      default:
        throw ArgumentError('Invalid event type: $type');
    }
  }

  static String _typeToString(SleepEventType type) {
    switch (type) {
      case SleepEventType.sleepStart:
        return 'SleepStart';
      case SleepEventType.sleepEnd:
        return 'SleepEnd';
    }
  }
}

