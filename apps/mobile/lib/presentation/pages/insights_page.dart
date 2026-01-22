import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:temp_flutter/application/providers/active_baby_provider.dart';
import 'package:temp_flutter/application/providers/babies_provider.dart';
import 'package:temp_flutter/application/providers/sleep_expectations_provider.dart';
import 'package:temp_flutter/application/providers/sleep_insights_provider.dart';
import 'package:temp_flutter/application/providers/sleep_metrics_provider.dart';
import 'package:temp_flutter/application/providers/sleep_routine_provider.dart';
import 'package:temp_flutter/core/l10n/l10n.dart';
import 'package:temp_flutter/domain/analysis/age_band.dart';
import 'package:temp_flutter/domain/analysis/sleep_insight.dart';
import 'package:temp_flutter/domain/analysis/sleep_metrics.dart';
import 'package:temp_flutter/domain/analysis/sleep_routine_suggestion.dart';
import 'package:temp_flutter/domain/entities/baby.dart';
import 'package:temp_flutter/presentation/pages/baby_profile_page.dart';
import 'package:temp_flutter/presentation/pages/guide_detail_page.dart';
import 'package:temp_flutter/presentation/theme/night_theme.dart';

/// InsightsPage - Redesenhado segundo o plano de wireframe
class InsightsPage extends ConsumerWidget {
  const InsightsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeBaby = ref.watch(activeBabyProvider);
    final babiesAsync = ref.watch(babiesNotifierProvider);
    final metricsAsync = ref.watch(sleepMetricsProvider);
    final insightsAsync = ref.watch(sleepInsightsProvider);
    final expectationsDataAsync = ref.watch(activeBabySleepExpectationsProvider);
    final routineAsync = ref.watch(sleepRoutineProvider);

    if (activeBaby == null) {
      return const _EmptyStateNoBaby();
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
              baby: activeBaby,
              babies: babies,
              daysWithData: metrics.daysWithData,
              onBabyChanged: (baby) => ref.read(activeBabyProvider.notifier).setBaby(baby),
            ),
            const SizedBox(height: 16),
            if (!hasBirthDate) _NoBirthDateBanner(baby: activeBaby),
            if (!hasBirthDate) const SizedBox(height: 16),
            if (!hasData)
              const _EmptyStateNoData()
            else ...[
              _TodaySection(
                metrics: metrics,
                topInsight: insightResult.topInsights.isNotEmpty ? insightResult.topInsights.first : null,
                topAction: insightResult.suggestedActions.isNotEmpty ? insightResult.suggestedActions.first : null,
              ),
              const SizedBox(height: 28),
              _PatternsSection(
                insights: insightResult.allInsights.where((i) =>
                    !['currently_sleeping', 'no_birthdate', 'insufficient_data', 'total_sleep_24h', 'total_sleep_24h_generic'].contains(i.id)).take(4).toList(),
                daysWithData: metrics.daysWithData,
              ),
              const SizedBox(height: 28),
              _RoutineSection(routine: routine, metrics: metrics, hasBirthDate: hasBirthDate),
              const SizedBox(height: 28),
              _GuideSection(hasBirthDate: hasBirthDate, ageBand: expectationsData?.ageBand, baby: activeBaby),
            ],
          ],
        ),
      ),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  final Baby baby;
  final List<Baby> babies;
  final int daysWithData;
  final ValueChanged<Baby> onBabyChanged;

  const _HeaderSection({required this.baby, required this.babies, required this.daysWithData, required this.onBabyChanged});

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
          Text('Hoje · ${dateFormat.format(now)}', style: const TextStyle(fontSize: 14, color: NightTheme.textSecondary)),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: NightTheme.surface, borderRadius: BorderRadius.circular(8)),
            child: Text(
              daysWithData == 0 ? 'Sem dados' : daysWithData == 1 ? 'Baseado em 1 dia' : 'Baseado em $daysWithData dias',
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
            Text(context.l10n.selectBaby, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: NightTheme.textPrimary)),
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
  final Baby baby;
  const _NoBirthDateBanner({required this.baby});

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
          Expanded(child: Text(context.l10n.insightsAddDobBanner, style: const TextStyle(fontSize: 13, color: NightTheme.textBody))),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => BabyProfilePage(baby: baby, showSkipOption: true))),
            style: TextButton.styleFrom(backgroundColor: NightTheme.accent, foregroundColor: NightTheme.backgroundTop, padding: const EdgeInsets.symmetric(vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: Text(context.l10n.insightsAddNow, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
    );
  }
}

