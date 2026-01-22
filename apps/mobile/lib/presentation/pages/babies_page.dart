import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:temp_flutter/application/providers/auth_provider.dart';
import 'package:temp_flutter/application/providers/babies_provider.dart';
import 'package:temp_flutter/application/providers/active_baby_provider.dart';
import 'package:temp_flutter/application/providers/sync_provider.dart';
import 'package:temp_flutter/application/providers/caregiver_context_provider.dart';
import 'package:temp_flutter/core/l10n/l10n.dart';
import 'package:temp_flutter/presentation/widgets/baby_list_tile.dart';
import 'package:temp_flutter/presentation/widgets/empty_state.dart';
import 'package:temp_flutter/presentation/widgets/sync_status_chip.dart';
import 'package:temp_flutter/sync/sync_state.dart';
import 'package:temp_flutter/presentation/widgets/starry_background.dart';

/// BabiesPage - List and manage babies
/// 
/// Features:
/// - List babies from local SQLite
/// - Pull Babies (Global) button - always available with auth (Guardrail 3)
/// - Create baby locally (offline-first)
/// - Select baby as active
/// 
/// GUARDRAIL 3: "Pull Babies (Global)" is always available when authenticated,
/// with a prominent CTA in empty state for new device onboarding.
class BabiesPage extends ConsumerStatefulWidget {
  const BabiesPage({super.key});

  @override
  ConsumerState<BabiesPage> createState() => _BabiesPageState();
}

class _BabiesPageState extends ConsumerState<BabiesPage> {
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final activeBaby = ref.watch(activeBabyProvider);
    final babiesAsync = ref.watch(babiesNotifierProvider);
    final syncState = ref.watch(syncProvider);

    return StarryScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(context.l10n.babiesTitle),
        centerTitle: true,
        actions: [
          // Sync status
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SyncStatusChip(syncState: syncState),
          ),
          // Overflow menu
          PopupMenuButton<String>(
            onSelected: (value) => _handleMenuAction(value, user),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout),
                    SizedBox(width: 8),
                    Text('Logout'),
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
        child: Column(
          children: [
            // Pull Babies button - always available with auth (Guardrail 3)
            if (user != null)
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: syncState.status == SyncStatus.syncing
                            ? null
                            : _pullBabiesGlobal,
                        icon: const Icon(Icons.cloud_download),
                        label: const Text('Pull Babies (Global)'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: () => _showCreateBabyDialog(context),
                      icon: const Icon(Icons.add),
                      label: const Text('New'),
                    ),
                  ],
                ),
              ),
  
            // Babies list
            Expanded(
              child: babiesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => EmptyState(
                  icon: Icons.error_outline,
                  title: 'Error loading babies',
                  subtitle: e.toString(),
                ),
                data: (babies) {
                  if (babies.isEmpty) {
                    return EmptyState(
                      icon: Icons.child_care,
                      title: context.l10n.babiesNoBabies,
                      subtitle: context.l10n.babiesNoBabies, // Simplified for now
                      ctaLabel: context.l10n.babiesAddNew,
                      onCtaPressed: user != null ? _pullBabiesGlobal : null,
                    );
                  }
  
                  return RefreshIndicator(
                    onRefresh: () async {
                      await ref.read(babiesNotifierProvider.notifier).refresh();
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.only(bottom: 100),
                      itemCount: babies.length,
                      itemBuilder: (context, index) {
                        final baby = babies[index];
                        final isActive = activeBaby?.id == baby.id;
  
                        return BabyListTile(
                          baby: baby,
                          isActive: isActive,
                          onTap: () => _selectBaby(baby),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pullBabiesGlobal() async {
    await ref.read(syncProvider.notifier).pullBabiesGlobal();
    // Refresh local list after pull
    if (mounted) {
      ref.invalidate(babiesNotifierProvider);
    }
  }

  void _selectBaby(dynamic baby) async {
    // Clear caregiver context cache before changing baby
    ref.read(caregiverContextProvider.notifier).clearCache();
    
    // Set active baby
    await ref.read(activeBabyProvider.notifier).setBaby(baby);
    
    // Pre-trigger caregiver context verification
    // (BabyHomePage will also call this in initState, but we start early)
    ref.read(caregiverContextProvider.notifier).ensureContext();
    
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  void _showCreateBabyDialog(BuildContext context) {
    _nameController.clear();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.babiesAddNew),
        content: TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Baby name',
            hintText: 'e.g., Emma',
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () async {
              final name = _nameController.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(dialogContext);
                await _createBaby(name);
              }
            },
            child: Text(context.l10n.commonSave),
          ),
        ],
      ),
    );
  }

  Future<void> _createBaby(String name) async {
    try {
      await ref.read(babiesNotifierProvider.notifier).createLocalBaby(
            name: name,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Baby "$name" created'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create baby: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _handleMenuAction(String action, user) async {
    switch (action) {
      case 'logout':
        await ref.read(authProvider.notifier).clearUser();
        await ref.read(activeBabyProvider.notifier).clearBaby();
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/');
        }
      case 'debug':
        if (kDebugMode && mounted) {
          Navigator.of(context).pushNamed('/debug');
        }
    }
  }
}
