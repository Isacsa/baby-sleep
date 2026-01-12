import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:temp_flutter/application/providers/auth_provider.dart';
import 'package:temp_flutter/application/providers/active_baby_provider.dart';
import 'package:temp_flutter/application/providers/babies_provider.dart';
import 'package:temp_flutter/application/providers/caregivers_provider.dart';
import 'package:temp_flutter/application/providers/sleep_events_provider.dart';
import 'package:temp_flutter/application/providers/sleep_state_provider.dart';
import 'package:temp_flutter/application/providers/sync_provider.dart';
import 'package:temp_flutter/domain/entities/baby.dart';
import 'package:temp_flutter/sync/sync_state.dart';

/// DebugPage - Smoke Test UI
/// 
/// Single page to validate end-to-end system functionality.
/// Shows state (auth, active baby, caregiver/role, sleep state, sync state)
/// and provides buttons for manual actions (create events, push, pull).
/// 
/// NO business logic here - only consumes providers.
class DebugPage extends ConsumerWidget {
  const DebugPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Page - Smoke Test'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Section 1: Auth
            _buildAuthSection(context, ref),
            const Divider(height: 32),
            
            // Section 2: Babies (from SQLite)
            _buildBabiesSection(context, ref),
            const Divider(height: 32),
            
            // Section 3: Active Baby
            _buildActiveBabySection(context, ref),
            const Divider(height: 32),
            
            // Section 4: Caregivers/Role
            _buildCaregiversSection(context, ref),
            const Divider(height: 32),
            
            // Section 5: Sleep State (derived)
            _buildSleepStateSection(context, ref),
            const Divider(height: 32),
            
            // Section 6: Event Actions
            _buildEventActionsSection(context, ref),
            const Divider(height: 32),
            
            // Section 7: Sync
            _buildSyncSection(context, ref),
            const Divider(height: 32),
            
