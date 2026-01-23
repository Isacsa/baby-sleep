import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:temp_flutter/application/providers/active_baby_provider.dart';
import 'package:temp_flutter/application/providers/navigation_provider.dart';
import 'package:temp_flutter/application/providers/relax_providers.dart';
import 'package:temp_flutter/application/providers/sleep_state_provider.dart';
import 'package:temp_flutter/core/l10n/l10n.dart';
import 'package:temp_flutter/domain/relax/relax.dart';
import 'package:temp_flutter/presentation/theme/night_theme.dart';

/// RelaxPage - Relaxamento tab
/// 
/// Full implementation with audio player, sounds grid, favorites,
/// night mode, quick guides, and sleep shortcuts.
class RelaxPage extends ConsumerStatefulWidget {
  const RelaxPage({super.key});

  @override
  ConsumerState<RelaxPage> createState() => _RelaxPageState();
}

class _RelaxPageState extends ConsumerState<RelaxPage> {
  @override
  Widget build(BuildContext context) {
    final isNight = ref.watch(isNightModeProvider);
    final baby = ref.watch(activeBabyProvider);
    final locale = Localizations.localeOf(context);

    return SafeArea(
      child: Stack(
        children: [
          Column(
            children: [
              // Header
              _RelaxHeader(isNight: isNight, babyName: baby?.name),

              // Sleep shortcuts bar (moved to top)
              const _SleepShortcutsBar(),
              const SizedBox(height: 16),

              // Main content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Modo Agora (player)
                  const _ModeNowSection(),

                  // Night Mode card (positioned based on time)
                  if (isNight) ...[
                    const SizedBox(height: 16),
                    _NightModeCard(locale: locale),
                  ],

                  // Sounds grid
                  const SizedBox(height: 20),
                  const _SoundsSection(),

                  // Night mode card (day position)
                  if (!isNight) ...[
                    const SizedBox(height: 20),
                    _NightModeCard(locale: locale),
                  ],

                  // Quick guides
                  const SizedBox(height: 20),
                  _QuickGuidesSection(locale: locale),

                  // Disclaimer
                  const SizedBox(height: 24),
                  _Disclaimer(),
                ],
              ),
            ),
          ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────────

class _RelaxHeader extends StatelessWidget {
  final bool isNight;
  final String? babyName;

  const _RelaxHeader({required this.isNight, this.babyName});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Line 1: Title + Night badge
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.relaxTitle,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: NightTheme.textPrimary,
                  ),
                ),
              ),
              if (isNight)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: NightTheme.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.nightlight_round, size: 14, color: NightTheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        l10n.relaxNightModeBadge,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: NightTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          // Line 2: Safety checklist button
          const SizedBox(height: 8),
          _SafetyChecklistButton(),
        ],
      ),
    );
  }
}

