import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:temp_flutter/application/providers/active_baby_provider.dart';
import 'package:temp_flutter/application/providers/babies_provider.dart';
import 'package:temp_flutter/application/providers/insights_v2_provider.dart';
import 'package:temp_flutter/application/providers/sleep_expectations_provider.dart';
import 'package:temp_flutter/application/providers/sleep_metrics_provider.dart';
import 'package:temp_flutter/application/providers/sleep_routine_provider.dart';
import 'package:temp_flutter/domain/analysis/age_band.dart';
import 'package:temp_flutter/domain/analysis/insight_render_model.dart';
import 'package:temp_flutter/domain/analysis/sleep_metrics.dart';
import 'package:temp_flutter/domain/analysis/sleep_routine_suggestion.dart';
import 'package:temp_flutter/domain/content/content_ids.dart';
import 'package:temp_flutter/domain/entities/baby.dart';
import 'package:temp_flutter/l10n/generated/app_localizations.dart';
import 'package:temp_flutter/presentation/pages/baby_profile_page.dart';
import 'package:temp_flutter/presentation/pages/guide_detail_page_v2.dart';
import 'package:temp_flutter/presentation/theme/night_theme.dart';

/// InsightsPage v2 - Uses l10n and InsightRenderModel
class InsightsPageV2 extends ConsumerWidget {
  const InsightsPageV2({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final activeBaby = ref.watch(activeBabyProvider);
    final babiesAsync = ref.watch(babiesNotifierProvider);
    final metricsAsync = ref.watch(sleepMetricsProvider);
    final insightsAsync = ref.watch(insightsV2Provider);
    final expectationsDataAsync = ref.watch(activeBabySleepExpectationsProvider);
    final routineAsync = ref.watch(sleepRoutineProvider);

    if (activeBaby == null) {
      return _EmptyStateNoBaby(l10n: l10n);
    }

    final babies = babiesAsync.valueOrNull ?? [];
    final metrics = metricsAsync.valueOrNull ?? SleepMetrics.empty();
    final insightResult = insightsAsync.valueOrEmpty;
    final expectationsData = expectationsDataAsync.valueOrNull;
    final routine = routineAsync.valueOrEmpty;

    final hasBirthDate = expectationsData?.hasBirthDate ?? false;
    final hasData = metrics.daysWithData > 0;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HeaderSection(
              l10n: l10n,
              baby: activeBaby,
              babies: babies,
              daysWithData: metrics.daysWithData,
              onBabyChanged: (baby) => ref.read(activeBabyProvider.notifier).setBaby(baby),
            ),
            const SizedBox(height: 16),
            if (!hasBirthDate) _NoBirthDateBanner(l10n: l10n, baby: activeBaby),
            if (!hasBirthDate) const SizedBox(height: 16),
            if (!hasData)
              _EmptyStateNoData(l10n: l10n)
            else ...[
              _TodaySection(
                l10n: l10n,
                metrics: metrics,
                todayCards: insightResult.todayCards,
              ),
              const SizedBox(height: 28),
              _PatternsSection(
                l10n: l10n,
                patternCards: insightResult.patternCards,
                daysWithData: metrics.daysWithData,
              ),
              const SizedBox(height: 28),
              _RoutineSection(
                l10n: l10n,
                routine: routine,
                metrics: metrics,
                hasBirthDate: hasBirthDate,
              ),
              const SizedBox(height: 28),
              _GuideSection(
                l10n: l10n,
                hasBirthDate: hasBirthDate,
                ageBand: expectationsData?.ageBand,
                baby: activeBaby,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  final AppLocalizations l10n;
  final Baby baby;
  final List<Baby> babies;
  final int daysWithData;
  final ValueChanged<Baby> onBabyChanged;

  const _HeaderSection({
    required this.l10n,
    required this.baby,
    required this.babies,
    required this.daysWithData,
    required this.onBabyChanged,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateFormat = DateFormat('d MMM', Localizations.localeOf(context).toLanguageTag());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (babies.length > 1)
          GestureDetector(
            onTap: () => _showBabySelector(context),
            child: Row(children: [
              Text(baby.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: NightTheme.textPrimary)),
              const SizedBox(width: 6),
              const Icon(Icons.keyboard_arrow_down, color: NightTheme.textSecondary, size: 22),
            ]),
          )
        else
          Text(baby.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: NightTheme.textPrimary)),
        const SizedBox(height: 6),
        Row(children: [
          Text('${l10n.insightsHeaderToday} · ${dateFormat.format(now)}', style: const TextStyle(fontSize: 14, color: NightTheme.textSecondary)),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: NightTheme.surface, borderRadius: BorderRadius.circular(8)),
            child: Text(
              daysWithData == 0 ? l10n.statsNoData : l10n.insightsHeaderBasedOn(daysWithData),
              style: const TextStyle(fontSize: 11, color: NightTheme.textSecondary),
            ),
          ),
        ]),
      ],
    );
  }

  void _showBabySelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: NightTheme.backgroundBase,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.selectBaby, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: NightTheme.textPrimary)),
            const SizedBox(height: 16),
            ...babies.map((b) => ListTile(
              leading: Icon(b.id == baby.id ? Icons.check_circle : Icons.circle_outlined, color: b.id == baby.id ? NightTheme.accent : NightTheme.textSecondary),
              title: Text(b.name, style: const TextStyle(color: NightTheme.textPrimary)),
              onTap: () { onBabyChanged(b); Navigator.pop(context); },
            )),
          ],
        ),
      ),
    );
  }
}

