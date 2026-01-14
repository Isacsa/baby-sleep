import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:temp_flutter/application/providers/sleep_events_provider.dart';
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
    
    // Calculate day boundaries (local time)
    final selectedLocal = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final dayStartLocal = selectedLocal;
    final dayEndLocal = selectedLocal.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));
    final now = DateTime.now();
    final isToday = _isSameDay(now, _selectedDate);
    
    // Filter sessions that OVERLAP with the selected day
    // A session overlaps if: sessionStart <= dayEnd AND sessionEnd >= dayStart
    final sessions = allSessions.where((session) {
      final sessionStartLocal = session.startEvent.timestamp.toLocal();
      // For open sessions: use "now" if today, otherwise use day end
      final sessionEndLocal = session.endEvent?.timestamp.toLocal() 
          ?? (isToday ? now : dayEndLocal);
      
      return !sessionStartLocal.isAfter(dayEndLocal) && !sessionEndLocal.isBefore(dayStartLocal);
    }).toList();
    
    // Calculate totals with CLIPPED duration (only count time within the day)
    Duration totalSleep = Duration.zero;
    int napCount = 0;
    
    for (final session in sessions) {
      final sessionStartLocal = session.startEvent.timestamp.toLocal();
      final sessionEndLocal = session.endEvent?.timestamp.toLocal() 
          ?? (isToday ? now : dayEndLocal);
      
      // Clip to day boundaries
      final clipStart = sessionStartLocal.isBefore(dayStartLocal) ? dayStartLocal : sessionStartLocal;
      final clipEnd = sessionEndLocal.isAfter(dayEndLocal) ? dayEndLocal : sessionEndLocal;
      
      if (clipEnd.isAfter(clipStart)) {
        final clippedDuration = clipEnd.difference(clipStart);
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
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final selected = DateTime(date.year, date.month, date.day);
    
    if (selected == today) {
      return 'Hoje, ${date.day} ${_monthName(date.month)}';
    } else if (selected == yesterday) {
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

  /// Compara se dois DateTimes são do mesmo dia LOCAL
  /// 
  /// IMPORTANTE: Converte para local antes de comparar, porque os eventos
  /// estão guardados em UTC mas queremos filtrar pelo dia local do utilizador.
  bool _isSameDay(DateTime eventTimestamp, DateTime selectedDate) {
    // Converter timestamp do evento (UTC) para local
    final eventLocal = eventTimestamp.toLocal();
    final selectedLocal = selectedDate.toLocal();
    
    return eventLocal.year == selectedLocal.year && 
           eventLocal.month == selectedLocal.month && 
           eventLocal.day == selectedLocal.day;
  }

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
}

class _SessionTile extends StatelessWidget {
  final SleepSession session;
  final DateTime selectedDate;

  const _SessionTile({required this.session, required this.selectedDate});

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
                Text(
                  timeRange,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: NightTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      isNap ? 'Sesta' : 'Sono noturno',
                      style: const TextStyle(
                        fontSize: 12,
                        color: NightTheme.textSecondary,
                      ),
                    ),
                    if (crossMidnightNote != null) ...[
                      const SizedBox(width: 8),
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
                  ],
                ),
              ],
            ),
          ),
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
