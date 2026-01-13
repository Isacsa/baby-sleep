import 'package:flutter/material.dart';
import 'package:temp_flutter/presentation/theme/night_theme.dart';

/// QuickTimeChip - Chip para seleção rápida de tempo
/// 
/// Usado na Home para "Começar há: 5min, 10min, 15min, Outra hora"
class QuickTimeChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  final bool isSelected;

  const QuickTimeChip({
    super.key,
    required this.label,
    this.icon,
    required this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: icon != null ? 12 : 16,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: isSelected 
                ? NightTheme.primary.withValues(alpha: 0.2)
                : NightTheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected 
                  ? NightTheme.primary 
                  : NightTheme.textSecondary.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 16,
                  color: isSelected ? NightTheme.primary : NightTheme.textSecondary,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? NightTheme.primary : NightTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