class _NoBirthDateBanner extends StatelessWidget {
  final AppLocalizations l10n;
  final Baby baby;
  const _NoBirthDateBanner({required this.l10n, required this.baby});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NightTheme.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: NightTheme.accent.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.cake_outlined, size: 20, color: NightTheme.accent),
          const SizedBox(width: 10),
          Expanded(child: Text(l10n.insightsAddDobBanner, style: const TextStyle(fontSize: 13, color: NightTheme.textBody))),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => BabyProfilePage(baby: baby, showSkipOption: true))),
            style: TextButton.styleFrom(backgroundColor: NightTheme.accent, foregroundColor: NightTheme.backgroundTop, padding: const EdgeInsets.symmetric(vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: Text(l10n.insightsAddDob, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
    );
  }
}

class _TodaySection extends StatelessWidget {
  final AppLocalizations l10n;
  final SleepMetrics metrics;
  final List<InsightRenderModel> todayCards;

  const _TodaySection({
    required this.l10n,
    required this.metrics,
    required this.todayCards,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(l10n.insightsHeaderToday, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: NightTheme.textPrimary)),
      const SizedBox(height: 12),
      _Summary24hCardV2(l10n: l10n, metrics: metrics),
      for (final card in todayCards.where((c) => c.id != InsightId.summary24h))
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: _InsightCardWidget(l10n: l10n, insight: card),
        ),
    ]);
  }
}

class _Summary24hCardV2 extends StatelessWidget {
  final AppLocalizations l10n;
  final SleepMetrics metrics;
  const _Summary24hCardV2({required this.l10n, required this.metrics});

  @override
  Widget build(BuildContext context) {
    final hasComparison = metrics.diffFromAvg7d != null && metrics.daysWithData >= 3;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: NightTheme.surface, borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.nights_stay, size: 20, color: NightTheme.primary),
          const SizedBox(width: 10),
          Text(l10n.insightSummary24hTitle, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: NightTheme.textPrimary)),
          const Spacer(),
          if (metrics.isCurrentlySleeping)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: NightTheme.primary.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
              child: Text(l10n.sessionInProgress, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: NightTheme.primary)),
            ),
        ]),
        const SizedBox(height: 14),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(metrics.totalSleepLast24hFormatted, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: NightTheme.textPrimary)),
          const SizedBox(width: 8),
          Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(l10n.totalLabel, style: TextStyle(fontSize: 14, color: NightTheme.textSecondary.withValues(alpha: 0.7)))),
        ]),
        if (hasComparison) ...[
          const SizedBox(height: 8),
          Row(children: [
            Icon(metrics.diffFromAvg7d!.inMinutes >= 0 ? Icons.trending_up : Icons.trending_down, size: 16, color: metrics.diffFromAvg7d!.inMinutes >= 0 ? NightTheme.success : NightTheme.warning),
            const SizedBox(width: 6),
            Text('${metrics.diffFromAvg7dFormatted} vs ${l10n.statsWeek.toLowerCase()}', style: const TextStyle(fontSize: 12, color: NightTheme.textSecondary)),
          ]),
        ] else if (metrics.daysWithData < 3) ...[
          const SizedBox(height: 8),
          Text(l10n.insightsLearning, style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: NightTheme.textSecondary)),
        ],
      ]),
    );
  }
}

class _InsightCardWidget extends StatefulWidget {
  final AppLocalizations l10n;
  final InsightRenderModel insight;
  const _InsightCardWidget({required this.l10n, required this.insight});

  @override
  State<_InsightCardWidget> createState() => _InsightCardWidgetState();
}

class _InsightCardWidgetState extends State<_InsightCardWidget> {
  bool _showWhy = false;

