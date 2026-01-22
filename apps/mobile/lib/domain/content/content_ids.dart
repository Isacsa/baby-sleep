/// Stable IDs for content (insights, guide sections, sources)
///
/// These IDs are used as keys in ARB files and assets.
/// They must remain stable to avoid breaking translations.
library;

/// Guide section IDs (match guide_index.json)
abstract class GuideSectionId {
  static const normalPorIdade = 'normal_por_idade';
  static const diaVsNoite = 'dia_vs_noite';
  static const rotinaAntesDormir = 'rotina_antes_dormir';
  static const sonoSeguro = 'sono_seguro';
  static const quandoPediatra = 'quando_pediatra';

  static const all = [
    normalPorIdade,
    diaVsNoite,
    rotinaAntesDormir,
    sonoSeguro,
    quandoPediatra,
  ];
}

/// Insight IDs (used in triggers and ARB)
abstract class InsightId {
  // Group A: Safe sleep
  static const safeSleepBackToSleep = 'safe_sleep_back_to_sleep';
  static const safeSleepRoomTemp = 'safe_sleep_room_temp';
  static const safeSleepSmoke = 'safe_sleep_smoke';
  static const whenCallPediatrician = 'when_call_pediatrician';

  // Group B: Day vs night
  static const dayNightLowStimulus = 'day_night_low_stimulus';
  static const dayNightMorningLight = 'day_night_morning_light';

  // Group C: Bedtime routine
  static const routineShortConsistent = 'routine_short_consistent';
  static const routineKeepSameOrder = 'routine_keep_same_order';

  // Group D: Age normalization
  static const ageNorm0to3Variability = 'age_norm_0_3_variability';
  static const ageNorm4to12Consolidation = 'age_norm_4_12_consolidation';
  static const ageNorm12to24Boundaries = 'age_norm_12_24_boundaries';

  // Group E: Below/within/above expected
  static const sleepBelowExpected = 'sleep_below_expected';
  static const sleepWithinExpected = 'sleep_within_expected';
  static const sleepAboveExpected = 'sleep_above_expected';

  // Group F: Fragmentation and blocks
  static const nightFragmentationHigh = 'night_fragmentation_high';
  static const largestBlockImproving = 'largest_block_improving';

  // Group G: Bedtime consistency
  static const bedtimeVariabilityHigh = 'bedtime_variability_high';
  static const bedtimeConsistencyGood = 'bedtime_consistency_good';

  // Group H: Outliers
  static const todayWasDifferent = 'today_was_different';

  // Group I: Screens
  static const screensBeforeBed12mPlus = 'screens_before_bed_12m_plus';

  // Group J: Utility
  static const noDobBanner = 'no_dob_banner';
  static const fewDataLearning = 'few_data_learning';

  // Summary cards
  static const summary24h = 'summary_24h';
  static const currentlySleeping = 'currently_sleeping';
}

/// Source IDs (match sources.json)
abstract class SourceId {
  static const aap = 'AAP';
  static const cdc = 'CDC';
  static const nhs = 'NHS';
  static const aasm = 'AASM';
  static const aapSafeSleep = 'AAP_safe_sleep';
  static const cdcSafeSleep = 'CDC_safe_sleep';
  static const nhsSafeSleep = 'NHS_safe_sleep';
  static const nhsDayNight = 'NHS_day_night';
  static const aapBedtimeRoutine = 'AAP_bedtime_routine';
  static const nhsBedtimeRoutine = 'NHS_bedtime_routine';
  static const aasmSleepDuration = 'AASM_sleep_duration';
  static const aapScreens = 'AAP_screens';
}
