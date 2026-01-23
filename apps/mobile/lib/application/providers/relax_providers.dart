import 'dart:async';
import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:temp_flutter/data/datasources/local/relax_content_loader.dart';
import 'package:temp_flutter/data/datasources/local/relax_preferences_local_datasource.dart';
import 'package:temp_flutter/data/datasources/local/relax_sounds_loader.dart';
import 'package:temp_flutter/data/services/relax_player_service.dart';
import 'package:temp_flutter/domain/relax/relax.dart';
import 'package:temp_flutter/application/providers/active_baby_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data Sources & Loaders
// ─────────────────────────────────────────────────────────────────────────────

final relaxSoundsLoaderProvider = Provider<RelaxSoundsLoader>((ref) {
  return RelaxSoundsLoader();
});

final relaxContentLoaderProvider = Provider<RelaxContentLoader>((ref) {
  return RelaxContentLoader();
});

final relaxPreferencesProvider = FutureProvider<RelaxPreferencesLocalDataSource>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return RelaxPreferencesLocalDataSource(prefs);
});

// ─────────────────────────────────────────────────────────────────────────────
// Sounds
// ─────────────────────────────────────────────────────────────────────────────

final relaxSoundsProvider = FutureProvider<List<RelaxSound>>((ref) async {
  final loader = ref.watch(relaxSoundsLoaderProvider);
  return loader.loadSounds();
});

final relaxTimerPresetsProvider = FutureProvider<List<int>>((ref) async {
  final loader = ref.watch(relaxSoundsLoaderProvider);
  return loader.getTimerPresets();
});

// ─────────────────────────────────────────────────────────────────────────────
// Content (Localized)
// ─────────────────────────────────────────────────────────────────────────────

final relaxContentProvider = FutureProvider.family<RelaxContent, Locale>((ref, locale) async {
  final loader = ref.watch(relaxContentLoaderProvider);
  return loader.loadContent(locale);
});

// ─────────────────────────────────────────────────────────────────────────────
// Favorites (per baby)
// ─────────────────────────────────────────────────────────────────────────────

final relaxFavoritesProvider = StateNotifierProvider<RelaxFavoritesNotifier, List<RelaxFavorite>>((ref) {
  return RelaxFavoritesNotifier(ref);
});

class RelaxFavoritesNotifier extends StateNotifier<List<RelaxFavorite>> {
  final Ref _ref;
  String? _currentBabyId;

  RelaxFavoritesNotifier(this._ref) : super([]) {
    _init();
  }

  Future<void> _init() async {
    final baby = _ref.read(activeBabyProvider);
    if (baby != null) {
      _currentBabyId = baby.id;
      await _loadFavorites();
    }

    // Watch for baby changes
    _ref.listen(activeBabyProvider, (_, baby) {
      if (baby != null && baby.id != _currentBabyId) {
        _currentBabyId = baby.id;
        _loadFavorites();
      }
    });
  }

  Future<void> _loadFavorites() async {
    if (_currentBabyId == null) {
      state = [];
      return;
    }

    final prefs = await _ref.read(relaxPreferencesProvider.future);
    state = prefs.getFavorites(_currentBabyId!);
  }

  Future<void> addFavorite(RelaxFavorite favorite) async {
    if (_currentBabyId == null) return;

    final prefs = await _ref.read(relaxPreferencesProvider.future);
    await prefs.addFavorite(_currentBabyId!, favorite);
    await _loadFavorites();
  }

  Future<void> removeFavorite(RelaxFavorite favorite) async {
    if (_currentBabyId == null) return;

    final prefs = await _ref.read(relaxPreferencesProvider.future);
    await prefs.removeFavorite(_currentBabyId!, favorite);
    await _loadFavorites();
  }

  bool isFavorite(String soundId, int timerMinutes, bool fadeOut) {
    return state.any((f) => 
      f.soundId == soundId && 
      f.timerMinutes == timerMinutes && 
      f.fadeOutEnabled == fadeOut
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Player
// ─────────────────────────────────────────────────────────────────────────────

final relaxPlayerServiceProvider = Provider<RelaxPlayerService>((ref) {
  final service = RelaxPlayerService();
  
  // Initialize on creation
  service.initialize();
  
  // Dispose when provider is disposed
  ref.onDispose(() {
    service.dispose();
  });
  
  return service;
});

final relaxPlayerStateProvider = StateNotifierProvider<RelaxPlayerNotifier, RelaxPlayerState>((ref) {
  return RelaxPlayerNotifier(ref);
});

class RelaxPlayerNotifier extends StateNotifier<RelaxPlayerState> {
  final Ref _ref;
  Timer? _uiUpdateTimer;
  bool _volumeWarningShownThisSession = false;

  RelaxPlayerNotifier(this._ref) : super(RelaxPlayerState.stopped) {
    _init();
  }

  Future<void> _init() async {
    final service = _ref.read(relaxPlayerServiceProvider);
    
    // Listen to player state changes
    service.onStateChanged = (newState) {
      state = newState;
    };

    service.onError = (type, message) {
      state = RelaxPlayerState.error(
        type: type,
        message: message,
        currentSound: state.currentSound,
      );
    };

    // Check persisted timer on init
    await _checkPersistedTimer();

    // Load last config for active baby
    await _loadLastConfig();

    // Start UI update timer for countdown display
    _uiUpdateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.isPlaying && state.timerEndAt != null) {
        // Force a state emission to update countdown in UI
        state = state.copyWith();
      }
    });
  }

