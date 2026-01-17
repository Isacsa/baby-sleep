import 'package:flutter/material.dart';
import 'package:temp_flutter/sync/sync_state.dart';

/// Displays current sync status as a compact chip
/// 
/// Shows icon + label for IDLE/SYNCING/SUCCESS/ERROR
/// Optional error message on tap (via tooltip)
/// Optional pending count badge for unsynced events (FIX P5)
class SyncStatusChip extends StatelessWidget {
  final SyncState syncState;
  final VoidCallback? onTap;
  /// Number of events pending sync (0 = no badge)
  final int pendingCount;

  const SyncStatusChip({
    super.key,
    required this.syncState,
    this.onTap,
    this.pendingCount = 0,
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

    // Build the icon widget with optional pending badge
    Widget iconWidget;
    if (syncState.status == SyncStatus.syncing) {
      iconWidget = SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation(color),
        ),
      );
    } else if (pendingCount > 0) {
      // Show pending badge on icon
      iconWidget = Badge(
        label: Text(
          pendingCount > 99 ? '99+' : pendingCount.toString(),
          style: const TextStyle(fontSize: 10),
        ),
        backgroundColor: theme.colorScheme.error,
        child: Icon(Icons.cloud_upload_outlined, size: 16, color: color),
      );
    } else {
      iconWidget = Icon(icon, size: 16, color: color);
    }
    
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
          iconWidget,
          const SizedBox(width: 6),
          Text(
            pendingCount > 0 ? '$pendingCount pending' : label,
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