  @override
  Widget build(BuildContext context) {
    final insight = widget.insight;
    final l10n = widget.l10n;
    
    // Determine tone color based on priority
    final toneColor = insight.priority == InsightPriority.high
        ? NightTheme.warning
        : insight.priority == InsightPriority.low
            ? NightTheme.success
            : NightTheme.textSecondary;

    final title = _getLocalizedString(l10n, insight.titleKey, insight.args);
    final body = _getLocalizedString(l10n, insight.bodyKey, insight.args);
    final why = insight.whyKey != null 
        ? _getLocalizedString(l10n, insight.whyKey!, insight.args)
        : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NightTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: toneColor.withValues(alpha: 0.3), width: 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.lightbulb_outline, size: 18, color: toneColor),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: NightTheme.textPrimary))),
        ]),
        const SizedBox(height: 10),
        Text(body, style: const TextStyle(fontSize: 14, color: NightTheme.textBody, height: 1.4)),
        if (why != null) ...[
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => setState(() => _showWhy = !_showWhy),
            child: Row(children: [
              Icon(_showWhy ? Icons.expand_less : Icons.expand_more, size: 16, color: NightTheme.textSecondary),
              const SizedBox(width: 4),
              Text(_showWhy ? l10n.commonCancel : l10n.insightCtaWhyThis, style: const TextStyle(fontSize: 12, color: NightTheme.textSecondary)),
            ]),
          ),
          if (_showWhy) ...[
            const SizedBox(height: 8),
            Text(why, style: TextStyle(fontSize: 12, color: NightTheme.textSecondary.withValues(alpha: 0.8), fontStyle: FontStyle.italic)),
          ],
        ],
        if (insight.ctaAction != InsightCtaAction.none && insight.guideSectionId != null) ...[
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => GuideDetailPageV2.navigateTo(context, insight.guideSectionId!),
            icon: const Icon(Icons.menu_book, size: 16),
            label: Text(_getLocalizedString(l10n, insight.ctaLabelKey ?? 'insightCtaLearnMore', {})),
            style: TextButton.styleFrom(
              foregroundColor: NightTheme.secondary,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              textStyle: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ]),
    );
  }

  String _getLocalizedString(AppLocalizations l10n, String key, Map<String, dynamic> args) {
    // Map keys to l10n methods
    // This is a simplified approach - in production you might use code generation
    switch (key) {
      case 'insightSummary24hTitle':
        return l10n.insightSummary24hTitle;
      case 'insightSummary24hNoData':
        return l10n.insightSummary24hNoData;
      case 'insightCurrentlySleepingTitle':
        return l10n.insightCurrentlySleepingTitle;
      case 'insightCurrentlySleepingBody':
        return l10n.insightCurrentlySleepingBody(args['time'] as String? ?? '');
      case 'insightSleepBelowExpectedTitle':
        return l10n.insightSleepBelowExpectedTitle;
      case 'insightSleepBelowExpectedBody':
        return l10n.insightSleepBelowExpectedBody;
      case 'insightSleepBelowExpectedWhy':
        return l10n.insightSleepBelowExpectedWhy(args['min'] as int? ?? 0, args['max'] as int? ?? 0);
      case 'insightSleepWithinExpectedTitle':
        return l10n.insightSleepWithinExpectedTitle;
      case 'insightSleepWithinExpectedBody':
        return l10n.insightSleepWithinExpectedBody;
      case 'insightSleepAboveExpectedTitle':
        return l10n.insightSleepAboveExpectedTitle;
      case 'insightSleepAboveExpectedBody':
        return l10n.insightSleepAboveExpectedBody;
      case 'insightBedtimeVariabilityHighTitle':
        return l10n.insightBedtimeVariabilityHighTitle;
      case 'insightBedtimeVariabilityHighBody':
        return l10n.insightBedtimeVariabilityHighBody(args['minutes'] as int? ?? 0);
      case 'insightBedtimeVariabilityHighWhy':
        return l10n.insightBedtimeVariabilityHighWhy;
      case 'insightBedtimeConsistencyGoodTitle':
        return l10n.insightBedtimeConsistencyGoodTitle;
      case 'insightBedtimeConsistencyGoodBody':
        return l10n.insightBedtimeConsistencyGoodBody;
      case 'insightNightFragmentationHighTitle':
        return l10n.insightNightFragmentationHighTitle;
      case 'insightNightFragmentationHighBody':
        return l10n.insightNightFragmentationHighBody;
      case 'insightNightFragmentationHighWhy':
        return l10n.insightNightFragmentationHighWhy(args['count'] as int? ?? 0);
      case 'insightAgeNorm0to3Title':
        return l10n.insightAgeNorm0to3Title;
      case 'insightAgeNorm0to3Body':
        return l10n.insightAgeNorm0to3Body;
      case 'insightAgeNorm4to12Title':
        return l10n.insightAgeNorm4to12Title;
      case 'insightAgeNorm4to12Body':
        return l10n.insightAgeNorm4to12Body;
      case 'insightAgeNorm12to24Title':
        return l10n.insightAgeNorm12to24Title;
      case 'insightAgeNorm12to24Body':
        return l10n.insightAgeNorm12to24Body;
      case 'insightSafeSleepBackToSleepTitle':
        return l10n.insightSafeSleepBackToSleepTitle;
      case 'insightSafeSleepBackToSleepBody':
        return l10n.insightSafeSleepBackToSleepBody;
      case 'insightDayNightLowStimulusTitle':
        return l10n.insightDayNightLowStimulusTitle;
      case 'insightDayNightLowStimulusBody':
        return l10n.insightDayNightLowStimulusBody;
      case 'insightRoutineShortConsistentTitle':
        return l10n.insightRoutineShortConsistentTitle;
      case 'insightRoutineShortConsistentBody':
        return l10n.insightRoutineShortConsistentBody;
      case 'insightWhenCallPediatricianTitle':
        return l10n.insightWhenCallPediatricianTitle;
      case 'insightWhenCallPediatricianBody':
        return l10n.insightWhenCallPediatricianBody;
      case 'insightFewDataLearningTitle':
        return l10n.insightFewDataLearningTitle;
      case 'insightFewDataLearningBody':
        return l10n.insightFewDataLearningBody;
      case 'insightCtaLearnMore':
        return l10n.insightCtaLearnMore;
      case 'insightCtaSave':
        return l10n.insightCtaSave;
      case 'insightCtaCheckGuide':
        return l10n.insightCtaCheckGuide;
      case 'insightCtaOpenGuide':
        return l10n.insightCtaOpenGuide;
      case 'insightCtaWhyThis':
        return l10n.insightCtaWhyThis;
      default:
        return key;
    }
  }
}

