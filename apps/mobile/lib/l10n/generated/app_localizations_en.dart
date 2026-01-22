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
  String get relaxTitle => 'Relax';

  @override
  String get relaxComingSoon => 'Coming soon';

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
}
