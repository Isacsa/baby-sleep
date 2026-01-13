import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:temp_flutter/application/providers/active_baby_provider.dart';
import 'package:temp_flutter/application/providers/sleep_state_provider.dart';
import 'package:temp_flutter/application/providers/sleep_events_provider.dart';
import 'package:temp_flutter/application/providers/sync_provider.dart';
import 'package:temp_flutter/application/providers/caregiver_context_provider.dart';
import 'package:temp_flutter/presentation/widgets/sync_status_chip.dart';
import 'package:temp_flutter/presentation/widgets/primary_sleep_action_button.dart';
import 'package:temp_flutter/sync/sync_state.dart';

/// BabyHomePage - Main dashboard for the active baby
/// 
/// Features:
/// - Sleep state (SLEEPING/AWAKE) derived from events
/// - Last event info
/// - Primary action button (Start Sleep / End Sleep)
/// - Sync status chip
/// - Sync now button (uses syncNowForBaby - Guardrail 2)
/// - Link to timeline
/// 
/// CAREGIVER CONTEXT:
/// - On init, ensures caregiver context exists (local or pull from remote)
/// - Shows loading state while verifying permissions
/// - Shows clear error/CTA if offline without caregiver
/// - Start/End buttons disabled until caregiver context is ready
class BabyHomePage extends ConsumerStatefulWidget {
  const BabyHomePage({super.key});

  @override
  ConsumerState<BabyHomePage> createState() => _BabyHomePageState();
}

class _BabyHomePageState extends ConsumerState<BabyHomePage> {
  bool _isActionLoading = false;

