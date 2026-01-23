import 'package:flutter/material.dart';

/// A saved favorite configuration (sound + timer + fade-out).
/// Volume is NOT part of the favorite (stored per device, not per baby).
@immutable
class RelaxFavorite {
  final String soundId;
  final int timerMinutes; // -1 for infinite
  final bool fadeOutEnabled;
  final DateTime createdAt;

  const RelaxFavorite({
    required this.soundId,
    required this.timerMinutes,
    required this.fadeOutEnabled,
    required this.createdAt,
  });

  factory RelaxFavorite.fromJson(Map<String, dynamic> json) {
    return RelaxFavorite(
      soundId: json['soundId'] as String,
      timerMinutes: json['timerMinutes'] as int,
      fadeOutEnabled: json['fadeOutEnabled'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'soundId': soundId,
      'timerMinutes': timerMinutes,
      'fadeOutEnabled': fadeOutEnabled,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Unique key for deduplication (same sound + timer combo)
  String get uniqueKey => '$soundId:$timerMinutes:$fadeOutEnabled';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RelaxFavorite &&
          runtimeType == other.runtimeType &&
          uniqueKey == other.uniqueKey;

  @override
  int get hashCode => uniqueKey.hashCode;
}
