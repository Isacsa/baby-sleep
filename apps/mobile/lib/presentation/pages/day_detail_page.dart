import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:temp_flutter/application/providers/sleep_events_provider.dart';
import 'package:temp_flutter/core/l10n/l10n.dart';
import 'package:temp_flutter/core/utils/local_time_utils.dart';
import 'package:temp_flutter/domain/value_objects/sleep_session.dart';
import 'package:temp_flutter/presentation/theme/night_theme.dart';
import 'package:temp_flutter/presentation/widgets/starry_background.dart';
import 'package:temp_flutter/presentation/widgets/day_summary_card.dart';

/// DayDetailPage - Página de detalhe do dia
/// 
/// Mostra:
/// - Header com data
/// - DaySummaryCard (total + sestas)
/// - Lista de sessões do dia
class DayDetailPage extends ConsumerStatefulWidget {
  const DayDetailPage({super.key});

  @override
  ConsumerState<DayDetailPage> createState() => _DayDetailPageState();
}

class _DayDetailPageState extends ConsumerState<DayDetailPage> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(sleepEventsNotifierProvider);
    final events = eventsAsync.value ?? [];
    
    // Derive ALL sessions from timeline (not just events from this day)
    final allSessions = SleepSession.fromEventList(events);
    
    // Calculate day boundaries using LocalTimeUtils (half-open interval)
    final dayRange = LocalTimeUtils.localDayRange(_selectedDate);
    final dayStartLocal = dayRange.startLocal;
    final dayEndExclusiveLocal = dayRange.endExclusiveLocal;
    final nowUtc = DateTime.now().toUtc();
    final isToday = LocalTimeUtils.isSameLocalDay(DateTime.now(), _selectedDate);
    
    // Filter sessions that OVERLAP with the selected day
    // A session overlaps if: sessionStart < dayEndExclusive AND sessionEnd > dayStart
    final sessions = allSessions.where((session) {
      final sessionStartUtc = session.startEvent.timestamp;
      // For open sessions: use "now" if today, otherwise use day end
      final sessionEndUtc = session.endEvent?.timestamp 
          ?? (isToday ? nowUtc : dayEndExclusiveLocal.toUtc());
      
      return LocalTimeUtils.sessionOverlapsDay(
        sessionStartUtc: sessionStartUtc,
        sessionEndUtc: sessionEndUtc,
        dayStartLocal: dayStartLocal,
        dayEndExclusiveLocal: dayEndExclusiveLocal,
      );
    }).toList();
    
    // Calculate totals with CLIPPED duration (only count time within the day)
    Duration totalSleep = Duration.zero;
    int napCount = 0;
    
    for (final session in sessions) {
      final sessionStartUtc = session.startEvent.timestamp;
      // For open sessions: use "now" if today, otherwise use day end exclusive
      final sessionEndUtc = session.endEvent?.timestamp 
          ?? (isToday ? nowUtc : dayEndExclusiveLocal.toUtc());
      
      // Clip to day boundaries using helper
      final clippedDuration = LocalTimeUtils.clipDurationToLocalDay(
        sessionStartUtc: sessionStartUtc,
        sessionEndUtc: sessionEndUtc,
        dayStartLocal: dayStartLocal,
        dayEndExclusiveLocal: dayEndExclusiveLocal,
      );
      
      if (clippedDuration > Duration.zero) {
        totalSleep += clippedDuration;
        
        // Count as nap if clipped duration < 3 hours
        if (clippedDuration.inHours < 3) {
          napCount++;
        }
      }
    }

    return StarryScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: GestureDetector(
          onTap: _showDatePicker,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_formatDateHeader(_selectedDate)),
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down, size: 20),
            ],
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: eventsAsync.isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Summary card
                    DaySummaryCard(
                      totalSleep: totalSleep,
                      napCount: napCount,
                      sessionCount: sessions.length,
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Sessions header
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Sessões de sono',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: NightTheme.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          '${sessions.length} registos',
                          style: const TextStyle(
                            fontSize: 13,
                            color: NightTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Sessions list
                    if (sessions.isEmpty)
                      _buildEmptyState()
                    else
                      ...sessions.reversed.map((session) => _SessionTile(
                        session: session,
                        selectedDate: _selectedDate,
                        onEdit: session.isComplete ? () => _showEditSession(session) : null,
                        onDelete: session.isComplete ? () => _confirmDeleteSession(session) : null,
                      )),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.bedtime_outlined,
              size: 48,
              color: NightTheme.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'Ainda sem registos hoje',
              style: TextStyle(
                fontSize: 16,
                color: NightTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Os registos de sono aparecerão aqui',
              style: TextStyle(
                fontSize: 13,
                color: NightTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateHeader(DateTime date) {
    final todayRange = LocalTimeUtils.todayLocalRange();
    final yesterdayRange = LocalTimeUtils.yesterdayLocalRange();
    final selectedRange = LocalTimeUtils.localDayRange(date);
    
    if (selectedRange.key == todayRange.key) {
      return 'Hoje, ${date.day} ${_monthName(date.month)}';
    } else if (selectedRange.key == yesterdayRange.key) {
      return 'Ontem, ${date.day} ${_monthName(date.month)}';
    } else {
      return '${date.day} ${_monthName(date.month)}';
    }
  }

  String _monthName(int month) {
    const months = [
      'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
      'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'
    ];
    return months[month - 1];
  }

  // Note: _isSameDay replaced by LocalTimeUtils.isSameLocalDay

  Future<void> _showDatePicker() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
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
    
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  /// Shows confirmation dialog for deleting a session
  Future<void> _confirmDeleteSession(SleepSession session) async {
    final startLocal = session.startEvent.timestamp.toLocal();
    final endLocal = session.endEvent!.timestamp.toLocal();
    final startStr = '${startLocal.hour.toString().padLeft(2, '0')}:${startLocal.minute.toString().padLeft(2, '0')}';
    final endStr = '${endLocal.hour.toString().padLeft(2, '0')}:${endLocal.minute.toString().padLeft(2, '0')}';
    
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NightTheme.surface,
        title: Text(
          l10n.deleteSleepTitle,
          style: const TextStyle(color: NightTheme.textPrimary),
        ),
        content: Text(
          l10n.deleteSleepConfirm(startStr, endStr),
          style: const TextStyle(color: NightTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    
    if (confirmed == true && mounted) {
      try {
        await ref.read(sleepEventsNotifierProvider.notifier).deleteSleepSession(session: session);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.deleteSleepSuccess),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } on SleepEventException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.errorWithMessage(e.message)),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  /// Shows editor bottom sheet for editing a session
  Future<void> _showEditSession(SleepSession session) async {
    final result = await showModalBottomSheet<_EditSessionResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EditSessionSheet(session: session),
    );
    
    if (result != null && mounted) {
      await _executeEdit(session, result.newStartTime, result.newEndTime, const []);
    }
  }

  /// Executes the edit operation with overlap handling
  Future<void> _executeEdit(
    SleepSession session,
    DateTime newStartTime,
    DateTime newEndTime,
    List<SleepSession> extraOverwrite,
  ) async {
    final l10n = context.l10n;
    try {
      await ref.read(sleepEventsNotifierProvider.notifier).editSleepSession(
        original: session,
        newStartTime: newStartTime,
        newEndTime: newEndTime,
        extraSessionsToOverwrite: extraOverwrite,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.editSleepSuccess),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on OverlapException catch (e) {
      // Show overlap confirmation dialog
      if (mounted) {
        final overwrite = await _showOverlapConfirmation(e.overlappingSessions);
        if (overwrite == true) {
          await _executeEdit(session, newStartTime, newEndTime, e.overlappingSessions);
        }
      }
    } on SleepEventException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorWithMessage(e.message)),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Shows confirmation dialog for overlapping sessions
  Future<bool?> _showOverlapConfirmation(List<SleepSession> overlapping) {
    final l10n = context.l10n;
    final sessionsStr = overlapping.map((s) {
      final start = s.startEvent.timestamp.toLocal();
      final end = s.endEvent?.timestamp.toLocal();
      final startStr = '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
      if (end != null) {
        final endStr = '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';
        return '$startStr - $endStr';
      }
      return l10n.sinceSomething(startStr);
    }).join(', ');
    
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NightTheme.surface,
        title: Text(
          l10n.overlapOtherSleep,
          style: const TextStyle(color: NightTheme.textPrimary),
        ),
        content: Text(
          l10n.overlapNewPeriodMessage(sessionsStr),
          style: const TextStyle(color: NightTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: Text(l10n.overlapReplace),
          ),
        ],
      ),
    );
  }
}

/// Result from edit session sheet
class _EditSessionResult {
  final DateTime newStartTime;
  final DateTime newEndTime;
  
  const _EditSessionResult({
    required this.newStartTime,
    required this.newEndTime,
  });
}

/// Bottom sheet for editing a session's start and end times
class _EditSessionSheet extends StatefulWidget {
  final SleepSession session;
  
  const _EditSessionSheet({required this.session});

  @override
  State<_EditSessionSheet> createState() => _EditSessionSheetState();
}

class _EditSessionSheetState extends State<_EditSessionSheet> {
  late DateTime _startDate;
  late TimeOfDay _startTime;
  late DateTime _endDate;
  late TimeOfDay _endTime;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final startLocal = widget.session.startEvent.timestamp.toLocal();
    final endLocal = widget.session.endEvent!.timestamp.toLocal();
    
    _startDate = DateTime(startLocal.year, startLocal.month, startLocal.day);
    _startTime = TimeOfDay(hour: startLocal.hour, minute: startLocal.minute);
    _endDate = DateTime(endLocal.year, endLocal.month, endLocal.day);
    _endTime = TimeOfDay(hour: endLocal.hour, minute: endLocal.minute);
  }

  void _validate() {
    // Check for DST gaps first
    final startValidated = LocalTimeUtils.buildValidatedLocalDateTime(
      dateLocal: _startDate,
      time: _startTime,
    );
    final endValidated = LocalTimeUtils.buildValidatedLocalDateTime(
      dateLocal: _endDate,
      time: _endTime,
    );
    
    if (startValidated.isDstGap) {
      setState(() => _errorMessage = 'Hora de início inválida (mudança de hora DST)');
      return;
    }
    if (endValidated.isDstGap) {
      setState(() => _errorMessage = 'Hora de fim inválida (mudança de hora DST)');
      return;
    }
    
    final start = startValidated.local;
    final end = endValidated.local;
    
    if (!end.isAfter(start)) {
      setState(() => _errorMessage = 'A hora de fim deve ser depois do início');
    } else {
      setState(() => _errorMessage = null);
    }
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: NightTheme.primary,
            surface: NightTheme.backgroundBase,
            onSurface: NightTheme.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _startDate = picked);
      _validate();
    }
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: NightTheme.primary,
            surface: NightTheme.backgroundBase,
            onSurface: NightTheme.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _startTime = picked);
      _validate();
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 1)), // Allow tomorrow for cross-midnight
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: NightTheme.primary,
            surface: NightTheme.backgroundBase,
            onSurface: NightTheme.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _endDate = picked);
      _validate();
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: NightTheme.primary,
            surface: NightTheme.backgroundBase,
            onSurface: NightTheme.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _endTime = picked);
      _validate();
    }
  }

  void _submit() {
    // DST validation
    final startValidated = LocalTimeUtils.buildValidatedLocalDateTime(
      dateLocal: _startDate,
      time: _startTime,
    );
    final endValidated = LocalTimeUtils.buildValidatedLocalDateTime(
      dateLocal: _endDate,
      time: _endTime,
    );
    
    if (startValidated.isDstGap) {
      setState(() => _errorMessage = 'Hora de início inválida (mudança de hora DST)');
      return;
    }
    if (endValidated.isDstGap) {
      setState(() => _errorMessage = 'Hora de fim inválida (mudança de hora DST)');
      return;
    }
    
    final start = startValidated.local;
    final end = endValidated.local;
    
    if (!end.isAfter(start)) {
      setState(() => _errorMessage = 'A hora de fim deve ser depois do início');
      return;
    }
    
    Navigator.of(context).pop(_EditSessionResult(
      newStartTime: start,
      newEndTime: end,
    ));
  }

  String _formatDate(DateTime dt) {
    final todayRange = LocalTimeUtils.todayLocalRange();
    final yesterdayRange = LocalTimeUtils.yesterdayLocalRange();
    final dateKey = LocalTimeUtils.dateKey(dt);
    
    if (dateKey == todayRange.key) return 'Hoje';
    if (dateKey == yesterdayRange.key) return 'Ontem';
    return '${dt.day}/${dt.month}';
  }

  String _formatTime(TimeOfDay t) {
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: NightTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
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
              const Text(
                'Editar sono',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: NightTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 24),
              
              // Start picker
              const Text(
                'Início',
                style: TextStyle(
                  fontSize: 13,
                  color: NightTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _DateTimeButton(
                      icon: Icons.calendar_today,
                      label: _formatDate(_startDate),
                      onTap: _pickStartDate,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DateTimeButton(
                      icon: Icons.access_time,
                      label: _formatTime(_startTime),
                      onTap: _pickStartTime,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // End picker
              const Text(
                'Fim',
                style: TextStyle(
                  fontSize: 13,
                  color: NightTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _DateTimeButton(
                      icon: Icons.calendar_today,
                      label: _formatDate(_endDate),
                      onTap: _pickEndDate,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DateTimeButton(
                      icon: Icons.access_time,
                      label: _formatTime(_endTime),
                      onTap: _pickEndTime,
                    ),
                  ),
                ],
              ),
              
              // Error message
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.red,
                  ),
                ),
              ],
              
              const SizedBox(height: 24),
              
              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: NightTheme.textSecondary,
                        side: BorderSide(color: NightTheme.textSecondary.withValues(alpha: 0.3)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(context.l10n.commonCancel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _errorMessage == null ? _submit : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: NightTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(context.l10n.commonSave),
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
}

/// Simple date/time picker button
class _DateTimeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DateTimeButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: NightTheme.backgroundBase,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: NightTheme.textSecondary),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: NightTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Session tile with edit/delete actions (only for complete sessions)
class _SessionTile extends StatelessWidget {
  final SleepSession session;
  final DateTime selectedDate;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _SessionTile({
    required this.session,
    required this.selectedDate,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final start = session.startEvent.timestamp.toLocal();
    final end = session.endEvent?.timestamp.toLocal();
    
    // Check if session crosses day boundaries
    final selectedDay = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final startDay = DateTime(start.year, start.month, start.day);
    final endDay = end != null ? DateTime(end.year, end.month, end.day) : null;
    
    final startsBeforeToday = startDay.isBefore(selectedDay);
    final endsAfterToday = endDay != null && endDay.isAfter(selectedDay);
    
    String timeRange;
    String durationText;
    String? crossMidnightNote;
    
    if (end != null) {
      // Build time range with cross-midnight indicators
      final startStr = startsBeforeToday ? '(ontem) ${_formatTime(start)}' : _formatTime(start);
      final endStr = endsAfterToday ? '${_formatTime(end)} (amanhã)' : _formatTime(end);
      timeRange = '$startStr - $endStr';
      
      final duration = session.duration!;
      final hours = duration.inHours;
      final minutes = duration.inMinutes % 60;
      durationText = hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';
      
      if (startsBeforeToday || endsAfterToday) {
        crossMidnightNote = 'Atravessa meia-noite';
      }
    } else {
      timeRange = '${_formatTime(start)} - em curso';
      durationText = 'A dormir...';
      if (startsBeforeToday) {
        crossMidnightNote = 'Começou ontem';
      }
    }

    final isNap = session.duration != null && session.duration!.inHours < 3;
    final icon = session.isComplete
        ? (isNap ? Icons.brightness_5 : Icons.nights_stay)
        : Icons.bedtime;
    final color = session.isComplete
        ? (isNap ? NightTheme.accent : NightTheme.secondary)
        : NightTheme.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NightTheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Time range with ellipsis for overflow (FIX overflow)
                Text(
                  timeRange,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: NightTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                // Use Wrap instead of Row to prevent overflow (FIX overflow)
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      isNap ? 'Sesta' : 'Sono noturno',
                      style: const TextStyle(
                        fontSize: 12,
                        color: NightTheme.textSecondary,
                      ),
                    ),
                    if (crossMidnightNote != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: NightTheme.secondary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          crossMidnightNote,
                          style: const TextStyle(
                            fontSize: 10,
                            color: NightTheme.secondary,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          // Duration badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              durationText,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
          // Actions menu (only for complete sessions)
          if (session.isComplete) ...[
            const SizedBox(width: 4),
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert,
                color: NightTheme.textSecondary.withValues(alpha: 0.6),
                size: 20,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              splashRadius: 20,
              onSelected: (value) {
                if (value == 'edit') {
                  onEdit?.call();
                } else if (value == 'delete') {
                  onDelete?.call();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      const Icon(Icons.edit, size: 18),
                      const SizedBox(width: 8),
                      Text(context.l10n.commonEdit),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      const Icon(Icons.delete, size: 18, color: Colors.red),
                      const SizedBox(width: 8),
                      Text(context.l10n.commonDelete, style: const TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