            // Section 8: Timeline (local events)
            _buildTimelineSection(context, ref),
          ],
        ),
      ),
    );
  }

  /// Section 1: Auth state and actions
  Widget _buildAuthSection(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    
    return _SectionCard(
      title: 'Auth',
      children: [
        Text('Authenticated: ${user != null ? "yes" : "no"}'),
        if (user != null) Text('UserId (auth.uid): ${user.id}'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: user == null 
                    ? () => _showAuthDialog(context, ref)
                    : null,
                child: const Text('Send Magic Link'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                onPressed: user != null
                    ? () => ref.read(authProvider.notifier).clearUser()
                    : null,
                child: const Text('Sign Out'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Shows auth dialog for email input
  void _showAuthDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Magic Link'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Email',
            hintText: 'Enter your email',
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(authProvider.notifier).sendMagicLink(controller.text);
              Navigator.pop(context);
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  /// Section 2: Babies list from SQLite
  Widget _buildBabiesSection(BuildContext context, WidgetRef ref) {
    final babiesAsync = ref.watch(babiesNotifierProvider);
    final user = ref.watch(authProvider);
    
    return _SectionCard(
      title: 'Babies (SQLite)',
      children: [
        babiesAsync.when(
          data: (babies) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Count: ${babies.length}'),
              const SizedBox(height: 8),
              if (babies.isEmpty)
                const Text('No babies in local cache')
              else
                ...babies.map((baby) => _BabyListItem(
                  baby: baby,
                  onTap: () => ref.read(activeBabyProvider.notifier).setBaby(baby),
                )),
            ],
          ),
          loading: () => const CircularProgressIndicator(),
          error: (e, _) => Text('Error: $e', style: const TextStyle(color: Colors.red)),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () => ref.read(babiesNotifierProvider.notifier).refresh(),
                child: const Text('Refresh'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: user != null
                    ? () => _showCreateBabyDialog(context, ref)
                    : null,
                icon: const Icon(Icons.add),
                label: const Text('Create Baby'),
              ),
            ),
          ],
        ),
        if (user == null)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'Login to create babies',
              style: TextStyle(fontSize: 12, color: Colors.orange),
            ),
          ),
      ],
    );
  }

  /// Shows dialog to create a new baby locally
  void _showCreateBabyDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Baby (local)'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Baby name',
            hintText: 'Enter baby name',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(context);
              try {
                await ref.read(babiesNotifierProvider.notifier).createLocalBaby(
                  name: name,
                );
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  /// Section 3: Active Baby
  Widget _buildActiveBabySection(BuildContext context, WidgetRef ref) {
    final activeBaby = ref.watch(activeBabyProvider);
    
    return _SectionCard(
      title: 'Active Baby',
      children: [
        Text('ActiveBabyId: ${activeBaby?.id ?? "none"}'),
        if (activeBaby != null) Text('Name: ${activeBaby.name}'),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: activeBaby != null
              ? () => ref.read(activeBabyProvider.notifier).clearBaby()
              : null,
          child: const Text('Clear Active Baby'),
        ),
      ],
    );
  }

  /// Section 4: Caregivers for active baby
  Widget _buildCaregiversSection(BuildContext context, WidgetRef ref) {
    final caregiversAsync = ref.watch(caregiversNotifierProvider);
    final user = ref.watch(authProvider);
    
    return _SectionCard(
      title: 'Caregivers/Role',
      children: [
        caregiversAsync.when(
          data: (caregivers) {
            if (caregivers.isEmpty) {
              return const Text('No caregivers in local cache');
            }
            
            // Find current user's caregiver
            final currentCaregiver = user != null
                ? caregivers.where((c) => c.userId == user.id).firstOrNull
                : null;
            
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Count: ${caregivers.length}'),
                if (currentCaregiver != null) ...[
                  const SizedBox(height: 4),
                  Text('Your caregiver_id: ${currentCaregiver.id}'),
                  Text('Your role: ${currentCaregiver.role}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: currentCaregiver.canWrite ? Colors.green : Colors.orange,
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 4),
                  const Text('Your role: unknown (not found in cache)',
                    style: TextStyle(color: Colors.orange),
                  ),
                ],
                const SizedBox(height: 8),
                ...caregivers.map((c) => Text(
                  '• ${c.id.substring(0, 8)}... - ${c.role} ${c.userId == user?.id ? "(you)" : ""}',
                )),
              ],
            );
          },
          loading: () => const CircularProgressIndicator(),
          error: (e, _) => Text('Error: $e', style: const TextStyle(color: Colors.red)),
        ),
      ],
    );
  }

  /// Section 5: Sleep State (derived)
  Widget _buildSleepStateSection(BuildContext context, WidgetRef ref) {
    final sleepState = ref.watch(sleepStateNotifierProvider);
    
    return _SectionCard(
      title: 'SleepState (derived)',
      children: [
        Row(
          children: [
            Icon(
              sleepState.isSleeping ? Icons.bedtime : Icons.wb_sunny,
              size: 32,
              color: sleepState.isSleeping ? Colors.indigo : Colors.amber,
            ),
            const SizedBox(width: 8),
            Text(
              sleepState.isSleeping ? 'SLEEPING' : 'AWAKE',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: sleepState.isSleeping ? Colors.indigo : Colors.amber.shade700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (sleepState.lastEvent != null) ...[
          Text('Last event: ${sleepState.lastEvent!.type.name}'),
          Text('Timestamp: ${sleepState.lastEventTimestamp}'),
        ] else
          const Text('No events yet'),
      ],
    );
  }

  /// Section 6: Event creation actions
  Widget _buildEventActionsSection(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final activeBaby = ref.watch(activeBabyProvider);
    final caregiversAsync = ref.watch(caregiversNotifierProvider);
    
    // Check preconditions for event creation
    final canCreate = user != null && activeBaby != null;
    final hasWritePermission = caregiversAsync.valueOrNull
        ?.any((c) => c.userId == user?.id && c.canWrite) ?? false;
    final isBlocked = !canCreate || !hasWritePermission;
    
    String? blockReason;
    if (user == null) {
      blockReason = 'Not authenticated';
    } else if (activeBaby == null) {
      blockReason = 'No active baby selected';
    } else if (!hasWritePermission) {
      blockReason = 'No write permission (viewer or not in cache)';
    }
    
    return _SectionCard(
      title: 'Create Events (offline-first)',
      children: [
        if (blockReason != null)
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(child: Text(blockReason)),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: isBlocked
                    ? null
                    : () => ref.read(sleepEventsNotifierProvider.notifier).createSleepStart(),
                icon: const Icon(Icons.bedtime),
                label: const Text('SleepStart'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo.shade100,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: isBlocked
                    ? null
                    : () => ref.read(sleepEventsNotifierProvider.notifier).createSleepEnd(),
                icon: const Icon(Icons.wb_sunny),
                label: const Text('SleepEnd'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade100,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Section 7: Sync state and actions
  Widget _buildSyncSection(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncProvider);
    final activeBaby = ref.watch(activeBabyProvider);
    final user = ref.watch(authProvider);
    
    final isAuthenticated = user != null;
    final hasActiveBaby = activeBaby != null;
    final isSyncing = syncState.status == SyncStatus.syncing;
    
    return _SectionCard(
      title: 'Sync',
      children: [
        _buildSyncStatusIndicator(syncState),
        const SizedBox(height: 8),
        Text('Status: ${syncState.status.name}'),
        if (syncState.lastSyncedAt != null)
          Text('Last synced: ${syncState.lastSyncedAt}'),
        if (syncState.pendingEventsCount > 0)
          Text('Pending: ${syncState.pendingEventsCount} events'),
        if (syncState.errorMessage != null)
          Text('Error: ${syncState.errorMessage}',
            style: const TextStyle(color: Colors.red),
          ),
        const SizedBox(height: 12),
        
        // PUSH section
        Text('Push (requires auth + active baby)',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        ElevatedButton.icon(
          onPressed: isAuthenticated && hasActiveBaby && !isSyncing
              ? () => ref.read(syncProvider.notifier).pushForBaby(activeBaby.id)
              : null,
          icon: const Icon(Icons.cloud_upload),
          label: const Text('Push Active Baby'),
        ),
        const SizedBox(height: 12),
        
        // PULL section - split into Global and Active Baby
        Text('Pull (global = only auth, active baby = auth + baby)',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: isAuthenticated && !isSyncing
                    ? () async {
                        await ref.read(syncProvider.notifier).pullBabiesGlobal();
                        // Refresh babies after pull
                        ref.read(babiesNotifierProvider.notifier).refresh();
                      }
                    : null,
                icon: const Icon(Icons.cloud_download),
                label: const Text('Babies (Global)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade100,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: isAuthenticated && hasActiveBaby && !isSyncing
                    ? () async {
                        await ref.read(syncProvider.notifier).pullActiveBabyData(activeBaby.id);
                        // Refresh caregivers and events after pull
                        ref.read(caregiversNotifierProvider.notifier).refresh();
                        ref.read(sleepEventsNotifierProvider.notifier).refresh();
                      }
                    : null,
                icon: const Icon(Icons.cloud_download),
                label: const Text('Active Baby'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade100,
                ),
              ),
            ),
          ],
        ),
        if (!isAuthenticated)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'Login to enable sync',
              style: TextStyle(fontSize: 12, color: Colors.orange),
            ),
          ),
        if (isAuthenticated && !hasActiveBaby)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'Pull Babies first, then select one to enable Active Baby sync',
              style: TextStyle(fontSize: 12, color: Colors.orange),
            ),
          ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: () => ref.read(syncProvider.notifier).reset(),
          child: const Text('Reset Sync State'),
        ),
      ],
    );
  }

  Widget _buildSyncStatusIndicator(SyncState state) {
    Color color;
    IconData icon;
    
    switch (state.status) {
      case SyncStatus.idle:
        color = Colors.grey;
        icon = Icons.cloud_off;
      case SyncStatus.syncing:
        color = Colors.blue;
        icon = Icons.sync;
      case SyncStatus.success:
        color = Colors.green;
        icon = Icons.cloud_done;
      case SyncStatus.error:
        color = Colors.red;
        icon = Icons.cloud_off;
    }
    
    return Row(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 8),
        Text(
          state.status.name.toUpperCase(),
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (state.status == SyncStatus.syncing)
          const Padding(
            padding: EdgeInsets.only(left: 8),
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
      ],
    );
  }

  /// Section 8: Timeline (local events)
  Widget _buildTimelineSection(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(sleepEventsNotifierProvider);
    
    return _SectionCard(
      title: 'Timeline (local)',
      children: [
        ElevatedButton(
          onPressed: () => ref.read(sleepEventsNotifierProvider.notifier).refresh(),
          child: const Text('Refresh Timeline'),
        ),
        const SizedBox(height: 8),
        eventsAsync.when(
          data: (events) {
            if (events.isEmpty) {
              return const Text('No events');
            }
            
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Count: ${events.length}'),
                const SizedBox(height: 8),
                ...events.take(20).map((event) => Card(
                  margin: const EdgeInsets.only(bottom: 4),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              event.type.name == 'sleepStart'
                                  ? Icons.bedtime
                                  : Icons.wb_sunny,
                              size: 16,
                              color: event.type.name == 'sleepStart'
                                  ? Colors.indigo
                                  : Colors.amber,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              event.type.name,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            if (event.isCorrected)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'CORRECTED',
                                  style: TextStyle(fontSize: 10, color: Colors.red),
                                ),
                              ),
                            if (event.syncedAt != null)
                              const Icon(Icons.cloud_done, size: 16, color: Colors.green)
                            else
                              const Icon(Icons.cloud_off, size: 16, color: Colors.grey),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('Timestamp: ${event.timestamp}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text('Created: ${event.createdAt}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text('ID: ${event.id.substring(0, 8)}...',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                )),
                if (events.length > 20)
                  Text('... and ${events.length - 20} more events'),
              ],
            );
          },
          loading: () => const CircularProgressIndicator(),
          error: (e, _) => Text('Error: $e', style: const TextStyle(color: Colors.red)),
        ),
      ],
    );
  }
}

/// Section card wrapper
class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Baby list item
class _BabyListItem extends StatelessWidget {
  final Baby baby;
  final VoidCallback onTap;

  const _BabyListItem({
    required this.baby,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            const Icon(Icons.child_care, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(baby.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                  Text(
                    '${baby.id.substring(0, 8)}...',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

