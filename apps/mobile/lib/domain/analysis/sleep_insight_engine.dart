import 'age_band.dart';
import 'sleep_expectations.dart';
import 'sleep_insight.dart';
import 'sleep_metrics.dart';

/// Engine that generates sleep insights from metrics and expectations
///
/// Pure function-based engine. No side effects, no network.
/// Takes metrics and optional expectations, returns insights and actions.
class SleepInsightEngine {
  const SleepInsightEngine._();

  /// Generates insights from metrics and expectations
  ///
  /// [metrics] - Calculated sleep metrics
  /// [expectations] - Optional age-based expectations (null if no birthDate)
  /// [babyName] - Baby's name for personalized messages
  ///
  /// Returns a result containing:
  /// - All insights (for Stats page)
  /// - Top insights (for Home page, max 2)
  /// - Suggested actions (max 2)
  static SleepInsightResult generate({
    required SleepMetrics metrics,
    SleepExpectations? expectations,
    required String babyName,
  }) {
    final insights = <SleepInsight>[];
    final actions = <SuggestedAction>[];

    // If not enough data, return minimal result
    if (!metrics.hasMinimumData) {
      return SleepInsightResult(
        allInsights: [
          SleepInsight(
            id: 'insufficient_data',
            category: InsightCategory.general,
            priority: 100,
            messagePt:
                'Regista mais algumas noites para ver insights personalizados sobre o sono do $babyName.',
            evidencePt: 'Menos de 1 dia de dados registados.',
            tone: InsightTone.neutral,
          ),
        ],
        topInsights: [],
        suggestedActions: [],
        hasAgeExpectations: false,
      );
    }

    final hasExpectations = expectations != null;

    // === 1. Total Sleep 24h (with age comparison if available) ===
    if (hasExpectations) {
      insights.add(_generateTotalSleepInsight(
        metrics: metrics,
        expectations: expectations,
        babyName: babyName,
      ));
    } else {
      // Generic insight without age comparison
      insights.add(_generateGenericTotalSleepInsight(
        metrics: metrics,
        babyName: babyName,
      ));
    }

    // === 2. Fragmentation ===
    if (metrics.fragmentationScore > 0.3) {
      insights.add(_generateFragmentationInsight(
        metrics: metrics,
        babyName: babyName,
        hasExpectations: hasExpectations,
        expectations: expectations,
      ));

      // Action for fragmentation
      if (metrics.fragmentationScore > 0.5) {
        actions.add(const SuggestedAction(
          id: 'action_calming_routine',
          titlePt: 'Rotina calmante',
          descriptionPt:
              'Experimenta um ambiente mais calmo antes de dormir: luz baixa, menos estímulos.',
          reasonPt: 'O sono parece fragmentado, uma rotina relaxante pode ajudar.',
          priority: 1,
        ));
      }
    }

    // === 3. Bedtime Consistency ===
    if (metrics.hasConsistencyData && metrics.bedtimeConsistencyMinutes != null) {
      insights.add(_generateConsistencyInsight(
        metrics: metrics,
        babyName: babyName,
      ));

      // Action for inconsistency
      if (metrics.bedtimeConsistencyMinutes! > 45) {
        actions.add(const SuggestedAction(
          id: 'action_consistent_bedtime',
          titlePt: 'Horário consistente',
          descriptionPt:
              'Tenta manter o mesmo horário de deitar todos os dias, mesmo ao fim de semana.',
          reasonPt:
              'O horário de deitar tem variado bastante. Consistência ajuda o relógio biológico.',
          priority: 2,
        ));
      }
    }

    // === 4. Short Naps ===
    if (metrics.napCountLast24h >= 2 && metrics.shortNapRate > 0.4) {
      insights.add(_generateShortNapsInsight(
        metrics: metrics,
        babyName: babyName,
        hasExpectations: hasExpectations,
        expectations: expectations,
      ));
    }

    // === 5. Age-appropriate description ===
    if (hasExpectations && expectations.descriptionPt != null) {
      insights.add(SleepInsight(
        id: 'age_description',
        category: InsightCategory.general,
        priority: 50,
        messagePt: expectations.descriptionPt!,
        evidencePt:
            'Informação típica para bebés com ${expectations.ageBand.labelPt}.',
        tone: InsightTone.neutral,
      ));
    }

    // === 6. No birthDate prompt ===
    if (!hasExpectations) {
      insights.add(const SleepInsight(
        id: 'no_birthdate',
        category: InsightCategory.general,
        priority: 90,
        messagePt:
            'Adiciona a data de nascimento para ver insights personalizados por idade.',
        evidencePt: 'A data de nascimento não está definida.',
        tone: InsightTone.neutral,
      ));
    }

    // === 7. Currently sleeping ===
    if (metrics.isCurrentlySleeping && metrics.currentSessionStart != null) {
      final sleepingSince = DateTime.now().difference(metrics.currentSessionStart!);
      final hours = sleepingSince.inHours;
      final minutes = sleepingSince.inMinutes % 60;
      final durationText = hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';

      insights.add(SleepInsight(
        id: 'currently_sleeping',
        category: InsightCategory.currentState,
        priority: 1,
        messagePt: 'O $babyName está a dormir há $durationText.',
        evidencePt: 'Sessão em curso iniciada às ${_formatTime(metrics.currentSessionStart!)}.',
        tone: InsightTone.positive,
      ));
    }

    // Sort by priority
    insights.sort((a, b) => a.priority.compareTo(b.priority));
    actions.sort((a, b) => a.priority.compareTo(b.priority));

    // Top insights for Home (max 2, skip currently_sleeping for Home)
    final topInsights = insights
        .where((i) => i.id != 'currently_sleeping' && i.id != 'no_birthdate')
        .take(2)
        .toList();

    // Top actions (max 2)
    final topActions = actions.take(2).toList();

    return SleepInsightResult(
      allInsights: insights,
      topInsights: topInsights,
      suggestedActions: topActions,
      hasAgeExpectations: hasExpectations,
      rangeComparison: hasExpectations
          ? expectations.compareTotalSleep24h(metrics.totalSleepLast24hMinutes)
          : null,
    );
  }

