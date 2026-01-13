import 'package:flutter/material.dart';
import 'package:temp_flutter/sync/sync_state.dart';

/// Displays current sync status as a compact chip
/// 
/// Shows icon + label for IDLE/SYNCING/SUCCESS/ERROR
/// Optional error message on tap (via tooltip)
class SyncStatusChip extends StatelessWidget {
  final SyncState syncState;
  final VoidCallback? onTap;

  const SyncStatusChip({
    super.key,
    required this.syncState,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    final (icon, label, color) = switch (syncState.status) {
      SyncStatus.idle => (
        Icons.cloud_outlined,
        'Idle',
        theme.colorScheme.outline,
      ),
      SyncStatus.syncing => (
        Icons.sync,
        'Syncing...',
        theme.colorScheme.primary,
      ),
      SyncStatus.success => (
        Icons.cloud_done,
        'Synced',
        theme.colorScheme.primary,
      ),
      SyncStatus.error => (
        Icons.cloud_off,
        'Error',
        theme.colorScheme.error,
      ),
    };

    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          syncState.status == SyncStatus.syncing
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                )
              : Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(color: color),
          ),
        ],
      ),
    );

    if (syncState.errorMessage != null) {
      return Tooltip(
        message: syncState.errorMessage!,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: chip,
        ),
      );
    }

    return onTap != null
        ? InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: chip,
          )
        : chip;
  }
}
