import 'dart:async';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:temp_flutter/domain/relax/relax.dart';

/// Service for playing relaxation sounds with timer, fade-out, and crossfade.
class RelaxPlayerService {
  final AudioPlayer _player;
  AudioSession? _session;
  
  // Fade-out timer
  Timer? _fadeOutTimer;
  Timer? _timerCheckTimer;
  
  // Configuration
  static const _fadeOutDurationSeconds = 30;
  static const _crossfadeDurationMs = 200;
  
  // Current state
  RelaxSound? _currentSound;
  DateTime? _timerEndAt;
  double _baseVolume = 0.5;
  bool _isFadingOut = false;
  bool _fadeOutEnabled = true;
  
  // Callbacks
  void Function(RelaxPlayerState)? onStateChanged;
  void Function(PlayerErrorType, String?)? onError;

  RelaxPlayerService() : _player = AudioPlayer();

  /// Initialize the audio session.
  Future<void> initialize() async {
    try {
      _session = await AudioSession.instance;
      await _session!.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.mixWithOthers,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: true,
      ));

      // Listen to audio focus changes
      _session!.interruptionEventStream.listen((event) {
        if (event.begin) {
          // Audio interrupted (e.g., phone call)
          if (_player.playing) {
            _player.pause();
            _emitState();
          }
        }
        // Don't auto-resume after interruption (user must explicitly resume)
      });

      // Listen to player state changes
      _player.playerStateStream.listen((state) {
        _emitState();
      });