class _TodaySection extends StatelessWidget {
  final SleepMetrics metrics;
  final SleepInsight? topInsight;
  final SuggestedAction? topAction;

  const _TodaySection({required this.metrics, this.topInsight, this.topAction});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(context.l10n.dayToday, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: NightTheme.textPrimary)),
      const SizedBox(height: 12),
      _Summary24hCard(metrics: metrics),
      if (topInsight != null) ...[const SizedBox(height: 10), _MainInsightCard(insight: topInsight!)],
      if (topAction != null) ...[const SizedBox(height: 10), _NextStepCard(action: topAction!)],
    ]);
  }
}

class _Summary24hCard extends StatelessWidget {
  final SleepMetrics metrics;
  const _Summary24hCard({required this.metrics});

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
          Text(context.l10n.insightSummary24hTitle, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: NightTheme.textPrimary)),
          const Spacer(),
          if (metrics.isCurrentlySleeping)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: NightTheme.primary.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
              child: Text(context.l10n.sessionInProgress, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: NightTheme.primary)),
            ),
        ]),
        const SizedBox(height: 14),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(metrics.totalSleepLast24hFormatted, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: NightTheme.textPrimary)),
          const SizedBox(width: 8),
          Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(context.l10n.totalLabel, style: TextStyle(fontSize: 14, color: NightTheme.textSecondary.withValues(alpha: 0.7)))),
        ]),
        if (hasComparison) ...[
          const SizedBox(height: 8),
          Row(children: [
            Icon(metrics.diffFromAvg7d!.inMinutes >= 0 ? Icons.trending_up : Icons.trending_down, size: 16, color: metrics.diffFromAvg7d!.inMinutes >= 0 ? NightTheme.success : NightTheme.warning),
            const SizedBox(width: 6),
            Text(context.l10n.insightsVsAvg7Days(metrics.diffFromAvg7dFormatted ?? ''), style: const TextStyle(fontSize: 12, color: NightTheme.textSecondary)),
          ]),
        ] else if (metrics.daysWithData < 3) ...[
          const SizedBox(height: 8),
          Text(context.l10n.insightsLearning, style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: NightTheme.textSecondary)),
        ],
        if (metrics.nightSleepLast24h.inMinutes > 0 || metrics.napSleepLast24h.inMinutes > 0) ...[
          const SizedBox(height: 12),
          Row(children: [
            _MiniStat(icon: Icons.dark_mode, label: 'Noite', value: metrics.nightSleepLast24hFormatted),
            const SizedBox(width: 16),
            _MiniStat(icon: Icons.wb_sunny_outlined, label: 'Sestas', value: metrics.napSleepLast24hFormatted),
          ]),
        ],
      ]),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _MiniStat({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 14, color: NightTheme.textSecondary),
      const SizedBox(width: 4),
      Text('$label: $value', style: const TextStyle(fontSize: 11, color: NightTheme.textSecondary)),
    ]);
  }
}

class _MainInsightCard extends StatefulWidget {
  final SleepInsight insight;
  const _MainInsightCard({required this.insight});
  @override
  State<_MainInsightCard> createState() => _MainInsightCardState();
}

class _MainInsightCardState extends State<_MainInsightCard> {
  bool _showWhy = false;

  @override
  Widget build(BuildContext context) {
    final tone = widget.insight.tone;
    final toneColor = tone == InsightTone.positive ? NightTheme.success : tone == InsightTone.attention ? NightTheme.warning : NightTheme.textSecondary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: NightTheme.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: toneColor.withValues(alpha: 0.3), width: 1)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.lightbulb_outline, size: 18, color: toneColor),
          const SizedBox(width: 8),
          Text(context.l10n.insightsMainPoint, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: NightTheme.textPrimary)),
        ]),
        const SizedBox(height: 10),
        Text(widget.insight.messagePt, style: const TextStyle(fontSize: 14, color: NightTheme.textBody, height: 1.4)),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => setState(() => _showWhy = !_showWhy),
          child: Row(children: [
            Icon(_showWhy ? Icons.expand_less : Icons.expand_more, size: 16, color: NightTheme.textSecondary),
            const SizedBox(width: 4),
            Text(_showWhy ? 'Esconder' : 'Porquê estamos a sugerir isto?', style: const TextStyle(fontSize: 12, color: NightTheme.textSecondary)),
          ]),
        ),
        if (_showWhy) ...[
          const SizedBox(height: 8),
          Text(widget.insight.evidencePt, style: TextStyle(fontSize: 12, color: NightTheme.textSecondary.withValues(alpha: 0.8), fontStyle: FontStyle.italic)),
        ],
      ]),
    );
  }
}