  static SleepInsight _generateTotalSleepInsight({
    required SleepMetrics metrics,
    required SleepExpectations expectations,
    required String babyName,
  }) {
    final totalMinutes = metrics.totalSleepLast24hMinutes;
    final comparison = expectations.compareTotalSleep24h(totalMinutes);
    final rangeText =
        '${expectations.totalSleep24hMin ~/ 60}-${expectations.totalSleep24hMax ~/ 60}h';

    String messagePt;
    InsightTone tone;

    switch (comparison) {
      case RangeComparison.below:
        final diff = expectations.totalSleep24hMin - totalMinutes;
        final diffHours = (diff / 60).toStringAsFixed(1);
        messagePt =
            'O $babyName dormiu ${metrics.totalSleepLast24hFormatted} nas últimas 24h, cerca de ${diffHours}h abaixo do esperado ($rangeText). Isto pode ser uma fase normal.';
        tone = InsightTone.attention;
        break;
      case RangeComparison.within:
        messagePt =
            'O $babyName dormiu ${metrics.totalSleepLast24hFormatted} nas últimas 24h, dentro do esperado para a idade ($rangeText). Bom trabalho!';
        tone = InsightTone.positive;
        break;
      case RangeComparison.above:
        messagePt =
            'O $babyName dormiu ${metrics.totalSleepLast24hFormatted} nas últimas 24h, acima do esperado ($rangeText). Pode ser um pico de crescimento ou recuperação.';
        tone = InsightTone.neutral;
        break;
    }

    return SleepInsight(
      id: 'total_sleep_24h',
      category: InsightCategory.totalSleep,
      priority: 5,
      messagePt: messagePt,
      evidencePt:
          'Sono total: ${metrics.totalSleepLast24hFormatted}. Esperado: $rangeText para ${expectations.ageBand.labelPt}.',
      rangeComparison: comparison,
      tone: tone,
    );
  }

  static SleepInsight _generateGenericTotalSleepInsight({
    required SleepMetrics metrics,
    required String babyName,
  }) {
    final hours = metrics.totalSleepLast24h.inHours;
    InsightTone tone;
    String messagePt;

    if (hours >= 10) {
      messagePt =
          'O $babyName dormiu ${metrics.totalSleepLast24hFormatted} nas últimas 24h. Parece estar a descansar bem!';
      tone = InsightTone.positive;
    } else if (hours >= 7) {
      messagePt =
          'O $babyName dormiu ${metrics.totalSleepLast24hFormatted} nas últimas 24h.';
      tone = InsightTone.neutral;
    } else {
      messagePt =
          'O $babyName dormiu ${metrics.totalSleepLast24hFormatted} nas últimas 24h. Pode precisar de mais descanso.';
      tone = InsightTone.attention;
    }

    return SleepInsight(
      id: 'total_sleep_24h_generic',
      category: InsightCategory.totalSleep,
      priority: 5,
      messagePt: messagePt,
      evidencePt: 'Sono total nas últimas 24h: ${metrics.totalSleepLast24hFormatted}.',
      tone: tone,
    );
  }

