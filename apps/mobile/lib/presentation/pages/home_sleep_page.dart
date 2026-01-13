import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:temp_flutter/application/providers/active_baby_provider.dart';
import 'package:temp_flutter/application/providers/sleep_state_provider.dart';
import 'package:temp_flutter/application/providers/sleep_events_provider.dart';
import 'package:temp_flutter/application/providers/sync_provider.dart';
import 'package:temp_flutter/application/providers/caregiver_context_provider.dart';
import 'package:temp_flutter/presentation/theme/night_theme.dart';
import 'package:temp_flutter/presentation/widgets/sync_status_chip.dart';
import 'package:temp_flutter/presentation/widgets/quick_time_chip.dart';

/// HomeSleepPage - Tab principal de Sono
/// 
/// Features:
/// - Header com nome do bebé e ícone calendário
/// - PrimarySleepButton central (Start/End)
/// - QuickTimeChips (5/10/15 min + "Outra hora")
/// - SyncStatusChip no header
/// - Caregiver context integration
class HomeSleepPage extends ConsumerStatefulWidget {
  const HomeSleepPage({super.key});

  @override
  ConsumerState<HomeSleepPage> createState() => _HomeSleepPageState();
}

class _HomeSleepPageState extends ConsumerState<HomeSleepPage> {
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
    final activeBaby = ref.watch(activeBabyProvider);
    final sleepState = ref.watch(sleepStateNotifierProvider);
    final syncState = ref.watch(syncProvider);
    final caregiverContext = ref.watch(caregiverContextProvider);

    // Redirect if no baby
    if (activeBaby == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed('/babies');
      });
      return const SizedBox.shrink();
    }

    // Determine button state
    final (canCreateEvents, contextMessage) = switch (caregiverContext) {
      CaregiverContextReady() => (true, null),
      CaregiverContextLoading() => (false, null),
      CaregiverContextInitial() => (false, null),
      CaregiverContextOfflineNoCaregiver(:final message) => (false, message),
      CaregiverContextError(:final message) => (false, message),
    };

    final isLoading = _isActionLoading || caregiverContext is CaregiverContextLoading;

    return SafeArea(
      child: Column(
        children: [
          // Header
          _buildHeader(activeBaby.name, syncState),
          
          // Main content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Caregiver context status
                  if (caregiverContext is CaregiverContextLoading)
                    _buildLoadingBanner()
                  else if (contextMessage != null)
                    _buildErrorBanner(contextMessage),

                  const Spacer(),
                  
                  // Primary Sleep Button
                  _PrimarySleepButton(
                    isSleeping: sleepState.isSleeping,
                    lastEventTimestamp: sleepState.lastEventTimestamp,
                    isLoading: isLoading,
                    isDisabled: !canCreateEvents,
                    onPressed: canCreateEvents ? _handleSleepAction : null,
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Quick time chips
                  if (canCreateEvents && !sleepState.isSleeping)
                    _buildQuickTimeChips(),
                  
                  const Spacer(),
                ],
              ),
            ),
          ),
          
          // Bottom padding for floating bar
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildHeader(String babyName, syncState) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          // Baby icon/avatar
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: NightTheme.primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.child_care,
              color: NightTheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          
          // Baby name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bebé $babyName',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: NightTheme.textPrimary,
                  ),
                ),
                const Text(
                  'Olá, como correu a noite?',
                  style: TextStyle(
                    fontSize: 12,
                    color: NightTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          
          // Sync status
          SyncStatusChip(
            syncState: syncState,
            onTap: () => _showSyncDetails(),
          ),
          
          const SizedBox(width: 8),
          
          // Calendar icon
          IconButton(
            onPressed: () => Navigator.of(context).pushNamed('/day-detail'),
            icon: const Icon(
              Icons.calendar_today,
              color: NightTheme.textSecondary,
            ),
          ),
          
          // Debug menu (only in debug mode)
          if (kDebugMode)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: NightTheme.textSecondary),
              onSelected: _handleMenuAction,
              itemBuilder: (context) => [
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
                const PopupMenuItem(
                  value: 'switch',
                  child: Row(
                    children: [
                      Icon(Icons.swap_horiz),
                      SizedBox(width: 8),
                      Text('Mudar bebé'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildLoadingBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: NightTheme.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: NightTheme.primary,
            ),
          ),
          SizedBox(width: 12),
          Text(
            'A preparar permissões...',
            style: TextStyle(color: NightTheme.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: NightTheme.error.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.wifi_off, color: NightTheme.error, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: NightTheme.textPrimary,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _ensureCaregiverContext,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Tentar novamente'),
            style: FilledButton.styleFrom(
              backgroundColor: NightTheme.error,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickTimeChips() {
    return Column(
      children: [
        Text(
          'Começar há:',
          style: TextStyle(
            fontSize: 14,
            color: NightTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            QuickTimeChip(
              label: '5 min',
              onTap: () => _handleQuickStart(5),
            ),
            QuickTimeChip(
              label: '10 min',
              onTap: () => _handleQuickStart(10),
            ),
            QuickTimeChip(
              label: '15 min',
              onTap: () => _handleQuickStart(15),
            ),
            QuickTimeChip(
              label: 'Outra hora',
              icon: Icons.schedule,
              onTap: _handleCustomTime,
            ),
          ],
        ),
      ],
    );
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
      if (mounted) {
        _showErrorSnackBar(e.toString(), onRetry: _handleSleepAction);
      }
    } finally {
      if (mounted) {
        setState(() => _isActionLoading = false);
      }
    }
  }

  Future<void> _handleQuickStart(int minutesAgo) async {
    setState(() => _isActionLoading = true);
    try {
      await ref.read(sleepEventsNotifierProvider.notifier).createSleepStartAt(
        DateTime.now().subtract(Duration(minutes: minutesAgo)),
      );
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar(e.toString(), onRetry: () => _handleQuickStart(minutesAgo));
      }
    } finally {
      if (mounted) {
        setState(() => _isActionLoading = false);
      }
    }
  }

  Future<void> _handleCustomTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    
    if (time == null || !mounted) return;
    
    final now = DateTime.now();
    final selectedDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    
    DateTime? finalDateTime;
    
    // Se hora é no futuro, mostrar diálogo com opções
    if (selectedDateTime.isAfter(now)) {
      finalDateTime = await _showFutureTimeDialog(selectedDateTime);
      if (finalDateTime == null || !mounted) return; // Cancelado
    } else {
      // Hora no passado ou presente - usar diretamente
      finalDateTime = selectedDateTime;
    }
    
    setState(() => _isActionLoading = true);
    try {
      await ref.read(sleepEventsNotifierProvider.notifier).createSleepStartAt(
        finalDateTime,
      );
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isActionLoading = false);
      }
    }
  }

  void _showSyncDetails() {
    final activeBaby = ref.read(activeBabyProvider);
    if (activeBaby == null) return;
    
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sincronização', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await ref.read(syncProvider.notifier).syncNowForBaby(activeBaby.id);
                  await _ensureCaregiverContext();
                },
                child: const Text('Sincronizar agora'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'debug':
        if (kDebugMode) {
          Navigator.of(context).pushNamed('/debug');
        }
      case 'switch':
        Navigator.of(context).pushReplacementNamed('/babies');
    }
  }

  /// Helper para mostrar erros de forma consistente
  void _showErrorSnackBar(String message, {VoidCallback? onRetry}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: NightTheme.error,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        action: onRetry != null
            ? SnackBarAction(
                label: 'Tentar',
                textColor: Colors.white,
                onPressed: onRetry,
              )
            : null,
      ),
    );
  }

  /// Diálogo para quando o utilizador escolhe uma hora no futuro
  Future<DateTime?> _showFutureTimeDialog(DateTime futureTime) async {
    return showDialog<DateTime>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: NightTheme.surface,
        title: const Text(
          'Hora no futuro',
          style: TextStyle(color: NightTheme.textPrimary),
        ),
        content: const Text(
          'Não podes registar uma hora no futuro.\n\nO que queres fazer?',
          style: TextStyle(color: NightTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: Text(
              'Cancelar',
              style: TextStyle(color: NightTheme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, DateTime.now()),
            child: const Text('Usar agora'),
          ),
          FilledButton(
            onPressed: () {
              // Registar como ontem (mesma hora, -1 dia)
              final yesterday = futureTime.subtract(const Duration(days: 1));
              Navigator.pop(context, yesterday);
            },
            child: const Text('Ontem'),
          ),
        ],
      ),
    );
  }
}

