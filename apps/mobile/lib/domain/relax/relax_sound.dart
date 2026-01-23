import 'package:flutter/material.dart';

/// Represents a relaxation sound available for playback.
@immutable
class RelaxSound {
  final String id;
  final String nameKey; // l10n key for localized name
  final String icon; // Material icon name
  final String assetPath;
  final int durationSeconds;
  final bool loopable;

  const RelaxSound({
    required this.id,
    required this.nameKey,
    required this.icon,
    required this.assetPath,
    required this.durationSeconds,
    required this.loopable,
  });

  factory RelaxSound.fromJson(Map<String, dynamic> json) {
    return RelaxSound(
      id: json['id'] as String,
      nameKey: json['nameKey'] as String,
      icon: json['icon'] as String,
      assetPath: json['assetPath'] as String,
      durationSeconds: json['durationSeconds'] as int,
      loopable: json['loopable'] as bool? ?? true,
    );
  }

  /// Get the full asset path for loading
  String get fullAssetPath => 'assets/curated/relax/v1/$assetPath';

  /// Get the Material icon for this sound
  IconData get iconData {
    switch (icon) {
      case 'waves':
        return Icons.waves;
      case 'water_drop':
        return Icons.water_drop;
      case 'air':
        return Icons.air;
      case 'record_voice_over':
        return Icons.record_voice_over;
      default:
        return Icons.music_note;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RelaxSound &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
