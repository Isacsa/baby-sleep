import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:temp_flutter/domain/relax/relax.dart';

/// Loads the relax sounds index from bundled assets.
class RelaxSoundsLoader {
  static const _indexPath = 'assets/curated/relax/v1/relax_index.json';

  List<RelaxSound>? _cachedSounds;
  List<int>? _cachedTimerPresets;
  int? _cachedFadeOutDuration;
  int? _cachedVolumeSoftCap;

  /// Load all available sounds.
  Future<List<RelaxSound>> loadSounds() async {
    if (_cachedSounds != null) return _cachedSounds!;

    final jsonStr = await rootBundle.loadString(_indexPath);
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;

    final sounds = (json['sounds'] as List<dynamic>)
        .map((e) => RelaxSound.fromJson(e as Map<String, dynamic>))
        .toList();

    _cachedSounds = sounds;
    _cachedTimerPresets = (json['timerPresets'] as List<dynamic>)
        .map((e) => e as int)
        .toList();
    _cachedFadeOutDuration = json['fadeOutDurationSeconds'] as int? ?? 30;
    _cachedVolumeSoftCap = json['volumeSoftCapPercent'] as int? ?? 70;

    return sounds;
  }

  /// Get available timer presets (in minutes). -1 means infinite.
  Future<List<int>> getTimerPresets() async {
    if (_cachedTimerPresets == null) await loadSounds();
    return _cachedTimerPresets ?? [15, 30, 60, -1];
  }

  /// Get fade-out duration in seconds.
  Future<int> getFadeOutDurationSeconds() async {
    if (_cachedFadeOutDuration == null) await loadSounds();
    return _cachedFadeOutDuration ?? 30;
  }

  /// Get volume soft cap percentage.
  Future<int> getVolumeSoftCapPercent() async {
    if (_cachedVolumeSoftCap == null) await loadSounds();
    return _cachedVolumeSoftCap ?? 70;
  }

  /// Find a sound by ID.
  Future<RelaxSound?> findSoundById(String id) async {
    final sounds = await loadSounds();
    try {
      return sounds.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }
}