/// PrimarySleepButton - Botão circular central
class _PrimarySleepButton extends StatelessWidget {
  final bool isSleeping;
  final DateTime? lastEventTimestamp;
  final bool isLoading;
  final bool isDisabled;
  final VoidCallback? onPressed;

  const _PrimarySleepButton({
    required this.isSleeping,
    this.lastEventTimestamp,
    this.isLoading = false,
    this.isDisabled = false,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSleeping ? NightTheme.secondary : NightTheme.primary;
    final icon = isSleeping ? Icons.wb_sunny : Icons.bedtime;
    final label = isSleeping ? 'Acordou' : 'Dormir Agora';
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Main button
        GestureDetector(
          onTap: isLoading || isDisabled ? null : onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDisabled 
                  ? NightTheme.textSecondary.withValues(alpha: 0.3)
                  : color.withValues(alpha: 0.2),
              border: Border.all(
                color: isDisabled 
                    ? NightTheme.textSecondary.withValues(alpha: 0.5)
                    : color,
                width: 3,
              ),
              boxShadow: isDisabled ? [] : [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: NightTheme.textPrimary,
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icon,
                        size: 48,
                        color: isDisabled ? NightTheme.textSecondary : color,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDisabled ? NightTheme.textSecondary : color,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        
        // Timer if sleeping
        if (isSleeping && lastEventTimestamp != null) ...[
          const SizedBox(height: 16),
          _SleepTimer(startTime: lastEventTimestamp!),
        ],
      ],
    );
  }
}

/// Timer display for active sleep
class _SleepTimer extends StatefulWidget {
  final DateTime startTime;

  const _SleepTimer({required this.startTime});

  @override
  State<_SleepTimer> createState() => _SleepTimerState();
}

class _SleepTimerState extends State<_SleepTimer> {
  late Duration _elapsed;

  @override
  void initState() {
    super.initState();
    _elapsed = DateTime.now().difference(widget.startTime);
    // Update every minute
    Future.delayed(const Duration(minutes: 1), _tick);
  }

  void _tick() {
    if (mounted) {
      setState(() {
        _elapsed = DateTime.now().difference(widget.startTime);
      });
      Future.delayed(const Duration(minutes: 1), _tick);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hours = _elapsed.inHours;
    final minutes = _elapsed.inMinutes % 60;
    
    return Text(
      hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m',
      style: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w300,
        color: NightTheme.textSecondary,
      ),
    );
  }
}