class _SafetyChecklistButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    return TextButton.icon(
      onPressed: () => _showSafetyChecklist(context, ref),
      icon: const Icon(Icons.verified_user, size: 18),
      label: Text(l10n.relaxSafetyChecklistShort),
      style: TextButton.styleFrom(
        foregroundColor: NightTheme.textSecondary,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  void _showSafetyChecklist(BuildContext context, WidgetRef ref) {
    final locale = Localizations.localeOf(context);
    final contentAsync = ref.read(relaxContentProvider(locale));

    contentAsync.whenData((content) {
      showModalBottomSheet(
        context: context,
        backgroundColor: NightTheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => _SafetyChecklistSheet(checklist: content.safetyChecklist),
      );
    });
  }
}

class _SafetyChecklistSheet extends StatelessWidget {
  final SafetyChecklist checklist;

  const _SafetyChecklistSheet({required this.checklist});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            checklist.title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: NightTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          ...checklist.items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle, size: 18, color: NightTheme.success),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item,
                    style: const TextStyle(fontSize: 14, color: NightTheme.textPrimary),
                  ),
                ),
              ],
            ),
          )),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: NightTheme.warning.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber, color: NightTheme.warning, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    checklist.warning,
                    style: const TextStyle(fontSize: 13, color: NightTheme.textPrimary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            checklist.sources,
            style: const TextStyle(fontSize: 11, color: NightTheme.textSecondary),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Modo Agora (Player Section)
// ─────────────────────────────────────────────────────────────────────────────

class _ModeNowSection extends ConsumerStatefulWidget {
  const _ModeNowSection();

  @override
  ConsumerState<_ModeNowSection> createState() => _ModeNowSectionState();
}

class _ModeNowSectionState extends ConsumerState<_ModeNowSection> {
  int _selectedTimer = -1; // -1 = infinite
  bool _fadeOutEnabled = true;
  bool _volumeWarningShown = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final playerState = ref.watch(relaxPlayerStateProvider);
    final timerPresets = ref.watch(relaxTimerPresetsProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NightTheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section title
          Text(
            l10n.relaxModeNow,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: NightTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 12),

          // Error state
          if (playerState.hasError) _ErrorBanner(playerState: playerState),

          // Player row
          _PlayerRow(playerState: playerState),

          const SizedBox(height: 12),

          // Safety tip
          Text(
            l10n.relaxVolumeSafetyTip,
            style: const TextStyle(fontSize: 11, color: NightTheme.textSecondary),
          ),

          const SizedBox(height: 16),

          // Volume slider with soft cap
          _VolumeSlider(
            volume: playerState.volume,
            onChanged: (v) => ref.read(relaxPlayerStateProvider.notifier).setVolume(v),
            onHighVolume: () {
              if (!_volumeWarningShown) {
                _volumeWarningShown = true;
                _showVolumeWarning(context);
              }
            },
          ),

          const SizedBox(height: 16),

          // Timer + Fade-out
          timerPresets.when(
            data: (presets) => _TimerRow(
              presets: presets,
              selectedTimer: _selectedTimer,
              fadeOutEnabled: _fadeOutEnabled,
              onTimerChanged: (t) => setState(() => _selectedTimer = t),
              onFadeOutChanged: (f) => setState(() => _fadeOutEnabled = f),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          const SizedBox(height: 16),

          // Utility buttons
          _UtilityButtonsRow(
            playerState: playerState,
            selectedTimer: _selectedTimer,
            fadeOutEnabled: _fadeOutEnabled,
          ),
        ],
      ),
    );
  }

  void _showVolumeWarning(BuildContext context) {
    final l10n = context.l10n;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.relaxVolumeHighWarning),
        backgroundColor: NightTheme.warning.withValues(alpha: 0.9),
        duration: const Duration(seconds: 4),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final RelaxPlayerState playerState;

  const _ErrorBanner({required this.playerState});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final message = playerState.errorType == PlayerErrorType.assetMissing
        ? l10n.relaxAudioUnavailable
        : l10n.relaxAudioError;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: NightTheme.warning.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline, color: NightTheme.warning, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(fontSize: 13, color: NightTheme.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Consumer(
                builder: (context, ref, _) => TextButton(
                  onPressed: () => ref.read(relaxPlayerStateProvider.notifier).retry(),
                  child: Text(l10n.relaxTryAgain),
                ),
              ),
              TextButton(
                onPressed: () {
                  // TODO: Open help page
                },
                child: Text(l10n.relaxHelp),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlayerRow extends ConsumerWidget {
  final RelaxPlayerState playerState;

  const _PlayerRow({required this.playerState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final isPlaying = playerState.isPlaying;
    final isPaused = playerState.status == PlayerStatus.paused;
    final isLoading = playerState.status == PlayerStatus.loading;

    return Row(
      children: [
        // Play/Pause button (large)
        SizedBox(
          width: 64,
          height: 64,
          child: Material(
            color: NightTheme.primary,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: isLoading ? null : () => _togglePlayback(ref),
              customBorder: const CircleBorder(),
              child: Center(
                child: isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        isPlaying ? Icons.pause : (isPaused ? Icons.play_arrow : Icons.play_arrow),
                        color: Colors.white,
                        size: 32,
                      ),
              ),
            ),
          ),
        ),

        const SizedBox(width: 16),

        // Sound name + timer countdown
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                playerState.currentSound != null
                    ? _getSoundName(context, playerState.currentSound!.nameKey)
                    : l10n.relaxSounds,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: NightTheme.textPrimary,
                ),
              ),
              if (playerState.timerEndAt != null && playerState.isPlaying) ...[
                const SizedBox(height: 4),
                _TimerCountdown(endAt: playerState.timerEndAt!),
              ],
              if (playerState.isFadingOut) ...[
                const SizedBox(height: 2),
                Text(
                  l10n.relaxFadeOut,
                  style: const TextStyle(fontSize: 12, color: NightTheme.textSecondary),
                ),
              ],
            ],
          ),
        ),

        // Stop button
        if (isPlaying || isPaused)
          IconButton(
            onPressed: () => ref.read(relaxPlayerStateProvider.notifier).stop(),
            icon: const Icon(Icons.stop, color: NightTheme.textSecondary),
          ),
      ],
    );
  }

  void _togglePlayback(WidgetRef ref) {
    final notifier = ref.read(relaxPlayerStateProvider.notifier);
    final state = ref.read(relaxPlayerStateProvider);

    if (state.isPlaying) {
      notifier.pause();
    } else if (state.status == PlayerStatus.paused) {
      notifier.resume();
    }
    // If stopped, user needs to select a sound first
  }

  String _getSoundName(BuildContext context, String nameKey) {
    final l10n = context.l10n;
    switch (nameKey) {
      case 'relaxSoundWhiteNoise':
        return l10n.relaxSoundWhiteNoise;
      case 'relaxSoundRain':
        return l10n.relaxSoundRain;
      case 'relaxSoundFan':
        return l10n.relaxSoundFan;
      case 'relaxSoundShush':
        return l10n.relaxSoundShush;
      default:
        return nameKey;
    }
  }
}

