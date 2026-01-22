import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:temp_flutter/application/providers/sleep_events_provider.dart';
import 'package:temp_flutter/core/l10n/l10n.dart';
import 'package:temp_flutter/core/utils/local_time_utils.dart';
import 'package:temp_flutter/domain/value_objects/sleep_session.dart';
import 'package:temp_flutter/presentation/theme/night_theme.dart';

/// Reusable session editor bottom sheet.
///
/// Allows editing start and end times of a completed sleep session.
/// Handles overlap detection and user confirmation.
///
/// Usage:
/// ```dart
/// final result = await showSessionEditorSheet(
///   context: context,
///   ref: ref,
///   session: session,
/// );
/// if (result == true) {
///   // Session was edited successfully
/// }
/// ```
Future<bool?> showSessionEditorSheet({
  required BuildContext context,
  required WidgetRef ref,
  required SleepSession session,
}) async {
  if (!session.isComplete) {
    // Cannot edit incomplete sessions with this editor
    return null;
  }

  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _SessionEditorSheet(
      session: session,
      onSave: (newStart, newEnd) async {
        return _executeEdit(context, ref, session, newStart, newEnd, []);
      },
    ),
  );
}

/// Executes the edit operation with overlap handling
Future<bool> _executeEdit(
  BuildContext context,
  WidgetRef ref,
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

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.editSleepSuccess),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return true;
  } on OverlapException catch (e) {
    // Show overlap confirmation dialog
    if (context.mounted) {
      final overwrite = await _showOverlapConfirmation(context, e.overlappingSessions);
      if (overwrite == true && context.mounted) {
        return _executeEdit(
          context,
          ref,
          session,
          newStartTime,
          newEndTime,
          e.overlappingSessions,
        );
      }
    }
    return false;
  } on SleepEventException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.errorWithMessage(e.message)),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return false;
  }
}

/// Shows confirmation dialog for overlapping sessions
Future<bool?> _showOverlapConfirmation(
    BuildContext context, List<SleepSession> overlapping) {
  final l10n = context.l10n;
  final sessionsStr = overlapping.map((s) {
    final start = s.startEvent.timestamp.toLocal();
    final end = s.endEvent?.timestamp.toLocal();
    final startStr =
        '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
    if (end != null) {
      final endStr =
          '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';
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

/// Internal sheet widget
class _SessionEditorSheet extends StatefulWidget {
  final SleepSession session;
  final Future<bool> Function(DateTime newStart, DateTime newEnd) onSave;

  const _SessionEditorSheet({
    required this.session,
    required this.onSave,
  });

  @override
  State<_SessionEditorSheet> createState() => _SessionEditorSheetState();
}

class _SessionEditorSheetState extends State<_SessionEditorSheet> {
  late DateTime _startDate;
  late TimeOfDay _startTime;
  late DateTime _endDate;
  late TimeOfDay _endTime;
  String? _errorMessage;
  bool _isSaving = false;

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
      setState(
          () => _errorMessage = 'Hora de início inválida (mudança de hora DST)');
      return;
    }
    if (endValidated.isDstGap) {
      setState(
          () => _errorMessage = 'Hora de fim inválida (mudança de hora DST)');
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
      lastDate:
          DateTime.now().add(const Duration(days: 1)), // Allow tomorrow for cross-midnight
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

  Future<void> _submit() async {
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
      setState(
          () => _errorMessage = 'Hora de início inválida (mudança de hora DST)');
      return;
    }
    if (endValidated.isDstGap) {
      setState(
          () => _errorMessage = 'Hora de fim inválida (mudança de hora DST)');
      return;
    }

    final start = startValidated.local;
    final end = endValidated.local;

    if (!end.isAfter(start)) {
      setState(() => _errorMessage = 'A hora de fim deve ser depois do início');
      return;
    }

    setState(() => _isSaving = true);

    final success = await widget.onSave(start, end);

    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        Navigator.of(context).pop(true);
      }
    }
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
    final l10n = context.l10n;

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
              Text(
                l10n.editSleepTitle,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: NightTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 24),

              // Start picker
              Text(
                l10n.editSleepStart,
                style: const TextStyle(
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
              Text(
                l10n.editSleepEnd,
                style: const TextStyle(
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
                      onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: NightTheme.textSecondary,
                        side: BorderSide(
                            color: NightTheme.textSecondary.withValues(alpha: 0.3)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(l10n.commonCancel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _errorMessage == null && !_isSaving ? _submit : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: NightTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(l10n.commonSave),
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