  Future<void> _checkPersistedTimer() async {
    final baby = _ref.read(activeBabyProvider);
    if (baby == null) return;

    final prefs = await _ref.read(relaxPreferencesProvider.future);
    final persistedEndAt = prefs.getTimerEndAt(baby.id);
    
    if (persistedEndAt != null && DateTime.now().isAfter(persistedEndAt)) {
      // Timer expired while app was closed - clear it
      await prefs.setTimerEndAt(baby.id, null);
    }
  }

  Future<void> _loadLastConfig() async {
    final baby = _ref.read(activeBabyProvider);
    if (baby == null) return;

    final prefs = await _ref.read(relaxPreferencesProvider.future);
    final volume = prefs.getVolume();
    
    state = state.copyWith(volume: volume);
  }

  Future<void> play(RelaxSound sound, {
    int timerMinutes = -1,
    bool fadeOutEnabled = true,
  }) async {
    final service = _ref.read(relaxPlayerServiceProvider);
    final prefs = await _ref.read(relaxPreferencesProvider.future);
    final volume = prefs.getVolume();

    await service.play(
      sound: sound,
      volume: volume,
      timerMinutes: timerMinutes,
      fadeOutEnabled: fadeOutEnabled,
    );

    // Persist timer end time
    final baby = _ref.read(activeBabyProvider);
    if (baby != null && timerMinutes > 0) {
      final endAt = DateTime.now().add(Duration(minutes: timerMinutes));
      await prefs.setTimerEndAt(baby.id, endAt);
    }

    // Save last config
    if (baby != null) {
      await prefs.setLastConfig(baby.id, RelaxLastConfig(
        soundId: sound.id,
        timerPreset: timerMinutes,
        fadeOutEnabled: fadeOutEnabled,
        nightScreenEnabled: false,
      ));
    }
  }

  Future<void> pause() async {
    final service = _ref.read(relaxPlayerServiceProvider);
    await service.pause();
  }

  Future<void> resume() async {
    final service = _ref.read(relaxPlayerServiceProvider);
    await service.resume();
  }

  Future<void> stop() async {
    final service = _ref.read(relaxPlayerServiceProvider);
    await service.stop();

    // Clear persisted timer
    final baby = _ref.read(activeBabyProvider);
    if (baby != null) {
      final prefs = await _ref.read(relaxPreferencesProvider.future);
      await prefs.setTimerEndAt(baby.id, null);
    }
  }

  Future<void> setVolume(double volume) async {
    final service = _ref.read(relaxPlayerServiceProvider);
    await service.setVolume(volume);

    // Persist volume (per device)
    final prefs = await _ref.read(relaxPreferencesProvider.future);
    await prefs.setVolume(volume);

    // Check for volume warning (soft cap)
    if (volume > 0.7 && !_volumeWarningShownThisSession) {
      _volumeWarningShownThisSession = true;
      // The UI will check shouldShowVolumeWarning
    }
  }

  bool get shouldShowVolumeWarning {
    return state.isVolumeHigh && !_volumeWarningShownThisSession;
  }

  void markVolumeWarningShown() {
    _volumeWarningShownThisSession = true;
  }

  Future<void> retry() async {
    if (state.currentSound != null) {
      await play(
        state.currentSound!,
        timerMinutes: state.timerMinutes,
        fadeOutEnabled: state.fadeOutEnabled,
      );
    }
    state = state.copyWith(clearError: true);
  }

  @override
  void dispose() {
    _uiUpdateTimer?.cancel();
    super.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Night Mode Detection
// ─────────────────────────────────────────────────────────────────────────────

final isNightModeProvider = Provider<bool>((ref) {
  final hour = DateTime.now().hour;
  // Night mode: 20:00 - 06:00
  return hour >= 20 || hour < 6;
});
