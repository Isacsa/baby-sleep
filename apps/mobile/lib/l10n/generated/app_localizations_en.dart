// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Baby Sleep';

  @override
  String get tabSleep => 'Sleep';

  @override
  String get tabStats => 'Stats';

  @override
  String get tabRelax => 'Relax';

  @override
  String get tabInsights => 'Insights';

  @override
  String get homeGreeting => 'Hello, how was the night?';

  @override
  String homeBabyName(String name) {
    return 'Baby $name';
  }

  @override
  String get homeSleepNow => 'Sleep Now';

  @override
  String get homeWakeUp => 'Wake Up';

  @override
  String get homeStartedAgo => 'Started:';

  @override
  String get homeOtherTime => 'Other time';

  @override
  String get homeRegisterPastSleep => 'Register past sleep:';

  @override
  String get homeOtherTimePast => 'Other time (past sleep)';

  @override
  String get dayToday => 'Today';

  @override
  String get dayYesterday => 'Yesterday';

  @override
  String dayTodayWithDate(int day, String month) {
    return 'Today, $day $month';
  }

  @override
  String dayYesterdayWithDate(int day, String month) {
    return 'Yesterday, $day $month';
  }

  @override
  String get sessionsSleep => 'Sleep sessions';

  @override
  String sessionsCount(int count) {
    return '$count records';
  }

  @override
  String get sessionNap => 'Nap';

  @override
  String get sessionNight => 'Night sleep';

  @override
  String get sessionCrossMidnight => 'Crosses midnight';

  @override
  String get sessionStartedYesterday => 'Started yesterday';

  @override
  String get sessionOngoing => 'Sleeping...';

  @override
  String get sessionInProgress => 'in progress';

  @override
  String get emptyStateNoRecords => 'No records yet';

  @override
  String get emptyStateRecordsWillAppear => 'Sleep records will appear here';

  @override
  String get statsTitle => 'Statistics';

  @override
  String get statsWeek => 'Week';

  @override
  String get statsMonth => 'Month';

  @override
  String get statsNoData => 'No data yet';

  @override
  String get statsAvgPerDay => 'Avg/day';

  @override
  String get statsTotalNaps => 'Total naps';

  @override
  String get statsDaysRecorded => 'Days recorded';

  @override
  String get statsPeriodDay => 'Day';

  @override
  String get statsPeriod14Days => '14 days';

  @override
  String get statsPeriodCustom => 'Custom';

  @override
  String statsPeriodLabel(int days) {
    return 'Last $days days';
  }

  @override
  String get statsTypeAll => 'All';

  @override
  String get statsTypeNight => 'Night';

  @override
  String get statsTypeNaps => 'Naps';

  @override
  String get statsCompare => 'Compare';

  @override
  String get statsExport => 'Export';

  @override
  String get statsBasedOnLocalData => 'Based on local data';

  @override
  String get statsComparedWithPrevious => 'compared with previous period';

  @override
  String get statsDataQualityGood => 'Good';

  @override
  String get statsDataQualityPartial => 'Partial';

  @override
  String get statsDataQualityIncomplete => 'Incomplete';

  @override
  String get statsDataQualityDetails => 'See details';

  @override
  String get statsDataQualityTitle => 'Data quality';

  @override
  String get statsDataQualityGoodDesc => 'Complete and consistent data';

  @override
  String get statsDataQualityPartialDesc => 'May be underestimated';

  @override
  String get statsDataQualityIncompleteDesc =>
      'Insufficient data for accurate analysis';

  @override
  String statsDataQualityIssueMissingDays(int count) {
    return '$count days without records';
  }

  @override
  String get statsDataQualityIssueOngoingLong => 'Sleep ongoing for over 18h';

  @override
  String statsDataQualityIssueImprobable(int count) {
    return '$count improbable durations';
  }

  @override
  String statsDataQualityIssueOverlaps(int count) {
    return '$count overlaps detected';
  }

  @override
  String get statsDataQualityActionReviewDay => 'Review day';

  @override
  String get statsDataQualityActionEndSleep => 'End sleep';

  @override
  String get statsDataQualityActionEditSession => 'Edit session';

  @override
  String get statsKpiMedianTotal => 'Median/day';

  @override
  String get statsKpiNightVsNaps => 'Night vs Naps';

  @override
  String get statsKpiLongestBlock => 'Longest block';

  @override
  String get statsKpiFragmentation => 'Fragmentation';

  @override
  String get statsKpiBedtimeConsistency => 'Bedtime consistency';

  @override
  String get statsKpiEpisodesPerNight => 'episodes/night';

  @override
  String get statsKpiNoEnoughData => 'Not enough data';

  @override
  String get statsChartTotalPerDay => 'Total sleep per day';

  @override
  String get statsChartNightVsNaps => 'Night vs Naps';

  @override
  String get statsChartBedtimeConsistency => 'Bedtime';

  @override
  String get statsChartNapDistribution => 'Nap distribution';

  @override
  String get statsChartNapShort => '<30m';

  @override
  String get statsChartNap30to60 => '30-60m';

  @override
  String get statsChartNap60to90 => '60-90m';

  @override
  String get statsChartNapLong => '>90m';

  @override
  String get statsTimelineTitle => 'Timeline';

  @override
  String get statsTimelineEmpty => 'No records this day';

  @override
  String get statsTimelineIncomplete => 'Incomplete data';

  @override
  String get statsTimelineOngoing => 'Ongoing sleep';

  @override
  String get statsTimelineOverlap => 'Overlap';

  @override
  String get statsExportTitle => 'Export data';

  @override
  String get statsExportPdf => 'PDF';

  @override
  String get statsExportCsv => 'CSV';

  @override
  String get statsExportPeriod7 => '7 days';

  @override
  String get statsExportPeriod14 => '14 days';

  @override
  String get statsExportPeriod30 => '30 days';

  @override
  String get statsExportPeriodCustom => 'Selected period';

  @override
  String get statsExportCsvSessions => 'Sessions';

  @override
  String get statsExportCsvAggregates => 'Daily aggregates';

  @override
  String get statsExportCsvBoth => 'Both';

  @override
  String get statsExportIncludeName => 'Include baby name';

  @override
  String get statsExportGenerate => 'Generate and share';

  @override
  String get statsExportPreviewPdf => 'Summary with KPIs, charts and timeline';

  @override
  String get statsExportPreviewCsv => 'Tabular data for analysis';

  @override
  String get statsEmptyState => 'No sleep records yet';

  @override
  String get statsEmptyStateCta => 'Go to Sleep';

  @override
  String get statsGoToSleep => 'Register sleep';

  @override
  String get relaxTitle => 'Relax';

  @override
  String get relaxComingSoon => 'Coming soon';

  @override
  String get relaxModeNow => 'Now Mode';

  @override
  String get relaxNightMode => 'Night mode';

  @override
  String get relaxNightModeBadge => 'Night';

  @override
  String get relaxSounds => 'Sounds';

  @override
  String get relaxQuickGuides => 'Quick guides';

  @override
  String get relaxSleepShortcuts => 'Sleep shortcuts';

  @override
  String get relaxSoundWhiteNoise => 'White Noise';

  @override
  String get relaxSoundRain => 'Rain';

  @override
  String get relaxSoundFan => 'Fan';

  @override
  String get relaxSoundShush => 'Shushing';

  @override
  String get relaxPlay => 'Play';

  @override
  String get relaxPause => 'Pause';

  @override
  String get relaxStop => 'Stop';

  @override
  String get relaxResume => 'Resume';

  @override
  String get relaxVolume => 'Volume';

  @override
  String get relaxVolumeLow => 'low';

  @override
  String get relaxVolumeHigh => 'high';

  @override
  String get relaxVolumeHighWarning =>
      'If the indicator is in the high zone, consider lowering the volume.';

  @override
  String get relaxVolumeSafetyTip =>
      'Low volume and device away from the crib.';

  @override
  String get relaxTimer => 'Timer';

  @override
  String get relaxTimerInfinite => '∞';

  @override
  String relaxTimerMinutes(int minutes) {
    return '${minutes}min';
  }

  @override
  String get relaxFadeOut => 'Fade-out';

  @override
  String get relaxFadeOutEnabled => 'enabled';

  @override
  String get relaxFadeOutDisabled => 'disabled';

  @override
  String get relaxDarkScreen => 'Dark screen';

  @override
  String get relaxSaveConfig => 'Save configuration';

  @override
  String get relaxFavorites => 'Favorites';

  @override
  String get relaxNoFavorites => 'No favorites yet';

  @override
  String get relaxFavoriteSaved => 'Configuration saved to favorites';

  @override
  String get relaxFavoriteRemoved => 'Removed from favorites';

  @override
  String get relaxSafetyChecklist => 'Safe sleep checklist';

  @override
  String get relaxSafetyChecklistShort => 'Checklist (10s)';

  @override
  String get relaxBreathing60s => 'Breathing 60s';

  @override
  String get relaxGoToSleep => 'Go to Sleep';

  @override
  String get relaxStartSleep => 'Start sleep';

  @override
  String get relaxEndSleep => 'End sleep';

  @override
  String get relaxSleepOngoing => 'Sleep ongoing';

  @override
  String get relaxAwake => 'Awake';

  @override
  String get relaxAudioUnavailable =>
      'Audio unavailable on this device. Continue using the guides below.';

  @override
  String get relaxAudioError => 'Could not start audio.';

  @override
  String get relaxTryAgain => 'Try again';

  @override
  String get relaxHelp => 'Help';

  @override
  String get relaxInterrupted => 'Playback interrupted';

  @override
  String get relaxBackgroundWarning =>
      'In background, sound may stop on this device. Keep the app open to continue.';

  @override
  String get relaxDisclaimer =>
      'This is practical and safe support. It doesn\'t guarantee sleep. If you have medical concerns, talk to a professional.';

  @override
  String get relaxSofaWarning =>
      'Avoid falling asleep with the baby on the sofa/armchair — this is one of the highest risk scenarios.';

  @override
  String get relaxSafetyNote =>
      'If you\'re feeling sleepy, put the baby in a safe place.';

  @override
  String get relaxSources => 'Sources: AAP/CDC/NHS.';

  @override
  String get babiesTitle => 'Babies';

  @override
  String get babiesAddNew => 'Add baby';

  @override
  String get babiesNoBabies => 'No babies added yet';

  @override
  String babiesAge(int months) {
    return '$months months';
  }

  @override
  String babiesAgeYears(int years) {
    return '$years year(s)';
  }

  @override
  String get babiesPullGlobal => 'Pull Babies (Global)';

  @override
  String get babiesNew => 'New';

  @override
  String get babiesErrorLoading => 'Error loading babies';

  @override
  String get babiesNameLabel => 'Baby name';

  @override
  String get babiesNameHint => 'e.g., Emma';

  @override
  String babiesCreatedSuccess(String name) {
    return 'Baby \"$name\" created';
  }

  @override
  String babiesCreatedError(String error) {
    return 'Failed to create baby: $error';
  }

  @override
  String get menuLogout => 'Logout';

  @override
  String get menuDebug => 'Debug';

  @override
  String get loginTitle => 'Welcome';

  @override
  String get loginEmail => 'Email';

  @override
  String get loginPassword => 'Password';

  @override
  String get loginButton => 'Sign in';

  @override
  String get loginRegister => 'Create account';

  @override
  String get loginUseDifferentEmail => 'Use a different email';

  @override
  String get loginInvalidEmail => 'Please enter a valid email address';

  @override
  String get loginMagicLinkSent =>
      'Magic link sent! Check your email and tap the link to sign in.';

  @override
  String get loginMagicLinkFailed =>
      'Failed to send magic link. Please try again.';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonSave => 'Save';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonOk => 'OK';

  @override
  String get summaryTotalSleep => 'Total sleep';

  @override
  String get totalLabel => 'total';

  @override
  String summaryNaps(int count) {
    return '$count naps';
  }

  @override
  String summarySessions(int count) {
    return '$count sessions';
  }

  @override
  String durationHours(int hours, int minutes) {
    return '${hours}h ${minutes}m';
  }

  @override
  String durationMinutes(int minutes) {
    return '${minutes}m';
  }

  @override
  String get errorGeneric => 'An error occurred';

  @override
  String get errorNetwork => 'Network error. Check your connection.';

  @override
  String get errorNoBaby => 'No baby selected';

  @override
  String get syncSyncing => 'Syncing...';

  @override
  String get syncSynced => 'Synced';

  @override
  String get syncOffline => 'Offline';

  @override
  String syncPending(int count) {
    return '$count pending';
  }

  @override
  String get editSleepTitle => 'Edit sleep';

  @override
  String get editSleepStart => 'Start';

  @override
  String get editSleepEnd => 'End';

  @override
  String get editSleepEndAfterStart => 'End time must be after start';

  @override
  String get editSleepSuccess => 'Sleep edited';

  @override
  String errorWithMessage(String message) {
    return 'Error: $message';
  }

  @override
  String get overlapOtherSleep => 'Overlaps other sleep';

  @override
  String overlapNewPeriodMessage(String sessions) {
    return 'The new period overlaps: $sessions\n\nDo you want to replace?';
  }

  @override
  String sinceSomething(String time) {
    return 'since $time';
  }

  @override
  String get deleteSleepTitle => 'Delete sleep?';

  @override
  String deleteSleepConfirm(String start, String end) {
    return 'Are you sure you want to delete the sleep from $start to $end?';
  }

  @override
  String get deleteSleepSuccess => 'Sleep deleted';

  @override
  String get overlapTitle => 'Overlapping sleep exists';

  @override
  String get overlapReplace => 'Replace existing sleep';

  @override
  String get overlapReplaced => 'Sleep replaced';

  @override
  String get dstInvalidTime => 'Invalid time';

  @override
  String dstTimeNotExist(String time) {
    return 'The time $time does not exist on this day due to daylight saving time (DST).\n\nPlease choose another time.';
  }

  @override
  String get preparingPermissions => 'Preparing permissions...';

  @override
  String get selectBaby => 'Select a baby';

  @override
  String get whatDay => 'Which day?';

  @override
  String chosenTime(String time) {
    return 'Chosen time: $time';
  }

  @override
  String todayIsFuture(String time) {
    return 'Today at $time is still in the future';
  }

  @override
  String get otherDay => 'Other day...';

  @override
  String get cannotRegisterFuture => 'Cannot register sleep in the future';

  @override
  String get whatToRegister => 'What do you want to register?';

  @override
  String startAtTime(String day, String time) {
    return 'Start: $day at $time';
  }

  @override
  String get stillSleeping => 'Still sleeping';

  @override
  String get registerCompleteSleep => 'Register complete sleep';

  @override
  String sleepingSince(String time) {
    return 'Already sleeping since $time';
  }

  @override
  String get whatToDo => 'What do you want to do?';

  @override
  String get endSleepNow => 'End sleep now';

  @override
  String get registerPastCompleteSleep => 'Register complete past sleep';

  @override
  String get sleepEnded => 'Sleep ended';

  @override
  String get whenSleepStarted => 'When did sleep start?';

  @override
  String get whenWokeUp => 'When did they wake up?';

  @override
  String get startTimeHelp => 'Sleep start time';

  @override
  String get endTimeHelp => 'Sleep end time';

  @override
  String get startCannotBeFuture => 'Start time cannot be in the future';

  @override
  String get crossedMidnight => 'Crossed midnight?';

  @override
  String crossedMidnightQuestion(String start, String end) {
    return 'Start at $start and end at $end.\n\nDid the sleep cross midnight (slept last night, woke up this morning)?';
  }

  @override
  String get noCorrect => 'No, correct';

  @override
  String get yes => 'Yes';

  @override
  String get endInFuture => 'End time in future';

  @override
  String get endCannotBeFuture => 'End time cannot be in the future.';

  @override
  String get useNow => 'Use now';

  @override
  String get syncTitle => 'Synchronization';

  @override
  String get syncNow => 'Sync now';

  @override
  String get menuSwitchBaby => 'Switch baby';

  @override
  String get unknownTime => 'unknown time';

  @override
  String ongoingSince(String time) {
    return 'since $time (ongoing)';
  }

  @override
  String get overlapMessage =>
      'The new record overlaps with existing sleep(s). Do you want to replace?';

  @override
  String errorOverwriting(String error) {
    return 'Error replacing: $error';
  }

  @override
  String get pickDay => 'Pick day';

  @override
  String get noPermissionToCreate =>
      'You don\'t have permission to create events.';

  @override
  String get preparingPermissionsWait =>
      'Preparing permissions. Please wait a moment.';

  @override
  String get monthJan => 'Jan';

  @override
  String get monthFeb => 'Feb';

  @override
  String get monthMar => 'Mar';

  @override
  String get monthApr => 'Apr';

  @override
  String get monthMay => 'May';

  @override
  String get monthJun => 'Jun';

  @override
  String get monthJul => 'Jul';

  @override
  String get monthAug => 'Aug';

  @override
  String get monthSep => 'Sep';

  @override
  String get monthOct => 'Oct';

  @override
  String get monthNov => 'Nov';

  @override
  String get monthDec => 'Dec';

  @override
  String get insightsTitle => 'Insights';

  @override
  String get insightsHeaderToday => 'Today';

  @override
  String insightsHeaderBasedOn(int days) {
    return 'Based on $days days';
  }

  @override
  String get insightsHeaderPatterns => 'Detected patterns';

  @override
  String get insightsHeaderRoutine => 'Suggested routine';

  @override
  String get insightsHeaderGuide => 'Guide';

  @override
  String get insightsAddDob => 'Add birth date';

  @override
  String get insightsAddDobBanner =>
      'To personalize age-based insights, add the birth date';

  @override
  String get insightsAddNow => 'Add now';

  @override
  String get insightsMainPoint => 'Main point';

  @override
  String get insightsNextStep => 'Next step';

  @override
  String get insightsSavedFavorites => 'Saved to favorites';

  @override
  String get insightsSuggestionLabel => 'suggestion';

  @override
  String get insightsDefineDobForAge =>
      'Add birth date for age-based suggestions.';

  @override
  String get insightsToSeePersonalized => 'To see personalized insights.';

  @override
  String get insightsNoRecordsYet => 'No sleep records yet';

  @override
  String get insightsRecordFirstSleep =>
      'Record your first sleep in the \"Sleep\" tab to start seeing insights.';

  @override
  String get insightsRegisterSleep => 'Register sleep';

  @override
  String get insightsCollectingPatterns =>
      'Still collecting data to identify patterns.';

  @override
  String get insightsRegisterMoreNights =>
      'Record a few more nights to receive personalized routine suggestions.';

  @override
  String insightsVsAvg7Days(String diff) {
    return '$diff vs 7 day average';
  }

  @override
  String get insightsNoDobFallback => 'General insights (no age band)';

  @override
  String get insightsLearning => 'Still learning your baby\'s pattern';

  @override
  String get insightsMoreDataNeeded => 'We need a few more days of data';

  @override
  String get insightsSourcesTitle => 'Sources';

  @override
  String get insightsDisclaimerMedical =>
      'This content is informational and does not replace medical advice.';

  @override
  String get insightSummary24hTitle => '24h summary';

  @override
  String insightSummary24hBody(int hours, int minutes) {
    return 'Total sleep: ${hours}h ${minutes}m';
  }

  @override
  String insightSummary24hVsAvg(String sign, int minutes) {
    return '$sign${minutes}m vs 7 day average';
  }

  @override
  String get insightSummary24hNoData => 'Not enough data yet';

  @override
  String get insightCurrentlySleepingTitle => 'Sleeping';

  @override
  String insightCurrentlySleepingBody(String time) {
    return 'Sleeping since $time';
  }

  @override
  String get insightSleepBelowExpectedTitle => 'Sleep below expected';

  @override
  String get insightSleepBelowExpectedBody =>
      'Sleep in the last 24h is slightly below recommended for this age.';

  @override
  String insightSleepBelowExpectedWhy(int min, int max) {
    return 'Compared to the typical range ($min–${max}h).';
  }

  @override
  String get insightSleepWithinExpectedTitle => 'Sleep within expected';

  @override
  String get insightSleepWithinExpectedBody =>
      'Sleep is within the recommended range for this age.';

  @override
  String get insightSleepAboveExpectedTitle => 'Sleep above expected';

  @override
  String get insightSleepAboveExpectedBody =>
      'Sleep is above the typical range. Usually not a concern.';

  @override
  String get insightBedtimeVariabilityHighTitle => 'Variable bedtime';

  @override
  String insightBedtimeVariabilityHighBody(int minutes) {
    return 'Bedtime varied by ±${minutes}min in recent days.';
  }

  @override
  String get insightBedtimeVariabilityHighWhy =>
      'Consistency in bedtime can help regulate sleep.';

  @override
  String get insightBedtimeConsistencyGoodTitle => 'Good bedtime consistency';

  @override
  String get insightBedtimeConsistencyGoodBody =>
      'Bedtime has been consistent. Keep it up!';

  @override
  String get insightNightFragmentationHighTitle => 'Fragmented nights';

  @override
  String get insightNightFragmentationHighBody =>
      'Nights have had multiple awakenings.';

  @override
  String insightNightFragmentationHighWhy(int count) {
    return 'Average of $count awakenings per night.';
  }

  @override
  String get insightLargestBlockImprovingTitle => 'Night block improving';

  @override
  String get insightLargestBlockImprovingBody =>
      'The longest night sleep block is increasing.';

  @override
  String get insightTodayWasDifferentTitle => 'Today was different';

  @override
  String get insightTodayWasDifferentBody =>
      'Today\'s sleep differed significantly from the recent average.';

  @override
  String get insightAgeNorm0to3Title => 'Variability is normal';

  @override
  String get insightAgeNorm0to3Body =>
      'In the first months, it\'s normal for sleep to vary a lot day to day.';

  @override
  String get insightAgeNorm4to12Title => 'Consolidation in progress';

  @override
  String get insightAgeNorm4to12Body =>
      'At this stage, night sleep starts consolidating naturally.';

  @override
  String get insightAgeNorm12to24Title => 'Testing limits is normal';

  @override
  String get insightAgeNorm12to24Body =>
      'Resisting bedtime is common at this age. Stay calm!';

  @override
  String get insightSafeSleepBackToSleepTitle => 'Safe sleep: on back';

  @override
  String get insightSafeSleepBackToSleepBody =>
      'Remember: babies should always sleep on their back.';

  @override
  String get insightDayNightLowStimulusTitle => 'Low stimulus at night';

  @override
  String get insightDayNightLowStimulusBody =>
      'Calm interactions and low light at night help establish day vs night.';

  @override
  String get insightRoutineShortConsistentTitle => 'Short consistent routine';

  @override
  String get insightRoutineShortConsistentBody =>
      'A simple 2–4 step routine before bed can help.';

  @override
  String get insightWhenCallPediatricianTitle =>
      'When to contact the pediatrician';

  @override
  String get insightWhenCallPediatricianBody =>
      'If something concerns you, don\'t hesitate to consult the doctor.';

  @override
  String get insightFewDataLearningTitle => 'Still learning';

  @override
  String get insightFewDataLearningBody =>
      'We need a few more days of data to generate personalized insights.';

  @override
  String get insightCtaLearnMore => 'Learn more';

  @override
  String get insightCtaSave => 'Save';

  @override
  String get insightCtaCheckGuide => 'Check guide';

  @override
  String get insightCtaOpenGuide => 'Open guide';

  @override
  String get insightCtaTryThis => 'Try this';

  @override
  String get insightCtaWhyThis => 'Why this?';

  @override
  String get insightCtaDismiss => 'Dismiss';

  @override
  String get routineSuggestionTitle => 'Routine suggestion';

  @override
  String get routineNextNap => 'Next nap';

  @override
  String routineNextNapWindow(String start, String end) {
    return 'Window: $start–$end';
  }

  @override
  String routineNextNapSuggested(String time) {
    return 'Suggested: $time';
  }

  @override
  String get routineBedtime => 'Bedtime';

  @override
  String routineBedtimeWindow(String start, String end) {
    return 'Window: $start–$end';
  }

  @override
  String routineBedtimeSuggested(String time) {
    return 'Suggested: $time';
  }

  @override
  String get routineNoData => 'Not enough data to suggest yet';

  @override
  String get routineCurrentlySleeping => 'Sleeping — rest well!';

  @override
  String get routineNapWindowPassed => 'The nap window has passed';

  @override
  String get routineExplanation => 'Based on recent patterns';

  @override
  String routineNapCount(int count) {
    return '$count naps expected';
  }

  @override
  String routineNapDuration(int minutes) {
    return '~${minutes}min each';
  }

  @override
  String get guide_normal_por_idade_title => 'What\'s normal by age';

  @override
  String get guide_normal_por_idade_subtitle =>
      'Sleep expectations 0–24 months';

  @override
  String get guide_dia_vs_noite_title => 'Day vs Night';

  @override
  String get guide_dia_vs_noite_subtitle => 'How to help the circadian rhythm';

  @override
  String get guide_rotina_antes_dormir_title => 'Bedtime routine';

  @override
  String get guide_rotina_antes_dormir_subtitle => 'Simple steps to help';

  @override
  String get guide_sono_seguro_title => 'Safe sleep';

  @override
  String get guide_sono_seguro_subtitle => 'Recommended practices';

  @override
  String get guide_quando_pediatra_title => 'When to talk to the pediatrician';

  @override
  String get guide_quando_pediatra_subtitle => 'Warning signs';

  @override
  String get guideOpenSection => 'Open';

  @override
  String get guideBackToList => 'Back';

  @override
  String get guideDisclaimer =>
      'This content is informational and does not replace personalized medical advice.';

  @override
  String get cockpitTodayLabel => 'Today';

  @override
  String cockpitRecommended(String range) {
    return 'Recommended: $range';
  }

  @override
  String cockpitReference(String range) {
    return 'Reference: $range';
  }

  @override
  String get cockpitAddDobForGoal => 'Add birth date for age-based goals';

  @override
  String get cockpitAddDob => 'Add DOB';

  @override
  String get cockpitNoDataYet => 'When you record sleep, progress shows here.';

  @override
  String get cockpitBuildingTrend => 'Building trend with more records.';

  @override
  String get cockpitApproachingReference => 'Approaching reference zone.';

  @override
  String get cockpitApproachingMin => 'Heading to recommended minimum.';

  @override
  String get cockpitWithinReference => 'Within reference.';

  @override
  String get cockpitWithinRange => 'Within recommended range.';

  @override
  String get cockpitDifferentToday => 'Today was different — look at the week.';

  @override
  String get cockpitUpdatingWhileSleeping => 'Updating while sleeping.';

  @override
  String get cockpitInProgress => 'In progress';

  @override
  String get predictionTitle => 'Likely next sleep';

  @override
  String get predictionCollecting =>
      'Collecting pattern — record a few more sleeps.';

  @override
  String get predictionSleepingNow =>
      'Sleeping now — prediction available after waking.';

  @override
  String get predictionDataQualityLow =>
      'Review records to improve prediction.';

  @override
  String get predictionWindowPassed =>
      'Window has passed — today was atypical.';

  @override
  String predictionConfidence(String level) {
    return 'Confidence: $level';
  }

  @override
  String predictionBasedOn(int count) {
    return 'Based on last $count gaps between sleeps.';
  }

  @override
  String get predictionRemindMe => 'Remind me';

  @override
  String get predictionRemindMeSoon => 'Coming soon';

  @override
  String get predictionHowWeCalculate => 'How we calculate';

  @override
  String get predictionExplainTitle => 'How prediction works';

  @override
  String get predictionExplain1 => 'We look at recent gaps between sleeps.';

  @override
  String get predictionExplain2 =>
      'We use the median to reduce impact of atypical days.';

  @override
  String get predictionExplain3 =>
      'The window widens when there\'s more variability.';

  @override
  String get predictionDataPartial => 'Data: Partial';

  @override
  String get predictionDataIncomplete => 'Data: Incomplete';

  @override
  String get predictionSeeDetails => 'See details';

  @override
  String get dataQualityTitle => 'Data quality';

  @override
  String get dataQualityGood => 'Good';

  @override
  String get dataQualityPartial => 'Partial';

  @override
  String get dataQualityIncomplete => 'Incomplete';

  @override
  String get dataQualityWarning => 'Prediction may be less accurate today.';

  @override
  String get dataQualitySeeDetails => 'See details';

  @override
  String get timelineTitle => 'Today';

  @override
  String get timelineSeeAll => 'See all';

  @override
  String get timelineSeeMore => 'See more';

  @override
  String get timelineNoRecords => 'No records today yet';

  @override
  String get timelineAddManual => 'Add manual';

  @override
  String get quickActionsAddManual => 'Add manual';

  @override
  String get quickActionsEditLast => 'Edit last';

  @override
  String get quickActionsViewDay => 'View day';
}
