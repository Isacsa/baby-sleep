import 'age_band.dart';
import 'sleep_expectations.dart';
import 'sleep_insight.dart';
import 'sleep_metrics.dart';

/// Catalog of all InsightCards with their triggers and configurations
///
/// Each card has:
/// - Trigger condition (evaluated against metrics)
/// - Copy in PT-PT
/// - Why explanation
/// - CTA action
/// - Cooldown, requiresDob, sources
///
/// Based on plan Section 5 (Entregável 4)
class InsightCardsCatalog {
  InsightCardsCatalog._();

  /// Evaluates all cards against the given metrics and returns triggered insights
  static List<SleepInsight> evaluate({
    required SleepMetrics metrics,
    required String babyName,
    SleepExpectations? expectations,
    DateTime? birthDate,
    int availableDays = 0,
  }) {
    final triggered = <SleepInsight>[];
    final hasDob = birthDate != null;
    final ageBand = birthDate != null
        ? AgeCalculator.ageBand(birthDate)
        : SleepAgeBand.unknown;

    // === GROUP A: Segurança do sono (CDC/AAP/NHS) ===

    // Card 1: safe_sleep_back_to_sleep
    triggered.add(SleepInsight(
      id: 'safe_sleep_back_to_sleep',
      category: InsightCategory.general,
      priority: 80,
      messagePt: 'Para o sono, coloca o $babyName **de costas** numa superfície firme e livre de objetos soltos.',
      evidencePt: 'Recomendação de sono seguro (reduz riscos evitáveis).',
      tone: InsightTone.neutral,
      cooldownHours: 168, // 7 days
      requiresDataDays: 0,
      requiresDob: false,
      ctaAction: InsightCtaAction.openGuideAnchor,
      ctaLabel: 'Ver checklist',
      sourcesRefs: ['AAP_safe_sleep', 'CDC_safe_sleep', 'NHS_safe_sleep'],
    ));

    // Card 2: safe_sleep_room_temp
    triggered.add(SleepInsight(
      id: 'safe_sleep_room_temp',
      category: InsightCategory.general,
      priority: 82,
      messagePt: 'Um quarto fresco e roupa leve costuma ajudar a manter o sono mais estável.',
      evidencePt: 'Ambiente consistente reduz despertares.',
      tone: InsightTone.neutral,
      cooldownHours: 168,
      requiresDataDays: 0,
      requiresDob: false,
      ctaAction: InsightCtaAction.openGuideAnchor,
      ctaLabel: 'Ler mais',
      sourcesRefs: ['NHS_safe_sleep'],
    ));

    // Card 3: safe_sleep_smoke (educativo, baixa prioridade)
    triggered.add(SleepInsight(
      id: 'safe_sleep_smoke',
      category: InsightCategory.general,
      priority: 90,
      messagePt: 'Evitar fumo perto do bebé (mesmo "só na varanda") é uma das medidas mais protetoras.',
      evidencePt: 'Sono seguro: reduzir exposição a fumo.',
      tone: InsightTone.neutral,
      cooldownHours: 336, // 14 days
      requiresDataDays: 0,
      requiresDob: false,
      ctaAction: InsightCtaAction.openGuideAnchor,
      ctaLabel: 'Ler mais',
      sourcesRefs: ['AAP_safe_sleep', 'CDC_safe_sleep'],
    ));

    // Card 4: when_call_pediatrician
    triggered.add(SleepInsight(
      id: 'when_call_pediatrician',
      category: InsightCategory.general,
      priority: 85,
      messagePt: 'Se algo te preocupa (respiração, febre, recusa alimentar), fala com o pediatra. Confia no teu instinto.',
      evidencePt: 'Guia educativo; sem alarmismo.',
      tone: InsightTone.neutral,
      cooldownHours: 168,
      requiresDataDays: 0,
      requiresDob: false,
      ctaAction: InsightCtaAction.openGuideAnchor,
      ctaLabel: 'Quando falar com pediatra',
      sourcesRefs: ['AAP', 'NHS'],
    ));

    // === GROUP B: Dia vs noite (NHS) ===

    // Card 5: day_night_low_stimulus
    if (availableDays >= 3 && metrics.fragmentationScore > 0.4) {
      triggered.add(SleepInsight(
        id: 'day_night_low_stimulus',
        category: InsightCategory.fragmentation,
        priority: 25,
        messagePt: 'À noite, mantém luz baixa e interações curtas. Ajuda o $babyName a voltar ao sono mais depressa.',
        evidencePt: 'Padrão noturno com muitos episódios (fragmentação: ${(metrics.fragmentationScore * 100).toStringAsFixed(0)}%).',
        tone: InsightTone.attention,
        cooldownHours: 72,
        requiresDataDays: 3,
        requiresDob: false,
        ctaAction: InsightCtaAction.openChecklist,
        ctaLabel: 'Ver como',
        sourcesRefs: ['NHS_day_night'],
      ));
    }

    // Card 6: day_night_morning_light
    if (availableDays >= 3 && metrics.napSleepLast24h > metrics.nightSleepLast24h) {
      triggered.add(SleepInsight(
        id: 'day_night_morning_light',
        category: InsightCategory.naps,
        priority: 30,
        messagePt: 'Durante o dia, luz natural e atividades normais podem ajudar a diferenciar dia e noite.',
        evidencePt: 'Distribuição dia/noite desequilibrada: mais sono durante o dia.',
        tone: InsightTone.neutral,
        cooldownHours: 72,
        requiresDataDays: 3,
        requiresDob: false,
        ctaAction: InsightCtaAction.openGuideAnchor,
        ctaLabel: 'Isto é normal?',
        sourcesRefs: ['NHS_day_night'],
      ));
    }

    // === GROUP C: Rotina curta consistente (AAP/NHS) ===

    // Card 7: routine_short_consistent
    if (availableDays >= 7 && 
        metrics.bedtimeVariabilityRangeMinutes != null && 
        metrics.bedtimeVariabilityRangeMinutes! > 60) {
      triggered.add(SleepInsight(
        id: 'routine_short_consistent',
        category: InsightCategory.consistency,
        priority: 20,
        messagePt: 'Uma rotina curta e repetida (2–4 passos) pode ajudar mais do que "fazer muito".',
        evidencePt: 'Início da noite variável nos últimos dias (±${metrics.bedtimeVariabilityRangeMinutes} min).',
        tone: InsightTone.attention,
        cooldownHours: 72,
        requiresDataDays: 7,
        requiresDob: false,
        ctaAction: InsightCtaAction.openRoutineEditor,
        ctaLabel: 'Personalizar rotina',
        sourcesRefs: ['AAP_bedtime_routine', 'NHS_bedtime_routine'],
      ));
    }

    // Card 8: routine_keep_same_order
    triggered.add(SleepInsight(
      id: 'routine_keep_same_order',
      category: InsightCategory.general,
      priority: 60,
      messagePt: 'Escolhe 2–3 passos e mantém a mesma ordem. Simplicidade funciona melhor quando há cansaço.',
      evidencePt: 'Rotina consistente reduz esforço decisório.',
      tone: InsightTone.neutral,
      cooldownHours: 168,
      requiresDataDays: 0,
      requiresDob: false,
      ctaAction: InsightCtaAction.openChecklist,
      ctaLabel: 'Ver como',
      sourcesRefs: ['AAP_bedtime_routine'],
    ));

    // === GROUP D: Normalização por idade (requiresDob) ===

    // Card 9: age_norm_0_3_variability (0-3m)
    if (hasDob && (ageBand == SleepAgeBand.newborn0to28d || 
                   ageBand == SleepAgeBand.months1to2 || 
                   ageBand == SleepAgeBand.months2to4)) {
      triggered.add(SleepInsight(
        id: 'age_norm_0_3_variability',
        category: InsightCategory.general,
        priority: 35,
        messagePt: 'Nesta fase é comum haver muita variabilidade e blocos de sono curtos. Não estás a "fazer algo mal".',
        evidencePt: 'Padrões variáveis são típicos no início (${ageBand.labelPt}).',
        tone: InsightTone.neutral,
        cooldownHours: 168,
        requiresDataDays: 1,
        requiresDob: true,
        ageBands: [SleepAgeBand.newborn0to28d, SleepAgeBand.months1to2, SleepAgeBand.months2to4],
        ctaAction: InsightCtaAction.openGuideAnchor,
        ctaLabel: 'Normal por idade',
        sourcesRefs: ['AASM', 'AAP'],
      ));
    }

    // Card 10: age_norm_4_12_consolidation (4-12m)
    if (hasDob && (ageBand == SleepAgeBand.months4to6 || 
                   ageBand == SleepAgeBand.months6to9 || 
                   ageBand == SleepAgeBand.months9to12)) {
      triggered.add(SleepInsight(
        id: 'age_norm_4_12_consolidation',
        category: InsightCategory.general,
        priority: 35,
        messagePt: 'Muitos bebés começam a consolidar mais sono à noite nesta fase, mas as regressões também são comuns.',
        evidencePt: 'Normalização por idade (${ageBand.labelPt}).',
        tone: InsightTone.neutral,
        cooldownHours: 168,
        requiresDataDays: 1,
        requiresDob: true,
        ageBands: [SleepAgeBand.months4to6, SleepAgeBand.months6to9, SleepAgeBand.months9to12],
        ctaAction: InsightCtaAction.openGuideAnchor,
        ctaLabel: 'Normal por idade',
        sourcesRefs: ['AASM', 'AAP'],
      ));
    }

    // Card 11: age_norm_12_24_boundaries (12-24m)
    if (hasDob && (ageBand == SleepAgeBand.months12to18 || 
                   ageBand == SleepAgeBand.months18to24)) {
      triggered.add(SleepInsight(
        id: 'age_norm_12_24_boundaries',
        category: InsightCategory.general,
        priority: 35,
        messagePt: 'Nesta fase, "testar limites" e resistir à hora de deitar é comum. Rotinas previsíveis ajudam.',
        evidencePt: 'Normalização por idade (${ageBand.labelPt}).',
        tone: InsightTone.neutral,
        cooldownHours: 168,
        requiresDataDays: 1,
        requiresDob: true,
        ageBands: [SleepAgeBand.months12to18, SleepAgeBand.months18to24],
        ctaAction: InsightCtaAction.openGuideAnchor,
        ctaLabel: 'Normal por idade',
        sourcesRefs: ['AASM', 'AAP'],
      ));
    }

    // === GROUP E: Abaixo/acima do recomendado (requiresDob) ===

    // Card 12: sleep_below_expected
    if (hasDob && expectations != null && availableDays >= 3) {
      final comparison = expectations.compareTotalSleep24h(metrics.totalSleepLast24hMinutes);
      if (comparison == RangeComparison.below) {
        triggered.add(SleepInsight(
          id: 'sleep_below_expected',
          category: InsightCategory.totalSleep,
          priority: 10,
          messagePt: 'Nas últimas 24h, o sono está **um pouco abaixo** do esperado para esta idade. Hoje pode ajudar reduzir estímulos e priorizar uma rotina simples.',
          evidencePt: 'Total 24h (${metrics.totalSleepLast24hFormatted}) vs intervalo por idade (${expectations.totalSleep24hMin ~/ 60}-${expectations.totalSleep24hMax ~/ 60}h).',
          rangeComparison: RangeComparison.below,
          tone: InsightTone.attention,
          cooldownHours: 48,
          requiresDataDays: 3,
          requiresDob: true,
          ctaAction: InsightCtaAction.openChecklist,
          ctaLabel: 'Ver como',
          sourcesRefs: ['AASM_sleep_duration'],
        ));
      }

      // Card 13: sleep_within_expected
      if (comparison == RangeComparison.within) {
        triggered.add(SleepInsight(
          id: 'sleep_within_expected',
          category: InsightCategory.totalSleep,
          priority: 15,
          messagePt: 'O sono nas últimas 24h está **dentro do esperado** para esta idade. O foco pode ser só manter consistência.',
          evidencePt: 'Total 24h (${metrics.totalSleepLast24hFormatted}) dentro do intervalo por idade.',
          rangeComparison: RangeComparison.within,
          tone: InsightTone.positive,
          cooldownHours: 72,
          requiresDataDays: 3,
          requiresDob: true,
          ctaAction: InsightCtaAction.saveFavorite,
          ctaLabel: 'Guardar',
          sourcesRefs: ['AASM_sleep_duration'],
        ));
      }

      // Card 14: sleep_above_expected
      if (comparison == RangeComparison.above) {
        triggered.add(SleepInsight(
          id: 'sleep_above_expected',
          category: InsightCategory.totalSleep,
          priority: 18,
          messagePt: 'O sono nas últimas 24h está **acima do esperado** para esta idade. Se hoje foi um dia diferente, é normal — observa a semana.',
          evidencePt: 'Total 24h (${metrics.totalSleepLast24hFormatted}) acima do intervalo por idade.',
          rangeComparison: RangeComparison.above,
          tone: InsightTone.neutral,
          cooldownHours: 72,
          requiresDataDays: 3,
          requiresDob: true,
          ctaAction: InsightCtaAction.none,
          ctaLabel: 'Ver semana',
          sourcesRefs: ['AASM_sleep_duration'],
        ));
      }
    }

    // === GROUP F: Fragmentação e maior bloco ===

    // Card 15: night_fragmentation_high
    if (availableDays >= 7 && metrics.fragmentationScore > 0.6) {
      triggered.add(SleepInsight(
        id: 'night_fragmentation_high',
        category: InsightCategory.fragmentation,
        priority: 22,
        messagePt: 'Tem havido mais despertares à noite do que o habitual para o teu bebé. Uma noite "calma" começa com luz baixa e poucas mudanças.',
        evidencePt: 'Episódios por noite acima do padrão (fragmentação: ${(metrics.fragmentationScore * 100).toStringAsFixed(0)}%).',
        tone: InsightTone.attention,
        cooldownHours: 72,
        requiresDataDays: 7,
        requiresDob: false,
        ctaAction: InsightCtaAction.openGuideAnchor,
        ctaLabel: 'Isto é normal?',
        sourcesRefs: ['NHS_day_night'],
      ));
    }

    // Card 16: largest_block_improving
    if (availableDays >= 7 && 
        metrics.longestSession7d != null && 
        metrics.longestSessionLast24h != null &&
        metrics.longestSession7d!.inMinutes > 0 &&
        metrics.longestSessionLast24h!.inMinutes >= metrics.longestSession7d!.inMinutes * 0.9) {
      triggered.add(SleepInsight(
        id: 'largest_block_improving',
        category: InsightCategory.totalSleep,
        priority: 40,
        messagePt: 'Boa notícia: o maior bloco de sono desta semana está a ficar mais longo.',
        evidencePt: 'Maior bloco semanal em tendência positiva.',
        tone: InsightTone.positive,
        cooldownHours: 168,
        requiresDataDays: 7,
        requiresDob: false,
        ctaAction: InsightCtaAction.saveFavorite,
        ctaLabel: 'Guardar',
        sourcesRefs: [],
      ));
    }

    // === GROUP G: Consistência do início da noite ===

    // Card 17: bedtime_variability_high
    if (availableDays >= 7 && 
        metrics.bedtimeVariabilityRangeMinutes != null &&
        metrics.bedtimeVariabilityRangeMinutes! >= 90) {
      triggered.add(SleepInsight(
        id: 'bedtime_variability_high',
        category: InsightCategory.consistency,
        priority: 20,
        messagePt: 'O início da noite tem variado bastante. Se conseguires, escolhe uma janela e repete por 3 dias — sem perfeccionismo.',
        evidencePt: 'Variação de início de noite elevada (±${metrics.bedtimeVariabilityRangeMinutes} min).',
        tone: InsightTone.attention,
        cooldownHours: 72,
        requiresDataDays: 7,
        requiresDob: false,
        ctaAction: InsightCtaAction.openChecklist,
        ctaLabel: 'Ver como',
        sourcesRefs: ['AAP_bedtime_routine'],
      ));
    }

    // Card 18: bedtime_consistency_good
    if (availableDays >= 7 && 
        metrics.bedtimeConsistencyMinutes != null &&
        metrics.bedtimeConsistencyMinutes! <= 30) {
      triggered.add(SleepInsight(
        id: 'bedtime_consistency_good',
        category: InsightCategory.consistency,
        priority: 45,
        messagePt: 'O início da noite tem sido consistente. Isso costuma facilitar as sestas e reduzir "lutas" na hora de deitar.',
        evidencePt: 'Variação baixa no início da noite (~${metrics.bedtimeConsistencyMinutes!.toStringAsFixed(0)} min).',
        tone: InsightTone.positive,
        cooldownHours: 168,
        requiresDataDays: 7,
        requiresDob: false,
        ctaAction: InsightCtaAction.saveFavorite,
        ctaLabel: 'Guardar',
        sourcesRefs: [],
      ));
    }

    // === GROUP H: Outliers / hoje diferente ===

    // Card 19: today_was_different
    if (availableDays >= 7 && 
        metrics.diffFromAvg7d != null &&
        metrics.diffFromAvg7d!.inMinutes.abs() > 90) {
      triggered.add(SleepInsight(
        id: 'today_was_different',
        category: InsightCategory.totalSleep,
        priority: 12,
        messagePt: 'Hoje foi um dia diferente do habitual. Faz sentido olhar para a semana em vez de um só dia.',
        evidencePt: 'Desvio grande vs média 7 dias (${metrics.diffFromAvg7dFormatted}).',
        tone: InsightTone.neutral,
        cooldownHours: 48,
        requiresDataDays: 7,
        requiresDob: false,
        ctaAction: InsightCtaAction.none,
        ctaLabel: 'Ver semana',
        sourcesRefs: [],
      ));
    }

    // === GROUP I: Ecrãs (AAP) ===

    // Card 20: screens_before_bed_12m_plus
    if (hasDob && (ageBand == SleepAgeBand.months12to18 || 
                   ageBand == SleepAgeBand.months18to24 ||
                   ageBand == SleepAgeBand.years2to3 ||
                   ageBand == SleepAgeBand.years3plus)) {
      triggered.add(SleepInsight(
        id: 'screens_before_bed_12m_plus',
        category: InsightCategory.general,
        priority: 70,
        messagePt: 'Se for possível, evita ecrãs perto da hora de deitar. Rotinas calmas ajudam o corpo a "desligar".',
        evidencePt: 'Higiene do sono.',
        tone: InsightTone.neutral,
        cooldownHours: 336, // 14 days
        requiresDataDays: 0,
        requiresDob: true,
        ageBands: [SleepAgeBand.months12to18, SleepAgeBand.months18to24, SleepAgeBand.years2to3, SleepAgeBand.years3plus],
        ctaAction: InsightCtaAction.openGuideAnchor,
        ctaLabel: 'Ler mais',
        sourcesRefs: ['AAP_screens'],
      ));
    }

    // === GROUP J: Cards utilitários ===

    // Card 21: no_dob_banner (rendered as banner, not card)
    if (!hasDob) {
      triggered.add(const SleepInsight(
        id: 'no_dob_banner',
        category: InsightCategory.general,
        priority: 5,
        messagePt: 'Adiciona a data de nascimento para insights por idade.',
        evidencePt: 'Data de nascimento não definida.',
        tone: InsightTone.neutral,
        cooldownHours: 0, // Always show
        requiresDataDays: 0,
        requiresDob: false,
        ctaAction: InsightCtaAction.openBabyProfile,
        ctaLabel: 'Adicionar agora',
      ));
    }

    // Card 22: few_data_learning
    if (availableDays < 3) {
      triggered.add(const SleepInsight(
        id: 'few_data_learning',
        category: InsightCategory.general,
        priority: 8,
        messagePt: 'Ainda estamos a aprender o padrão do teu bebé. Para já, foca-te no básico: ambiente noturno calmo e sono seguro.',
        evidencePt: 'Poucos dias de dados.',
        tone: InsightTone.neutral,
        cooldownHours: 24,
        requiresDataDays: 0,
        requiresDob: false,
        ctaAction: InsightCtaAction.openGuideAnchor,
        ctaLabel: 'Sono seguro',
      ));
    }

    // Sort by priority
    triggered.sort((a, b) => a.priority.compareTo(b.priority));

    return triggered;
  }
}