  static SleepInsight _generateFragmentationInsight({
    required SleepMetrics metrics,
    required String babyName,
    required bool hasExpectations,
    SleepExpectations? expectations,
  }) {
    final score = metrics.fragmentationScore;
    String messagePt;
    InsightTone tone;

    if (score > 0.7) {
      messagePt =
          'O sono do $babyName parece bastante fragmentado, com várias interrupções. Isto é comum em certas fases.';
      tone = InsightTone.attention;
    } else if (score > 0.5) {
      messagePt =
          'O sono do $babyName tem algumas interrupções. Uma rotina relaxante antes de dormir pode ajudar.';
      tone = InsightTone.attention;
    } else {
      messagePt =
          'O sono do $babyName mostra alguma fragmentação, mas está dentro do normal.';
      tone = InsightTone.neutral;
    }

    // Add age context if available
    if (hasExpectations && expectations?.commonChallengesPt.isNotEmpty == true) {
      final challenges = expectations!.commonChallengesPt;
      if (challenges.any((c) =>
          c.toLowerCase().contains('fragment') ||
          c.toLowerCase().contains('acord') ||
          c.toLowerCase().contains('interrup'))) {
        messagePt +=
            ' Para esta idade, alguma fragmentação é esperada.';
      }
    }

    return SleepInsight(
      id: 'fragmentation',
      category: InsightCategory.fragmentation,
      priority: 15,
      messagePt: messagePt,
      evidencePt:
          'Índice de fragmentação: ${(score * 100).toStringAsFixed(0)}% (baseado em sessões curtas e acordares noturnos).',
      tone: tone,
    );
  }

  static SleepInsight _generateConsistencyInsight({
    required SleepMetrics metrics,
    required String babyName,
  }) {
    final stdDev = metrics.bedtimeConsistencyMinutes!;
    String messagePt;
    InsightTone tone;

    if (stdDev < 20) {
      messagePt =
          'O horário de deitar do $babyName está muito consistente. Isto ajuda o relógio biológico!';
      tone = InsightTone.positive;
    } else if (stdDev < 45) {
      messagePt =
          'O horário de deitar do $babyName está razoavelmente consistente.';
      tone = InsightTone.neutral;
    } else {
      messagePt =
          'O horário de deitar do $babyName tem variado cerca de ${stdDev.toStringAsFixed(0)} minutos. Mais consistência pode ajudar.';
      tone = InsightTone.attention;
    }

    return SleepInsight(
      id: 'bedtime_consistency',
      category: InsightCategory.consistency,
      priority: 20,
      messagePt: messagePt,
      evidencePt:
          'Variação do horário de deitar: ~${stdDev.toStringAsFixed(0)} minutos nos últimos dias.',
      tone: tone,
    );
  }

  static SleepInsight _generateShortNapsInsight({
    required SleepMetrics metrics,
    required String babyName,
    required bool hasExpectations,
    SleepExpectations? expectations,
  }) {
    final rate = metrics.shortNapRate;
    final pct = (rate * 100).toStringAsFixed(0);

    String messagePt =
        'Cerca de $pct% das sestas do $babyName são curtas (<30 min). Isto é comum em muitas fases.';
    InsightTone tone = InsightTone.neutral;

    if (rate > 0.6) {
      messagePt =
          'A maioria das sestas do $babyName são curtas (<30 min). Pode ser uma fase, ou o ambiente pode ser ajustado.';
      tone = InsightTone.attention;
    }

    return SleepInsight(
      id: 'short_naps',
      category: InsightCategory.naps,
      priority: 25,
      messagePt: messagePt,
      evidencePt:
          '$pct% de sestas curtas (<30 min) nas últimas 24h.',
      tone: tone,
    );
  }

  static String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

/// Result from the insight engine
class SleepInsightResult {
  /// All generated insights (for Stats page)
  final List<SleepInsight> allInsights;

  /// Top 2 insights for Home page
  final List<SleepInsight> topInsights;

  /// Suggested actions for today (max 2)
  final List<SuggestedAction> suggestedActions;

  /// Whether age-based expectations were available
  final bool hasAgeExpectations;

  /// Range comparison for total sleep (if expectations available)
  final RangeComparison? rangeComparison;

  const SleepInsightResult({
    required this.allInsights,
    required this.topInsights,
    required this.suggestedActions,
    required this.hasAgeExpectations,
    this.rangeComparison,
  });

  /// Whether there are any insights to show
  bool get hasInsights => allInsights.isNotEmpty;

  /// Whether there are suggested actions
  bool get hasActions => suggestedActions.isNotEmpty;

  /// Empty result
  factory SleepInsightResult.empty() {
    return const SleepInsightResult(
      allInsights: [],
      topInsights: [],
      suggestedActions: [],
      hasAgeExpectations: false,
    );
  }

  @override
  String toString() =>
      'SleepInsightResult(insights: ${allInsights.length}, actions: ${suggestedActions.length})';
}
