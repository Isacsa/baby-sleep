import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:temp_flutter/application/providers/active_baby_provider.dart';
import 'package:temp_flutter/application/providers/sleep_events_provider.dart';
import 'package:temp_flutter/domain/entities/sleep_event.dart';
import 'package:temp_flutter/presentation/widgets/empty_state.dart';

/// TimelinePage - List of sleep events for the active baby
/// 
/// Displays events from local SQLite, ordered by timestamp DESC.
/// Shows: type, timestamp, isCorrected flag, syncedAt status
class TimelinePage extends ConsumerWidget {
  const TimelinePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeBaby = ref.watch(activeBabyProvider);
    final eventsAsync = ref.watch(sleepEventsNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(activeBaby != null ? '${activeBaby.name}\'s Timeline' : 'Timeline'),
        centerTitle: true,
      ),
      body: eventsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          title: 'Error loading events',
          subtitle: e.toString(),
        ),
        data: (events) {
          if (events.isEmpty) {
            return const EmptyState(
              icon: Icons.timeline,
              title: 'No events yet',
              subtitle: 'Sleep events will appear here when you start tracking.',
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              await ref.read(sleepEventsNotifierProvider.notifier).refresh();
            },
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: events.length,
              itemBuilder: (context, index) {
                final event = events[index];
                final isFirst = index == 0;
                final isLast = index == events.length - 1;

                return _EventTile(
                  event: event,
                  isFirst: isFirst,
                  isLast: isLast,
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  final SleepEvent event;
  final bool isFirst;
  final bool isLast;

  const _EventTile({
    required this.event,
    required this.isFirst,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSleepStart = event.type == SleepEventType.sleepStart;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Timeline line with dot
            SizedBox(
              width: 40,
              child: Column(
                children: [
                  // Top line
                  Expanded(
                    child: Container(
                      width: 2,
                      color: isFirst
                          ? Colors.transparent
                          : theme.colorScheme.outline.withOpacity(0.3),
                    ),
                  ),
                  // Dot
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSleepStart
                          ? theme.colorScheme.primary
                          : theme.colorScheme.tertiary,
                      border: Border.all(
                        color: theme.colorScheme.surface,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      isSleepStart
                          ? Icons.nightlight_round
                          : Icons.wb_sunny_rounded,
                      size: 8,
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                  // Bottom line
                  Expanded(
                    child: Container(
                      width: 2,
                      color: isLast
                          ? Colors.transparent
                          : theme.colorScheme.outline.withOpacity(0.3),
                    ),
                  ),
                ],
              ),
            ),

            // Event card
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: event.isCorrected
                      ? Border.all(
                          color: theme.colorScheme.error.withOpacity(0.3),
                          width: 1,
                        )
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Type and time
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isSleepStart ? 'Sleep Start' : 'Sleep End',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isSleepStart
                                ? theme.colorScheme.primary
                                : theme.colorScheme.tertiary,
                          ),
                        ),
                        Text(
                          _formatDateTime(event.timestamp),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Status indicators
                    Wrap(
                      spacing: 8,
                      children: [
                        // Sync status
                        _StatusChip(
                          icon: event.syncedAt != null
                              ? Icons.cloud_done
                              : Icons.cloud_off,
                          label: event.syncedAt != null ? 'Synced' : 'Local',
                          color: event.syncedAt != null
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outline,
                        ),
                        // Corrected indicator
                        if (event.isCorrected)
                          _StatusChip(
                            icon: Icons.edit_off,
                            label: 'Corrected',
                            color: theme.colorScheme.error,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    final now = DateTime.now();
    final isToday = local.day == now.day &&
        local.month == now.month &&
        local.year == now.year;

    final time = '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';

    if (isToday) {
      return 'Today $time';
    } else {
      return '${local.day}/${local.month} $time';
    }
  }
}

class _StatusChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatusChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
              ),
        ),
      ],
    );
  }
}
