import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:temp_flutter/domain/stats/daily_sleep_aggregate.dart';
import 'package:temp_flutter/domain/stats/period_kpis.dart';
import 'package:temp_flutter/domain/value_objects/sleep_session.dart';

/// Export type for CSV
enum CsvExportType {
  sessions,
  aggregates,
  both,
}

/// Service for exporting stats data to CSV and PDF.
///
/// All export operations are performed locally (offline-first).
class StatsExportService {
  /// Generates and shares a CSV file with sleep sessions.
  ///
  /// [sessions]: List of sessions to export
  /// [babyName]: Optional baby name for file naming
  /// [startDate]: Period start date
  /// [endDate]: Period end date
  static Future<void> exportSessionsCsv({
    required List<SleepSession> sessions,
    String? babyName,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final csv = _generateSessionsCsv(sessions);
    await _shareAsCsv(
      content: csv,
      fileName: _generateFileName(
        type: 'sessions',
        babyName: babyName,
        startDate: startDate,
        endDate: endDate,
      ),
    );
  }

  /// Generates and shares a CSV file with daily aggregates.
  ///
  /// [aggregates]: List of daily aggregates to export
  /// [babyName]: Optional baby name for file naming
  static Future<void> exportAggregatesCsv({
    required List<DailySleepAggregate> aggregates,
    String? babyName,
  }) async {
    if (aggregates.isEmpty) return;

    final csv = _generateAggregatesCsv(aggregates);
    await _shareAsCsv(
      content: csv,
      fileName: _generateFileName(
        type: 'aggregates',
        babyName: babyName,
        startDate: aggregates.first.dateLocal,
        endDate: aggregates.last.dateLocal,
      ),
    );
  }

  /// Generates and shares both sessions and aggregates CSVs.
  static Future<void> exportBothCsv({
    required List<SleepSession> sessions,
    required List<DailySleepAggregate> aggregates,
    String? babyName,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final sessionsCsv = _generateSessionsCsv(sessions);
    final aggregatesCsv = _generateAggregatesCsv(aggregates);

    final dir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final babySlug = babyName?.replaceAll(' ', '_').toLowerCase() ?? 'export';

    final sessionsFile = File('${dir.path}/${babySlug}_sessions_$timestamp.csv');
    final aggregatesFile =
        File('${dir.path}/${babySlug}_aggregates_$timestamp.csv');

    await sessionsFile.writeAsString(sessionsCsv);
    await aggregatesFile.writeAsString(aggregatesCsv);

    await Share.shareXFiles(
      [XFile(sessionsFile.path), XFile(aggregatesFile.path)],
      subject: 'Sleep Data Export',
    );
  }

  // ============================================================
  // CSV GENERATION
  // ============================================================

  static String _generateSessionsCsv(List<SleepSession> sessions) {
    final buffer = StringBuffer();

    // Header
    buffer.writeln(
      'start_utc,end_utc,start_local,end_local,duration_minutes,classification,created_at',
    );

    // Data rows
    for (final session in sessions) {
      final startUtc = session.startEvent.timestamp.toIso8601String();
      final endUtc = session.endEvent?.timestamp.toIso8601String() ?? '';
      final startLocal =
          session.startEvent.timestamp.toLocal().toIso8601String();
      final endLocal =
          session.endEvent?.timestamp.toLocal().toIso8601String() ?? '';
      final durationMinutes = session.duration?.inMinutes ?? 0;
      final classification = _classifySession(session);
      final createdAt = session.startEvent.createdAt.toIso8601String();

      buffer.writeln(
        '$startUtc,$endUtc,$startLocal,$endLocal,$durationMinutes,$classification,$createdAt',
      );
    }

    return buffer.toString();
  }

  static String _generateAggregatesCsv(List<DailySleepAggregate> aggregates) {
    final buffer = StringBuffer();

    // Header
    buffer.writeln(
      'date_local,total_minutes,night_minutes,nap_minutes,longest_block_minutes,night_episodes_count,bedtime_start_local,has_ongoing,session_count',
    );

    // Data rows
    for (final agg in aggregates) {
      final dateLocal = _formatDateOnly(agg.dateLocal);
      final bedtimeLocal = agg.bedtimeStartLocal != null
          ? _formatTimeOnly(agg.bedtimeStartLocal!)
          : '';

      buffer.writeln(
        '$dateLocal,${agg.totalMinutes},${agg.nightMinutes},${agg.napMinutes},${agg.longestBlockMinutes},${agg.nightEpisodesCount},$bedtimeLocal,${agg.hasOngoingSleep},${agg.sessions.length}',
      );
    }

    return buffer.toString();
  }

  // ============================================================
  // HELPERS
  // ============================================================

  static String _classifySession(SleepSession session) {
    if (!session.isComplete) return 'ongoing';

    final duration = session.duration!;
    if (duration.inHours < 3) return 'nap';
    return 'night';
  }

  static String _formatDateOnly(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  static String _formatTimeOnly(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  static String _generateFileName({
    required String type,
    String? babyName,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final babySlug = babyName?.replaceAll(' ', '_').toLowerCase() ?? 'sleep';
    final startStr = _formatDateOnly(startDate);
    final endStr = _formatDateOnly(endDate);
    return '${babySlug}_${type}_${startStr}_$endStr.csv';
  }

  static Future<void> _shareAsCsv({
    required String content,
    required String fileName,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(content);

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Sleep Data Export',
    );
  }

  // ============================================================
  // PDF EXPORT
  // ============================================================

  /// Generates and shares a PDF report with KPIs, charts summary, and timeline.
  ///
  /// Designed to be pediatrician-friendly with clear, factual information.
  static Future<void> exportPdf({
    required List<DailySleepAggregate> aggregates,
    required PeriodKPIs kpis,
    String? babyName,
    required DateTime startDate,
    required DateTime endDate,
    required String timezone,
    KPIComparison? comparison,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          _buildPdfHeader(babyName, startDate, endDate, timezone),
          pw.SizedBox(height: 20),
          _buildPdfKPIs(kpis, comparison),
          pw.SizedBox(height: 20),
          _buildPdfTimeline(aggregates),
          pw.SizedBox(height: 30),
          _buildPdfFooter(),
        ],
      ),
    );

    final bytes = await pdf.save();
    await _shareAsPdf(
      bytes: bytes,
      fileName: _generateFileName(
        type: 'report',
        babyName: babyName,
        startDate: startDate,
        endDate: endDate,
      ).replaceAll('.csv', '.pdf'),
    );
  }

  static pw.Widget _buildPdfHeader(
    String? babyName,
    DateTime startDate,
    DateTime endDate,
    String timezone,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Relatório de Sono',
          style: pw.TextStyle(
            fontSize: 24,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 8),
        if (babyName != null)
          pw.Text(
            'Bebé: $babyName',
            style: const pw.TextStyle(fontSize: 14),
          ),
        pw.Text(
          'Período: ${_formatDateOnly(startDate)} - ${_formatDateOnly(endDate)}',
          style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
        ),
        pw.Text(
          'Timezone: $timezone',
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
        ),
        pw.Text(
          'Gerado em: ${_formatDateOnly(DateTime.now())}',
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
        ),
        pw.Divider(),
      ],
    );
  }

  static pw.Widget _buildPdfKPIs(PeriodKPIs kpis, KPIComparison? comparison) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Resumo',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 12),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            _buildPdfKpiItem(
              'Mediana/dia',
              kpis.medianTotalFormatted,
              comparison?.deltaAvgFormatted,
            ),
            _buildPdfKpiItem(
              'Noite vs Sestas',
              '${(kpis.nightPercentage * 100).toStringAsFixed(0)}% / ${(kpis.napPercentage * 100).toStringAsFixed(0)}%',
              null,
            ),
            _buildPdfKpiItem(
              'Maior bloco',
              kpis.longestBlockFormatted,
              null,
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            _buildPdfKpiItem(
              'Fragmentação',
              '${kpis.avgNightEpisodes.toStringAsFixed(1)} ep/noite',
              null,
            ),
            if (kpis.hasBedtimeConsistency)
              _buildPdfKpiItem(
                'Consistência deitar',
                kpis.bedtimeConsistencyFormatted ?? '-',
                null,
              ),
            _buildPdfKpiItem(
              'Dias c/ dados',
              '${kpis.daysWithData}/${kpis.totalDays}',
              null,
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildPdfKpiItem(String label, String value, String? delta) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          if (delta != null)
            pw.Text(
              delta,
              style: pw.TextStyle(
                fontSize: 9,
                color: delta.startsWith('+')
                    ? PdfColors.green700
                    : delta.startsWith('-')
                        ? PdfColors.red700
                        : PdfColors.grey600,
              ),
            ),
        ],
      ),
    );
  }

  static pw.Widget _buildPdfTimeline(List<DailySleepAggregate> aggregates) {
    // Show most recent 14 days max
    final toShow = aggregates.reversed.take(14).toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Timeline (últimos ${toShow.length} dias)',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 12),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          columnWidths: {
            0: const pw.FlexColumnWidth(2),
            1: const pw.FlexColumnWidth(1.5),
            2: const pw.FlexColumnWidth(1.5),
            3: const pw.FlexColumnWidth(1.5),
            4: const pw.FlexColumnWidth(1),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey100),
              children: [
                _buildPdfTableCell('Data', isHeader: true),
                _buildPdfTableCell('Total', isHeader: true),
                _buildPdfTableCell('Noite', isHeader: true),
                _buildPdfTableCell('Sestas', isHeader: true),
                _buildPdfTableCell('Sessões', isHeader: true),
              ],
            ),
            ...toShow.map((agg) => pw.TableRow(
                  children: [
                    _buildPdfTableCell(_formatDateOnly(agg.dateLocal)),
                    _buildPdfTableCell(_formatDuration(agg.totalMinutes)),
                    _buildPdfTableCell(_formatDuration(agg.nightMinutes)),
                    _buildPdfTableCell(_formatDuration(agg.napMinutes)),
                    _buildPdfTableCell('${agg.sessions.length}'),
                  ],
                )),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildPdfTableCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 10 : 9,
          fontWeight: isHeader ? pw.FontWeight.bold : null,
        ),
      ),
    );
  }

  static pw.Widget _buildPdfFooter() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Divider(),
        pw.SizedBox(height: 8),
        pw.Text(
          'Nota: Este relatório é informativo e não substitui avaliação clínica.',
          style: const pw.TextStyle(
            fontSize: 9,
            color: PdfColors.grey600,
          ),
        ),
        pw.Text(
          'Dados exportados da aplicação Baby Sleep.',
          style: const pw.TextStyle(
            fontSize: 8,
            color: PdfColors.grey500,
          ),
        ),
      ],
    );
  }

  static String _formatDuration(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0) return '${h}h${m}m';
    return '${m}m';
  }

  static Future<void> _shareAsPdf({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Sleep Report',
    );
  }
}