class _PatternsSection extends StatelessWidget {
  final AppLocalizations l10n;
  final List<InsightRenderModel> patternCards;
  final int daysWithData;
  const _PatternsSection({
    required this.l10n,
    required this.patternCards,
    required this.daysWithData,
  });

  @override
  Widget build(BuildContext context) {
    if (patternCards.isEmpty && daysWithData < 7) return const SizedBox.shrink();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(l10n.insightsHeaderPatterns, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: NightTheme.textPrimary)),
      const SizedBox(height: 12),
      if (patternCards.isEmpty)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: NightTheme.surface, borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            const Icon(Icons.search, size: 20, color: NightTheme.textSecondary),
            const SizedBox(width: 12),
            Expanded(child: Text(l10n.insightsMoreDataNeeded, style: const TextStyle(fontSize: 13, color: NightTheme.textSecondary))),
          ]),
        )
      else
        ...patternCards.map((card) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _InsightCardWidget(l10n: l10n, insight: card),
        )),
    ]);
  }
}

class _RoutineSection extends StatelessWidget {
  final AppLocalizations l10n;
  final SleepRoutineSuggestion routine;
  final SleepMetrics metrics;
  final bool hasBirthDate;
  const _RoutineSection({
    required this.l10n,
    required this.routine,
    required this.metrics,
    required this.hasBirthDate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(l10n.insightsHeaderRoutine, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: NightTheme.textPrimary)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: NightTheme.textSecondary.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
          child: Text(l10n.routineSuggestionTitle.toLowerCase(), style: const TextStyle(fontSize: 10, color: NightTheme.textSecondary)),
        ),
      ]),
      const SizedBox(height: 12),
      if (!routine.hasSufficientData && metrics.daysWithData < 3)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: NightTheme.surface, borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            const Icon(Icons.schedule, size: 20, color: NightTheme.textSecondary),
            const SizedBox(width: 12),
            Expanded(child: Text(l10n.routineNoData, style: const TextStyle(fontSize: 13, color: NightTheme.textSecondary))),
          ]),
        )
      else
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: NightTheme.surface, borderRadius: BorderRadius.circular(14)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (routine.bedtimeWindowStart != null)
              _RoutineItem(
                icon: Icons.nightlight,
                title: l10n.routineBedtime,
                value: routine.bedtimeWindowFormatted,
              ),
            if (routine.suggestedNapsCount != null) ...[
              const SizedBox(height: 12),
              _RoutineItem(
                icon: Icons.wb_sunny_outlined,
                title: l10n.routineNextNap,
                value: l10n.routineNapCount(routine.suggestedNapsCount!),
              ),
            ],
            if (!hasBirthDate) ...[
              const SizedBox(height: 12),
              Text(l10n.insightsNoDobFallback, style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: NightTheme.textSecondary.withValues(alpha: 0.8))),
            ],
          ]),
        ),
    ]);
  }
}

