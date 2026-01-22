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

  /// No description provided for @statsPeriodDay.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get statsPeriodDay;

  /// No description provided for @statsPeriod14Days.
  ///
  /// In en, this message translates to:
  /// **'14 days'**
  String get statsPeriod14Days;

  /// No description provided for @statsPeriodCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get statsPeriodCustom;

  /// No description provided for @statsPeriodLabel.
  ///
  /// In en, this message translates to:
  /// **'Last {days} days'**
  String statsPeriodLabel(int days);

  /// No description provided for @statsTypeAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get statsTypeAll;

  /// No description provided for @statsTypeNight.
  ///
  /// In en, this message translates to:
  /// **'Night'**
  String get statsTypeNight;

  /// No description provided for @statsTypeNaps.
  ///
  /// In en, this message translates to:
  /// **'Naps'**
  String get statsTypeNaps;

  /// No description provided for @statsCompare.
  ///
  /// In en, this message translates to:
  /// **'Compare'**
  String get statsCompare;

  /// No description provided for @statsExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get statsExport;

  /// No description provided for @statsBasedOnLocalData.
  ///
  /// In en, this message translates to:
  /// **'Based on local data'**
  String get statsBasedOnLocalData;

  /// No description provided for @statsComparedWithPrevious.
  ///
  /// In en, this message translates to:
  /// **'compared with previous period'**
  String get statsComparedWithPrevious;

  /// No description provided for @statsDataQualityGood.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get statsDataQualityGood;

  /// No description provided for @statsDataQualityPartial.
  ///
  /// In en, this message translates to:
  /// **'Partial'**
  String get statsDataQualityPartial;

  /// No description provided for @statsDataQualityIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Incomplete'**
  String get statsDataQualityIncomplete;

  /// No description provided for @statsDataQualityDetails.
  ///
  /// In en, this message translates to:
  /// **'See details'**
  String get statsDataQualityDetails;

  /// No description provided for @statsDataQualityTitle.
  ///
  /// In en, this message translates to:
  /// **'Data quality'**
  String get statsDataQualityTitle;

  /// No description provided for @statsDataQualityGoodDesc.
  ///
  /// In en, this message translates to:
  /// **'Complete and consistent data'**
  String get statsDataQualityGoodDesc;

  /// No description provided for @statsDataQualityPartialDesc.
  ///
  /// In en, this message translates to:
  /// **'May be underestimated'**
  String get statsDataQualityPartialDesc;

  /// No description provided for @statsDataQualityIncompleteDesc.
  ///
  /// In en, this message translates to:
  /// **'Insufficient data for accurate analysis'**
  String get statsDataQualityIncompleteDesc;

  /// No description provided for @statsDataQualityIssueMissingDays.
  ///
  /// In en, this message translates to:
  /// **'{count} days without records'**
  String statsDataQualityIssueMissingDays(int count);

  /// No description provided for @statsDataQualityIssueOngoingLong.
  ///
  /// In en, this message translates to:
  /// **'Sleep ongoing for over 18h'**
  String get statsDataQualityIssueOngoingLong;

  /// No description provided for @statsDataQualityIssueImprobable.
  ///
  /// In en, this message translates to:
  /// **'{count} improbable durations'**
  String statsDataQualityIssueImprobable(int count);

  /// No description provided for @statsDataQualityIssueOverlaps.
  ///
  /// In en, this message translates to:
  /// **'{count} overlaps detected'**
  String statsDataQualityIssueOverlaps(int count);

  /// No description provided for @statsDataQualityActionReviewDay.
  ///
  /// In en, this message translates to:
  /// **'Review day'**
  String get statsDataQualityActionReviewDay;

  /// No description provided for @statsDataQualityActionEndSleep.
  ///
  /// In en, this message translates to:
  /// **'End sleep'**
  String get statsDataQualityActionEndSleep;

  /// No description provided for @statsDataQualityActionEditSession.
  ///
  /// In en, this message translates to:
  /// **'Edit session'**
  String get statsDataQualityActionEditSession;

  /// No description provided for @statsKpiMedianTotal.
  ///
  /// In en, this message translates to:
  /// **'Median/day'**
  String get statsKpiMedianTotal;

  /// No description provided for @statsKpiNightVsNaps.
  ///
  /// In en, this message translates to:
  /// **'Night vs Naps'**
  String get statsKpiNightVsNaps;

  /// No description provided for @statsKpiLongestBlock.
  ///
  /// In en, this message translates to:
  /// **'Longest block'**
  String get statsKpiLongestBlock;

  /// No description provided for @statsKpiFragmentation.
  ///
  /// In en, this message translates to:
  /// **'Fragmentation'**
  String get statsKpiFragmentation;

  /// No description provided for @statsKpiBedtimeConsistency.
  ///
  /// In en, this message translates to:
  /// **'Bedtime consistency'**
  String get statsKpiBedtimeConsistency;

  /// No description provided for @statsKpiEpisodesPerNight.
  ///
  /// In en, this message translates to:
  /// **'episodes/night'**
  String get statsKpiEpisodesPerNight;

  /// No description provided for @statsKpiNoEnoughData.
  ///
  /// In en, this message translates to:
  /// **'Not enough data'**
  String get statsKpiNoEnoughData;

  /// No description provided for @statsChartTotalPerDay.
  ///
  /// In en, this message translates to:
  /// **'Total sleep per day'**
  String get statsChartTotalPerDay;

  /// No description provided for @statsChartNightVsNaps.
  ///
  /// In en, this message translates to:
  /// **'Night vs Naps'**
  String get statsChartNightVsNaps;

  /// No description provided for @statsChartBedtimeConsistency.
  ///
  /// In en, this message translates to:
  /// **'Bedtime'**
  String get statsChartBedtimeConsistency;

  /// No description provided for @statsChartNapDistribution.
  ///
  /// In en, this message translates to:
  /// **'Nap distribution'**
  String get statsChartNapDistribution;

  /// No description provided for @statsChartNapShort.
  ///
  /// In en, this message translates to:
  /// **'<30m'**
  String get statsChartNapShort;

  /// No description provided for @statsChartNap30to60.
  ///
  /// In en, this message translates to:
  /// **'30-60m'**
  String get statsChartNap30to60;

  /// No description provided for @statsChartNap60to90.
  ///
  /// In en, this message translates to:
  /// **'60-90m'**
  String get statsChartNap60to90;

  /// No description provided for @statsChartNapLong.
  ///
  /// In en, this message translates to:
  /// **'>90m'**
  String get statsChartNapLong;

  /// No description provided for @statsTimelineTitle.
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get statsTimelineTitle;

  /// No description provided for @statsTimelineEmpty.
  ///
  /// In en, this message translates to:
  /// **'No records this day'**
  String get statsTimelineEmpty;

  /// No description provided for @statsTimelineIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Incomplete data'**
  String get statsTimelineIncomplete;

  /// No description provided for @statsTimelineOngoing.
  ///
  /// In en, this message translates to:
  /// **'Ongoing sleep'**
  String get statsTimelineOngoing;

  /// No description provided for @statsTimelineOverlap.
  ///
  /// In en, this message translates to:
  /// **'Overlap'**
  String get statsTimelineOverlap;

  /// No description provided for @statsExportTitle.
  ///
  /// In en, this message translates to:
  /// **'Export data'**
  String get statsExportTitle;

  /// No description provided for @statsExportPdf.
  ///
  /// In en, this message translates to:
  /// **'PDF'**
  String get statsExportPdf;

  /// No description provided for @statsExportCsv.
  ///
  /// In en, this message translates to:
  /// **'CSV'**
  String get statsExportCsv;

  /// No description provided for @statsExportPeriod7.
  ///
  /// In en, this message translates to:
  /// **'7 days'**
  String get statsExportPeriod7;

  /// No description provided for @statsExportPeriod14.
  ///
  /// In en, this message translates to:
  /// **'14 days'**
  String get statsExportPeriod14;

  /// No description provided for @statsExportPeriod30.
  ///
  /// In en, this message translates to:
  /// **'30 days'**
  String get statsExportPeriod30;

  /// No description provided for @statsExportPeriodCustom.
  ///
  /// In en, this message translates to:
  /// **'Selected period'**
  String get statsExportPeriodCustom;

  /// No description provided for @statsExportCsvSessions.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get statsExportCsvSessions;

  /// No description provided for @statsExportCsvAggregates.
  ///
  /// In en, this message translates to:
  /// **'Daily aggregates'**
  String get statsExportCsvAggregates;

  /// No description provided for @statsExportCsvBoth.
  ///
  /// In en, this message translates to:
  /// **'Both'**
  String get statsExportCsvBoth;

  /// No description provided for @statsExportIncludeName.
  ///
  /// In en, this message translates to:
  /// **'Include baby name'**
  String get statsExportIncludeName;

  /// No description provided for @statsExportGenerate.
  ///
  /// In en, this message translates to:
  /// **'Generate and share'**
  String get statsExportGenerate;

  /// No description provided for @statsExportPreviewPdf.
  ///
  /// In en, this message translates to:
  /// **'Summary with KPIs, charts and timeline'**
  String get statsExportPreviewPdf;

  /// No description provided for @statsExportPreviewCsv.
  ///
  /// In en, this message translates to:
  /// **'Tabular data for analysis'**
  String get statsExportPreviewCsv;

  /// No description provided for @statsEmptyState.
  ///
  /// In en, this message translates to:
  /// **'No sleep records yet'**
  String get statsEmptyState;

  /// No description provided for @statsEmptyStateCta.
  ///
  /// In en, this message translates to:
  /// **'Go to Sleep'**
  String get statsEmptyStateCta;

  /// No description provided for @statsGoToSleep.
  ///
  /// In en, this message translates to:
  /// **'Register sleep'**
  String get statsGoToSleep;

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

  /// Button to pull babies from server
  ///
  /// In en, this message translates to:
  /// **'Pull Babies (Global)'**
  String get babiesPullGlobal;

  /// Short new baby button
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get babiesNew;

  /// Error when babies fail to load
  ///
  /// In en, this message translates to:
  /// **'Error loading babies'**
  String get babiesErrorLoading;

  /// Label for baby name input
  ///
  /// In en, this message translates to:
  /// **'Baby name'**
  String get babiesNameLabel;

  /// Hint for baby name input
  ///
  /// In en, this message translates to:
  /// **'e.g., Emma'**
  String get babiesNameHint;

  /// Success message after creating baby
  ///
  /// In en, this message translates to:
  /// **'Baby \"{name}\" created'**
  String babiesCreatedSuccess(String name);

  /// Error message when baby creation fails
  ///
  /// In en, this message translates to:
  /// **'Failed to create baby: {error}'**
  String babiesCreatedError(String error);

  /// Logout menu item
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get menuLogout;

  /// Debug menu item
  ///
  /// In en, this message translates to:
  /// **'Debug'**
  String get menuDebug;

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

  /// Link to retry with different email
  ///
  /// In en, this message translates to:
  /// **'Use a different email'**
  String get loginUseDifferentEmail;

  /// Invalid email error
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address'**
  String get loginInvalidEmail;

  /// Success message after sending magic link
  ///
  /// In en, this message translates to:
  /// **'Magic link sent! Check your email and tap the link to sign in.'**
  String get loginMagicLinkSent;

  /// Error message when magic link fails
  ///
  /// In en, this message translates to:
  /// **'Failed to send magic link. Please try again.'**
  String get loginMagicLinkFailed;

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

  /// Total label for sleep summary
  ///
  /// In en, this message translates to:
  /// **'total'**
  String get totalLabel;

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

  /// Success message after editing sleep
  ///
  /// In en, this message translates to:
  /// **'Sleep edited'**
  String get editSleepSuccess;

  /// Error message with detail
  ///
  /// In en, this message translates to:
  /// **'Error: {message}'**
  String errorWithMessage(String message);

  /// Overlap edit dialog title
  ///
  /// In en, this message translates to:
  /// **'Overlaps other sleep'**
  String get overlapOtherSleep;

  /// Overlap edit message
  ///
  /// In en, this message translates to:
  /// **'The new period overlaps: {sessions}\n\nDo you want to replace?'**
  String overlapNewPeriodMessage(String sessions);

  /// Label for since time
  ///
  /// In en, this message translates to:
  /// **'since {time}'**
  String sinceSomething(String time);

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

  /// Menu option to switch baby
  ///
  /// In en, this message translates to:
  /// **'Switch baby'**
  String get menuSwitchBaby;

  /// Placeholder for unknown time
  ///
  /// In en, this message translates to:
  /// **'unknown time'**
  String get unknownTime;

  /// Ongoing session label
  ///
  /// In en, this message translates to:
  /// **'since {time} (ongoing)'**
  String ongoingSince(String time);

  /// Overlap confirmation message
  ///
  /// In en, this message translates to:
  /// **'The new record overlaps with existing sleep(s). Do you want to replace?'**
  String get overlapMessage;

  /// Error message when overwrite fails
  ///
  /// In en, this message translates to:
  /// **'Error replacing: {error}'**
  String errorOverwriting(String error);

  /// Date picker help text
  ///
  /// In en, this message translates to:
  /// **'Pick day'**
  String get pickDay;

  /// Error when user lacks permission
  ///
  /// In en, this message translates to:
  /// **'You don\'t have permission to create events.'**
  String get noPermissionToCreate;

  /// Loading message for permissions
  ///
  /// In en, this message translates to:
  /// **'Preparing permissions. Please wait a moment.'**
  String get preparingPermissionsWait;

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

  /// No description provided for @insightsTitle.
  ///
  /// In en, this message translates to:
  /// **'Insights'**
  String get insightsTitle;

  /// No description provided for @insightsHeaderToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get insightsHeaderToday;

  /// No description provided for @insightsHeaderBasedOn.
  ///
  /// In en, this message translates to:
  /// **'Based on {days} days'**
  String insightsHeaderBasedOn(int days);

  /// No description provided for @insightsHeaderPatterns.
  ///
  /// In en, this message translates to:
  /// **'Detected patterns'**
  String get insightsHeaderPatterns;

  /// No description provided for @insightsHeaderRoutine.
  ///
  /// In en, this message translates to:
  /// **'Suggested routine'**
  String get insightsHeaderRoutine;

  /// No description provided for @insightsHeaderGuide.
  ///
  /// In en, this message translates to:
  /// **'Guide'**
  String get insightsHeaderGuide;

  /// No description provided for @insightsAddDob.
  ///
  /// In en, this message translates to:
  /// **'Add birth date'**
  String get insightsAddDob;

  /// No description provided for @insightsAddDobBanner.
  ///
  /// In en, this message translates to:
  /// **'To personalize age-based insights, add the birth date'**
  String get insightsAddDobBanner;

  /// CTA to add birth date now
  ///
  /// In en, this message translates to:
  /// **'Add now'**
  String get insightsAddNow;

  /// Main insight title
  ///
  /// In en, this message translates to:
  /// **'Main point'**
  String get insightsMainPoint;

  /// Next step action title
  ///
  /// In en, this message translates to:
  /// **'Next step'**
  String get insightsNextStep;

  /// Snackbar when saved
  ///
  /// In en, this message translates to:
  /// **'Saved to favorites'**
  String get insightsSavedFavorites;

  /// Suggestion badge label
  ///
  /// In en, this message translates to:
  /// **'suggestion'**
  String get insightsSuggestionLabel;

  /// Hint to add dob for suggestions
  ///
  /// In en, this message translates to:
  /// **'Add birth date for age-based suggestions.'**
  String get insightsDefineDobForAge;

  /// Subtitle when no baby selected
  ///
  /// In en, this message translates to:
  /// **'To see personalized insights.'**
  String get insightsToSeePersonalized;

  /// Empty state title
  ///
  /// In en, this message translates to:
  /// **'No sleep records yet'**
  String get insightsNoRecordsYet;

  /// Empty state subtitle
  ///
  /// In en, this message translates to:
  /// **'Record your first sleep in the \"Sleep\" tab to start seeing insights.'**
  String get insightsRecordFirstSleep;

  /// CTA to register sleep
  ///
  /// In en, this message translates to:
  /// **'Register sleep'**
  String get insightsRegisterSleep;

  /// Patterns section empty state
  ///
  /// In en, this message translates to:
  /// **'Still collecting data to identify patterns.'**
  String get insightsCollectingPatterns;

  /// Routine empty state
  ///
  /// In en, this message translates to:
  /// **'Record a few more nights to receive personalized routine suggestions.'**
  String get insightsRegisterMoreNights;

  /// Comparison with 7 day average
  ///
  /// In en, this message translates to:
  /// **'{diff} vs 7 day average'**
  String insightsVsAvg7Days(String diff);

  /// No description provided for @insightsNoDobFallback.
  ///
  /// In en, this message translates to:
  /// **'General insights (no age band)'**
  String get insightsNoDobFallback;

  /// No description provided for @insightsLearning.
  ///
  /// In en, this message translates to:
  /// **'Still learning your baby\'s pattern'**
  String get insightsLearning;

  /// No description provided for @insightsMoreDataNeeded.
  ///
  /// In en, this message translates to:
  /// **'We need a few more days of data'**
  String get insightsMoreDataNeeded;

  /// No description provided for @insightsSourcesTitle.
  ///
  /// In en, this message translates to:
  /// **'Sources'**
  String get insightsSourcesTitle;

  /// No description provided for @insightsDisclaimerMedical.
  ///
  /// In en, this message translates to:
  /// **'This content is informational and does not replace medical advice.'**
  String get insightsDisclaimerMedical;

  /// No description provided for @insightSummary24hTitle.
  ///
  /// In en, this message translates to:
  /// **'24h summary'**
  String get insightSummary24hTitle;

  /// No description provided for @insightSummary24hBody.
  ///
  /// In en, this message translates to:
  /// **'Total sleep: {hours}h {minutes}m'**
  String insightSummary24hBody(int hours, int minutes);

  /// No description provided for @insightSummary24hVsAvg.
  ///
  /// In en, this message translates to:
  /// **'{sign}{minutes}m vs 7 day average'**
  String insightSummary24hVsAvg(String sign, int minutes);

  /// No description provided for @insightSummary24hNoData.
  ///
  /// In en, this message translates to:
  /// **'Not enough data yet'**
  String get insightSummary24hNoData;

  /// No description provided for @insightCurrentlySleepingTitle.
  ///
  /// In en, this message translates to:
  /// **'Sleeping'**
  String get insightCurrentlySleepingTitle;

  /// No description provided for @insightCurrentlySleepingBody.
  ///
  /// In en, this message translates to:
  /// **'Sleeping since {time}'**
  String insightCurrentlySleepingBody(String time);

  /// No description provided for @insightSleepBelowExpectedTitle.
  ///
  /// In en, this message translates to:
  /// **'Sleep below expected'**
  String get insightSleepBelowExpectedTitle;

  /// No description provided for @insightSleepBelowExpectedBody.
  ///
  /// In en, this message translates to:
  /// **'Sleep in the last 24h is slightly below recommended for this age.'**
  String get insightSleepBelowExpectedBody;

  /// No description provided for @insightSleepBelowExpectedWhy.
  ///
  /// In en, this message translates to:
  /// **'Compared to the typical range ({min}–{max}h).'**
  String insightSleepBelowExpectedWhy(int min, int max);

  /// No description provided for @insightSleepWithinExpectedTitle.
  ///
  /// In en, this message translates to:
  /// **'Sleep within expected'**
  String get insightSleepWithinExpectedTitle;

  /// No description provided for @insightSleepWithinExpectedBody.
  ///
  /// In en, this message translates to:
  /// **'Sleep is within the recommended range for this age.'**
  String get insightSleepWithinExpectedBody;

  /// No description provided for @insightSleepAboveExpectedTitle.
  ///
  /// In en, this message translates to:
  /// **'Sleep above expected'**
  String get insightSleepAboveExpectedTitle;

  /// No description provided for @insightSleepAboveExpectedBody.
  ///
  /// In en, this message translates to:
  /// **'Sleep is above the typical range. Usually not a concern.'**
  String get insightSleepAboveExpectedBody;

  /// No description provided for @insightBedtimeVariabilityHighTitle.
  ///
  /// In en, this message translates to:
  /// **'Variable bedtime'**
  String get insightBedtimeVariabilityHighTitle;

  /// No description provided for @insightBedtimeVariabilityHighBody.
  ///
  /// In en, this message translates to:
  /// **'Bedtime varied by ±{minutes}min in recent days.'**
  String insightBedtimeVariabilityHighBody(int minutes);

  /// No description provided for @insightBedtimeVariabilityHighWhy.
  ///
  /// In en, this message translates to:
  /// **'Consistency in bedtime can help regulate sleep.'**
  String get insightBedtimeVariabilityHighWhy;

  /// No description provided for @insightBedtimeConsistencyGoodTitle.
  ///
  /// In en, this message translates to:
  /// **'Good bedtime consistency'**
  String get insightBedtimeConsistencyGoodTitle;

  /// No description provided for @insightBedtimeConsistencyGoodBody.
  ///
  /// In en, this message translates to:
  /// **'Bedtime has been consistent. Keep it up!'**
  String get insightBedtimeConsistencyGoodBody;

  /// No description provided for @insightNightFragmentationHighTitle.
  ///
  /// In en, this message translates to:
  /// **'Fragmented nights'**
  String get insightNightFragmentationHighTitle;

  /// No description provided for @insightNightFragmentationHighBody.
  ///
  /// In en, this message translates to:
  /// **'Nights have had multiple awakenings.'**
  String get insightNightFragmentationHighBody;

  /// No description provided for @insightNightFragmentationHighWhy.
  ///
  /// In en, this message translates to:
  /// **'Average of {count} awakenings per night.'**
  String insightNightFragmentationHighWhy(int count);

  /// No description provided for @insightLargestBlockImprovingTitle.
  ///
  /// In en, this message translates to:
  /// **'Night block improving'**
  String get insightLargestBlockImprovingTitle;

  /// No description provided for @insightLargestBlockImprovingBody.
  ///
  /// In en, this message translates to:
  /// **'The longest night sleep block is increasing.'**
  String get insightLargestBlockImprovingBody;

  /// No description provided for @insightTodayWasDifferentTitle.
  ///
  /// In en, this message translates to:
  /// **'Today was different'**
  String get insightTodayWasDifferentTitle;

  /// No description provided for @insightTodayWasDifferentBody.
  ///
  /// In en, this message translates to:
  /// **'Today\'s sleep differed significantly from the recent average.'**
  String get insightTodayWasDifferentBody;

  /// No description provided for @insightAgeNorm0to3Title.
  ///
  /// In en, this message translates to:
  /// **'Variability is normal'**
  String get insightAgeNorm0to3Title;

  /// No description provided for @insightAgeNorm0to3Body.
  ///
  /// In en, this message translates to:
  /// **'In the first months, it\'s normal for sleep to vary a lot day to day.'**
  String get insightAgeNorm0to3Body;

  /// No description provided for @insightAgeNorm4to12Title.
  ///
  /// In en, this message translates to:
  /// **'Consolidation in progress'**
  String get insightAgeNorm4to12Title;

  /// No description provided for @insightAgeNorm4to12Body.
  ///
  /// In en, this message translates to:
  /// **'At this stage, night sleep starts consolidating naturally.'**
  String get insightAgeNorm4to12Body;

  /// No description provided for @insightAgeNorm12to24Title.
  ///
  /// In en, this message translates to:
  /// **'Testing limits is normal'**
  String get insightAgeNorm12to24Title;

  /// No description provided for @insightAgeNorm12to24Body.
  ///
  /// In en, this message translates to:
  /// **'Resisting bedtime is common at this age. Stay calm!'**
  String get insightAgeNorm12to24Body;

  /// No description provided for @insightSafeSleepBackToSleepTitle.
  ///
  /// In en, this message translates to:
  /// **'Safe sleep: on back'**
  String get insightSafeSleepBackToSleepTitle;

  /// No description provided for @insightSafeSleepBackToSleepBody.
  ///
  /// In en, this message translates to:
  /// **'Remember: babies should always sleep on their back.'**
  String get insightSafeSleepBackToSleepBody;

  /// No description provided for @insightDayNightLowStimulusTitle.
  ///
  /// In en, this message translates to:
  /// **'Low stimulus at night'**
  String get insightDayNightLowStimulusTitle;

  /// No description provided for @insightDayNightLowStimulusBody.
  ///
  /// In en, this message translates to:
  /// **'Calm interactions and low light at night help establish day vs night.'**
  String get insightDayNightLowStimulusBody;

  /// No description provided for @insightRoutineShortConsistentTitle.
  ///
  /// In en, this message translates to:
  /// **'Short consistent routine'**
  String get insightRoutineShortConsistentTitle;

  /// No description provided for @insightRoutineShortConsistentBody.
  ///
  /// In en, this message translates to:
  /// **'A simple 2–4 step routine before bed can help.'**
  String get insightRoutineShortConsistentBody;

  /// No description provided for @insightWhenCallPediatricianTitle.
  ///
  /// In en, this message translates to:
  /// **'When to contact the pediatrician'**
  String get insightWhenCallPediatricianTitle;

  /// No description provided for @insightWhenCallPediatricianBody.
  ///
  /// In en, this message translates to:
  /// **'If something concerns you, don\'t hesitate to consult the doctor.'**
  String get insightWhenCallPediatricianBody;

  /// No description provided for @insightFewDataLearningTitle.
  ///
  /// In en, this message translates to:
  /// **'Still learning'**
  String get insightFewDataLearningTitle;

  /// No description provided for @insightFewDataLearningBody.
  ///
  /// In en, this message translates to:
  /// **'We need a few more days of data to generate personalized insights.'**
  String get insightFewDataLearningBody;

  /// No description provided for @insightCtaLearnMore.
  ///
  /// In en, this message translates to:
  /// **'Learn more'**
  String get insightCtaLearnMore;

  /// No description provided for @insightCtaSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get insightCtaSave;

  /// No description provided for @insightCtaCheckGuide.
  ///
  /// In en, this message translates to:
  /// **'Check guide'**
  String get insightCtaCheckGuide;

  /// No description provided for @insightCtaOpenGuide.
  ///
  /// In en, this message translates to:
  /// **'Open guide'**
  String get insightCtaOpenGuide;

  /// No description provided for @insightCtaTryThis.
  ///
  /// In en, this message translates to:
  /// **'Try this'**
  String get insightCtaTryThis;

  /// No description provided for @insightCtaWhyThis.
  ///
  /// In en, this message translates to:
  /// **'Why this?'**
  String get insightCtaWhyThis;

  /// No description provided for @insightCtaDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get insightCtaDismiss;

  /// No description provided for @routineSuggestionTitle.
  ///
  /// In en, this message translates to:
  /// **'Routine suggestion'**
  String get routineSuggestionTitle;

  /// No description provided for @routineNextNap.
  ///
  /// In en, this message translates to:
  /// **'Next nap'**
  String get routineNextNap;

  /// No description provided for @routineNextNapWindow.
  ///
  /// In en, this message translates to:
  /// **'Window: {start}–{end}'**
  String routineNextNapWindow(String start, String end);

  /// No description provided for @routineNextNapSuggested.
  ///
  /// In en, this message translates to:
  /// **'Suggested: {time}'**
  String routineNextNapSuggested(String time);

  /// No description provided for @routineBedtime.
  ///
  /// In en, this message translates to:
  /// **'Bedtime'**
  String get routineBedtime;

  /// No description provided for @routineBedtimeWindow.
  ///
  /// In en, this message translates to:
  /// **'Window: {start}–{end}'**
  String routineBedtimeWindow(String start, String end);

  /// No description provided for @routineBedtimeSuggested.
  ///
  /// In en, this message translates to:
  /// **'Suggested: {time}'**
  String routineBedtimeSuggested(String time);

  /// No description provided for @routineNoData.
  ///
  /// In en, this message translates to:
  /// **'Not enough data to suggest yet'**
  String get routineNoData;

  /// No description provided for @routineCurrentlySleeping.
  ///
  /// In en, this message translates to:
  /// **'Sleeping — rest well!'**
  String get routineCurrentlySleeping;

  /// No description provided for @routineNapWindowPassed.
  ///
  /// In en, this message translates to:
  /// **'The nap window has passed'**
  String get routineNapWindowPassed;

  /// No description provided for @routineExplanation.
  ///
  /// In en, this message translates to:
  /// **'Based on recent patterns'**
  String get routineExplanation;

  /// No description provided for @routineNapCount.
  ///
  /// In en, this message translates to:
  /// **'{count} naps expected'**
  String routineNapCount(int count);

  /// No description provided for @routineNapDuration.
  ///
  /// In en, this message translates to:
  /// **'~{minutes}min each'**
  String routineNapDuration(int minutes);

  /// No description provided for @guide_normal_por_idade_title.
  ///
  /// In en, this message translates to:
  /// **'What\'s normal by age'**
  String get guide_normal_por_idade_title;

  /// No description provided for @guide_normal_por_idade_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Sleep expectations 0–24 months'**
  String get guide_normal_por_idade_subtitle;

  /// No description provided for @guide_dia_vs_noite_title.
  ///
  /// In en, this message translates to:
  /// **'Day vs Night'**
  String get guide_dia_vs_noite_title;

  /// No description provided for @guide_dia_vs_noite_subtitle.
  ///
  /// In en, this message translates to:
  /// **'How to help the circadian rhythm'**
  String get guide_dia_vs_noite_subtitle;

  /// No description provided for @guide_rotina_antes_dormir_title.
  ///
  /// In en, this message translates to:
  /// **'Bedtime routine'**
  String get guide_rotina_antes_dormir_title;

  /// No description provided for @guide_rotina_antes_dormir_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Simple steps to help'**
  String get guide_rotina_antes_dormir_subtitle;

  /// No description provided for @guide_sono_seguro_title.
  ///
  /// In en, this message translates to:
  /// **'Safe sleep'**
  String get guide_sono_seguro_title;

  /// No description provided for @guide_sono_seguro_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Recommended practices'**
  String get guide_sono_seguro_subtitle;

  /// No description provided for @guide_quando_pediatra_title.
  ///
  /// In en, this message translates to:
  /// **'When to talk to the pediatrician'**
  String get guide_quando_pediatra_title;

  /// No description provided for @guide_quando_pediatra_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Warning signs'**
  String get guide_quando_pediatra_subtitle;

  /// No description provided for @guideOpenSection.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get guideOpenSection;

  /// No description provided for @guideBackToList.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get guideBackToList;

  /// No description provided for @guideDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'This content is informational and does not replace personalized medical advice.'**
  String get guideDisclaimer;
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