class _TimerCountdown extends StatefulWidget {
  final DateTime endAt;

  const _TimerCountdown({required this.endAt});

  @override
  State<_TimerCountdown> createState() => _TimerCountdownState();
}

class _TimerCountdownState extends State<_TimerCountdown> {
  Timer? _timer;
  int _remainingSeconds = 0;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateRemaining());
  }

  void _updateRemaining() {
    final remaining = widget.endAt.difference(DateTime.now()).inSeconds;
    if (mounted) {
      setState(() => _remainingSeconds = remaining > 0 ? remaining : 0);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;

    return Text(
      '$minutes:${seconds.toString().padLeft(2, '0')}',
      style: const TextStyle(
        fontSize: 14,
        fontFamily: 'monospace',
        color: NightTheme.textSecondary,
      ),
    );
  }
}

class _VolumeSlider extends StatelessWidget {
  final double volume;
  final ValueChanged<double> onChanged;
  final VoidCallback onHighVolume;

  const _VolumeSlider({
    required this.volume,
    required this.onChanged,
    required this.onHighVolume,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isHigh = volume > 0.7;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '${l10n.relaxVolume} (${isHigh ? l10n.relaxVolumeHigh : l10n.relaxVolumeLow})',
              style: TextStyle(
                fontSize: 13,
                color: isHigh ? NightTheme.warning : NightTheme.textSecondary,
              ),
            ),
            const Spacer(),
            Text(
              '${(volume * 100).round()}%',
              style: const TextStyle(fontSize: 13, color: NightTheme.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: isHigh ? NightTheme.warning : NightTheme.primary,
            inactiveTrackColor: NightTheme.surface.withValues(alpha: 0.3),
            thumbColor: isHigh ? NightTheme.warning : NightTheme.primary,
            overlayColor: (isHigh ? NightTheme.warning : NightTheme.primary).withValues(alpha: 0.2),
            trackHeight: 6,
          ),
          child: Slider(
            value: volume,
            onChanged: (v) {
              onChanged(v);
              if (v > 0.7) onHighVolume();
            },
          ),
        ),
      ],
    );
  }
}

class _TimerRow extends StatelessWidget {
  final List<int> presets;
  final int selectedTimer;
  final bool fadeOutEnabled;
  final ValueChanged<int> onTimerChanged;
  final ValueChanged<bool> onFadeOutChanged;