class _NextStepCard extends StatelessWidget {
  final SuggestedAction action;
  const _NextStepCard({required this.action});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: NightTheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14), border: Border.all(color: NightTheme.primary.withValues(alpha: 0.3), width: 1)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.arrow_forward, size: 18, color: NightTheme.primary),
          const SizedBox(width: 8),
          Text(context.l10n.insightsNextStep, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: NightTheme.textPrimary)),
        ]),
        const SizedBox(height: 10),
        Text(action.titlePt, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: NightTheme.textPrimary)),
        const SizedBox(height: 4),
        Text(action.descriptionPt, style: const TextStyle(fontSize: 13, color: NightTheme.textBody, height: 1.4)),
        const SizedBox(height: 12),
        Row(children: [
          OutlinedButton.icon(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.insightsSavedFavorites), duration: const Duration(seconds: 2))),
            icon: const Icon(Icons.bookmark_border, size: 16),
            label: Text(context.l10n.insightCtaSave),
            style: OutlinedButton.styleFrom(foregroundColor: NightTheme.textSecondary, side: BorderSide(color: NightTheme.textSecondary.withValues(alpha: 0.3)), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), textStyle: const TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.notifications_none, size: 16),
            label: Text(context.l10n.relaxComingSoon),
            style: OutlinedButton.styleFrom(foregroundColor: NightTheme.textSecondary.withValues(alpha: 0.5), side: BorderSide(color: NightTheme.textSecondary.withValues(alpha: 0.2)), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), textStyle: const TextStyle(fontSize: 12)),
          ),
        ]),
      ]),
    );
  }
}

class _PatternsSection extends StatelessWidget {
  final List<SleepInsight> insights;
  final int daysWithData;
  const _PatternsSection({required this.insights, required this.daysWithData});

  @override
  Widget build(BuildContext context) {
    if (insights.isEmpty && daysWithData < 7) return const SizedBox.shrink();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(context.l10n.insightsHeaderPatterns, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: NightTheme.textPrimary)),
      const SizedBox(height: 12),
      if (insights.isEmpty)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: NightTheme.surface, borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            const Icon(Icons.search, size: 20, color: NightTheme.textSecondary),
            const SizedBox(width: 12),
            Expanded(child: Text(context.l10n.insightsCollectingPatterns, style: const TextStyle(fontSize: 13, color: NightTheme.textSecondary))),
          ]),
        )
      else
        ...insights.map((i) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _PatternCard(insight: i))),
    ]);
  }
}

class _PatternCard extends StatelessWidget {
  final SleepInsight insight;
  const _PatternCard({required this.insight});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: NightTheme.surface, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(insight.messagePt, style: const TextStyle(fontSize: 13, color: NightTheme.textBody, height: 1.4)),
        const SizedBox(height: 8),
        Text(insight.evidencePt, style: TextStyle(fontSize: 11, color: NightTheme.textSecondary.withValues(alpha: 0.8))),
      ]),
    );
  }
}