class _RoutineItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  const _RoutineItem({required this.icon, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 18, color: NightTheme.secondary),
      const SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 11, color: NightTheme.textSecondary)),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: NightTheme.textPrimary)),
      ]),
    ]);
  }
}

class _GuideSection extends StatelessWidget {
  final AppLocalizations l10n;
  final bool hasBirthDate;
  final SleepAgeBand? ageBand;
  final Baby baby;
  const _GuideSection({
    required this.l10n,
    required this.hasBirthDate,
    this.ageBand,
    required this.baby,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(l10n.insightsHeaderGuide, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: NightTheme.textPrimary)),
      const SizedBox(height: 12),
      _GuideItem(
        title: l10n.guide_normal_por_idade_title,
        subtitle: hasBirthDate && ageBand != null ? ageBand!.labelPt : l10n.insightsAddDob,
        icon: Icons.child_care,
        onTap: () {
          if (!hasBirthDate) {
            Navigator.of(context).push(MaterialPageRoute(builder: (context) => BabyProfilePage(baby: baby, showSkipOption: true)));
          } else {
            GuideDetailPageV2.navigateTo(context, GuideSectionId.normalPorIdade);
          }
        },
      ),
      _GuideItem(
        title: l10n.guide_dia_vs_noite_title,
        subtitle: l10n.guide_dia_vs_noite_subtitle,
        icon: Icons.brightness_4,
        onTap: () => GuideDetailPageV2.navigateTo(context, GuideSectionId.diaVsNoite),
      ),
      _GuideItem(
        title: l10n.guide_rotina_antes_dormir_title,
        subtitle: l10n.guide_rotina_antes_dormir_subtitle,
        icon: Icons.format_list_numbered,
        onTap: () => GuideDetailPageV2.navigateTo(context, GuideSectionId.rotinaAntesDormir),
      ),
      _GuideItem(
        title: l10n.guide_sono_seguro_title,
        subtitle: l10n.guide_sono_seguro_subtitle,
        icon: Icons.verified_user,
        onTap: () => GuideDetailPageV2.navigateTo(context, GuideSectionId.sonoSeguro),
      ),
      _GuideItem(
        title: l10n.guide_quando_pediatra_title,
        subtitle: l10n.guide_quando_pediatra_subtitle,
        icon: Icons.medical_services_outlined,
        onTap: () => GuideDetailPageV2.navigateTo(context, GuideSectionId.quandoPediatra),
      ),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: NightTheme.surface.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(10)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.info_outline, size: 16, color: NightTheme.textSecondary),
          const SizedBox(width: 8),
          Expanded(child: Text(l10n.insightsDisclaimerMedical, style: const TextStyle(fontSize: 11, color: NightTheme.textSecondary))),
        ]),
      ),
    ]);
  }
}

class _GuideItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  const _GuideItem({required this.title, required this.subtitle, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: NightTheme.surface, borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Icon(icon, size: 22, color: NightTheme.secondary),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: NightTheme.textPrimary)),
              Text(subtitle, style: const TextStyle(fontSize: 12, color: NightTheme.textSecondary)),
            ])),
            const Icon(Icons.chevron_right, size: 20, color: NightTheme.textSecondary),
          ]),
        ),
      ),
    );
  }
}

class _EmptyStateNoBaby extends StatelessWidget {
  final AppLocalizations l10n;
  const _EmptyStateNoBaby({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.child_care, size: 48, color: NightTheme.textSecondary),
      const SizedBox(height: 16),
      Text(l10n.selectBaby, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: NightTheme.textPrimary)),
    ])));
  }
}

class _EmptyStateNoData extends StatelessWidget {
  final AppLocalizations l10n;
  const _EmptyStateNoData({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: NightTheme.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        const Icon(Icons.bedtime_outlined, size: 48, color: NightTheme.textSecondary),
        const SizedBox(height: 16),
        Text(l10n.emptyStateNoRecords, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: NightTheme.textPrimary)),
        const SizedBox(height: 8),
        Text(l10n.emptyStateRecordsWillAppear, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: NightTheme.textSecondary)),
      ]),
    );
  }
}
