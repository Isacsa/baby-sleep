import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:temp_flutter/application/providers/active_baby_provider.dart';
import 'package:temp_flutter/application/providers/sleep_state_provider.dart';
import 'package:temp_flutter/application/providers/sleep_events_provider.dart';
import 'package:temp_flutter/application/providers/sync_provider.dart';
import 'package:temp_flutter/application/providers/caregiver_context_provider.dart';
import 'package:temp_flutter/domain/entities/baby.dart';
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
  ProviderSubscription<Baby?>? _babySubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Ensure caregiver context on init
      _ensureCaregiverContext();
      
      // GUARDRAIL 1: Listen for baby changes to re-trigger context + refresh
      _babySubscription = ref.listenManual<Baby?>(
        activeBabyProvider,
        (previous, next) {
          if (previous?.id != next?.id) {
            debugPrint('[HomeSleep] Baby changed: ${previous?.id} -> ${next?.id}');
            _onBabyChanged();
          }
        },
      );
    });
  }

  @override
  void dispose() {
    _babySubscription?.close();
    super.dispose();
  }

  /// Called when active baby changes - re-trigger context and refresh events
  Future<void> _onBabyChanged() async {
    // Reset local loading state
    if (mounted) {
      setState(() => _isActionLoading = false);
    }
    
    // Clear cache and re-ensure context for new baby
    ref.read(caregiverContextProvider.notifier).clearCache();
    await ref.read(caregiverContextProvider.notifier).ensureContext();
    
    // Refresh events for new baby
    await ref.read(sleepEventsNotifierProvider.notifier).refresh();
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
    // GUARDRAIL 1: Initial também mostra UI (nunca silencioso)
    final (canCreateEvents, contextMessage, isContextLoading) = switch (caregiverContext) {
      CaregiverContextReady() => (true, null, false),
      CaregiverContextLoading() => (false, null, true),
      CaregiverContextInitial() => (false, null, true), // Treat Initial as loading (not silent)
      CaregiverContextOfflineNoCaregiver(:final message) => (false, message, false),
      CaregiverContextError(:final message) => (false, message, false),
    };

    final isLoading = _isActionLoading || isContextLoading;

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
                  // GUARDRAIL 1: Show loading banner for both Loading and Initial states
                  if (isContextLoading)
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
                  
                  // Quick time chips - different based on sleep state
                  if (canCreateEvents)
                    if (!sleepState.isSleeping)
                      _buildQuickTimeChips() // AWAKE: 5/10/15 min + Outra hora
                    else
                      _buildRetroactiveOnlyChip(), // SLEEPING: apenas "Outra hora (sono anterior)"
                  
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

  /// Chip shown when baby is SLEEPING - allows registering past sleep sessions
  Widget _buildRetroactiveOnlyChip() {
    return Column(
      children: [
        Text(
          'Registar sono anterior:',
          style: TextStyle(
            fontSize: 14,
            color: NightTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        QuickTimeChip(
          label: 'Outra hora (sono anterior)',
          icon: Icons.history,
          onTap: _handleCustomTimeWhileSleeping,
        ),
      ],
    );
  }

  Future<void> _handleSleepAction() async {
    // GUARDRAIL 3: Validate context BEFORE any action
    if (!_validateContextBeforeAction()) return;
    
    final sleepState = ref.read(sleepStateNotifierProvider);
    debugPrint('[HomeSleep] SleepAction: isSleeping=${sleepState.isSleeping}');
    
    setState(() => _isActionLoading = true);
    try {
      if (sleepState.isSleeping) {
        debugPrint('[HomeSleep] Creating SleepEnd...');
        await ref.read(sleepEventsNotifierProvider.notifier).createSleepEnd();
      } else {
        debugPrint('[HomeSleep] Creating SleepStart...');
        await ref.read(sleepEventsNotifierProvider.notifier).createSleepStart();
      }
      debugPrint('[HomeSleep] SleepAction completed successfully');
      // Note: addEvent() already updates state - no refresh() needed
    } catch (e, stack) {
      debugPrint('[HomeSleep] SleepAction error: $e');
      debugPrint('[HomeSleep] Stack: $stack');
      if (mounted) {
        _showErrorSnackBar(e.toString(), onRetry: _handleSleepAction);
      }
    } finally {
      if (mounted) {
        setState(() => _isActionLoading = false);
      }
    }
  }

  /// GUARDRAIL 3: Validates caregiver context before any action
  /// Returns true if can proceed, false if blocked (shows snackbar)
  bool _validateContextBeforeAction() {
    final baby = ref.read(activeBabyProvider);
    final context = ref.read(caregiverContextProvider);
    
    if (baby == null) {
      _showErrorSnackBar('Nenhum bebé selecionado');
      return false;
    }
    
    if (context is CaregiverContextReady) {
      return true;
    }
    
    // Show appropriate message based on state
    final message = switch (context) {
      CaregiverContextLoading() || CaregiverContextInitial() => 
        'A preparar permissões. Aguarda um momento.',
      CaregiverContextOfflineNoCaregiver(:final message) => message,
      CaregiverContextError(:final message) => message,
      _ => 'Não tens permissão para criar eventos.',
    };
    
    _showErrorSnackBar(message);
    return false;
  }

  Future<void> _handleQuickStart(int minutesAgo) async {
    // GUARDRAIL 3: Validate context BEFORE any action
    if (!_validateContextBeforeAction()) return;
    
    final timestamp = DateTime.now().subtract(Duration(minutes: minutesAgo));
    debugPrint('[HomeSleep] QuickStart: $minutesAgo min ago = $timestamp');
    
    setState(() => _isActionLoading = true);
    try {
      await ref.read(sleepEventsNotifierProvider.notifier).createSleepStartAt(
        timestamp,
      );
      debugPrint('[HomeSleep] QuickStart created successfully');
      // Note: addEvent() already updates state - no refresh() needed
    } catch (e, stack) {
      debugPrint('[HomeSleep] QuickStart error: $e');
      debugPrint('[HomeSleep] Stack: $stack');
      if (mounted) {
        _showErrorSnackBar(e.toString(), onRetry: () => _handleQuickStart(minutesAgo));
      }
    } finally {
      if (mounted) {
        setState(() => _isActionLoading = false);
      }
    }
  }

  /// Handler for "Outra hora" when baby is already SLEEPING
  /// Shows modal with options: End now / Register past sleep / Cancel
  Future<void> _handleCustomTimeWhileSleeping() async {
    // GUARDRAIL 3: Validate context BEFORE any action
    if (!_validateContextBeforeAction()) return;
    
    final sleepState = ref.read(sleepStateNotifierProvider);
    debugPrint('[HomeSleep] CustomTimeWhileSleeping: isSleeping=${sleepState.isSleeping}');
    
    // Show modal with options
    final choice = await _showAlreadySleepingModal(sleepState.lastEventTimestamp);
    if (choice == null || !mounted) return;
    
    switch (choice) {
      case _SleepingModalChoice.endNow:
        debugPrint('[HomeSleep] User chose: End now');
        await _handleEndSleepNow();
        
      case _SleepingModalChoice.registerPastSleep:
        debugPrint('[HomeSleep] User chose: Register past sleep');
        // Use a default start time (2 hours ago) for the wizard
        final defaultStart = DateTime.now().subtract(const Duration(hours: 2));
        await _showCompleteSleepFlow(defaultStart);
        
      case _SleepingModalChoice.cancel:
        debugPrint('[HomeSleep] User chose: Cancel');
        // Do nothing
    }
  }

  /// Shows modal when user tries to register sleep while baby is already sleeping
  Future<_SleepingModalChoice?> _showAlreadySleepingModal(DateTime? sleepingSince) async {
    final sinceStr = sleepingSince != null
        ? '${sleepingSince.toLocal().hour.toString().padLeft(2, '0')}:${sleepingSince.toLocal().minute.toString().padLeft(2, '0')}'
        : 'hora desconhecida';
    
    return showModalBottomSheet<_SleepingModalChoice>(
      context: context,
      backgroundColor: NightTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: NightTheme.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // Title
            Row(
              children: [
                Icon(Icons.bedtime, color: NightTheme.primary, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Já está a dormir desde $sinceStr',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: NightTheme.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'O que queres fazer?',
              style: TextStyle(
                fontSize: 14,
                color: NightTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            
            // Option 1: End now
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, _SleepingModalChoice.endNow),
              icon: const Icon(Icons.stop_circle_outlined),
              label: const Text('Terminar sono agora'),
              style: FilledButton.styleFrom(
                backgroundColor: NightTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 12),
            
            // Option 2: Register past sleep
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context, _SleepingModalChoice.registerPastSleep),
              icon: const Icon(Icons.history),
              label: const Text('Registar sono completo do passado'),
              style: OutlinedButton.styleFrom(
                foregroundColor: NightTheme.textPrimary,
                side: BorderSide(color: NightTheme.textSecondary.withValues(alpha: 0.3)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 12),
            
            // Option 3: Cancel
            TextButton(
              onPressed: () => Navigator.pop(context, _SleepingModalChoice.cancel),
              child: Text(
                'Cancelar',
                style: TextStyle(color: NightTheme.textSecondary),
              ),
            ),
            
            // Bottom padding for safe area
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  /// Handles ending the current sleep session
  Future<void> _handleEndSleepNow() async {
    setState(() => _isActionLoading = true);
    try {
      await ref.read(sleepEventsNotifierProvider.notifier).createSleepEnd();
      debugPrint('[HomeSleep] Sleep ended successfully');
      if (mounted) {
        _showSuccessSnackBar('Sono terminado');
      }
    } catch (e, stack) {
      debugPrint('[HomeSleep] Error ending sleep: $e');
      debugPrint('[HomeSleep] Stack: $stack');
      if (mounted) {
        _showErrorSnackBar(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isActionLoading = false);
      }
    }
  }

  /// Shows a success snackbar
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleCustomTime() async {
    // GUARDRAIL 3: Validate context BEFORE any action
    if (!_validateContextBeforeAction()) return;
    
    // Passo 1: Escolher hora
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    
    if (time == null) {
      debugPrint('[HomeSleep] Time picker cancelled');
      return;
    }
    if (!mounted) return;
    
    // Passo 2: Escolher dia (Hoje/Ontem)
    final day = await _showDayPicker(time);
    if (day == null) {
      debugPrint('[HomeSleep] Day picker cancelled');
      return;
    }
    if (!mounted) return;
    
    // Construir DateTime baseado na escolha
    final now = DateTime.now();
    DateTime selectedDateTime;
    if (day == 'today') {
      selectedDateTime = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    } else {
      // yesterday
      final yesterday = now.subtract(const Duration(days: 1));
      selectedDateTime = DateTime(yesterday.year, yesterday.month, yesterday.day, time.hour, time.minute);
    }
    
    debugPrint('[HomeSleep] Selected DateTime: $selectedDateTime (day=$day)');
    
    // Verificar se ainda é futuro (edge case: escolheu "hoje" mas hora ainda não chegou)
    if (selectedDateTime.isAfter(now)) {
      debugPrint('[HomeSleep] DateTime is in future, showing dialog');
      final adjusted = await _showFutureTimeDialog(selectedDateTime);
      if (adjusted == null) {
        debugPrint('[HomeSleep] Future dialog cancelled');
        return;
      }
      if (!mounted) return;
      selectedDateTime = adjusted;
      debugPrint('[HomeSleep] Adjusted to: $selectedDateTime');
    }
    
    // Passo 3: Perguntar intenção (A: ainda a dormir, B: sono completo)
    final intent = await _showPastTimeIntentSheet(selectedDateTime);
    if (intent == null) {
      debugPrint('[HomeSleep] Intent sheet cancelled');
      return;
    }
    if (!mounted) return;
    
    debugPrint('[HomeSleep] Intent selected: $intent');
    
    if (intent == 'still_sleeping') {
      // Opção A: criar apenas SleepStart
      await _createStartEvent(selectedDateTime);
    } else if (intent == 'complete') {
      // Opção B: wizard para sono completo
      await _showCompleteSleepFlow(selectedDateTime);
    }
  }

  /// Bottom sheet para escolher Hoje ou Ontem
  Future<String?> _showDayPicker(TimeOfDay time) async {
    final now = DateTime.now();
    final currentHour = now.hour;
    
    // Default inteligente para contexto noturno:
    // Se a hora escolhida é maior que a hora atual (ex: 23:00 quando são 08:00),
    // provavelmente é de ontem à noite
    final defaultIsYesterday = time.hour > currentHour + 2;
    
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: NightTheme.surface,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Que dia?',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: NightTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Hora escolhida: ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                fontSize: 14,
                color: NightTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            
            // Hoje
            FilledButton(
              onPressed: () => Navigator.pop(context, 'today'),
              style: FilledButton.styleFrom(
                backgroundColor: defaultIsYesterday 
                    ? NightTheme.surface 
                    : NightTheme.primary,
                foregroundColor: defaultIsYesterday 
                    ? NightTheme.textPrimary 
                    : Colors.white,
                side: defaultIsYesterday 
                    ? BorderSide(color: NightTheme.textSecondary.withValues(alpha: 0.3))
                    : null,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Hoje'),
            ),
            const SizedBox(height: 12),
            
            // Ontem
            FilledButton(
              onPressed: () => Navigator.pop(context, 'yesterday'),
              style: FilledButton.styleFrom(
                backgroundColor: defaultIsYesterday 
                    ? NightTheme.primary 
                    : NightTheme.surface,
                foregroundColor: defaultIsYesterday 
                    ? Colors.white 
                    : NightTheme.textPrimary,
                side: defaultIsYesterday 
                    ? null
                    : BorderSide(color: NightTheme.textSecondary.withValues(alpha: 0.3)),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Ontem'),
            ),
            const SizedBox(height: 12),
            
            // Cancelar
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: Text(
                'Cancelar',
                style: TextStyle(color: NightTheme.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Bottom sheet para perguntar intenção: ainda a dormir vs sono completo
  Future<String?> _showPastTimeIntentSheet(DateTime pastTime) async {
    final timeStr = '${pastTime.hour.toString().padLeft(2, '0')}:${pastTime.minute.toString().padLeft(2, '0')}';
    final isYesterday = pastTime.day != DateTime.now().day;
    final dayLabel = isYesterday ? 'ontem' : 'hoje';
    
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: NightTheme.surface,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'O que queres registar?',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: NightTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Início: $dayLabel às $timeStr',
              style: TextStyle(
                fontSize: 14,
                color: NightTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            
            // Opção A: Ainda a dormir
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, 'still_sleeping'),
              icon: const Icon(Icons.bedtime),
              label: const Text('Ainda está a dormir'),
              style: FilledButton.styleFrom(
                backgroundColor: NightTheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 12),
            
            // Opção B: Sono completo
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, 'complete'),
              icon: const Icon(Icons.check_circle),
              label: const Text('Registar sono completo'),
              style: FilledButton.styleFrom(
                backgroundColor: NightTheme.secondary,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 12),
            
            // Cancelar
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: Text(
                'Cancelar',
                style: TextStyle(color: NightTheme.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Helper para criar SleepStart com feedback
  Future<void> _createStartEvent(DateTime startTime) async {
    debugPrint('[HomeSleep] Creating SleepStart at: $startTime (UTC: ${startTime.toUtc()})');
    setState(() => _isActionLoading = true);
    try {
      await ref.read(sleepEventsNotifierProvider.notifier).createSleepStartAt(
        startTime,
      );
      debugPrint('[HomeSleep] SleepStart created successfully');
      // Note: addEvent() already updates state - no refresh() needed
    } catch (e, stack) {
      debugPrint('[HomeSleep] Error creating SleepStart: $e');
      debugPrint('[HomeSleep] Stack: $stack');
      if (mounted) {
        _showErrorSnackBar(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isActionLoading = false);
      }
    }
  }

  /// Wizard para registar sono completo (2 passos: início + fim)
  Future<void> _showCompleteSleepFlow(DateTime initialStart) async {
    debugPrint('[HomeSleep] Complete sleep flow started with: $initialStart');
    DateTime startTime = initialStart;
    
    // Passo 1: Confirmar/ajustar hora de início
    final startTimeOfDay = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(startTime),
      helpText: 'Hora de início do sono',
    );
    
    if (startTimeOfDay == null) {
      debugPrint('[HomeSleep] Start time picker cancelled');
      return;
    }
    if (!mounted) return;
    
    // Reconstruir startTime com a hora ajustada (mantendo o dia)
    startTime = DateTime(
      startTime.year,
      startTime.month,
      startTime.day,
      startTimeOfDay.hour,
      startTimeOfDay.minute,
    );
    debugPrint('[HomeSleep] Start time adjusted to: $startTime');
    
    // Passo 2: Escolher hora de fim
    final endTimeOfDay = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        startTime.add(const Duration(hours: 2)),
      ),
      helpText: 'Hora de fim do sono',
    );
    
    if (endTimeOfDay == null) {
      debugPrint('[HomeSleep] End time picker cancelled');
      return;
    }
    if (!mounted) return;
    
    // Construir endTime no mesmo dia que startTime
    DateTime endTime = DateTime(
      startTime.year,
      startTime.month,
      startTime.day,
      endTimeOfDay.hour,
      endTimeOfDay.minute,
    );
    debugPrint('[HomeSleep] End time initial: $endTime');
    
    // Se end <= start, assumir que atravessou meia-noite (fim no dia seguinte)
    if (!endTime.isAfter(startTime)) {
      debugPrint('[HomeSleep] End <= Start, showing midnight dialog');
      final crossMidnight = await _showCrossMidnightDialog(startTime, endTime);
      if (crossMidnight == null) {
        debugPrint('[HomeSleep] Midnight dialog cancelled');
        return;
      }
      if (!mounted) return;
      
      if (crossMidnight) {
        endTime = endTime.add(const Duration(days: 1));
        debugPrint('[HomeSleep] End time adjusted for midnight: $endTime');
      } else {
        debugPrint('[HomeSleep] User chose to correct, returning');
        return;
      }
    }
    
    // Verificar se fim está no futuro
    final now = DateTime.now();
    if (endTime.isAfter(now)) {
      debugPrint('[HomeSleep] End is in future, showing dialog');
      final adjusted = await _showFutureEndDialog(endTime);
      if (adjusted == null) {
        debugPrint('[HomeSleep] Future end dialog cancelled');
        return;
      }
      if (!mounted) return;
      endTime = adjusted;
      debugPrint('[HomeSleep] End time adjusted to: $endTime');
    }
    
    // Criar sessão completa
    debugPrint('[HomeSleep] Creating session: start=$startTime, end=$endTime');
    debugPrint('[HomeSleep] UTC: start=${startTime.toUtc()}, end=${endTime.toUtc()}');
    setState(() => _isActionLoading = true);
    try {
      await ref.read(sleepEventsNotifierProvider.notifier).createSleepSession(
        startTime: startTime,
        endTime: endTime,
      );
      debugPrint('[HomeSleep] Session created successfully');
      // Note: createSleepSession already calls refresh() internally
    } catch (e, stack) {
      debugPrint('[HomeSleep] Error creating session: $e');
      debugPrint('[HomeSleep] Stack: $stack');
      if (mounted) {
        _showErrorSnackBar(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isActionLoading = false);
      }
    }
  }

  /// Diálogo para confirmar que o sono atravessou meia-noite
  Future<bool?> _showCrossMidnightDialog(DateTime start, DateTime end) async {
    final startStr = '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
    final endStr = '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';
    
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: NightTheme.surface,
        title: const Text(
          'Atravessou meia-noite?',
          style: TextStyle(color: NightTheme.textPrimary),
        ),
        content: Text(
          'Início às $startStr e fim às $endStr.\n\nO sono atravessou a meia-noite (dormiu ontem à noite, acordou hoje de manhã)?',
          style: const TextStyle(color: NightTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: Text('Cancelar', style: TextStyle(color: NightTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Não, corrigir'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sim'),
          ),
        ],
      ),
    );
  }

  /// Diálogo para quando hora de fim está no futuro
  Future<DateTime?> _showFutureEndDialog(DateTime futureEnd) async {
    return showDialog<DateTime>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: NightTheme.surface,
        title: const Text(
          'Hora de fim no futuro',
          style: TextStyle(color: NightTheme.textPrimary),
        ),
        content: const Text(
          'A hora de fim não pode estar no futuro.',
          style: TextStyle(color: NightTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: Text('Cancelar', style: TextStyle(color: NightTheme.textSecondary)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, DateTime.now()),
            child: const Text('Usar agora'),
          ),
        ],
      ),
    );
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
            // X button to dismiss
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 20),
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        backgroundColor: NightTheme.error,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
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

/// Enum for modal choices when baby is already sleeping
enum _SleepingModalChoice {
  endNow,
  registerPastSleep,
  cancel,
}