class _RoutineSection extends StatelessWidget {
  final SleepRoutineSuggestion routine;
  final SleepMetrics metrics;
  final bool hasBirthDate;
  const _RoutineSection({required this.routine, required this.metrics, required this.hasBirthDate});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(context.l10n.insightsHeaderRoutine, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: NightTheme.textPrimary)),
        const SizedBox(width: 8),
        Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: NightTheme.textSecondary.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)), child: Text(context.l10n.insightsSuggestionLabel, style: const TextStyle(fontSize: 10, color: NightTheme.textSecondary))),
      ]),
      const SizedBox(height: 12),
      if (!routine.hasSufficientData && metrics.daysWithData < 3)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: NightTheme.surface, borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            const Icon(Icons.schedule, size: 20, color: NightTheme.textSecondary),
            const SizedBox(width: 12),
            Expanded(child: Text(context.l10n.insightsRegisterMoreNights, style: const TextStyle(fontSize: 13, color: NightTheme.textSecondary))),
          ]),
        )
      else
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: NightTheme.surface, borderRadius: BorderRadius.circular(14)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (routine.bedtimeWindowStart != null) _RoutineItem(icon: Icons.nightlight, title: 'Janela para a noite', value: routine.bedtimeWindowFormatted),
            if (routine.suggestedNapsCount != null) ...[const SizedBox(height: 12), _RoutineItem(icon: Icons.wb_sunny_outlined, title: 'Sestas prováveis', value: '${routine.suggestedNapsCount} sestas')],
            const SizedBox(height: 16),
            const Text('Rotina curta (2–4 passos)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: NightTheme.textPrimary)),
            const SizedBox(height: 8),
            ...['Banho ou limpeza', 'Vestir pijama', 'Canção ou história curta', 'Luz baixa e despedida'].map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                Container(width: 20, height: 20, decoration: BoxDecoration(border: Border.all(color: NightTheme.textSecondary.withValues(alpha: 0.4)), borderRadius: BorderRadius.circular(4))),
                const SizedBox(width: 10),
                Text(s, style: const TextStyle(fontSize: 13, color: NightTheme.textBody)),
              ]),
            )),
            if (!hasBirthDate) ...[const SizedBox(height: 12), Text(context.l10n.insightsDefineDobForAge, style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: NightTheme.textSecondary.withValues(alpha: 0.8)))],
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
  final bool hasBirthDate;
  final SleepAgeBand? ageBand;
  final Baby baby;
  const _GuideSection({required this.hasBirthDate, this.ageBand, required this.baby});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(context.l10n.insightsHeaderGuide, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: NightTheme.textPrimary)),
      const SizedBox(height: 12),
      _GuideItem(title: 'Normal por idade', subtitle: hasBirthDate && ageBand != null ? 'Para ${ageBand!.labelPt}' : 'Adiciona DOB para ver', icon: Icons.child_care, onTap: () {
        if (!hasBirthDate) {
          Navigator.of(context).push(MaterialPageRoute(builder: (context) => BabyProfilePage(baby: baby, showSkipOption: true)));
        } else {
          GuideDetailPage.navigateTo(context, 'normal_por_idade');
        }
      }),
      _GuideItem(title: 'Dia vs noite', subtitle: 'Baixo estímulo à noite', icon: Icons.brightness_4, onTap: () => GuideDetailPage.navigateTo(context, 'dia_vs_noite')),
      _GuideItem(title: 'Rotina antes de dormir', subtitle: '2–4 passos simples', icon: Icons.format_list_numbered, onTap: () => GuideDetailPage.navigateTo(context, 'rotina_antes_dormir')),
      _GuideItem(title: 'Sono seguro', subtitle: 'Checklist rápida', icon: Icons.verified_user, onTap: () => GuideDetailPage.navigateTo(context, 'sono_seguro')),
      _GuideItem(title: 'Quando falar com pediatra', subtitle: 'Sinais de atenção', icon: Icons.medical_services_outlined, onTap: () => GuideDetailPage.navigateTo(context, 'quando_pediatra')),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: NightTheme.surface.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(10)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.info_outline, size: 16, color: NightTheme.textSecondary),
          const SizedBox(width: 8),
          Expanded(child: Text(context.l10n.guideDisclaimer, style: const TextStyle(fontSize: 11, color: NightTheme.textSecondary))),
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
  const _EmptyStateNoBaby();

  @override
  Widget build(BuildContext context) {
    return Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.child_care, size: 48, color: NightTheme.textSecondary),
      const SizedBox(height: 16),
      Text(context.l10n.selectBaby, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: NightTheme.textPrimary)),
      const SizedBox(height: 8),
      Text(context.l10n.insightsToSeePersonalized, style: const TextStyle(fontSize: 14, color: NightTheme.textSecondary)),
    ])));
  }
}

class _EmptyStateNoData extends StatelessWidget {
  const _EmptyStateNoData();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: NightTheme.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        const Icon(Icons.bedtime_outlined, size: 48, color: NightTheme.textSecondary),
        const SizedBox(height: 16),
        Text(context.l10n.insightsNoRecordsYet, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: NightTheme.textPrimary)),
        const SizedBox(height: 8),
        Text(context.l10n.insightsRecordFirstSleep, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: NightTheme.textSecondary)),
        const SizedBox(height: 16),
        TextButton.icon(onPressed: () {}, icon: const Icon(Icons.add, size: 18), label: Text(context.l10n.insightsRegisterSleep), style: TextButton.styleFrom(foregroundColor: NightTheme.primary)),
      ]),
    );
  }
}
