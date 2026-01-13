import 'package:flutter/material.dart';
import 'package:temp_flutter/presentation/theme/night_theme.dart';

/// InsightCard - Card de texto com dicas/insights
/// 
/// Usado na página de Estatísticas para mostrar insights
/// personalizados sobre o sono do bebé
class InsightCard extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? iconColor;

  const InsightCard({
    super.key,
    required this.icon,
    required this.text,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NightTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: NightTheme.textSecondary.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: (iconColor ?? NightTheme.accent).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 18,
              color: iconColor ?? NightTheme.accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
                color: NightTheme.textBody,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