      // Listen for errors
      _player.playbackEventStream.listen(
        (_) {},
        onError: (Object e, StackTrace st) {
          _handleError(PlayerErrorType.generic, e.toString());
        },
      );
    } catch (e) {
      // Audio session not available, continue without it
    }
  }

  /// Check if background audio is likely supported.
  bool get isBackgroundAudioSupported {
    // On mobile platforms, background audio is generally supported
    // when properly configured. This is a hint for UI messaging.
    return true;
  }

  /// Play a sound with optional timer and fade-out.
  Future<void> play({
    required RelaxSound sound,
    required double volume,
    required int timerMinutes,
    required bool fadeOutEnabled,
    bool crossfade = true,
  }) async {
    // If already playing a different sound, do a crossfade
    final shouldCrossfade = crossfade && 
        _currentSound != null && 
        _currentSound!.id != sound.id &&
        _player.playing;

    if (shouldCrossfade) {
      await _crossfadeTo(sound, volume);
    } else {
      await _startPlaying(sound, volume);
    }

    _currentSound = sound;
    _baseVolume = volume;
    _fadeOutEnabled = fadeOutEnabled;

    // Set up timer
    _setupTimer(timerMinutes, fadeOutEnabled);

    _emitState();
  }

  Future<void> _startPlaying(RelaxSound sound, double volume) async {
    try {
      _cancelTimers();
      _isFadingOut = false;

      // Load the asset with looping
      final source = AudioSource.asset(sound.fullAssetPath);
      await _player.setAudioSource(source, preload: true);
      await _player.setLoopMode(LoopMode.one);
      await _player.setVolume(volume);
      await _player.play();
    } on PlayerException catch (e) {
      _handleError(PlayerErrorType.decodeFailed, e.message);
    } on PlayerInterruptedException catch (e) {
      _handleError(PlayerErrorType.generic, e.message);
    } catch (e) {
      if (e.toString().contains('Unable to load asset')) {
        _handleError(PlayerErrorType.assetMissing, 'Audio file not found');
      } else {
        _handleError(PlayerErrorType.generic, e.toString());
      }
    }
  }

  Future<void> _crossfadeTo(RelaxSound newSound, double volume) async {
    try {
      // Fade out current
      final steps = 10;
      final stepDuration = Duration(milliseconds: _crossfadeDurationMs ~/ steps);
      final volumeStep = _player.volume / steps;

      for (var i = 0; i < steps; i++) {
        await Future.delayed(stepDuration);
        final newVol = (_player.volume - volumeStep).clamp(0.0, 1.0);
        await _player.setVolume(newVol);
      }

      // Load new sound
      final source = AudioSource.asset(newSound.fullAssetPath);
      await _player.setAudioSource(source, preload: true);
      await _player.setLoopMode(LoopMode.one);
      await _player.setVolume(0);
      await _player.play();

      // Fade in
      for (var i = 0; i < steps; i++) {
        await Future.delayed(stepDuration);
        final newVol = (_player.volume + (volume / steps)).clamp(0.0, volume);
        await _player.setVolume(newVol);
      }

      await _player.setVolume(volume);
    } catch (e) {
      // If crossfade fails, try direct start
      await _startPlaying(newSound, volume);
    }
  }

  void _setupTimer(int timerMinutes, bool fadeOutEnabled) {
    _cancelTimers();

    if (timerMinutes <= 0) {
      // Infinite - no timer
      _timerEndAt = null;
      return;
    }

    _timerEndAt = DateTime.now().add(Duration(minutes: timerMinutes));
    _fadeOutEnabled = fadeOutEnabled;

    // Set up a periodic check for timer and fade-out
    _timerCheckTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _checkTimerAndFadeOut();
    });
  }

  void _checkTimerAndFadeOut() {
    if (_timerEndAt == null) return;

    final now = DateTime.now();
    final remaining = _timerEndAt!.difference(now);

    if (remaining.isNegative) {
      // Timer expired
      stop();
      return;
    }

    // Start fade-out when appropriate
    if (_fadeOutEnabled && 
        !_isFadingOut && 
        remaining.inSeconds <= _fadeOutDurationSeconds) {
      _startFadeOut(remaining.inSeconds);
    }
  }

  void _startFadeOut(int remainingSeconds) {
    if (_isFadingOut) return;
    _isFadingOut = true;
    _emitState();

    final steps = remainingSeconds;
    if (steps <= 0) return;

    final volumeStep = _baseVolume / steps;

    _fadeOutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isFadingOut) {
        timer.cancel();
        return;
      }

      final newVol = (_player.volume - volumeStep).clamp(0.0, 1.0);
      _player.setVolume(newVol);

      if (newVol <= 0) {
        timer.cancel();
        stop();
      }
    });
  }

  /// Pause playback.
  Future<void> pause() async {
    await _player.pause();
    _emitState();
  }

  /// Resume playback.
  Future<void> resume() async {
    // Check if timer has expired while paused
    if (_timerEndAt != null && DateTime.now().isAfter(_timerEndAt!)) {
      stop();
      return;
    }

    await _player.play();
    _emitState();
  }

  /// Stop playback and reset state.
  Future<void> stop() async {
    _cancelTimers();
    _isFadingOut = false;
    _timerEndAt = null;
    _currentSound = null;

    await _player.stop();
    _emitState();
  }

  /// Set volume. If called during fade-out, this becomes the new base volume.
  Future<void> setVolume(double volume) async {
    if (_isFadingOut) {
      // User adjusted volume during fade-out - new base
      _baseVolume = volume;
      _isFadingOut = false;
      _fadeOutTimer?.cancel();
      
      // Restart fade-out from new base if timer still active
      if (_timerEndAt != null) {
        final remaining = _timerEndAt!.difference(DateTime.now());
        if (remaining.inSeconds > 0 && remaining.inSeconds <= _fadeOutDurationSeconds) {
          _startFadeOut(remaining.inSeconds);
        }
      }
    } else {
      _baseVolume = volume;
    }

    await _player.setVolume(volume);
    _emitState();
  }

  /// Check and handle persisted timer state on app resume.
  void checkPersistedTimerState(DateTime? persistedEndAt) {
    if (persistedEndAt != null && DateTime.now().isAfter(persistedEndAt)) {
      // Timer expired while app was closed
      stop();
    }
  }

  void _cancelTimers() {
    _fadeOutTimer?.cancel();
    _fadeOutTimer = null;
    _timerCheckTimer?.cancel();
    _timerCheckTimer = null;
  }

  void _handleError(PlayerErrorType type, String? message) {
    onError?.call(type, message);
    _emitState(error: type, errorMessage: message);
  }

  void _emitState({PlayerErrorType? error, String? errorMessage}) {
    final state = RelaxPlayerState(
      status: _mapPlayerState(error),
      currentSound: _currentSound,
      volume: _player.volume,
      timerMinutes: _timerEndAt != null 
          ? (_timerEndAt!.difference(DateTime.now()).inMinutes + 1)
          : -1,
      fadeOutEnabled: _fadeOutEnabled,
      timerEndAt: _timerEndAt,
      isFadingOut: _isFadingOut,
      baseVolume: _baseVolume,
      errorType: error,
      errorMessage: errorMessage,
      backgroundAudioSupported: isBackgroundAudioSupported,
    );
    onStateChanged?.call(state);
  }

  PlayerStatus _mapPlayerState(PlayerErrorType? error) {
    if (error != null) return PlayerStatus.error;
    
    final processingState = _player.processingState;
    final playing = _player.playing;

    switch (processingState) {
      case ProcessingState.idle:
        return PlayerStatus.stopped;
      case ProcessingState.loading:
      case ProcessingState.buffering:
        return PlayerStatus.loading;
      case ProcessingState.ready:
        return playing ? PlayerStatus.playing : PlayerStatus.paused;
      case ProcessingState.completed:
        return PlayerStatus.stopped;
    }
  }

  /// Current player state snapshot.
  RelaxPlayerState get currentState => RelaxPlayerState(
    status: _mapPlayerState(null),
    currentSound: _currentSound,
    volume: _player.volume,
    timerMinutes: _timerEndAt != null 
        ? (_timerEndAt!.difference(DateTime.now()).inMinutes + 1)
        : -1,
    fadeOutEnabled: _fadeOutEnabled,
    timerEndAt: _timerEndAt,
    isFadingOut: _isFadingOut,
    baseVolume: _baseVolume,
    backgroundAudioSupported: isBackgroundAudioSupported,
  );

  /// Dispose of resources.
  Future<void> dispose() async {
    _cancelTimers();
    await _player.dispose();
  }
}
