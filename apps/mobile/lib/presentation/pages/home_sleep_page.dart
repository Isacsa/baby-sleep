import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:temp_flutter/application/providers/active_baby_provider.dart';
import 'package:temp_flutter/application/providers/sleep_state_provider.dart';
import 'package:temp_flutter/application/providers/sleep_events_provider.dart';
import 'package:temp_flutter/application/providers/sync_provider.dart';
import 'package:temp_flutter/application/providers/caregiver_context_provider.dart';
import 'package:temp_flutter/application/providers/sleep_cockpit_provider.dart';
import 'package:temp_flutter/core/l10n/l10n.dart';
import 'package:temp_flutter/core/utils/local_time_utils.dart';
import 'package:temp_flutter/domain/entities/baby.dart';
import 'package:temp_flutter/domain/entities/sleep_event.dart';
import 'package:temp_flutter/domain/value_objects/sleep_session.dart';
import 'package:temp_flutter/presentation/theme/night_theme.dart';
import 'package:temp_flutter/presentation/widgets/sync_status_chip.dart';
import 'package:temp_flutter/presentation/widgets/quick_time_chip.dart';
import 'package:temp_flutter/presentation/widgets/sleep_cockpit_hero.dart';
import 'package:temp_flutter/presentation/widgets/data_quality_indicator.dart';
// HomeSleepPage must stay minimal: only sleep logging UI (Start/End + quick chips).

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
  ProviderSubscription<AsyncValue<List<SleepEvent>>>? _eventsSubscription;
  
  /// Track which conflicts we've already shown to avoid repeated prompts
  final Set<String> _handledConflictIds = {};

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
            _handledConflictIds.clear(); // Clear handled conflicts for new baby
            _onBabyChanged();
          }
        },
      );
      
      // Listen for events changes to detect multi-device conflicts
      _eventsSubscription = ref.listenManual<AsyncValue<List<SleepEvent>>>(
        sleepEventsNotifierProvider,
        (previous, next) {
          if (next.hasValue) {
            _checkForDuplicateConflicts();
          }
        },
      );
      
      // Initial check for conflicts
      _checkForDuplicateConflicts();
    });
  }

  @override
  void dispose() {
    _babySubscription?.close();
    _eventsSubscription?.close();
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

  /// Checks for duplicate SleepStart conflicts (multi-device).
  /// 
  /// DISABLED: The automatic conflict detection was causing false positives
  /// when there were old uncorrected SleepStart events. The normal sync 
  /// mechanism (auto-pull + push) already handles convergence between devices.
  /// 
  /// The snackbar was confusing users by appearing constantly when there
  /// wasn't a real "double-tap" conflict, just stale data.
  void _checkForDuplicateConflicts() {
    // DISABLED: Conflict detection was causing false positives.
    // The sync mechanism already handles multi-device convergence.
    // If real conflicts occur, the last-write-wins in remote + pull will resolve.
    return;
  }
  
  // Conflict UI helpers removed (conflict detection is disabled).
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
          
          // Main content - now scrollable with cockpit
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Caregiver context status
                  // GUARDRAIL 1: Show loading banner for both Loading and Initial states
                  if (isContextLoading)
                    _buildLoadingBanner()
                  else if (contextMessage != null)
                    _buildErrorBanner(contextMessage),

                  // A. Hero Top (new cockpit section)
                  SleepCockpitHero(
                    onAddDob: () => Navigator.of(context).pushNamed('/baby-profile'),
                    onSeeDataQualityDetails: () => _showDataQualityDetails(),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // B. CTA Registo (Primary Sleep Button)
                  Center(
                    child: _PrimarySleepButton(
                      isSleeping: sleepState.isSleeping,
                      lastEventTimestamp: sleepState.lastEventTimestamp,
                      isLoading: isLoading,
                      isDisabled: !canCreateEvents,
                      onPressed: canCreateEvents ? _handleSleepAction : null,
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // C. Quick actions
                  if (canCreateEvents)
                    if (!sleepState.isSleeping)
                      _buildQuickTimeChips() // AWAKE: 5/10/15 min + Outra hora
                    else
                      _buildRetroactiveOnlyChip(), // SLEEPING: apenas "Outra hora (sono anterior)"
                  
                  const SizedBox(height: 16),
                  
                  // D. Timeline (compact - link to day detail)
                  _buildTimelineSection(),
                  
                  const SizedBox(height: 16),
                  
                  // E. Data Quality Indicator (if not good)
                  _buildDataQualitySection(),
                ],
              ),
            ),
          ),
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
            child: Builder(
              builder: (ctx) {
                final l10n = ctx.l10n;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.homeBabyName(babyName),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: NightTheme.textPrimary,
                      ),
                    ),
                    Text(
                      l10n.homeGreeting,
                      style: const TextStyle(
                        fontSize: 12,
                        color: NightTheme.textSecondary,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          
          // Sync status with pending count badge (FIX P5)
          Builder(builder: (context) {
            final pendingCount = ref.watch(pendingSyncCountProvider).valueOrNull ?? 0;
            return SyncStatusChip(
              syncState: syncState,
              pendingCount: pendingCount,
              onTap: () => _showSyncDetails(),
            );
          }),
          
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
            Builder(
              builder: (ctx) {
                final l10n = ctx.l10n;
                return PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: NightTheme.textSecondary),
                  onSelected: _handleMenuAction,
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'debug',
                      child: Row(
                        children: [
                          const Icon(Icons.bug_report),
                          const SizedBox(width: 8),
                          Text(l10n.menuDebug),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'switch',
                      child: Row(
                        children: [
                          const Icon(Icons.swap_horiz),
                          const SizedBox(width: 8),
                          Text(l10n.menuSwitchBaby),
                        ],
                      ),
                    ),
                  ],
                );
              },
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
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: NightTheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            context.l10n.preparingPermissions,
            style: const TextStyle(color: NightTheme.textPrimary),
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
            label: Text(context.l10n.commonRetry),
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
    final l10n = context.l10n;
    return Column(
      children: [
        Text(
          l10n.homeStartedAgo,
          style: const TextStyle(
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
              label: l10n.homeOtherTime,
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
    final l10n = context.l10n;
    return Column(
      children: [
        Text(
          l10n.homeRegisterPastSleep,
          style: const TextStyle(
            fontSize: 14,
            color: NightTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        QuickTimeChip(
          label: l10n.homeOtherTimePast,
          icon: Icons.history,
          onTap: _handleCustomTimeWhileSleeping,
        ),
      ],
    );
  }

  /// Compact timeline section - shows today's sessions with link to full day
  Widget _buildTimelineSection() {
    final cockpit = ref.watch(sleepCockpitProvider);
    final sessions = cockpit.todaySessions;
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NightTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: NightTheme.textSecondary.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Text(
                l10n.timelineTitle,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: NightTheme.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                cockpit.goal.totalFormatted,
                style: const TextStyle(
                  fontSize: 12,
                  color: NightTheme.textSecondary,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.of(context).pushNamed('/day-detail'),
                child: Text(
                  l10n.timelineSeeAll,
                  style: const TextStyle(
                    fontSize: 12,
                    color: NightTheme.primary,
                  ),
                ),
              ),
            ],
          ),

          // Sessions preview (max 3)
          if (sessions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                l10n.timelineNoRecords,
                style: const TextStyle(
                  fontSize: 13,
                  color: NightTheme.textSecondary,
                ),
              ),
            )
          else
            Stack(
              children: [
                // Connector line
                Positioned(
                  left: 7, // Center of icon (16px) is at 8px, line width 2px -> left at 7px
                  top: 12,
                  bottom: 12,
                  child: Container(
                    width: 2,
                    decoration: BoxDecoration(
                      color: NightTheme.textSecondary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
                // Sessions list
                Column(
                  children: sessions.take(3).map((session) => _buildSessionPreview(session)).toList(),
                ),
              ],
            ),

          // "See more" if > 3
          if (sessions.length > 3)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: GestureDetector(
                onTap: () => Navigator.of(context).pushNamed('/day-detail'),
                child: Text(
                  '${l10n.timelineSeeMore} (${sessions.length - 3})',
                  style: const TextStyle(
                    fontSize: 12,
                    color: NightTheme.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSessionPreview(SleepSession session) {
    final startLocal = session.startEvent.timestamp.toLocal();
    final startStr = '${startLocal.hour.toString().padLeft(2, '0')}:${startLocal.minute.toString().padLeft(2, '0')}';
    
    String endStr;
    if (session.isComplete) {
      final endLocal = session.endEvent!.timestamp.toLocal();
      endStr = '${endLocal.hour.toString().padLeft(2, '0')}:${endLocal.minute.toString().padLeft(2, '0')}';
    } else {
      endStr = context.l10n.sessionInProgress;
    }

    final durationStr = session.isComplete
        ? _formatDuration(session.duration!)
        : '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8), // Increased spacing
      child: Row(
        children: [
          // Icon with background circle to cover the line
          Container(
            decoration: BoxDecoration(
              color: NightTheme.surface, // Matches background to "cut" the line
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(2), // Small padding around icon
            child: Icon(
              session.isComplete ? Icons.brightness_3 : Icons.bedtime,
              size: 14,
              color: session.isComplete ? NightTheme.textSecondary : NightTheme.primary,
            ),
          ),
          const SizedBox(width: 12), // Increased spacing
          Text(
            '$startStr – $endStr',
            style: const TextStyle(
              fontSize: 13,
              color: NightTheme.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (durationStr.isNotEmpty) ...[
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: NightTheme.backgroundBase,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                durationStr,
                style: const TextStyle(
                  fontSize: 11,
                  color: NightTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final h = duration.inHours;
    final m = duration.inMinutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  /// Data quality section - only shown if not good
  Widget _buildDataQualitySection() {
    final cockpit = ref.watch(sleepCockpitProvider);

    // Only show if there are issues
    if (cockpit.isDataQualityGood) {
      return const SizedBox.shrink();
    }

    return DataQualityIndicator(
      viewModel: cockpit.dataQualityViewModel,
      onSeeDetails: _showDataQualityDetails,
    );
  }

  /// Shows the data quality details bottom sheet
  void _showDataQualityDetails() {
    final cockpit = ref.read(sleepCockpitProvider);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DataQualityDetailsSheet(
        viewModel: cockpit.dataQualityViewModel,
      ),
    );
  }

  /// Builds the routine suggestion section for the home page
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
    
    final l10n = this.context.l10n;
    if (baby == null) {
      _showErrorSnackBar(l10n.errorNoBaby);
      return false;
    }
    
    if (context is CaregiverContextReady) {
      return true;
    }
    
    // Show appropriate message based on state
    final message = switch (context) {
      CaregiverContextLoading() || CaregiverContextInitial() => 
        l10n.preparingPermissionsWait,
      CaregiverContextOfflineNoCaregiver(:final message) => message,
      CaregiverContextError(:final message) => message,
      _ => l10n.noPermissionToCreate,
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
    } on OverlapException catch (e) {
      debugPrint('[HomeSleep] QuickStart overlap detected: ${e.overlappingSessions.length} sessions');
      if (mounted) {
        // Show modal with Substituir option
        final shouldReplace = await _showOverlapModal(e.overlappingSessions, e.message);
        if (shouldReplace == true && mounted) {
          await _overwriteSessionsAndCreateStart(
            overlappingSessions: e.overlappingSessions,
            newStartTime: timestamp,
          );
        }
      }
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
    final l10n = context.l10n;
    final sinceStr = sleepingSince != null
        ? '${sleepingSince.toLocal().hour.toString().padLeft(2, '0')}:${sleepingSince.toLocal().minute.toString().padLeft(2, '0')}'
        : l10n.unknownTime;
    
    return showModalBottomSheet<_SleepingModalChoice>(
      context: context,
      backgroundColor: NightTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
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
                const Icon(Icons.bedtime, color: NightTheme.primary, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.sleepingSince(sinceStr),
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
              l10n.whatToDo,
              style: const TextStyle(
                fontSize: 14,
                color: NightTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            
            // Option 1: End now
            FilledButton.icon(
              onPressed: () => Navigator.pop(ctx, _SleepingModalChoice.endNow),
              icon: const Icon(Icons.stop_circle_outlined),
              label: Text(l10n.endSleepNow),
              style: FilledButton.styleFrom(
                backgroundColor: NightTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 12),
            
            // Option 2: Register past sleep
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(ctx, _SleepingModalChoice.registerPastSleep),
              icon: const Icon(Icons.history),
              label: Text(l10n.registerPastCompleteSleep),
              style: OutlinedButton.styleFrom(
                foregroundColor: NightTheme.textPrimary,
                side: BorderSide(color: NightTheme.textSecondary.withValues(alpha: 0.3)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 12),
            
            // Option 3: Cancel
            TextButton(
              onPressed: () => Navigator.pop(ctx, _SleepingModalChoice.cancel),
              child: Text(
                l10n.commonCancel,
                style: TextStyle(color: NightTheme.textSecondary),
              ),
            ),
            
            // Bottom padding for safe area
            SizedBox(height: MediaQuery.of(ctx).padding.bottom),
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
        _showSuccessSnackBar(context.l10n.sleepEnded);
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

  /// Shows modal when overlap is detected with existing sessions
  /// Returns true if user chooses to replace, false/null otherwise
  Future<bool?> _showOverlapModal(List<SleepSession> overlappingSessions, String message) async {
    final l10n = context.l10n;
    final sessionsStr = overlappingSessions.map((s) {
      final start = s.startEvent.timestamp.toLocal();
      final startStr = '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
      if (s.endEvent != null) {
        final end = s.endEvent!.timestamp.toLocal();
        final endStr = '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';
        return '$startStr - $endStr';
      }
      return l10n.ongoingSince(startStr);
    }).join('\n');

    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: NightTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
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
            
            // Warning icon and title
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange.shade400, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.overlapTitle,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: NightTheme.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Sessions info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: NightTheme.backgroundBase.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                sessionsStr,
                style: const TextStyle(
                  fontSize: 14,
                  color: NightTheme.textSecondary,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.overlapMessage,
              style: const TextStyle(
                fontSize: 14,
                color: NightTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            
            // Replace button
            FilledButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.swap_horiz),
              label: Text(l10n.overlapReplace),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.orange.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 12),
            
            // Cancel button
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                l10n.commonCancel,
                style: TextStyle(color: NightTheme.textSecondary),
              ),
            ),
            
            SizedBox(height: MediaQuery.of(ctx).padding.bottom),
          ],
        ),
      ),
    );
  }

  /// Overwrites overlapping sessions and creates a new SleepStart
  Future<void> _overwriteSessionsAndCreateStart({
    required List<SleepSession> overlappingSessions,
    required DateTime newStartTime,
  }) async {
    setState(() => _isActionLoading = true);
    try {
      await ref.read(sleepEventsNotifierProvider.notifier).overwriteAndCreateStart(
        overlappingSessions: overlappingSessions,
        newStartTime: newStartTime,
      );
      debugPrint('[HomeSleep] Overwrite and create start successful');
      
      if (mounted) {
        _showSuccessSnackBar(context.l10n.overlapReplaced);
      }
    } catch (e, stack) {
      debugPrint('[HomeSleep] Overwrite error: $e');
      debugPrint('[HomeSleep] Stack: $stack');
      if (mounted) {
        // FIX P5: Add retry to overwrite errors
        _showErrorSnackBar(
          context.l10n.errorOverwriting(e.toString()),
          onRetry: () => _overwriteSessionsAndCreateStart(
            overlappingSessions: overlappingSessions,
            newStartTime: newStartTime,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isActionLoading = false);
      }
    }
  }

  /// Overwrites overlapping sessions and creates a complete sleep session
  Future<void> _overwriteSessionsAndCreateSession({
    required List<SleepSession> overlappingSessions,
    required DateTime newStartTime,
    required DateTime newEndTime,
  }) async {
    setState(() => _isActionLoading = true);
    try {
      await ref.read(sleepEventsNotifierProvider.notifier).overwriteAndCreateSession(
        overlappingSessions: overlappingSessions,
        newStartTime: newStartTime,
        newEndTime: newEndTime,
      );
      debugPrint('[HomeSleep] Overwrite and create session successful');
      if (mounted) {
        _showSuccessSnackBar(context.l10n.overlapReplaced);
      }
    } catch (e, stack) {
      debugPrint('[HomeSleep] Overwrite session error: $e');
      debugPrint('[HomeSleep] Stack: $stack');
      if (mounted) {
        // FIX P5: Add retry to overwrite session errors
        _showErrorSnackBar(
          context.l10n.errorOverwriting(e.toString()),
          onRetry: () => _overwriteSessionsAndCreateSession(
            overlappingSessions: overlappingSessions,
            newStartTime: newStartTime,
            newEndTime: newEndTime,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isActionLoading = false);
      }
    }
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
    
    // Passo 2: Escolher dia (Hoje/Ontem/Outro dia) com regras anti-futuro
    final selectedDateTime = await _showSmartDayPicker(time);
    if (selectedDateTime == null) {
      debugPrint('[HomeSleep] Day picker cancelled');
      return;
    }
    if (!mounted) return;
    
    debugPrint('[HomeSleep] Selected DateTime: $selectedDateTime');
    
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

  /// Smart day picker that returns a DateTime (date + time)
  /// 
  /// Rules:
  /// - "Hoje" only shown if the time would NOT be in the future
  /// - "Ontem" always shown
  /// - "Outro dia…" opens a date picker
  Future<DateTime?> _showSmartDayPicker(TimeOfDay time) async {
    final l10n = context.l10n;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    
    // Check if "today" with this time would be in the future
    final todayWithTime = DateTime(today.year, today.month, today.day, time.hour, time.minute);
    final isTodayFuture = todayWithTime.isAfter(now);
    
    // Default: if time is future for today, default to yesterday
    final defaultIsYesterday = isTodayFuture || time.hour > now.hour + 2;
    
    final timeStr = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: NightTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
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
            
            Text(
              l10n.whatDay,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: NightTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.chosenTime(timeStr),
              style: const TextStyle(
                fontSize: 14,
                color: NightTheme.textSecondary,
              ),
            ),
            
            // Warning if today is not available
            if (isTodayFuture) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade900.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange.shade300, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.todayIsFuture(timeStr),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.orange.shade300,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            
            // Hoje (only if not future)
            if (!isTodayFuture)
              FilledButton(
                onPressed: () => Navigator.pop(ctx, 'today'),
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
                child: Text(l10n.dayToday),
              ),
            if (!isTodayFuture) const SizedBox(height: 12),
            
            // Ontem
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'yesterday'),
              style: FilledButton.styleFrom(
                backgroundColor: (defaultIsYesterday || isTodayFuture)
                    ? NightTheme.primary 
                    : NightTheme.surface,
                foregroundColor: (defaultIsYesterday || isTodayFuture)
                    ? Colors.white 
                    : NightTheme.textPrimary,
                side: (defaultIsYesterday || isTodayFuture)
                    ? null
                    : BorderSide(color: NightTheme.textSecondary.withValues(alpha: 0.3)),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(l10n.dayYesterday),
            ),
            const SizedBox(height: 12),
            
            // Outro dia
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(ctx, 'other'),
              icon: const Icon(Icons.calendar_today, size: 18),
              label: Text(l10n.otherDay),
              style: OutlinedButton.styleFrom(
                foregroundColor: NightTheme.textPrimary,
                side: BorderSide(color: NightTheme.textSecondary.withValues(alpha: 0.3)),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 12),
            
            // Cancelar
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: Text(
                l10n.commonCancel,
                style: TextStyle(color: NightTheme.textSecondary),
              ),
            ),
            
            SizedBox(height: MediaQuery.of(ctx).padding.bottom),
          ],
        ),
      ),
    );
    
    if (choice == null || !mounted) return null;
    
    DateTime selectedDate;
    
    switch (choice) {
      case 'today':
        selectedDate = today;
      case 'yesterday':
        selectedDate = yesterday;
      case 'other':
        // Show date picker (max = today)
        final picked = await showDatePicker(
          context: context,
          initialDate: yesterday,
          firstDate: DateTime.now().subtract(const Duration(days: 365)),
          lastDate: now,
          helpText: l10n.pickDay,
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.dark(
                  primary: NightTheme.primary,
                  onPrimary: NightTheme.backgroundTop,
                  surface: NightTheme.backgroundBase,
                  onSurface: NightTheme.textPrimary,
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked == null) return null;
        selectedDate = picked;
      default:
        return null;
    }
    
    // Combine date + time with DST validation
    final validated = LocalTimeUtils.buildValidatedLocalDateTime(
      dateLocal: selectedDate,
      time: time,
    );
    
    // DST gap detection: if the time was adjusted, show warning
    if (validated.isDstGap) {
      if (mounted) {
        await _showDstGapWarning(time);
      }
      return null;
    }
    
    final result = validated.local;
    
    // Final validation: never allow future
    if (result.isAfter(now)) {
      if (mounted) {
        _showErrorSnackBar(l10n.cannotRegisterFuture);
      }
      return null;
    }
    
    return result;
  }

  /// Shows a warning dialog when user selects a time that doesn't exist due to DST
  Future<void> _showDstGapWarning(TimeOfDay selectedTime) async {
    final l10n = context.l10n;
    final timeStr = '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';
    
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NightTheme.surface,
        icon: Icon(Icons.schedule, color: Colors.orange.shade400, size: 32),
        title: Text(
          l10n.dstInvalidTime,
          style: const TextStyle(color: NightTheme.textPrimary),
        ),
        content: Text(
          l10n.dstTimeNotExist(timeStr),
          style: const TextStyle(color: NightTheme.textSecondary),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonOk),
          ),
        ],
      ),
    );
  }

  /// Bottom sheet para perguntar intenção: ainda a dormir vs sono completo
  Future<String?> _showPastTimeIntentSheet(DateTime pastTime) async {
    final l10n = context.l10n;
    final timeStr = '${pastTime.hour.toString().padLeft(2, '0')}:${pastTime.minute.toString().padLeft(2, '0')}';
    final isYesterday = pastTime.day != DateTime.now().day;
    final dayLabel = isYesterday ? l10n.dayYesterday.toLowerCase() : l10n.dayToday.toLowerCase();
    
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: NightTheme.surface,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.whatToRegister,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: NightTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.startAtTime(dayLabel, timeStr),
              style: const TextStyle(
                fontSize: 14,
                color: NightTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            
            // Opção A: Ainda a dormir
            FilledButton.icon(
              onPressed: () => Navigator.pop(ctx, 'still_sleeping'),
              icon: const Icon(Icons.bedtime),
              label: Text(l10n.stillSleeping),
              style: FilledButton.styleFrom(
                backgroundColor: NightTheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 12),
            
            // Opção B: Sono completo
            FilledButton.icon(
              onPressed: () => Navigator.pop(ctx, 'complete'),
              icon: const Icon(Icons.check_circle),
              label: Text(l10n.registerCompleteSleep),
              style: FilledButton.styleFrom(
                backgroundColor: NightTheme.secondary,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 12),
            
            // Cancelar
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: Text(
                l10n.commonCancel,
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
    } on OverlapException catch (e) {
      debugPrint('[HomeSleep] CreateStartEvent overlap: ${e.overlappingSessions.length} sessions');
      if (mounted) {
        final shouldReplace = await _showOverlapModal(e.overlappingSessions, e.message);
        if (shouldReplace == true && mounted) {
          await _overwriteSessionsAndCreateStart(
            overlappingSessions: e.overlappingSessions,
            newStartTime: startTime,
          );
        }
      }
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

  /// Wizard para registar sono completo (4 passos: dia início + hora início + dia fim + hora fim)
  Future<void> _showCompleteSleepFlow(DateTime initialStart) async {
    debugPrint('[HomeSleep] Complete sleep flow started with: $initialStart');
    final now = DateTime.now();
    
    // === PASSO 1: Escolher dia do INÍCIO ===
    final startDate = await _showDatePickerForSleep(
      title: 'Quando começou o sono?',
      initialDate: initialStart,
      maxDate: now,
    );
    if (startDate == null || !mounted) {
      debugPrint('[HomeSleep] Start date cancelled');
      return;
    }
    
    // === PASSO 2: Escolher hora do INÍCIO ===
    final startTimeOfDay = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialStart),
      helpText: 'Hora de início do sono',
    );
    if (startTimeOfDay == null || !mounted) {
      debugPrint('[HomeSleep] Start time cancelled');
      return;
    }
    
    // Combine date + time with DST validation
    final startValidated = LocalTimeUtils.buildValidatedLocalDateTime(
      dateLocal: startDate,
      time: startTimeOfDay,
    );
    
    // DST gap detection
    if (startValidated.isDstGap) {
      if (mounted) {
        await _showDstGapWarning(startTimeOfDay);
      }
      return;
    }
    
    DateTime startTime = startValidated.local;
    
    // Validate start is not in future
    if (startTime.isAfter(now)) {
      _showErrorSnackBar(context.l10n.startCannotBeFuture);
      return;
    }
    debugPrint('[HomeSleep] Start: $startTime');
    
    // === PASSO 3: Escolher dia do FIM ===
    // Min date = start date, max date = today
    final endDate = await _showDatePickerForSleep(
      title: 'Quando acordou?',
      initialDate: startTime, // Default to same day
      minDate: startDate,
      maxDate: now,
    );
    if (endDate == null || !mounted) {
      debugPrint('[HomeSleep] End date cancelled');
      return;
    }
    
    // === PASSO 4: Escolher hora do FIM ===
    final defaultEndTime = startTime.add(const Duration(hours: 2));
    final endTimeOfDay = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(defaultEndTime),
      helpText: 'Hora de fim do sono',
    );
    if (endTimeOfDay == null || !mounted) {
      debugPrint('[HomeSleep] End time cancelled');
      return;
    }
    
    // Combine date + time with DST validation
    final endValidated = LocalTimeUtils.buildValidatedLocalDateTime(
      dateLocal: endDate,
      time: endTimeOfDay,
    );
    
    // DST gap detection
    if (endValidated.isDstGap) {
      if (mounted) {
        await _showDstGapWarning(endTimeOfDay);
      }
      return;
    }
    
    DateTime endTime = endValidated.local;
    debugPrint('[HomeSleep] End (initial): $endTime');
    
    // === VALIDAÇÕES ===
    
    // Se mesmo dia e end <= start, perguntar sobre meia-noite
    final sameDay = startDate.year == endDate.year &&
                    startDate.month == endDate.month &&
                    startDate.day == endDate.day;
    
    if (sameDay && !endTime.isAfter(startTime)) {
      debugPrint('[HomeSleep] Same day, end <= start, showing midnight dialog');
      final crossMidnight = await _showCrossMidnightDialog(startTime, endTime);
      if (crossMidnight == null || !mounted) {
        return;
      }
      if (crossMidnight) {
        endTime = endTime.add(const Duration(days: 1));
        debugPrint('[HomeSleep] Adjusted for midnight: $endTime');
      } else {
        return;
      }
    }
    
    // Validar end > start
    if (!endTime.isAfter(startTime)) {
      _showErrorSnackBar(context.l10n.editSleepEndAfterStart);
      return;
    }
    
    // Validar end não está no futuro
    if (endTime.isAfter(now)) {
      debugPrint('[HomeSleep] End is in future');
      final adjusted = await _showFutureEndDialog(endTime);
      if (adjusted == null || !mounted) {
        return;
      }
      endTime = adjusted;
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
    } on OverlapException catch (e) {
      debugPrint('[HomeSleep] Session overlap: ${e.overlappingSessions.length} sessions');
      if (mounted) {
        final shouldReplace = await _showOverlapModal(e.overlappingSessions, e.message);
        if (shouldReplace == true && mounted) {
          await _overwriteSessionsAndCreateSession(
            overlappingSessions: e.overlappingSessions,
            newStartTime: startTime,
            newEndTime: endTime,
          );
        }
      }
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

  /// Date picker styled for sleep registration
  /// 
  /// [title] - Title shown in the picker
  /// [initialDate] - Initial date to show
  /// [minDate] - Minimum selectable date (defaults to 1 year ago)
  /// [maxDate] - Maximum selectable date (defaults to now)
  Future<DateTime?> _showDatePickerForSleep({
    required String title,
    required DateTime initialDate,
    DateTime? minDate,
    DateTime? maxDate,
  }) async {
    final now = DateTime.now();
    final effectiveMinDate = minDate ?? now.subtract(const Duration(days: 365));
    final effectiveMaxDate = maxDate ?? now;
    
    // Ensure initialDate is within bounds
    DateTime effectiveInitial = initialDate;
    if (effectiveInitial.isBefore(effectiveMinDate)) {
      effectiveInitial = effectiveMinDate;
    }
    if (effectiveInitial.isAfter(effectiveMaxDate)) {
      effectiveInitial = effectiveMaxDate;
    }
    
    return showDatePicker(
      context: context,
      initialDate: effectiveInitial,
      firstDate: effectiveMinDate,
      lastDate: effectiveMaxDate,
      helpText: title,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: NightTheme.primary,
              onPrimary: NightTheme.backgroundTop,
              surface: NightTheme.backgroundBase,
              onSurface: NightTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
  }

  /// Diálogo para confirmar que o sono atravessou meia-noite
  Future<bool?> _showCrossMidnightDialog(DateTime start, DateTime end) async {
    final l10n = context.l10n;
    final startStr = '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
    final endStr = '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';
    
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NightTheme.surface,
        title: Text(
          l10n.crossedMidnight,
          style: const TextStyle(color: NightTheme.textPrimary),
        ),
        content: Text(
          l10n.crossedMidnightQuestion(startStr, endStr),
          style: const TextStyle(color: NightTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: Text(l10n.commonCancel, style: TextStyle(color: NightTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.noCorrect),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.yes),
          ),
        ],
      ),
    );
  }

  /// Diálogo para quando hora de fim está no futuro
  Future<DateTime?> _showFutureEndDialog(DateTime futureEnd) async {
    final l10n = context.l10n;
    return showDialog<DateTime>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NightTheme.surface,
        title: Text(
          l10n.endInFuture,
          style: const TextStyle(color: NightTheme.textPrimary),
        ),
        content: Text(
          l10n.endCannotBeFuture,
          style: const TextStyle(color: NightTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: Text(l10n.commonCancel, style: TextStyle(color: NightTheme.textSecondary)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, DateTime.now()),
            child: Text(l10n.useNow),
          ),
        ],
      ),
    );
  }

  void _showSyncDetails() {
    final activeBaby = ref.read(activeBabyProvider);
    if (activeBaby == null) return;
    final l10n = context.l10n;
    
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.syncTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await ref.read(syncProvider.notifier).syncNowForBaby(activeBaby.id);
                  await _ensureCaregiverContext();
                },
                child: Text(l10n.syncNow),
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
                label: context.l10n.commonRetry,
                textColor: Colors.white,
                onPressed: onRetry,
              )
            : null,
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
    final l10n = context.l10n;
    final color = isSleeping ? NightTheme.secondary : NightTheme.primary;
    final icon = isSleeping ? Icons.wb_sunny : Icons.bedtime;
    final label = isSleeping ? l10n.homeWakeUp : l10n.homeSleepNow;
    
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

// Note: _DuplicateConflictSheet removed - conflicts are now resolved automatically
