import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:temp_flutter/application/providers/active_baby_provider.dart';
import 'package:temp_flutter/application/providers/stats_aggregates_provider.dart';
import 'package:temp_flutter/application/providers/stats_data_quality_provider.dart';
import 'package:temp_flutter/application/providers/stats_filter_provider.dart';
import 'package:temp_flutter/application/providers/stats_period_provider.dart';
import 'package:temp_flutter/application/providers/stats_sessions_provider.dart';
import 'package:temp_flutter/core/l10n/l10n.dart';
import 'package:temp_flutter/core/utils/local_time_utils.dart';
import 'package:temp_flutter/domain/stats/stats.dart';
import 'package:temp_flutter/domain/value_objects/sleep_session.dart';
import 'package:temp_flutter/presentation/theme/night_theme.dart';
import 'package:temp_flutter/presentation/widgets/session_editor_sheet.dart';
import 'package:temp_flutter/data/services/stats_export_service.dart';

/// StatsPage V2 - Complete redesign following the wireframe spec.
///
/// Features:
/// - Period filter chips (Day/Week/14d/Month/Custom)
/// - Sleep type filter (All/Night/Naps)
/// - Compare toggle
/// - Data quality indicator
/// - KPI cards with comparison deltas
/// - Charts (total per day, night vs naps, bedtime consistency)
/// - Auditable timeline with edit access
/// - Export button
class StatsPageV2 extends ConsumerWidget {
  const StatsPageV2({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeBaby = ref.watch(activeBabyProvider);
    final filter = ref.watch(statsFilterProvider);
    final aggregatesAsync = ref.watch(statsDailyAggregatesProvider);
    final kpisAsync = ref.watch(statsKPIsProvider);
    final dataQualityAsync = ref.watch(statsDataQualityProvider);
    final periodRange = ref.watch(statsPeriodRangeProvider);
    final comparison = ref.watch(statsKPIComparisonProvider);

    if (activeBaby == null) {
      return Center(
        child: Text(
          context.l10n.selectBaby,
          style: const TextStyle(color: NightTheme.textSecondary),
        ),
      );
    }

    return SafeArea(
      child: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          // Header
          SliverToBoxAdapter(
            child: _Header(
              babyName: activeBaby.name,
              periodRange: periodRange,
              filter: filter,
              compareEnabled: filter.compareEnabled,
            ),
          ),
          // Sticky filter bar
          SliverPersistentHeader(
            pinned: true,
            delegate: _FilterBarDelegate(
              filter: filter,
              onPeriodChanged: (p) =>
                  ref.read(statsFilterProvider.notifier).setPeriod(p),
              onSleepTypeChanged: (t) =>
                  ref.read(statsFilterProvider.notifier).setSleepType(t),
              onCompareToggled: () =>
                  ref.read(statsFilterProvider.notifier).toggleCompare(),
              onExportTap: () => _showExportSheet(context, ref),
            ),
          ),
        ],
        body: aggregatesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, s) => Center(
            child: Text(
              context.l10n.errorGeneric,
              style: const TextStyle(color: NightTheme.textSecondary),
            ),
          ),
          data: (aggregates) {
            final kpis = kpisAsync.value ?? PeriodKPIs.empty();
            final dataQuality =
                dataQualityAsync.value ?? DataQualityAssessment.empty();
            final comparisonData = comparison.value;

            if (aggregates.isEmpty ||
                aggregates.every((a) => a.totalMinutes == 0)) {
              return _EmptyState(onTap: () {
                // Navigate to sleep tab
              });
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              children: [
                // Data quality indicator
                _DataQualityCard(
                  assessment: dataQuality,
                  onDetailsTap: () => _showDataQualityDetails(context, dataQuality),
                ),
                const SizedBox(height: 16),

                // KPIs
                _KPIsSection(
                  kpis: kpis,
                  comparison: comparisonData,
                ),
                const SizedBox(height: 20),

                // Charts
                _ChartsSection(aggregates: aggregates),
                const SizedBox(height: 20),

                // Timeline
                _TimelineSection(
                  aggregates: aggregates,
                  onSessionTap: (session, date) =>
                      _editSession(context, ref, session),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showExportSheet(BuildContext context, WidgetRef ref) {
    final activeBaby = ref.read(activeBabyProvider);
    final aggregates = ref.read(statsDailyAggregatesProvider).value ?? [];
    final sessions = ref.read(statsSessionsProvider).value ?? [];
    final periodRange = ref.read(statsPeriodRangeProvider);
    final kpis = ref.read(statsKPIsProvider).value ?? PeriodKPIs.empty();
    final comparison = ref.read(statsKPIComparisonProvider).value;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: NightTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ExportSheet(
        babyName: activeBaby?.name,
        sessions: sessions,
        aggregates: aggregates,
        periodRange: periodRange,
        kpis: kpis,
        comparison: comparison,
      ),
    );
  }

  void _showDataQualityDetails(
      BuildContext context, DataQualityAssessment assessment) {
    showModalBottomSheet(
      context: context,
      backgroundColor: NightTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _DataQualityDetailsSheet(assessment: assessment),
    );
  }

  void _editSession(BuildContext context, WidgetRef ref, SleepSession session) {
    if (session.isComplete) {
      showSessionEditorSheet(
        context: context,
        ref: ref,
        session: session,
      );
    }
  }
}

// =============================================================================
// HEADER
// =============================================================================

class _Header extends StatelessWidget {
  final String babyName;
  final DateRange periodRange;
  final StatsFilterState filter;
  final bool compareEnabled;

  const _Header({
    required this.babyName,
    required this.periodRange,
    required this.filter,
    required this.compareEnabled,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Baby name + Title + Period pill
          Row(
            children: [
              // Baby name (if needed)
              Expanded(
                child: Text(
                  l10n.statsTitle,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: NightTheme.textPrimary,
                  ),
                ),
              ),
              // Period pill
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: NightTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  _formatPeriodLabel(context, filter, periodRange),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: NightTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Row 2: Subtitle
          Text(
            compareEnabled
                ? '${l10n.statsBasedOnLocalData} · ${l10n.statsComparedWithPrevious}'
                : l10n.statsBasedOnLocalData,
            style: const TextStyle(
              fontSize: 12,
              color: NightTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  String _formatPeriodLabel(
      BuildContext context, StatsFilterState filter, DateRange range) {
    final l10n = context.l10n;
    switch (filter.period) {
      case StatsPeriod.day:
        return l10n.statsPeriodDay;
      case StatsPeriod.week:
        return l10n.statsWeek;
      case StatsPeriod.fourteenDays:
        return l10n.statsPeriod14Days;
      case StatsPeriod.month:
        return l10n.statsMonth;
      case StatsPeriod.custom:
        return l10n.statsPeriodLabel(range.days);
    }
  }
}

// =============================================================================
// STICKY FILTER BAR
// =============================================================================

class _FilterBarDelegate extends SliverPersistentHeaderDelegate {
  final StatsFilterState filter;
  final ValueChanged<StatsPeriod> onPeriodChanged;
  final ValueChanged<SleepTypeFilter> onSleepTypeChanged;
  final VoidCallback onCompareToggled;
  final VoidCallback onExportTap;

  const _FilterBarDelegate({
    required this.filter,
    required this.onPeriodChanged,
    required this.onSleepTypeChanged,
    required this.onCompareToggled,
    required this.onExportTap,
  });

  @override
  double get minExtent => 100;
  @override
  double get maxExtent => 100;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final l10n = context.l10n;

    return Container(
      color: NightTheme.backgroundBase,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Period chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: l10n.statsPeriodDay,
                  isSelected: filter.period == StatsPeriod.day,
                  onTap: () => onPeriodChanged(StatsPeriod.day),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: l10n.statsWeek,
                  isSelected: filter.period == StatsPeriod.week,
                  onTap: () => onPeriodChanged(StatsPeriod.week),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: l10n.statsPeriod14Days,
                  isSelected: filter.period == StatsPeriod.fourteenDays,
                  onTap: () => onPeriodChanged(StatsPeriod.fourteenDays),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: l10n.statsMonth,
                  isSelected: filter.period == StatsPeriod.month,
                  onTap: () => onPeriodChanged(StatsPeriod.month),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Type chips + Compare + Export
          Row(
            children: [
              _FilterChip(
                label: l10n.statsTypeAll,
                isSelected: filter.sleepType == SleepTypeFilter.all,
                onTap: () => onSleepTypeChanged(SleepTypeFilter.all),
                small: true,
              ),
              const SizedBox(width: 6),
              _FilterChip(
                label: l10n.statsTypeNight,
                isSelected: filter.sleepType == SleepTypeFilter.night,
                onTap: () => onSleepTypeChanged(SleepTypeFilter.night),
                small: true,
              ),
              const SizedBox(width: 6),
              _FilterChip(
                label: l10n.statsTypeNaps,
                isSelected: filter.sleepType == SleepTypeFilter.naps,
                onTap: () => onSleepTypeChanged(SleepTypeFilter.naps),
                small: true,
              ),
              const Spacer(),
              if (filter.canCompare)
                GestureDetector(
                  onTap: onCompareToggled,
                  child: Row(
                    children: [
                      Icon(
                        filter.compareEnabled
                            ? Icons.check_box
                            : Icons.check_box_outline_blank,
                        size: 18,
                        color: filter.compareEnabled
                            ? NightTheme.primary
                            : NightTheme.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        l10n.statsCompare,
                        style: TextStyle(
                          fontSize: 12,
                          color: filter.compareEnabled
                              ? NightTheme.primary
                              : NightTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: onExportTap,
                child: Row(
                  children: [
                    const Icon(
                      Icons.ios_share,
                      size: 18,
                      color: NightTheme.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      l10n.statsExport,
                      style: const TextStyle(
                        fontSize: 12,
                        color: NightTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _FilterBarDelegate oldDelegate) =>
      filter != oldDelegate.filter;
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool small;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: small ? 10 : 14,
          vertical: small ? 4 : 6,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? NightTheme.primary.withValues(alpha: 0.2)
              : NightTheme.surface,
          borderRadius: BorderRadius.circular(small ? 8 : 10),
          border: isSelected
              ? Border.all(color: NightTheme.primary.withValues(alpha: 0.5))
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: small ? 11 : 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? NightTheme.primary : NightTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// DATA QUALITY CARD
// =============================================================================

class _DataQualityCard extends StatelessWidget {
  final DataQualityAssessment assessment;
  final VoidCallback onDetailsTap;

  const _DataQualityCard({
    required this.assessment,
    required this.onDetailsTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (statusText, statusColor, descText) = _getStatusInfo(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              statusText,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              descText,
              style: const TextStyle(
                fontSize: 12,
                color: NightTheme.textSecondary,
              ),
            ),
          ),
          if (assessment.hasIssues)
            GestureDetector(
              onTap: onDetailsTap,
              child: Text(
                l10n.statsDataQualityDetails,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: statusColor,
                ),
              ),
            ),
        ],
      ),
    );
  }

  (String, Color, String) _getStatusInfo(BuildContext context) {
    final l10n = context.l10n;
    switch (assessment.status) {
      case DataQualityStatus.good:
        return (
          l10n.statsDataQualityGood,
          Colors.green,
          l10n.statsDataQualityGoodDesc,
        );
      case DataQualityStatus.partial:
        return (
          l10n.statsDataQualityPartial,
          Colors.orange,
          l10n.statsDataQualityPartialDesc,
        );
      case DataQualityStatus.incomplete:
        return (
          l10n.statsDataQualityIncomplete,
          Colors.red,
          l10n.statsDataQualityIncompleteDesc,
        );
    }
  }
}

class _DataQualityDetailsSheet extends StatelessWidget {
  final DataQualityAssessment assessment;

  const _DataQualityDetailsSheet({required this.assessment});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return SafeArea(
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

            Text(
              l10n.statsDataQualityTitle,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: NightTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 16),

            // Issues list
            ...assessment.sortedIssues.map((issue) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _IssueRow(issue: issue),
                )),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _IssueRow extends StatelessWidget {
  final DataQualityIssue issue;

  const _IssueRow({required this.issue});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (icon, text, color) = _getIssueInfo(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: NightTheme.backgroundBase,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: NightTheme.textPrimary,
              ),
            ),
          ),
          Text(
            l10n.statsDataQualityActionReviewDay,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  (IconData, String, Color) _getIssueInfo(BuildContext context) {
    final l10n = context.l10n;
    final count = issue.details?['count'] as int? ?? issue.count;

    switch (issue.type) {
      case DataQualityIssueType.missingDays:
        return (
          Icons.event_busy,
          l10n.statsDataQualityIssueMissingDays(count),
          Colors.orange,
        );
      case DataQualityIssueType.ongoingSleepTooLong:
        return (
          Icons.timer_off,
          l10n.statsDataQualityIssueOngoingLong,
          Colors.red,
        );
      case DataQualityIssueType.improbableDurations:
        return (
          Icons.warning_amber,
          l10n.statsDataQualityIssueImprobable(count),
          Colors.orange,
        );
      case DataQualityIssueType.overlapsDetected:
        return (
          Icons.layers,
          l10n.statsDataQualityIssueOverlaps(count),
          Colors.orange,
        );
    }
  }
}

// =============================================================================
// KPIs SECTION
// =============================================================================

class _KPIsSection extends StatelessWidget {
  final PeriodKPIs kpis;
  final KPIComparison? comparison;

  const _KPIsSection({
    required this.kpis,
    this.comparison,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Grid of KPI cards
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _KPICard(
              label: l10n.statsKpiMedianTotal,
              value: kpis.medianTotalFormatted,
              delta: comparison?.deltaAvgFormatted,
              icon: Icons.access_time,
            ),
            _KPICard(
              label: l10n.statsKpiNightVsNaps,
              value:
                  '${(kpis.nightPercentage * 100).toStringAsFixed(0)}% / ${(kpis.napPercentage * 100).toStringAsFixed(0)}%',
              delta: comparison?.deltaNightPPFormatted,
              icon: Icons.nights_stay,
            ),
            _KPICard(
              label: l10n.statsKpiLongestBlock,
              value: kpis.longestBlockFormatted,
              delta: comparison != null
                  ? '${comparison!.deltaLongestBlock > 0 ? '+' : ''}${comparison!.deltaLongestBlock}m'
                  : null,
              icon: Icons.hotel,
            ),
            _KPICard(
              label: l10n.statsKpiFragmentation,
              value: kpis.avgNightEpisodes.toStringAsFixed(1),
              subtitle: l10n.statsKpiEpisodesPerNight,
              delta: comparison?.deltaFragmentationFormatted,
              icon: Icons.blur_on,
            ),
            if (kpis.hasBedtimeConsistency)
              _KPICard(
                label: l10n.statsKpiBedtimeConsistency,
                value: kpis.bedtimeConsistencyFormatted ?? '-',
                icon: Icons.schedule,
              ),
          ],
        ),
      ],
    );
  }
}

class _KPICard extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  final String? delta;
  final IconData icon;

  const _KPICard({
    required this.label,
    required this.value,
    this.subtitle,
    this.delta,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = delta != null && delta!.startsWith('+');
    final isNegative = delta != null && delta!.startsWith('-');
    final deltaColor = isPositive
        ? Colors.green
        : isNegative
            ? Colors.red
            : NightTheme.textSecondary;

    return Container(
      width: (MediaQuery.of(context).size.width - 44) / 2,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NightTheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: NightTheme.primary),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: NightTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: NightTheme.textPrimary,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: const TextStyle(
                fontSize: 10,
                color: NightTheme.textSecondary,
              ),
            ),
          ],
          if (delta != null) ...[
            const SizedBox(height: 4),
            Text(
              delta!,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: deltaColor,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// =============================================================================
// CHARTS SECTION
// =============================================================================

class _ChartsSection extends StatelessWidget {
  final List<DailySleepAggregate> aggregates;

  const _ChartsSection({required this.aggregates});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Total per day chart
        _ChartCard(
          title: l10n.statsChartTotalPerDay,
          child: SizedBox(
            height: 150,
            child: CustomPaint(
              size: Size.infinite,
              painter: _TotalPerDayChartPainter(aggregates: aggregates),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Night vs Naps stacked bars
        _ChartCard(
          title: l10n.statsChartNightVsNaps,
          child: SizedBox(
            height: 120,
            child: CustomPaint(
              size: Size.infinite,
              painter: _NightVsNapsChartPainter(aggregates: aggregates),
            ),
          ),
        ),
      ],
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _ChartCard({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NightTheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: NightTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _TotalPerDayChartPainter extends CustomPainter {
  final List<DailySleepAggregate> aggregates;

  _TotalPerDayChartPainter({required this.aggregates});

  @override
  void paint(Canvas canvas, Size size) {
    if (aggregates.isEmpty) return;

    final days = aggregates.length;
    final barWidth = (size.width - 20) / days;
    final chartHeight = size.height - 20;

    // Find max
    double maxHours = 0;
    for (final a in aggregates) {
      final hours = a.totalMinutes / 60.0;
      if (hours > maxHours) maxHours = hours;
    }
    maxHours = math.max(maxHours, 12);

    // Draw bars
    for (int i = 0; i < days; i++) {
      final a = aggregates[i];
      final hours = a.totalMinutes / 60.0;
      final barHeight = (hours / maxHours) * chartHeight;

      final x = 10 + i * barWidth + barWidth * 0.15;
      final y = chartHeight - barHeight;

      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [NightTheme.primary, NightTheme.secondary],
        ).createShader(Rect.fromLTWH(x, y, barWidth * 0.7, barHeight));

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth * 0.7, barHeight),
          const Radius.circular(4),
        ),
        paint,
      );
    }

    // Draw x-axis labels (day numbers)
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    final labelStep = days > 14 ? 5 : (days > 7 ? 2 : 1);

    for (int i = 0; i < days; i += labelStep) {
      final a = aggregates[i];
      final x = 10 + i * barWidth + barWidth * 0.35;

      textPainter.text = TextSpan(
        text: '${a.dateLocal.day}',
        style: const TextStyle(fontSize: 9, color: NightTheme.textSecondary),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x, size.height - 12));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _NightVsNapsChartPainter extends CustomPainter {
  final List<DailySleepAggregate> aggregates;

  _NightVsNapsChartPainter({required this.aggregates});

  @override
  void paint(Canvas canvas, Size size) {
    if (aggregates.isEmpty) return;

    final days = aggregates.length;
    final barWidth = (size.width - 20) / days;
    final chartHeight = size.height - 20;

    // Find max
    double maxHours = 0;
    for (final a in aggregates) {
      final hours = a.totalMinutes / 60.0;
      if (hours > maxHours) maxHours = hours;
    }
    maxHours = math.max(maxHours, 12);

    final nightPaint = Paint()..color = NightTheme.secondary;
    final napPaint = Paint()..color = NightTheme.accent;

    for (int i = 0; i < days; i++) {
      final a = aggregates[i];
      final nightHours = a.nightMinutes / 60.0;
      final napHours = a.napMinutes / 60.0;

      final nightHeight = (nightHours / maxHours) * chartHeight;
      final napHeight = (napHours / maxHours) * chartHeight;

      final x = 10 + i * barWidth + barWidth * 0.15;

      // Draw night (bottom)
      final nightY = chartHeight - nightHeight;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, nightY, barWidth * 0.7, nightHeight),
          const Radius.circular(2),
        ),
        nightPaint,
      );

      // Draw nap (on top of night)
      final napY = nightY - napHeight;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, napY, barWidth * 0.7, napHeight),
          const Radius.circular(2),
        ),
        napPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// =============================================================================
// TIMELINE SECTION
// =============================================================================

class _TimelineSection extends StatelessWidget {
  final List<DailySleepAggregate> aggregates;
  final void Function(SleepSession session, DateTime date) onSessionTap;

  const _TimelineSection({
    required this.aggregates,
    required this.onSessionTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    // Show most recent days first
    final reversed = aggregates.reversed.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.statsTimelineTitle,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: NightTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        ...reversed.take(10).map((a) => _DayTimelineCard(
              aggregate: a,
              onSessionTap: onSessionTap,
            )),
      ],
    );
  }
}

class _DayTimelineCard extends StatelessWidget {
  final DailySleepAggregate aggregate;
  final void Function(SleepSession session, DateTime date) onSessionTap;

  const _DayTimelineCard({
    required this.aggregate,
    required this.onSessionTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).languageCode;

    final dateStr = _formatDate(aggregate.dateLocal, locale);
    final totalStr = _formatDuration(aggregate.totalMinutes);
    final nightStr = _formatDuration(aggregate.nightMinutes);
    final napStr = _formatDuration(aggregate.napMinutes);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NightTheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Text(
                dateStr,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: NightTheme.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                totalStr,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: NightTheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$nightStr / $napStr',
                style: const TextStyle(
                  fontSize: 11,
                  color: NightTheme.textSecondary,
                ),
              ),
            ],
          ),

          // Flags
          if (aggregate.hasOngoingSleep || aggregate.totalMinutes == 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(
                spacing: 6,
                children: [
                  if (aggregate.hasOngoingSleep)
                    _FlagChip(
                      label: l10n.statsTimelineOngoing,
                      color: NightTheme.primary,
                    ),
                  if (aggregate.totalMinutes == 0)
                    _FlagChip(
                      label: l10n.statsTimelineIncomplete,
                      color: Colors.orange,
                    ),
                ],
              ),
            ),

          // Sessions list
          if (aggregate.sessions.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...aggregate.sessions.take(5).map((s) => _SessionRow(
                  session: s,
                  onTap: () => onSessionTap(s, aggregate.dateLocal),
                )),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date, String locale) {
    final todayRange = LocalTimeUtils.todayLocalRange();
    final yesterdayRange = LocalTimeUtils.yesterdayLocalRange();
    final dateKey = LocalTimeUtils.dateKey(date);

    if (dateKey == todayRange.key) {
      return 'Hoje, ${date.day}';
    } else if (dateKey == yesterdayRange.key) {
      return 'Ontem, ${date.day}';
    }

    final weekdays = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
    return '${weekdays[date.weekday - 1]}, ${date.day}';
  }

  String _formatDuration(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0) return '${h}h${m}m';
    return '${m}m';
  }
}

class _FlagChip extends StatelessWidget {
  final String label;
  final Color color;

  const _FlagChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  final SleepSession session;
  final VoidCallback onTap;

  const _SessionRow({required this.session, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final start = session.startEvent.timestamp.toLocal();
    final end = session.endEvent?.timestamp.toLocal();

    final startStr =
        '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
    final endStr = end != null
        ? '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}'
        : 'em curso';

    final durationStr = session.isComplete
        ? _formatDuration(session.duration!.inMinutes)
        : '...';

    final isNap = session.duration != null && session.duration!.inHours < 3;

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(
              isNap ? Icons.brightness_5 : Icons.nights_stay,
              size: 14,
              color: isNap ? NightTheme.accent : NightTheme.secondary,
            ),
            const SizedBox(width: 8),
            Text(
              '$startStr – $endStr',
              style: const TextStyle(
                fontSize: 13,
                color: NightTheme.textPrimary,
              ),
            ),
            const Spacer(),
            Text(
              durationStr,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: NightTheme.textSecondary,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right,
              size: 16,
              color: NightTheme.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0) return '${h}h${m}m';
    return '${m}m';
  }
}

// =============================================================================
// EMPTY STATE
// =============================================================================

class _EmptyState extends StatelessWidget {
  final VoidCallback onTap;

  const _EmptyState({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bar_chart,
              size: 64,
              color: NightTheme.textSecondary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.statsEmptyState,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: NightTheme.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.bedtime),
              label: Text(l10n.statsGoToSleep),
              style: ElevatedButton.styleFrom(
                backgroundColor: NightTheme.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// EXPORT SHEET
// =============================================================================

class _ExportSheet extends StatefulWidget {
  final String? babyName;
  final List<SleepSession> sessions;
  final List<DailySleepAggregate> aggregates;
  final DateRange periodRange;
  final PeriodKPIs kpis;
  final KPIComparison? comparison;

  const _ExportSheet({
    required this.babyName,
    required this.sessions,
    required this.aggregates,
    required this.periodRange,
    required this.kpis,
    this.comparison,
  });

  @override
  State<_ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<_ExportSheet> {
  String _exportType = 'pdf';
  String _period = '7';
  String _csvType = 'sessions';
  bool _includeName = true;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return SafeArea(
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

            Text(
              l10n.statsExportTitle,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: NightTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 20),

            // Export type toggle
            Row(
              children: [
                Expanded(
                  child: _ExportTypeButton(
                    label: l10n.statsExportPdf,
                    isSelected: _exportType == 'pdf',
                    onTap: () => setState(() => _exportType = 'pdf'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ExportTypeButton(
                    label: l10n.statsExportCsv,
                    isSelected: _exportType == 'csv',
                    onTap: () => setState(() => _exportType = 'csv'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Period selection
            Wrap(
              spacing: 8,
              children: [
                _FilterChip(
                  label: l10n.statsExportPeriod7,
                  isSelected: _period == '7',
                  onTap: () => setState(() => _period = '7'),
                  small: true,
                ),
                _FilterChip(
                  label: l10n.statsExportPeriod14,
                  isSelected: _period == '14',
                  onTap: () => setState(() => _period = '14'),
                  small: true,
                ),
                _FilterChip(
                  label: l10n.statsExportPeriod30,
                  isSelected: _period == '30',
                  onTap: () => setState(() => _period = '30'),
                  small: true,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // CSV type (only for CSV)
            if (_exportType == 'csv') ...[
              Wrap(
                spacing: 8,
                children: [
                  _FilterChip(
                    label: l10n.statsExportCsvSessions,
                    isSelected: _csvType == 'sessions',
                    onTap: () => setState(() => _csvType = 'sessions'),
                    small: true,
                  ),
                  _FilterChip(
                    label: l10n.statsExportCsvAggregates,
                    isSelected: _csvType == 'aggregates',
                    onTap: () => setState(() => _csvType = 'aggregates'),
                    small: true,
                  ),
                  _FilterChip(
                    label: l10n.statsExportCsvBoth,
                    isSelected: _csvType == 'both',
                    onTap: () => setState(() => _csvType = 'both'),
                    small: true,
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // Include name toggle
            Row(
              children: [
                Checkbox(
                  value: _includeName,
                  onChanged: (v) => setState(() => _includeName = v ?? true),
                  activeColor: NightTheme.primary,
                ),
                Text(
                  l10n.statsExportIncludeName,
                  style: const TextStyle(
                    fontSize: 14,
                    color: NightTheme.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Preview
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: NightTheme.backgroundBase,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _exportType == 'pdf'
                    ? l10n.statsExportPreviewPdf
                    : l10n.statsExportPreviewCsv,
                style: const TextStyle(
                  fontSize: 12,
                  color: NightTheme.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Generate button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  
                  final babyName = _includeName ? widget.babyName : null;
                  
                  if (_exportType == 'csv') {
                    switch (_csvType) {
                      case 'sessions':
                        await StatsExportService.exportSessionsCsv(
                          sessions: widget.sessions,
                          babyName: babyName,
                          startDate: widget.periodRange.startLocal,
                          endDate: widget.periodRange.endExclusiveLocal,
                        );
                        break;
                      case 'aggregates':
                        await StatsExportService.exportAggregatesCsv(
                          aggregates: widget.aggregates,
                          babyName: babyName,
                        );
                        break;
                      case 'both':
                        await StatsExportService.exportBothCsv(
                          sessions: widget.sessions,
                          aggregates: widget.aggregates,
                          babyName: babyName,
                          startDate: widget.periodRange.startLocal,
                          endDate: widget.periodRange.endExclusiveLocal,
                        );
                        break;
                    }
                  } else {
                    // PDF export
                    await StatsExportService.exportPdf(
                      aggregates: widget.aggregates,
                      kpis: widget.kpis,
                      babyName: babyName,
                      startDate: widget.periodRange.startLocal,
                      endDate: widget.periodRange.endExclusiveLocal,
                      timezone: DateTime.now().timeZoneName,
                      comparison: widget.comparison,
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: NightTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(l10n.statsExportGenerate),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExportTypeButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ExportTypeButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? NightTheme.primary.withValues(alpha: 0.15)
              : NightTheme.backgroundBase,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: NightTheme.primary)
              : Border.all(color: NightTheme.surface),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected ? NightTheme.primary : NightTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
