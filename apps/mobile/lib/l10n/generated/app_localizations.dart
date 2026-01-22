import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('pt'),
  ];

  /// The title of the application
  ///
  /// In en, this message translates to:
  /// **'Baby Sleep'**
  String get appTitle;

  /// Label for the sleep tab
  ///
  /// In en, this message translates to:
  /// **'Sleep'**
  String get tabSleep;

  /// Label for the stats tab
  ///
  /// In en, this message translates to:
  /// **'Stats'**
  String get tabStats;

  /// Label for the relax tab
  ///
  /// In en, this message translates to:
  /// **'Relax'**
  String get tabRelax;

  /// Label for the insights tab
  ///
  /// In en, this message translates to:
  /// **'Insights'**
  String get tabInsights;

  /// Greeting on the home page
  ///
  /// In en, this message translates to:
  /// **'Hello, how was the night?'**
  String get homeGreeting;

  /// Baby name display on home
  ///
  /// In en, this message translates to:
  /// **'Baby {name}'**
  String homeBabyName(String name);

  /// Button label to start sleep
  ///
  /// In en, this message translates to:
  /// **'Sleep Now'**
  String get homeSleepNow;

  /// Button label to end sleep
  ///
  /// In en, this message translates to:
  /// **'Wake Up'**
  String get homeWakeUp;

  /// Label before quick time chips
  ///
  /// In en, this message translates to:
  /// **'Started:'**
  String get homeStartedAgo;

  /// Button to select a custom time
  ///
  /// In en, this message translates to:
  /// **'Other time'**
  String get homeOtherTime;

  /// Label when already sleeping
  ///
  /// In en, this message translates to:
  /// **'Register past sleep:'**
  String get homeRegisterPastSleep;

  /// Button to register past sleep while already sleeping
  ///
  /// In en, this message translates to:
  /// **'Other time (past sleep)'**
  String get homeOtherTimePast;

  /// Label for today
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get dayToday;

  /// Label for yesterday
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get dayYesterday;

  /// Today with date
  ///
  /// In en, this message translates to:
  /// **'Today, {day} {month}'**
  String dayTodayWithDate(int day, String month);

  /// Yesterday with date
  ///
  /// In en, this message translates to:
  /// **'Yesterday, {day} {month}'**
  String dayYesterdayWithDate(int day, String month);

  /// Header for sleep sessions list
  ///
  /// In en, this message translates to:
  /// **'Sleep sessions'**
  String get sessionsSleep;

  /// Number of records
  ///
  /// In en, this message translates to:
  /// **'{count} records'**
  String sessionsCount(int count);

  /// Label for nap session
  ///
  /// In en, this message translates to:
  /// **'Nap'**
  String get sessionNap;

  /// Label for night sleep session
  ///
  /// In en, this message translates to:
  /// **'Night sleep'**
  String get sessionNight;

  /// Note for sessions that cross midnight
  ///
  /// In en, this message translates to:
  /// **'Crosses midnight'**
  String get sessionCrossMidnight;

  /// Note for sessions that started yesterday
  ///
  /// In en, this message translates to:
  /// **'Started yesterday'**
  String get sessionStartedYesterday;

  /// Label for ongoing sleep
  ///
  /// In en, this message translates to:
  /// **'Sleeping...'**
  String get sessionOngoing;

  /// Short label for ongoing session
  ///
  /// In en, this message translates to:
  /// **'in progress'**
  String get sessionInProgress;

  /// Empty state title
  ///
  /// In en, this message translates to:
  /// **'No records yet'**
  String get emptyStateNoRecords;

  /// Empty state subtitle
  ///
  /// In en, this message translates to:
  /// **'Sleep records will appear here'**
  String get emptyStateRecordsWillAppear;

  /// Stats page title
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get statsTitle;

  /// Week toggle label
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get statsWeek;

  /// Month toggle label
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get statsMonth;

  /// No stats data message
  ///
  /// In en, this message translates to:
  /// **'No data yet'**
  String get statsNoData;

  /// Average per day label
  ///
  /// In en, this message translates to:
  /// **'Avg/day'**
  String get statsAvgPerDay;

  /// Total naps label
  ///
  /// In en, this message translates to:
  /// **'Total naps'**
  String get statsTotalNaps;

  /// Days with records label
  ///
  /// In en, this message translates to:
  /// **'Days recorded'**
  String get statsDaysRecorded;

  /// Relax page title
  ///
  /// In en, this message translates to:
  /// **'Relax'**
  String get relaxTitle;

  /// Relax coming soon message
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get relaxComingSoon;

  /// Babies page title
  ///
  /// In en, this message translates to:
  /// **'Babies'**
  String get babiesTitle;

  /// Add baby button
  ///
  /// In en, this message translates to:
  /// **'Add baby'**
  String get babiesAddNew;

  /// Empty state for babies
  ///
  /// In en, this message translates to:
  /// **'No babies added yet'**
  String get babiesNoBabies;

  /// Baby age in months
  ///
  /// In en, this message translates to:
  /// **'{months} months'**
  String babiesAge(int months);

  /// Baby age in years
  ///
  /// In en, this message translates to:
  /// **'{years} year(s)'**
  String babiesAgeYears(int years);

  /// Login page title
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get loginTitle;

  /// Email field label
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get loginEmail;

  /// Password field label
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get loginPassword;

  /// Login button
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get loginButton;

  /// Register link
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get loginRegister;

  /// Cancel button
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// Save button
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// Delete button
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// Edit button
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get commonEdit;

  /// Retry button
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// OK button
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// Total sleep label in summary
  ///
  /// In en, this message translates to:
  /// **'Total sleep'**
  String get summaryTotalSleep;

  /// Nap count in summary
  ///
  /// In en, this message translates to:
  /// **'{count} naps'**
  String summaryNaps(int count);

  /// Session count in summary
  ///
  /// In en, this message translates to:
  /// **'{count} sessions'**
  String summarySessions(int count);

  /// Duration with hours and minutes
  ///
  /// In en, this message translates to:
  /// **'{hours}h {minutes}m'**
  String durationHours(int hours, int minutes);

  /// Duration in minutes only
  ///
  /// In en, this message translates to:
  /// **'{minutes}m'**
  String durationMinutes(int minutes);

  /// Generic error message
  ///
  /// In en, this message translates to:
  /// **'An error occurred'**
  String get errorGeneric;

  /// Network error message
  ///
  /// In en, this message translates to:
  /// **'Network error. Check your connection.'**
  String get errorNetwork;

  /// Error when no baby is selected
  ///
  /// In en, this message translates to:
  /// **'No baby selected'**
  String get errorNoBaby;

  /// Syncing status
  ///
  /// In en, this message translates to:
  /// **'Syncing...'**
  String get syncSyncing;

  /// Synced status
  ///
  /// In en, this message translates to:
  /// **'Synced'**
  String get syncSynced;

  /// Offline status
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get syncOffline;

  /// Pending sync count
  ///
  /// In en, this message translates to:
  /// **'{count} pending'**
  String syncPending(int count);

  /// Edit sleep sheet title
  ///
  /// In en, this message translates to:
  /// **'Edit sleep'**
  String get editSleepTitle;

  /// Start time label
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get editSleepStart;

  /// End time label
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get editSleepEnd;

  /// Validation error
  ///
  /// In en, this message translates to:
  /// **'End time must be after start'**
  String get editSleepEndAfterStart;

  /// Delete confirmation title
  ///
  /// In en, this message translates to:
  /// **'Delete sleep?'**
  String get deleteSleepTitle;

  /// Delete confirmation message
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete the sleep from {start} to {end}?'**
  String deleteSleepConfirm(String start, String end);

  /// Delete success message
  ///
  /// In en, this message translates to:
  /// **'Sleep deleted'**
  String get deleteSleepSuccess;

  /// Overlap warning title
  ///
  /// In en, this message translates to:
  /// **'Overlapping sleep exists'**
  String get overlapTitle;

  /// Replace button for overlap
  ///
  /// In en, this message translates to:
  /// **'Replace existing sleep'**
  String get overlapReplace;

  /// Replacement success message
  ///
  /// In en, this message translates to:
  /// **'Sleep replaced'**
  String get overlapReplaced;

  /// DST gap warning title
  ///
  /// In en, this message translates to:
  /// **'Invalid time'**
  String get dstInvalidTime;

  /// DST gap warning message
  ///
  /// In en, this message translates to:
  /// **'The time {time} does not exist on this day due to daylight saving time (DST).\n\nPlease choose another time.'**
  String dstTimeNotExist(String time);

  /// Loading banner for caregiver context
  ///
  /// In en, this message translates to:
  /// **'Preparing permissions...'**
  String get preparingPermissions;

  /// Prompt to select a baby
  ///
  /// In en, this message translates to:
  /// **'Select a baby'**
  String get selectBaby;

  /// Day picker title
  ///
  /// In en, this message translates to:
  /// **'Which day?'**
  String get whatDay;

  /// Chosen time label
  ///
  /// In en, this message translates to:
  /// **'Chosen time: {time}'**
  String chosenTime(String time);

  /// Warning when today with chosen time is future
  ///
  /// In en, this message translates to:
  /// **'Today at {time} is still in the future'**
  String todayIsFuture(String time);

  /// Other day option
  ///
  /// In en, this message translates to:
  /// **'Other day...'**
  String get otherDay;

  /// Future time error
  ///
  /// In en, this message translates to:
  /// **'Cannot register sleep in the future'**
  String get cannotRegisterFuture;

  /// Intent sheet title
  ///
  /// In en, this message translates to:
  /// **'What do you want to register?'**
  String get whatToRegister;

  /// Start time summary
  ///
  /// In en, this message translates to:
  /// **'Start: {day} at {time}'**
  String startAtTime(String day, String time);

  /// Option for still sleeping
  ///
  /// In en, this message translates to:
  /// **'Still sleeping'**
  String get stillSleeping;

  /// Option for complete sleep
  ///
  /// In en, this message translates to:
  /// **'Register complete sleep'**
  String get registerCompleteSleep;

  /// Already sleeping message
  ///
  /// In en, this message translates to:
  /// **'Already sleeping since {time}'**
  String sleepingSince(String time);

  /// Question for already sleeping modal
  ///
  /// In en, this message translates to:
  /// **'What do you want to do?'**
  String get whatToDo;

  /// Option to end current sleep
  ///
  /// In en, this message translates to:
  /// **'End sleep now'**
  String get endSleepNow;

  /// Option to register past sleep
  ///
  /// In en, this message translates to:
  /// **'Register complete past sleep'**
  String get registerPastCompleteSleep;

  /// Success message for ending sleep
  ///
  /// In en, this message translates to:
  /// **'Sleep ended'**
  String get sleepEnded;

  /// Start date picker title
  ///
  /// In en, this message translates to:
  /// **'When did sleep start?'**
  String get whenSleepStarted;

  /// End date picker title
  ///
  /// In en, this message translates to:
  /// **'When did they wake up?'**
  String get whenWokeUp;

  /// Start time picker help text
  ///
  /// In en, this message translates to:
  /// **'Sleep start time'**
  String get startTimeHelp;

  /// End time picker help text
  ///
  /// In en, this message translates to:
  /// **'Sleep end time'**
  String get endTimeHelp;

  /// Start future error
  ///
  /// In en, this message translates to:
  /// **'Start time cannot be in the future'**
  String get startCannotBeFuture;

  /// Midnight dialog title
  ///
  /// In en, this message translates to:
  /// **'Crossed midnight?'**
  String get crossedMidnight;

  /// Midnight dialog question
  ///
  /// In en, this message translates to:
  /// **'Start at {start} and end at {end}.\n\nDid the sleep cross midnight (slept last night, woke up this morning)?'**
  String crossedMidnightQuestion(String start, String end);

  /// No option for midnight dialog
  ///
  /// In en, this message translates to:
  /// **'No, correct'**
  String get noCorrect;

  /// Yes button
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// Future end time dialog title
  ///
  /// In en, this message translates to:
  /// **'End time in future'**
  String get endInFuture;

  /// Future end time error
  ///
  /// In en, this message translates to:
  /// **'End time cannot be in the future.'**
  String get endCannotBeFuture;

  /// Use current time button
  ///
  /// In en, this message translates to:
  /// **'Use now'**
  String get useNow;

  /// Sync modal title
  ///
  /// In en, this message translates to:
  /// **'Synchronization'**
  String get syncTitle;

  /// Sync now button
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get syncNow;

  /// No description provided for @monthJan.
  ///
  /// In en, this message translates to:
  /// **'Jan'**
  String get monthJan;

  /// No description provided for @monthFeb.
  ///
  /// In en, this message translates to:
  /// **'Feb'**
  String get monthFeb;

  /// No description provided for @monthMar.
  ///
  /// In en, this message translates to:
  /// **'Mar'**
  String get monthMar;

  /// No description provided for @monthApr.
  ///
  /// In en, this message translates to:
  /// **'Apr'**
  String get monthApr;

  /// No description provided for @monthMay.
  ///
  /// In en, this message translates to:
  /// **'May'**
  String get monthMay;

  /// No description provided for @monthJun.
  ///
  /// In en, this message translates to:
  /// **'Jun'**
  String get monthJun;

  /// No description provided for @monthJul.
  ///
  /// In en, this message translates to:
  /// **'Jul'**
  String get monthJul;

  /// No description provided for @monthAug.
  ///
  /// In en, this message translates to:
  /// **'Aug'**
  String get monthAug;

  /// No description provided for @monthSep.
  ///
  /// In en, this message translates to:
  /// **'Sep'**
  String get monthSep;

  /// No description provided for @monthOct.
  ///
  /// In en, this message translates to:
  /// **'Oct'**
  String get monthOct;

  /// No description provided for @monthNov.
  ///
  /// In en, this message translates to:
  /// **'Nov'**
  String get monthNov;

  /// No description provided for @monthDec.
  ///
  /// In en, this message translates to:
  /// **'Dec'**
  String get monthDec;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