  const _TimerRow({
    required this.presets,
    required this.selectedTimer,
    required this.fadeOutEnabled,
    required this.onTimerChanged,
    required this.onFadeOutChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.relaxTimer,
          style: const TextStyle(fontSize: 13, color: NightTheme.textSecondary),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: presets.map((preset) {
            final isSelected = preset == selectedTimer;
            final label = preset == -1 
                ? l10n.relaxTimerInfinite 
                : l10n.relaxTimerMinutes(preset);

            return ChoiceChip(
              label: Text(label),
              selected: isSelected,
              onSelected: (_) => onTimerChanged(preset),
              backgroundColor: NightTheme.backgroundBase,
              selectedColor: NightTheme.primary.withValues(alpha: 0.2),
              labelStyle: TextStyle(
                color: isSelected ? NightTheme.primary : NightTheme.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Text(
              l10n.relaxFadeOut,
              style: const TextStyle(fontSize: 13, color: NightTheme.textSecondary),
            ),
            const SizedBox(width: 8),
            Switch(
              value: fadeOutEnabled,
              onChanged: selectedTimer == -1 ? null : onFadeOutChanged,
              activeTrackColor: NightTheme.primary.withValues(alpha: 0.5),
              activeThumbColor: NightTheme.primary,
            ),
            Text(
              fadeOutEnabled ? l10n.relaxFadeOutEnabled : l10n.relaxFadeOutDisabled,
              style: const TextStyle(fontSize: 12, color: NightTheme.textSecondary),
            ),
          ],
        ),
      ],
    );
  }
}

class _UtilityButtonsRow extends ConsumerWidget {
  final RelaxPlayerState playerState;
  final int selectedTimer;
  final bool fadeOutEnabled;

  const _UtilityButtonsRow({
    required this.playerState,
    required this.selectedTimer,
    required this.fadeOutEnabled,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // Dark screen button
        OutlinedButton.icon(
          onPressed: () => _showDarkScreen(context),
          icon: const Icon(Icons.brightness_2, size: 18),
          label: Text(l10n.relaxDarkScreen),
          style: OutlinedButton.styleFrom(
            foregroundColor: NightTheme.textSecondary,
            side: const BorderSide(color: NightTheme.textSecondary, width: 0.5),
          ),
        ),

        // Save config button
        if (playerState.currentSound != null)
          OutlinedButton.icon(
            onPressed: () => _saveToFavorites(context, ref),
            icon: const Icon(Icons.star_border, size: 18),
            label: Text(l10n.relaxSaveConfig),
            style: OutlinedButton.styleFrom(
              foregroundColor: NightTheme.textSecondary,
              side: const BorderSide(color: NightTheme.textSecondary, width: 0.5),
            ),
          ),
      ],
    );
  }

  void _showDarkScreen(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black,
      builder: (ctx) => const _DarkScreenOverlay(),
    );
  }

  void _saveToFavorites(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    if (playerState.currentSound == null) return;

    final favorite = RelaxFavorite(
      soundId: playerState.currentSound!.id,
      timerMinutes: selectedTimer,
      fadeOutEnabled: fadeOutEnabled,
      createdAt: DateTime.now(),
    );

    ref.read(relaxFavoritesProvider.notifier).addFavorite(favorite);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.relaxFavoriteSaved),
        backgroundColor: NightTheme.success.withValues(alpha: 0.9),
      ),
    );
  }
}

