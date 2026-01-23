import 'package:flutter/material.dart';
import 'relax_sound.dart';

/// Possible states for the relax audio player.
enum PlayerStatus {
  stopped,
  loading,
  playing,
  paused,
  error,
}

/// Error types for audio playback.
enum PlayerErrorType {
  assetMissing,
  decodeFailed,
  generic,
}

/// Immutable state of the relax audio player.
@immutable
class RelaxPlayerState {
  final PlayerStatus status;
  final RelaxSound? currentSound;
  final double volume; // 0.0 to 1.0
  final int timerMinutes; // -1 for infinite
  final bool fadeOutEnabled;
  final DateTime? timerEndAt; // null if timer is infinite or not started
  final bool isFadingOut;
  final double baseVolume; // Volume before fade-out started
  final PlayerErrorType? errorType;
  final String? errorMessage;
  final bool backgroundAudioSupported;

  const RelaxPlayerState({
    this.status = PlayerStatus.stopped,
    this.currentSound,
    this.volume = 0.5,
    this.timerMinutes = -1,
    this.fadeOutEnabled = true,
    this.timerEndAt,
    this.isFadingOut = false,
    this.baseVolume = 0.5,
    this.errorType,
    this.errorMessage,
    this.backgroundAudioSupported = true,
  });

  /// Whether the player is currently playing
  bool get isPlaying => status == PlayerStatus.playing;

  /// Whether we're in an error state
  bool get hasError => status == PlayerStatus.error;

  /// Whether we have a finite timer
  bool get hasTimer => timerMinutes > 0;

  /// Timer remaining in seconds, or null if no timer
  int? get timerRemainingSeconds {
    if (timerEndAt == null || timerMinutes <= 0) return null;
    final remaining = timerEndAt!.difference(DateTime.now()).inSeconds;
    return remaining > 0 ? remaining : 0;
  }

  /// Whether the timer has expired
  bool get timerExpired {
    if (timerEndAt == null || timerMinutes <= 0) return false;
    return DateTime.now().isAfter(timerEndAt!);
  }

  /// Volume is in the "high" zone (soft cap)
  bool get isVolumeHigh => volume > 0.7;

  RelaxPlayerState copyWith({
    PlayerStatus? status,
    RelaxSound? currentSound,
    double? volume,
    int? timerMinutes,
    bool? fadeOutEnabled,
    DateTime? timerEndAt,
    bool? isFadingOut,
    double? baseVolume,
    PlayerErrorType? errorType,
    String? errorMessage,
    bool? backgroundAudioSupported,
    bool clearSound = false,
    bool clearError = false,
    bool clearTimerEndAt = false,
  }) {
    return RelaxPlayerState(
      status: status ?? this.status,
      currentSound: clearSound ? null : (currentSound ?? this.currentSound),
      volume: volume ?? this.volume,
      timerMinutes: timerMinutes ?? this.timerMinutes,
      fadeOutEnabled: fadeOutEnabled ?? this.fadeOutEnabled,
      timerEndAt: clearTimerEndAt ? null : (timerEndAt ?? this.timerEndAt),
      isFadingOut: isFadingOut ?? this.isFadingOut,
      baseVolume: baseVolume ?? this.baseVolume,
      errorType: clearError ? null : (errorType ?? this.errorType),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      backgroundAudioSupported: backgroundAudioSupported ?? this.backgroundAudioSupported,
    );
  }

  /// Create a stopped state
  static const stopped = RelaxPlayerState();

  /// Create an error state
  factory RelaxPlayerState.error({
    required PlayerErrorType type,
    String? message,
    RelaxSound? currentSound,
  }) {
    return RelaxPlayerState(
      status: PlayerStatus.error,
      currentSound: currentSound,
      errorType: type,
      errorMessage: message,
    );
  }
}
