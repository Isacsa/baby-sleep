import 'package:flutter/material.dart';
import 'package:temp_flutter/domain/value_objects/sleep_state.dart';

/// Large contextual button for Start/End sleep action
/// 
/// Changes appearance based on current SleepState:
/// - AWAKE: "Start Sleep" (moon icon, accent color)
/// - SLEEPING: "End Sleep" (sun icon, secondary color)
class PrimarySleepActionButton extends StatelessWidget {
  final SleepState sleepState;
  final VoidCallback? onPressed;
  final bool isLoading;

  const PrimarySleepActionButton({
    super.key,
    required this.sleepState,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSleeping = sleepState.isSleeping;

    final (icon, label, bgColor, fgColor) = isSleeping
        ? (
            Icons.wb_sunny_rounded,
            'End Sleep',
            theme.colorScheme.secondaryContainer,
            theme.colorScheme.onSecondaryContainer,
          )
        : (
            Icons.nightlight_round,
            'Start Sleep',
            theme.colorScheme.primaryContainer,
            theme.colorScheme.onPrimaryContainer,
          );

    return SizedBox(
      width: double.infinity,
      height: 80,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: fgColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 2,
        ),
        child: isLoading
            ? CircularProgressIndicator(color: fgColor)
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 32),
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: fgColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