class _DarkScreenOverlay extends StatelessWidget {
  const _DarkScreenOverlay();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.touch_app, color: Colors.white24, size: 48),
              const SizedBox(height: 16),
              Text(
                'Toca para voltar',
                style: TextStyle(color: Colors.white24, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sounds Section
// ─────────────────────────────────────────────────────────────────────────────

class _SoundsSection extends ConsumerWidget {
  const _SoundsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final soundsAsync = ref.watch(relaxSoundsProvider);
    final favorites = ref.watch(relaxFavoritesProvider);
    final playerState = ref.watch(relaxPlayerStateProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.relaxSounds,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: NightTheme.textPrimary,
          ),
        ),

        // Favorites row
        if (favorites.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            l10n.relaxFavorites,
            style: const TextStyle(fontSize: 13, color: NightTheme.textSecondary),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 60,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: favorites.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) => _FavoriteChip(
                favorite: favorites[index],
              ),
            ),
          ),
        ],

        const SizedBox(height: 16),

        // Sounds grid
        soundsAsync.when(
          data: (sounds) => GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.5,
            ),
            itemCount: sounds.length,
            itemBuilder: (context, index) => _SoundTile(
              sound: sounds[index],
              isSelected: playerState.currentSound?.id == sounds[index].id,
              isPlaying: playerState.isPlaying && 
                         playerState.currentSound?.id == sounds[index].id,
            ),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _SoundTile extends ConsumerWidget {
  final RelaxSound sound;
  final bool isSelected;
  final bool isPlaying;

  const _SoundTile({
    required this.sound,
    required this.isSelected,
    required this.isPlaying,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: isSelected 
            ? NightTheme.primary.withValues(alpha: 0.15)
            : NightTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: isSelected
            ? Border.all(color: NightTheme.primary, width: 2)
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _playSound(ref),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      sound.iconData,
                      size: 32,
                      color: isSelected ? NightTheme.primary : NightTheme.textSecondary,
                    ),
                    if (isPlaying)
                      const Positioned(
                        right: -8,
                        bottom: -4,
                        child: Icon(Icons.volume_up, size: 16, color: NightTheme.primary),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _getSoundName(context, sound.nameKey),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? NightTheme.primary : NightTheme.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _playSound(WidgetRef ref) {
    // TODO: Get timer and fade-out from state
    ref.read(relaxPlayerStateProvider.notifier).play(
      sound,
      timerMinutes: -1, // Will be updated from _ModeNowSectionState
      fadeOutEnabled: true,
    );
  }

  String _getSoundName(BuildContext context, String nameKey) {
    final l10n = context.l10n;
    switch (nameKey) {
      case 'relaxSoundWhiteNoise':
        return l10n.relaxSoundWhiteNoise;
      case 'relaxSoundRain':
        return l10n.relaxSoundRain;
      case 'relaxSoundFan':
        return l10n.relaxSoundFan;
      case 'relaxSoundShush':
        return l10n.relaxSoundShush;
      default:
        return nameKey;
    }
  }
}

class _FavoriteChip extends ConsumerWidget {
  final RelaxFavorite favorite;

  const _FavoriteChip({required this.favorite});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final soundsAsync = ref.watch(relaxSoundsProvider);

    return soundsAsync.maybeWhen(
      data: (sounds) {
        final sound = sounds.firstWhere(
          (s) => s.id == favorite.soundId,
          orElse: () => sounds.first,
        );

        final timerLabel = favorite.timerMinutes == -1
            ? l10n.relaxTimerInfinite
            : l10n.relaxTimerMinutes(favorite.timerMinutes);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: NightTheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: NightTheme.primary.withValues(alpha: 0.3)),
          ),
          child: InkWell(
            onTap: () => _applyFavorite(ref, sound),
            onLongPress: () => _removeFavorite(context, ref),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(sound.iconData, size: 18, color: NightTheme.primary),
                const SizedBox(width: 6),
                Text(
                  timerLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    color: NightTheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  void _applyFavorite(WidgetRef ref, RelaxSound sound) {
    ref.read(relaxPlayerStateProvider.notifier).play(
      sound,
      timerMinutes: favorite.timerMinutes,
      fadeOutEnabled: favorite.fadeOutEnabled,
    );
  }

  void _removeFavorite(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    ref.read(relaxFavoritesProvider.notifier).removeFavorite(favorite);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.relaxFavoriteRemoved)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Night Mode Card
// ─────────────────────────────────────────────────────────────────────────────

class _NightModeCard extends ConsumerWidget {
  final Locale locale;

  const _NightModeCard({required this.locale});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final isNight = ref.watch(isNightModeProvider);
    final contentAsync = ref.watch(relaxContentProvider(locale));

    return contentAsync.when(
      data: (content) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: NightTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: isNight
              ? Border.all(color: NightTheme.primary, width: 1.5)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.nightlight_round, size: 20, color: NightTheme.primary),
                const SizedBox(width: 8),
                Text(
                  l10n.relaxNightMode,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: NightTheme.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...content.nightMode.bullets.map((bullet) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(color: NightTheme.textSecondary)),
                  Expanded(
                    child: Text(
                      bullet,
                      style: const TextStyle(fontSize: 13, color: NightTheme.textPrimary),
                    ),
                  ),
                ],
              ),
            )),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showSafetyChecklist(context, ref, content),
                  icon: const Icon(Icons.verified_user, size: 16),
                  label: Text(l10n.relaxSafetyChecklistShort),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: NightTheme.primary,
                    side: const BorderSide(color: NightTheme.primary),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _openBreathingGuide(context, ref, content),
                  icon: const Icon(Icons.spa, size: 16),
                  label: Text(l10n.relaxBreathing60s),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: NightTheme.textSecondary,
                    side: const BorderSide(color: NightTheme.textSecondary, width: 0.5),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  void _showSafetyChecklist(BuildContext context, WidgetRef ref, RelaxContent content) {
    showModalBottomSheet(
      context: context,
      backgroundColor: NightTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _SafetyChecklistSheet(checklist: content.safetyChecklist),
    );
  }

  void _openBreathingGuide(BuildContext context, WidgetRef ref, RelaxContent content) {
    final breathingGuide = content.guides.firstWhere(
      (g) => g.id == 'breathing_60s',
      orElse: () => content.guides.first,
    );
    _showGuideSheet(context, breathingGuide);
  }

  void _showGuideSheet(BuildContext context, RelaxGuide guide) {
    showModalBottomSheet(
      context: context,
      backgroundColor: NightTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _QuickGuideSheet(guide: guide),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quick Guides Section
// ─────────────────────────────────────────────────────────────────────────────

class _QuickGuidesSection extends ConsumerWidget {
  final Locale locale;

  const _QuickGuidesSection({required this.locale});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final contentAsync = ref.watch(relaxContentProvider(locale));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.relaxQuickGuides,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: NightTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        contentAsync.when(
          data: (content) => Column(
            children: content.guides.map((guide) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _QuickGuideCard(guide: guide),
            )).toList(),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _QuickGuideCard extends StatelessWidget {
  final RelaxGuide guide;

  const _QuickGuideCard({required this.guide});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: NightTheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showGuideSheet(context),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  guide.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: NightTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                ...guide.shortSteps.take(2).map((step) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(color: NightTheme.textSecondary, fontSize: 12)),
                      Expanded(
                        child: Text(
                          step,
                          style: const TextStyle(fontSize: 12, color: NightTheme.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                )),
                if (guide.shortSteps.length > 2)
                  Text(
                    '+${guide.shortSteps.length - 2} mais...',
                    style: const TextStyle(fontSize: 11, color: NightTheme.primary),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showGuideSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: NightTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) => _QuickGuideSheet(guide: guide),
    );
  }
}

class _QuickGuideSheet extends StatelessWidget {
  final RelaxGuide guide;

  const _QuickGuideSheet({required this.guide});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            guide.title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: NightTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          ...guide.shortSteps.asMap().entries.map((entry) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: NightTheme.primary.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${entry.key + 1}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: NightTheme.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    entry.value,
                    style: const TextStyle(fontSize: 14, color: NightTheme.textPrimary),
                  ),
                ),
              ],
            ),
          )),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: NightTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: NightTheme.primary, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    guide.safetyNote,
                    style: const TextStyle(fontSize: 12, color: NightTheme.textPrimary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sleep Shortcuts Bar
// ─────────────────────────────────────────────────────────────────────────────

class _SleepShortcutsBar extends ConsumerWidget {
  const _SleepShortcutsBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final sleepState = ref.watch(sleepStateNotifierProvider);
    final isSleeping = sleepState.isSleeping;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: NightTheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // State indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isSleeping
                  ? NightTheme.primary.withValues(alpha: 0.2)
                  : NightTheme.textSecondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSleeping ? Icons.bedtime : Icons.wb_sunny_outlined,
                  size: 16,
                  color: isSleeping ? NightTheme.primary : NightTheme.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  isSleeping ? l10n.relaxSleepOngoing : l10n.relaxAwake,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isSleeping ? NightTheme.primary : NightTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // Go to Sleep button
          ElevatedButton.icon(
            onPressed: () => _navigateToSleep(ref),
            icon: const Icon(Icons.bedtime, size: 18),
            label: Text(l10n.relaxGoToSleep),
            style: ElevatedButton.styleFrom(
              backgroundColor: NightTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToSleep(WidgetRef ref) {
    // Request navigation to the Sleep tab
    ref.read(requestedTabIndexProvider.notifier).state = MainTabs.sleep;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Disclaimer
// ─────────────────────────────────────────────────────────────────────────────

class _Disclaimer extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = Localizations.localeOf(context);
    final contentAsync = ref.watch(relaxContentProvider(locale));

    return contentAsync.maybeWhen(
      data: (content) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(
          content.disclaimer,
          style: const TextStyle(
            fontSize: 11,
            color: NightTheme.textSecondary,
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
      ),
      orElse: () => const SizedBox.shrink(),
    );
  }
}