  @override
  void initState() {
    super.initState();
    // Ensure caregiver context on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureCaregiverContext();
    });
  }

  Future<void> _ensureCaregiverContext() async {
    await ref.read(caregiverContextProvider.notifier).ensureContext();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeBaby = ref.watch(activeBabyProvider);
    final sleepState = ref.watch(sleepStateNotifierProvider);
    final eventsAsync = ref.watch(sleepEventsNotifierProvider);
    final syncState = ref.watch(syncProvider);
    final caregiverContext = ref.watch(caregiverContextProvider);

    // Safety check - should not happen if AuthGate works correctly
    if (activeBaby == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed('/babies');
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isSyncing = syncState.status == SyncStatus.syncing;
    final lastEvent = eventsAsync.value?.isNotEmpty == true
        ? eventsAsync.value!.first
        : null;

    // Determine if Start/End is enabled based on caregiver context
    final (canCreateEvents, contextMessage) = switch (caregiverContext) {
      CaregiverContextReady() => (true, null),
      CaregiverContextLoading() => (false, null),
      CaregiverContextInitial() => (false, null),
      CaregiverContextOfflineNoCaregiver(:final message) => (false, message),
      CaregiverContextError(:final message) => (false, message),
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(activeBaby.name),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pushReplacementNamed('/babies'),
        ),
        actions: [
          // Sync status chip
          SyncStatusChip(
            syncState: syncState,
            onTap: () => _showSyncDetails(context, syncState),
          ),
          // Overflow menu
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'timeline',
                child: Row(
                  children: [
                    Icon(Icons.timeline),
                    SizedBox(width: 8),
                    Text('Timeline'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'switch',
                child: Row(
                  children: [
                    Icon(Icons.swap_horiz),
                    SizedBox(width: 8),
                    Text('Switch Baby'),
                  ],
                ),
              ),
              if (kDebugMode)
                const PopupMenuItem(
                  value: 'debug',
                  child: Row(
                    children: [
                      Icon(Icons.bug_report),
                      SizedBox(width: 8),
                      Text('Debug'),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Sleep state indicator
              Expanded(
                flex: 2,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Large icon
                      Icon(
                        sleepState.isSleeping
                            ? Icons.bedtime_rounded
                            : Icons.wb_sunny_rounded,
                        size: 120,
                        color: sleepState.isSleeping
                            ? theme.colorScheme.primary
                            : theme.colorScheme.tertiary,
                      ),
                      const SizedBox(height: 16),
                      // State label
                      Text(
                        sleepState.isSleeping ? 'Sleeping' : 'Awake',
                        style: theme.textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: sleepState.isSleeping
                              ? theme.colorScheme.primary
                              : theme.colorScheme.tertiary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Duration or last event
                      if (sleepState.isSleeping && sleepState.lastEventTimestamp != null)
                        _buildDuration(sleepState.lastEventTimestamp!, theme)
                      else if (lastEvent != null)
                        Text(
                          'Last: ${lastEvent.type.name} at ${_formatTime(lastEvent.timestamp)}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Caregiver context status (loading or error)
              _buildCaregiverContextStatus(theme, caregiverContext),

              // Error message if sync failed
              if (syncState.errorMessage != null && contextMessage == null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline,
                          color: theme.colorScheme.onErrorContainer),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          syncState.errorMessage!,
                          style: TextStyle(
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Primary action button
              PrimarySleepActionButton(
                sleepState: sleepState,
                isLoading: _isActionLoading || caregiverContext is CaregiverContextLoading,
                onPressed: canCreateEvents ? _handleSleepAction : null,
              ),
              
              // Disabled reason text (if button is disabled but not loading)
              if (!canCreateEvents && caregiverContext is! CaregiverContextLoading)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    contextMessage ?? 'A verificar permissões...',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              
              const SizedBox(height: 16),

              // Secondary actions row
              Row(
                children: [
                  // Sync now button (Guardrail 2: single operation)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isSyncing ? null : _syncNow,
                      icon: isSyncing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync),
                      label: Text(isSyncing ? 'Syncing...' : 'Sync now'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Timeline button
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          Navigator.of(context).pushNamed('/timeline'),
                      icon: const Icon(Icons.timeline),
                      label: const Text('Timeline'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCaregiverContextStatus(ThemeData theme, CaregiverContextState state) {
    return switch (state) {
      CaregiverContextLoading() => Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'A preparar permissões...',
                style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
              ),
            ],
          ),
        ),
      CaregiverContextOfflineNoCaregiver(:final message) => Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.wifi_off, color: theme.colorScheme.onErrorContainer),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      message,
                      style: TextStyle(color: theme.colorScheme.onErrorContainer),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _ensureCaregiverContext,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                ),
              ),
            ],
          ),
        ),
      CaregiverContextError(:final message) => Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.error_outline, color: theme.colorScheme.onErrorContainer),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      message,
                      style: TextStyle(color: theme.colorScheme.onErrorContainer),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _ensureCaregiverContext,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                ),
              ),
            ],
          ),
        ),
      _ => const SizedBox.shrink(), // Ready or Initial
    };
  }

  Widget _buildDuration(DateTime start, ThemeData theme) {
    final now = DateTime.now();
    final duration = now.difference(start);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    String text;
    if (hours > 0) {
      text = '${hours}h ${minutes}m';
    } else {
      text = '${minutes}m';
    }

    return Text(
      'Sleeping for $text',
      style: theme.textTheme.bodyLarge?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final hour = dt.toLocal().hour.toString().padLeft(2, '0');
    final minute = dt.toLocal().minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _handleSleepAction() async {
    setState(() => _isActionLoading = true);
    try {
      final sleepState = ref.read(sleepStateNotifierProvider);
      if (sleepState.isSleeping) {
        await ref.read(sleepEventsNotifierProvider.notifier).createSleepEnd();
      } else {
        await ref.read(sleepEventsNotifierProvider.notifier).createSleepStart();
      }
    } catch (e) {
      // Show error message in SnackBar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text(e.toString())),
              ],
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _handleSleepAction,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isActionLoading = false);
      }
    }
  }

  /// Guardrail 2: Single sync operation
  Future<void> _syncNow() async {
    final activeBaby = ref.read(activeBabyProvider);
    if (activeBaby == null) return;

    // Use the single syncNowForBaby method (Guardrail 2)
    await ref.read(syncProvider.notifier).syncNowForBaby(activeBaby.id);
    
    // Re-verify caregiver context after sync
    await _ensureCaregiverContext();
  }

  void _showSyncDetails(BuildContext context, SyncState syncState) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sync Status', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            Text('Status: ${syncState.status.name}'),
            if (syncState.lastSyncedAt != null)
              Text('Last synced: ${_formatDateTime(syncState.lastSyncedAt!)}'),
            if (syncState.errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                'Error: ${syncState.errorMessage}',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  _syncNow();
                },
                child: const Text('Sync Now'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    return '${local.day}/${local.month} ${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'timeline':
        Navigator.of(context).pushNamed('/timeline');
      case 'switch':
        Navigator.of(context).pushReplacementNamed('/babies');
      case 'debug':
        if (kDebugMode) {
          Navigator.of(context).pushNamed('/debug');
        }
    }
  }
}
