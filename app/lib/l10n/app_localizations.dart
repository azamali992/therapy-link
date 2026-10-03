import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ur.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
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

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
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
    Locale('ur'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'TherapyLink'**
  String get appName;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retry;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Check your connection and try again.'**
  String get errorGeneric;

  /// No description provided for @notShared.
  ///
  /// In en, this message translates to:
  /// **'Not shared'**
  String get notShared;

  /// No description provided for @tabEve.
  ///
  /// In en, this message translates to:
  /// **'Eve'**
  String get tabEve;

  /// No description provided for @tabToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get tabToday;

  /// No description provided for @tabJournal.
  ///
  /// In en, this message translates to:
  /// **'Journal'**
  String get tabJournal;

  /// No description provided for @tabYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get tabYou;

  /// No description provided for @welcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Someone to talk to, any hour'**
  String get welcomeTitle;

  /// No description provided for @welcomeBody.
  ///
  /// In en, this message translates to:
  /// **'Eve listens in English or Roman Urdu. Your conversations with her are saved on this phone. Each message is sent to the TherapyLink server so she can answer, and it isn\'t stored there.'**
  String get welcomeBody;

  /// No description provided for @welcomeLanguage.
  ///
  /// In en, this message translates to:
  /// **'Which do you type in most?'**
  String get welcomeLanguage;

  /// No description provided for @welcomeEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get welcomeEnglish;

  /// No description provided for @welcomeRomanUrdu.
  ///
  /// In en, this message translates to:
  /// **'Roman Urdu'**
  String get welcomeRomanUrdu;

  /// No description provided for @signInTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get signInTitle;

  /// No description provided for @signInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to keep your check-ins and journal with you.'**
  String get signInSubtitle;

  /// No description provided for @continueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continueWithGoogle;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createAccount;

  /// No description provided for @haveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign in'**
  String get haveAccount;

  /// No description provided for @noAccount.
  ///
  /// In en, this message translates to:
  /// **'New here? Create an account'**
  String get noAccount;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// No description provided for @resetSent.
  ///
  /// In en, this message translates to:
  /// **'Reset email sent.'**
  String get resetSent;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @eveGreeting.
  ///
  /// In en, this message translates to:
  /// **'I\'m Eve. What\'s going on?'**
  String get eveGreeting;

  /// No description provided for @eveComposerHint.
  ///
  /// In en, this message translates to:
  /// **'Say anything…'**
  String get eveComposerHint;

  /// No description provided for @eveListening.
  ///
  /// In en, this message translates to:
  /// **'Eve is listening'**
  String get eveListening;

  /// No description provided for @evePrivacy.
  ///
  /// In en, this message translates to:
  /// **'Saved on this phone. Each message goes to the TherapyLink server to be answered.'**
  String get evePrivacy;

  /// No description provided for @evePrivacyCloud.
  ///
  /// In en, this message translates to:
  /// **'Cloud mode: messages are sent to your TherapyLink server.'**
  String get evePrivacyCloud;

  /// No description provided for @modelMissingTitle.
  ///
  /// In en, this message translates to:
  /// **'Eve isn\'t on this device yet'**
  String get modelMissingTitle;

  /// No description provided for @modelMissingBody.
  ///
  /// In en, this message translates to:
  /// **'One-time download of about {gb} GB. Wi-Fi recommended. After that, Eve works fully offline.'**
  String modelMissingBody(String gb);

  /// No description provided for @modelDownload.
  ///
  /// In en, this message translates to:
  /// **'Download Eve'**
  String get modelDownload;

  /// No description provided for @modelDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading Eve · {percent}%'**
  String modelDownloading(int percent);

  /// No description provided for @modelFailed.
  ///
  /// In en, this message translates to:
  /// **'The download didn\'t finish. Check your connection and try again.'**
  String get modelFailed;

  /// No description provided for @guardianTitle.
  ///
  /// In en, this message translates to:
  /// **'Safety check'**
  String get guardianTitle;

  /// No description provided for @guardianHeuristic.
  ///
  /// In en, this message translates to:
  /// **'Using the built-in keyword check.'**
  String get guardianHeuristic;

  /// No description provided for @guardianReady.
  ///
  /// In en, this message translates to:
  /// **'Trained model installed. Runs on this device before every message.'**
  String get guardianReady;

  /// No description provided for @guardianDownload.
  ///
  /// In en, this message translates to:
  /// **'Download safety model'**
  String get guardianDownload;

  /// No description provided for @guardianDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading safety model · {percent}%'**
  String guardianDownloading(int percent);

  /// No description provided for @guardianUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Not published yet.'**
  String get guardianUnavailable;

  /// PENDING CLINICIAN REVIEW: safety-status line while the Guardian download waits for Wi-Fi. Wording drafted by engineering, not yet approved.
  ///
  /// In en, this message translates to:
  /// **'Waiting for Wi-Fi to download the safety model ({megabytes} MB). The built-in keyword check runs until then.'**
  String guardianWaitingForWifi(int megabytes);

  /// No description provided for @guardianDownloadOnData.
  ///
  /// In en, this message translates to:
  /// **'Download on mobile data'**
  String get guardianDownloadOnData;

  /// PENDING CLINICIAN REVIEW: safety-status line when the phone lacks space for the Guardian bundle. Wording drafted by engineering, not yet approved.
  ///
  /// In en, this message translates to:
  /// **'There isn\'t enough space on this phone for the safety model. Free up about {megabytes} MB, then try again. The built-in keyword check runs until then.'**
  String guardianNoSpace(int megabytes);

  /// No description provided for @guardianMeanwhile.
  ///
  /// In en, this message translates to:
  /// **'The built-in keyword check runs until it\'s ready.'**
  String get guardianMeanwhile;

  /// No description provided for @crisisCallUmang.
  ///
  /// In en, this message translates to:
  /// **'Call Umang · 0311 7786264'**
  String get crisisCallUmang;

  /// No description provided for @crisisCallEmergency.
  ///
  /// In en, this message translates to:
  /// **'Emergency · 1122'**
  String get crisisCallEmergency;

  /// No description provided for @crisisKeepTalking.
  ///
  /// In en, this message translates to:
  /// **'Keep talking to Eve'**
  String get crisisKeepTalking;

  /// No description provided for @todayMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get todayMorning;

  /// No description provided for @todayAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get todayAfternoon;

  /// No description provided for @todayEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get todayEvening;

  /// No description provided for @moodPrompt.
  ///
  /// In en, this message translates to:
  /// **'How are you right now?'**
  String get moodPrompt;

  /// No description provided for @moodSaved.
  ///
  /// In en, this message translates to:
  /// **'Noted.'**
  String get moodSaved;

  /// No description provided for @moodVeryLow.
  ///
  /// In en, this message translates to:
  /// **'Very low'**
  String get moodVeryLow;

  /// No description provided for @moodLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get moodLow;

  /// No description provided for @moodOkay.
  ///
  /// In en, this message translates to:
  /// **'Okay'**
  String get moodOkay;

  /// No description provided for @moodGood.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get moodGood;

  /// No description provided for @moodGreat.
  ///
  /// In en, this message translates to:
  /// **'Great'**
  String get moodGreat;

  /// No description provided for @moodTrend.
  ///
  /// In en, this message translates to:
  /// **'Last 30 days'**
  String get moodTrend;

  /// No description provided for @moodTrendWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get moodTrendWeek;

  /// No description provided for @moodTrendEmpty.
  ///
  /// In en, this message translates to:
  /// **'Check in a few times and a trend will appear here.'**
  String get moodTrendEmpty;

  /// No description provided for @groundingOffer.
  ///
  /// In en, this message translates to:
  /// **'That sounds like a lot to sit with. Would a minute of paced breathing help?'**
  String get groundingOffer;

  /// No description provided for @groundingAccept.
  ///
  /// In en, this message translates to:
  /// **'Try it'**
  String get groundingAccept;

  /// No description provided for @groundingDecline.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get groundingDecline;

  /// No description provided for @insightMorning.
  ///
  /// In en, this message translates to:
  /// **'mornings'**
  String get insightMorning;

  /// No description provided for @insightAfternoon.
  ///
  /// In en, this message translates to:
  /// **'afternoons'**
  String get insightAfternoon;

  /// No description provided for @insightEvening.
  ///
  /// In en, this message translates to:
  /// **'evenings'**
  String get insightEvening;

  /// No description provided for @insightTimeOfDay.
  ///
  /// In en, this message translates to:
  /// **'Your {worse} have tended to be harder than your {better}.'**
  String insightTimeOfDay(String worse, String better);

  /// No description provided for @insightWeekUp.
  ///
  /// In en, this message translates to:
  /// **'This week has been a little lighter than last week.'**
  String get insightWeekUp;

  /// No description provided for @insightWeekDown.
  ///
  /// In en, this message translates to:
  /// **'This week has been heavier than last week.'**
  String get insightWeekDown;

  /// No description provided for @insightBasis.
  ///
  /// In en, this message translates to:
  /// **'Based on {n} check-ins. A pattern, not a diagnosis.'**
  String insightBasis(int n);

  /// No description provided for @exercisesTitle.
  ///
  /// In en, this message translates to:
  /// **'Grounding'**
  String get exercisesTitle;

  /// No description provided for @exercisesSub.
  ///
  /// In en, this message translates to:
  /// **'A few minutes of paced breathing'**
  String get exercisesSub;

  /// No description provided for @exerciseSigh.
  ///
  /// In en, this message translates to:
  /// **'Reset breath'**
  String get exerciseSigh;

  /// No description provided for @exerciseSighSub.
  ///
  /// In en, this message translates to:
  /// **'Two inhales, one long exhale · about 1 minute'**
  String get exerciseSighSub;

  /// No description provided for @exerciseBox.
  ///
  /// In en, this message translates to:
  /// **'Box breathing'**
  String get exerciseBox;

  /// No description provided for @exerciseBoxSub.
  ///
  /// In en, this message translates to:
  /// **'Even four counts · about 2 minutes'**
  String get exerciseBoxSub;

  /// No description provided for @exerciseCalming.
  ///
  /// In en, this message translates to:
  /// **'4-7-8'**
  String get exerciseCalming;

  /// No description provided for @exerciseCalmingSub.
  ///
  /// In en, this message translates to:
  /// **'Long exhale · about 1 minute'**
  String get exerciseCalmingSub;

  /// No description provided for @breathIn.
  ///
  /// In en, this message translates to:
  /// **'Breathe in'**
  String get breathIn;

  /// No description provided for @breathHold.
  ///
  /// In en, this message translates to:
  /// **'Hold'**
  String get breathHold;

  /// No description provided for @breathOut.
  ///
  /// In en, this message translates to:
  /// **'Breathe out'**
  String get breathOut;

  /// No description provided for @breathRest.
  ///
  /// In en, this message translates to:
  /// **'Rest'**
  String get breathRest;

  /// No description provided for @breathStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get breathStart;

  /// No description provided for @breathPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get breathPause;

  /// No description provided for @breathAgain.
  ///
  /// In en, this message translates to:
  /// **'Go again'**
  String get breathAgain;

  /// No description provided for @breathRestart.
  ///
  /// In en, this message translates to:
  /// **'Start over'**
  String get breathRestart;

  /// No description provided for @breathDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get breathDone;

  /// No description provided for @breathCycleOf.
  ///
  /// In en, this message translates to:
  /// **'Round {n} of {total}'**
  String breathCycleOf(int n, int total);

  /// No description provided for @breathResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get breathResume;

  /// No description provided for @breathStop.
  ///
  /// In en, this message translates to:
  /// **'Stop whenever you like. Nothing is counted.'**
  String get breathStop;

  /// No description provided for @breathNote.
  ///
  /// In en, this message translates to:
  /// **'Stop any time. If you feel light-headed, breathe normally.'**
  String get breathNote;

  /// No description provided for @assessmentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Check-ins'**
  String get assessmentsTitle;

  /// No description provided for @assessmentPhq9.
  ///
  /// In en, this message translates to:
  /// **'Mood check-in'**
  String get assessmentPhq9;

  /// No description provided for @assessmentPhq9Sub.
  ///
  /// In en, this message translates to:
  /// **'PHQ-9 · 9 questions · 2 minutes'**
  String get assessmentPhq9Sub;

  /// No description provided for @assessmentGad7.
  ///
  /// In en, this message translates to:
  /// **'Anxiety check-in'**
  String get assessmentGad7;

  /// No description provided for @assessmentGad7Sub.
  ///
  /// In en, this message translates to:
  /// **'GAD-7 · 7 questions · 2 minutes'**
  String get assessmentGad7Sub;

  /// No description provided for @assessmentLast.
  ///
  /// In en, this message translates to:
  /// **'Last: {score} · {band}'**
  String assessmentLast(int score, String band);

  /// No description provided for @assessmentNever.
  ///
  /// In en, this message translates to:
  /// **'Not taken yet'**
  String get assessmentNever;

  /// No description provided for @assessmentIntro.
  ///
  /// In en, this message translates to:
  /// **'Over the last two weeks, how often have you been bothered by the following?'**
  String get assessmentIntro;

  /// No description provided for @assessmentNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get assessmentNext;

  /// No description provided for @assessmentBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get assessmentBack;

  /// No description provided for @assessmentFinish.
  ///
  /// In en, this message translates to:
  /// **'See result'**
  String get assessmentFinish;

  /// No description provided for @assessmentQuestionOf.
  ///
  /// In en, this message translates to:
  /// **'{n} of {total}'**
  String assessmentQuestionOf(int n, int total);

  /// No description provided for @optNotAtAll.
  ///
  /// In en, this message translates to:
  /// **'Not at all'**
  String get optNotAtAll;

  /// No description provided for @optSeveralDays.
  ///
  /// In en, this message translates to:
  /// **'Several days'**
  String get optSeveralDays;

  /// No description provided for @optMoreThanHalf.
  ///
  /// In en, this message translates to:
  /// **'More than half the days'**
  String get optMoreThanHalf;

  /// No description provided for @optNearlyEveryDay.
  ///
  /// In en, this message translates to:
  /// **'Nearly every day'**
  String get optNearlyEveryDay;

  /// No description provided for @resultTitle.
  ///
  /// In en, this message translates to:
  /// **'Your result'**
  String get resultTitle;

  /// No description provided for @resultScore.
  ///
  /// In en, this message translates to:
  /// **'{score} out of {max}'**
  String resultScore(int score, int max);

  /// No description provided for @resultDelta.
  ///
  /// In en, this message translates to:
  /// **'{delta} since last time'**
  String resultDelta(String delta);

  /// No description provided for @bandMinimal.
  ///
  /// In en, this message translates to:
  /// **'Minimal'**
  String get bandMinimal;

  /// No description provided for @bandMild.
  ///
  /// In en, this message translates to:
  /// **'Mild'**
  String get bandMild;

  /// No description provided for @bandModerate.
  ///
  /// In en, this message translates to:
  /// **'Moderate'**
  String get bandModerate;

  /// No description provided for @bandModeratelySevere.
  ///
  /// In en, this message translates to:
  /// **'Moderately severe'**
  String get bandModeratelySevere;

  /// No description provided for @bandSevere.
  ///
  /// In en, this message translates to:
  /// **'Severe'**
  String get bandSevere;

  /// No description provided for @resultNote.
  ///
  /// In en, this message translates to:
  /// **'This is a screening score, not a diagnosis. It\'s most useful as a trend over time.'**
  String get resultNote;

  /// No description provided for @resultFlagged.
  ///
  /// In en, this message translates to:
  /// **'You answered that you\'ve had thoughts of being better off dead or of hurting yourself. That matters, and there are people who want to help right now.'**
  String get resultFlagged;

  /// No description provided for @resultDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get resultDone;

  /// No description provided for @resultTalkToEve.
  ///
  /// In en, this message translates to:
  /// **'Talk it through with Eve'**
  String get resultTalkToEve;

  /// No description provided for @journalTitle.
  ///
  /// In en, this message translates to:
  /// **'Journal'**
  String get journalTitle;

  /// No description provided for @journalNew.
  ///
  /// In en, this message translates to:
  /// **'New entry'**
  String get journalNew;

  /// No description provided for @journalEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get journalEmptyTitle;

  /// No description provided for @journalEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'A few honest lines are enough. Entries are saved to your account, and a clinician sees them only if you choose to share them.'**
  String get journalEmptyBody;

  /// No description provided for @journalTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Title (optional)'**
  String get journalTitleHint;

  /// No description provided for @journalBodyHint.
  ///
  /// In en, this message translates to:
  /// **'What\'s going on?'**
  String get journalBodyHint;

  /// No description provided for @journalSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get journalSave;

  /// No description provided for @journalDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete entry'**
  String get journalDelete;

  /// No description provided for @journalMood.
  ///
  /// In en, this message translates to:
  /// **'Mood while writing'**
  String get journalMood;

  /// No description provided for @youTitle.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get youTitle;

  /// No description provided for @youCare.
  ///
  /// In en, this message translates to:
  /// **'Your care team'**
  String get youCare;

  /// No description provided for @youCareSub.
  ///
  /// In en, this message translates to:
  /// **'Who can see what'**
  String get youCareSub;

  /// No description provided for @youSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get youSettings;

  /// No description provided for @youDataTitle.
  ///
  /// In en, this message translates to:
  /// **'Where your data lives'**
  String get youDataTitle;

  /// No description provided for @youDataBody.
  ///
  /// In en, this message translates to:
  /// **'Conversations with Eve and her memory notes are saved on this phone. To answer you, each message and the notes that relate to it are sent to the TherapyLink server, which doesn\'t store them. Check-in scores, your mood trend and journal entries are stored on your account so they follow you, and a clinician sees them only if you link one and switch that on.'**
  String get youDataBody;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsTextSize.
  ///
  /// In en, this message translates to:
  /// **'Text size'**
  String get settingsTextSize;

  /// No description provided for @settingsReduceMotion.
  ///
  /// In en, this message translates to:
  /// **'Reduce motion'**
  String get settingsReduceMotion;

  /// No description provided for @settingsTheme.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsTheme;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsThemeSystem;

  /// No description provided for @settingsThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

  /// No description provided for @settingsModel.
  ///
  /// In en, this message translates to:
  /// **'Eve runs'**
  String get settingsModel;

  /// No description provided for @settingsModelOnDevice.
  ///
  /// In en, this message translates to:
  /// **'On this device'**
  String get settingsModelOnDevice;

  /// No description provided for @settingsModelCloud.
  ///
  /// In en, this message translates to:
  /// **'In the cloud'**
  String get settingsModelCloud;

  /// No description provided for @careTitle.
  ///
  /// In en, this message translates to:
  /// **'Your care team'**
  String get careTitle;

  /// No description provided for @careEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No clinician linked'**
  String get careEmptyTitle;

  /// No description provided for @careEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'If you\'re working with a clinician, ask them for their invite code and add it here. Nothing is shared until you switch it on.'**
  String get careEmptyBody;

  /// No description provided for @careInvite.
  ///
  /// In en, this message translates to:
  /// **'Add a clinician'**
  String get careInvite;

  /// No description provided for @careInviteHint.
  ///
  /// In en, this message translates to:
  /// **'Invite code'**
  String get careInviteHint;

  /// No description provided for @careConsentTitle.
  ///
  /// In en, this message translates to:
  /// **'What they can see'**
  String get careConsentTitle;

  /// No description provided for @careShareAssessments.
  ///
  /// In en, this message translates to:
  /// **'Check-in scores'**
  String get careShareAssessments;

  /// No description provided for @careShareMood.
  ///
  /// In en, this message translates to:
  /// **'Mood trend'**
  String get careShareMood;

  /// No description provided for @careShareSummaries.
  ///
  /// In en, this message translates to:
  /// **'Weekly summaries'**
  String get careShareSummaries;

  /// No description provided for @careShareJournal.
  ///
  /// In en, this message translates to:
  /// **'Journal entries'**
  String get careShareJournal;

  /// No description provided for @careRevoke.
  ///
  /// In en, this message translates to:
  /// **'Remove clinician'**
  String get careRevoke;

  /// No description provided for @careRevoked.
  ///
  /// In en, this message translates to:
  /// **'Removed'**
  String get careRevoked;

  /// No description provided for @clinicianCaseload.
  ///
  /// In en, this message translates to:
  /// **'Patients'**
  String get clinicianCaseload;

  /// No description provided for @clinicianPending.
  ///
  /// In en, this message translates to:
  /// **'Your clinician account is awaiting verification. You\'ll be able to see patients once it\'s approved.'**
  String get clinicianPending;

  /// No description provided for @clinicianEmpty.
  ///
  /// In en, this message translates to:
  /// **'No patients yet. Give a patient your invite code and they can add you from their app.'**
  String get clinicianEmpty;

  /// No description provided for @clinicianYourId.
  ///
  /// In en, this message translates to:
  /// **'Your invite code'**
  String get clinicianYourId;

  /// No description provided for @clinicianCopyId.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get clinicianCopyId;

  /// No description provided for @clinicianCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get clinicianCopied;

  /// No description provided for @clinicianSharing.
  ///
  /// In en, this message translates to:
  /// **'Sharing'**
  String get clinicianSharing;

  /// No description provided for @clinicianAssessments.
  ///
  /// In en, this message translates to:
  /// **'Check-ins'**
  String get clinicianAssessments;

  /// No description provided for @clinicianMood.
  ///
  /// In en, this message translates to:
  /// **'Mood trend'**
  String get clinicianMood;

  /// No description provided for @clinicianSummaries.
  ///
  /// In en, this message translates to:
  /// **'Summaries'**
  String get clinicianSummaries;

  /// No description provided for @clinicianJournal.
  ///
  /// In en, this message translates to:
  /// **'Journal'**
  String get clinicianJournal;

  /// No description provided for @clinicianNoConsent.
  ///
  /// In en, this message translates to:
  /// **'This patient hasn\'t shared anything yet.'**
  String get clinicianNoConsent;

  /// No description provided for @youClinician.
  ///
  /// In en, this message translates to:
  /// **'I\'m a clinician'**
  String get youClinician;

  /// No description provided for @youClinicianSub.
  ///
  /// In en, this message translates to:
  /// **'Open the clinician workspace'**
  String get youClinicianSub;

  /// No description provided for @clinicianJoinTitle.
  ///
  /// In en, this message translates to:
  /// **'Clinician workspace'**
  String get clinicianJoinTitle;

  /// No description provided for @clinicianJoinBody.
  ///
  /// In en, this message translates to:
  /// **'Clinicians only see what a patient has linked them to and switched on. Accounts are checked against the licence number before any patient data opens.'**
  String get clinicianJoinBody;

  /// No description provided for @clinicianLicense.
  ///
  /// In en, this message translates to:
  /// **'Licence number (e.g. PMDC)'**
  String get clinicianLicense;

  /// No description provided for @clinicianSpecialty.
  ///
  /// In en, this message translates to:
  /// **'Specialty (optional)'**
  String get clinicianSpecialty;

  /// No description provided for @clinicianLicenseRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your licence number'**
  String get clinicianLicenseRequired;

  /// No description provided for @clinicianJoinAction.
  ///
  /// In en, this message translates to:
  /// **'Continue as clinician'**
  String get clinicianJoinAction;

  /// No description provided for @clinicianUsePatient.
  ///
  /// In en, this message translates to:
  /// **'Switch to patient view'**
  String get clinicianUsePatient;

  /// No description provided for @clinicianCodeHelp.
  ///
  /// In en, this message translates to:
  /// **'Patients enter this under You → Your care team.'**
  String get clinicianCodeHelp;

  /// No description provided for @clinicianNewCode.
  ///
  /// In en, this message translates to:
  /// **'New invite code'**
  String get clinicianNewCode;

  /// No description provided for @clinicianNewCodeBody.
  ///
  /// In en, this message translates to:
  /// **'Your current code will stop working. Patients already linked stay linked.'**
  String get clinicianNewCodeBody;

  /// No description provided for @clinicianNewCodeDone.
  ///
  /// In en, this message translates to:
  /// **'New code ready'**
  String get clinicianNewCodeDone;

  /// No description provided for @clinicianNotSharing.
  ///
  /// In en, this message translates to:
  /// **'Check-ins not shared'**
  String get clinicianNotSharing;

  /// No description provided for @clinicianNoCheckins.
  ///
  /// In en, this message translates to:
  /// **'No check-ins yet'**
  String get clinicianNoCheckins;

  /// No description provided for @clinicianAttentionRisk.
  ///
  /// In en, this message translates to:
  /// **'Item 9 endorsed (self-harm thoughts)'**
  String get clinicianAttentionRisk;

  /// No description provided for @clinicianAttentionWorsened.
  ///
  /// In en, this message translates to:
  /// **'Worsening'**
  String get clinicianAttentionWorsened;

  /// No description provided for @clinicianAttentionSevere.
  ///
  /// In en, this message translates to:
  /// **'Severe range'**
  String get clinicianAttentionSevere;

  /// No description provided for @careInviteNotFound.
  ///
  /// In en, this message translates to:
  /// **'No approved clinician has that code. Check it with them.'**
  String get careInviteNotFound;

  /// No description provided for @eveGreetingSub.
  ///
  /// In en, this message translates to:
  /// **'I\'ll listen first. You can start with something small.'**
  String get eveGreetingSub;

  /// No description provided for @eveSubtitleDevice.
  ///
  /// In en, this message translates to:
  /// **'Saved on this phone'**
  String get eveSubtitleDevice;

  /// No description provided for @eveSubtitleCloud.
  ///
  /// In en, this message translates to:
  /// **'Cloud mode · via your TherapyLink server'**
  String get eveSubtitleCloud;

  /// No description provided for @eveNewConversation.
  ///
  /// In en, this message translates to:
  /// **'New conversation'**
  String get eveNewConversation;

  /// No description provided for @eveExercises.
  ///
  /// In en, this message translates to:
  /// **'Exercises'**
  String get eveExercises;

  /// No description provided for @eveSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get eveSend;

  /// No description provided for @eveTryHere.
  ///
  /// In en, this message translates to:
  /// **'Try it here'**
  String get eveTryHere;

  /// No description provided for @eveStarterAnxious.
  ///
  /// In en, this message translates to:
  /// **'I\'ve been feeling anxious'**
  String get eveStarterAnxious;

  /// No description provided for @eveStarterSleep.
  ///
  /// In en, this message translates to:
  /// **'I can\'t sleep'**
  String get eveStarterSleep;

  /// No description provided for @eveStarterVent.
  ///
  /// In en, this message translates to:
  /// **'I just need to vent'**
  String get eveStarterVent;

  /// No description provided for @eveStarterRelationship.
  ///
  /// In en, this message translates to:
  /// **'Something happened with someone close'**
  String get eveStarterRelationship;

  /// No description provided for @eveStarterCalm.
  ///
  /// In en, this message translates to:
  /// **'Help me calm down'**
  String get eveStarterCalm;

  /// No description provided for @eveDateToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get eveDateToday;

  /// No description provided for @eveDateYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get eveDateYesterday;

  /// No description provided for @exerciseSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Take a minute'**
  String get exerciseSheetTitle;

  /// No description provided for @exerciseSheetBody.
  ///
  /// In en, this message translates to:
  /// **'These run right here in the chat. Stop any time.'**
  String get exerciseSheetBody;

  /// No description provided for @groundingTitle.
  ///
  /// In en, this message translates to:
  /// **'5-4-3-2-1 grounding'**
  String get groundingTitle;

  /// No description provided for @groundingSub.
  ///
  /// In en, this message translates to:
  /// **'Notice what\'s around you · about 2 minutes'**
  String get groundingSub;

  /// No description provided for @groundStep5.
  ///
  /// In en, this message translates to:
  /// **'Name 5 things you can see'**
  String get groundStep5;

  /// No description provided for @groundStep4.
  ///
  /// In en, this message translates to:
  /// **'4 things you can feel or touch'**
  String get groundStep4;

  /// No description provided for @groundStep3.
  ///
  /// In en, this message translates to:
  /// **'3 things you can hear'**
  String get groundStep3;

  /// No description provided for @groundStep2.
  ///
  /// In en, this message translates to:
  /// **'2 things you can smell'**
  String get groundStep2;

  /// No description provided for @groundStep1.
  ///
  /// In en, this message translates to:
  /// **'1 slow breath, in and out'**
  String get groundStep1;

  /// No description provided for @groundHint.
  ///
  /// In en, this message translates to:
  /// **'Type them if it helps, or just notice them.'**
  String get groundHint;

  /// No description provided for @groundAnswerHint.
  ///
  /// In en, this message translates to:
  /// **'For example: the window, my cup…'**
  String get groundAnswerHint;

  /// No description provided for @groundNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get groundNext;

  /// No description provided for @groundFinish.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get groundFinish;

  /// No description provided for @groundDone.
  ///
  /// In en, this message translates to:
  /// **'You\'re back in the room. How does it feel now?'**
  String get groundDone;

  /// No description provided for @muscleTitle.
  ///
  /// In en, this message translates to:
  /// **'Tense and release'**
  String get muscleTitle;

  /// No description provided for @muscleSub.
  ///
  /// In en, this message translates to:
  /// **'Seven muscle groups · about 2 minutes'**
  String get muscleSub;

  /// No description provided for @muscleIntro.
  ///
  /// In en, this message translates to:
  /// **'Squeeze each muscle group for five seconds, then let it go completely. Notice the difference.'**
  String get muscleIntro;

  /// No description provided for @muscleTense.
  ///
  /// In en, this message translates to:
  /// **'Squeeze'**
  String get muscleTense;

  /// No description provided for @muscleRelease.
  ///
  /// In en, this message translates to:
  /// **'Let go'**
  String get muscleRelease;

  /// No description provided for @muscleHands.
  ///
  /// In en, this message translates to:
  /// **'Your hands'**
  String get muscleHands;

  /// No description provided for @muscleArms.
  ///
  /// In en, this message translates to:
  /// **'Your arms'**
  String get muscleArms;

  /// No description provided for @muscleShoulders.
  ///
  /// In en, this message translates to:
  /// **'Your shoulders'**
  String get muscleShoulders;

  /// No description provided for @muscleFace.
  ///
  /// In en, this message translates to:
  /// **'Your face'**
  String get muscleFace;

  /// No description provided for @muscleStomach.
  ///
  /// In en, this message translates to:
  /// **'Your stomach'**
  String get muscleStomach;

  /// No description provided for @muscleLegs.
  ///
  /// In en, this message translates to:
  /// **'Your legs'**
  String get muscleLegs;

  /// No description provided for @muscleFeet.
  ///
  /// In en, this message translates to:
  /// **'Your feet'**
  String get muscleFeet;

  /// No description provided for @muscleDone.
  ///
  /// In en, this message translates to:
  /// **'Notice how loose feels different from tight.'**
  String get muscleDone;

  /// No description provided for @todayTakeAMinute.
  ///
  /// In en, this message translates to:
  /// **'Take a minute'**
  String get todayTakeAMinute;

  /// No description provided for @moodLogged.
  ///
  /// In en, this message translates to:
  /// **'Logged {mood} at {time}'**
  String moodLogged(String mood, String time);

  /// No description provided for @moodChange.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get moodChange;

  /// No description provided for @assessmentAgo.
  ///
  /// In en, this message translates to:
  /// **'{days} days ago'**
  String assessmentAgo(int days);

  /// No description provided for @resultOutOf.
  ///
  /// In en, this message translates to:
  /// **'out of {max}'**
  String resultOutOf(int max);

  /// No description provided for @resultExplainMinimal.
  ///
  /// In en, this message translates to:
  /// **'Your answers point to few or no symptoms over the last two weeks. That\'s a good place to be; checking in again in a fortnight keeps the picture honest.'**
  String get resultExplainMinimal;

  /// No description provided for @resultExplainMild.
  ///
  /// In en, this message translates to:
  /// **'Some symptoms showed up, but at a level many people manage on their own. Sleep, movement and someone to talk to tend to matter most here.'**
  String get resultExplainMild;

  /// No description provided for @resultExplainModerate.
  ///
  /// In en, this message translates to:
  /// **'Symptoms are affecting you often enough to be worth taking seriously. This is the range where talking to a psychologist or doctor usually helps, even if it feels manageable.'**
  String get resultExplainModerate;

  /// No description provided for @resultExplainModeratelySevere.
  ///
  /// In en, this message translates to:
  /// **'Symptoms are frequent and are likely getting in the way of daily life. Please consider seeing a psychologist or doctor soon; this responds well to treatment.'**
  String get resultExplainModeratelySevere;

  /// No description provided for @resultExplainSevere.
  ///
  /// In en, this message translates to:
  /// **'Your answers describe a heavy load, most days. You deserve proper support for this, and it helps: please book time with a psychologist or doctor this week.'**
  String get resultExplainSevere;

  /// No description provided for @resultTalk.
  ///
  /// In en, this message translates to:
  /// **'Talk it through with Eve'**
  String get resultTalk;

  /// No description provided for @journalPromptsTitle.
  ///
  /// In en, this message translates to:
  /// **'Need a start?'**
  String get journalPromptsTitle;

  /// No description provided for @journalPrompt1.
  ///
  /// In en, this message translates to:
  /// **'What drained me today'**
  String get journalPrompt1;

  /// No description provided for @journalPrompt2.
  ///
  /// In en, this message translates to:
  /// **'One thing that went okay'**
  String get journalPrompt2;

  /// No description provided for @journalPrompt3.
  ///
  /// In en, this message translates to:
  /// **'What I\'d tell a friend in my place'**
  String get journalPrompt3;

  /// No description provided for @welcomePointPrivate.
  ///
  /// In en, this message translates to:
  /// **'Your conversations with Eve are saved on this phone, and each message is sent to the TherapyLink server to be answered. Journal entries and check-ins are saved to your account.'**
  String get welcomePointPrivate;

  /// No description provided for @welcomePointLanguage.
  ///
  /// In en, this message translates to:
  /// **'English, Roman Urdu, or both, the way you actually type.'**
  String get welcomePointLanguage;

  /// No description provided for @welcomePointHelp.
  ///
  /// In en, this message translates to:
  /// **'When something is serious, real help is one tap away.'**
  String get welcomePointHelp;

  /// No description provided for @memoryTitle.
  ///
  /// In en, this message translates to:
  /// **'What Eve remembers'**
  String get memoryTitle;

  /// No description provided for @memoryRowSub.
  ///
  /// In en, this message translates to:
  /// **'See, delete, or switch off'**
  String get memoryRowSub;

  /// No description provided for @memoryIntro.
  ///
  /// In en, this message translates to:
  /// **'Eve keeps a few short notes from your conversations, like who matters to you and what you agreed to try, so you don\'t have to start from zero each time. They\'re saved on this phone, and the notes that relate to a message are sent with it to the TherapyLink server.'**
  String get memoryIntro;

  /// No description provided for @memoryToggle.
  ///
  /// In en, this message translates to:
  /// **'Remember between conversations'**
  String get memoryToggle;

  /// No description provided for @memoryToggleOn.
  ///
  /// In en, this message translates to:
  /// **'Eve uses these notes and adds new ones'**
  String get memoryToggleOn;

  /// No description provided for @memoryToggleOff.
  ///
  /// In en, this message translates to:
  /// **'Nothing is kept or used'**
  String get memoryToggleOff;

  /// No description provided for @memoryEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing yet'**
  String get memoryEmptyTitle;

  /// No description provided for @memoryEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'As you talk with Eve, the things worth remembering will show up here.'**
  String get memoryEmptyBody;

  /// No description provided for @memoryDelete.
  ///
  /// In en, this message translates to:
  /// **'Forget this'**
  String get memoryDelete;

  /// No description provided for @memoryForgetAll.
  ///
  /// In en, this message translates to:
  /// **'Forget everything'**
  String get memoryForgetAll;

  /// No description provided for @memoryForgetAllTitle.
  ///
  /// In en, this message translates to:
  /// **'Forget everything?'**
  String get memoryForgetAllTitle;

  /// No description provided for @memoryForgetAllBody.
  ///
  /// In en, this message translates to:
  /// **'Eve will lose all notes from earlier conversations. Your chats stay.'**
  String get memoryForgetAllBody;

  /// No description provided for @memoryKindPerson.
  ///
  /// In en, this message translates to:
  /// **'People'**
  String get memoryKindPerson;

  /// No description provided for @memoryKindSituation.
  ///
  /// In en, this message translates to:
  /// **'What\'s going on'**
  String get memoryKindSituation;

  /// No description provided for @memoryKindGoal.
  ///
  /// In en, this message translates to:
  /// **'What you want'**
  String get memoryKindGoal;

  /// No description provided for @memoryKindHelped.
  ///
  /// In en, this message translates to:
  /// **'What helped'**
  String get memoryKindHelped;

  /// No description provided for @memoryKindPlan.
  ///
  /// In en, this message translates to:
  /// **'Next steps you agreed'**
  String get memoryKindPlan;

  /// No description provided for @eveWrapUp.
  ///
  /// In en, this message translates to:
  /// **'Wrap up'**
  String get eveWrapUp;

  /// No description provided for @eveWrapUpWorking.
  ///
  /// In en, this message translates to:
  /// **'Pulling today together…'**
  String get eveWrapUpWorking;

  /// No description provided for @eveWrapUpFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t wrap up just now. Try again in a moment.'**
  String get eveWrapUpFailed;

  /// No description provided for @eveNextStep.
  ///
  /// In en, this message translates to:
  /// **'Next step: {step}'**
  String eveNextStep(String step);

  /// No description provided for @eveFollowUp.
  ///
  /// In en, this message translates to:
  /// **'Last time you planned to: {step}'**
  String eveFollowUp(String step);

  /// No description provided for @eveFollowUpStart.
  ///
  /// In en, this message translates to:
  /// **'How did it go?'**
  String get eveFollowUpStart;

  /// No description provided for @eveFollowUpMessage.
  ///
  /// In en, this message translates to:
  /// **'Let\'s talk about how my last step went: {step}'**
  String eveFollowUpMessage(String step);

  /// No description provided for @eveBreakNudge.
  ///
  /// In en, this message translates to:
  /// **'We\'ve been talking a while. It can help to take a break, or to share some of this with someone you trust.'**
  String get eveBreakNudge;

  /// No description provided for @eveBreakDismiss.
  ///
  /// In en, this message translates to:
  /// **'Keep talking'**
  String get eveBreakDismiss;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @signOutConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out?'**
  String get signOutConfirmTitle;

  /// No description provided for @signOutConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Your conversations with Eve and her memory notes will be deleted from this phone. Check-ins, mood trend and journal stay on your account.'**
  String get signOutConfirmBody;

  /// No description provided for @signOutUnsentTitle.
  ///
  /// In en, this message translates to:
  /// **'Some check-ins haven\'t been sent'**
  String get signOutUnsentTitle;

  /// No description provided for @signOutUnsentBody.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 check-in hasn\'t reached your account yet, probably because you\'re offline. If you sign out now it will be lost. Connect and try again to keep it.} other{{count} check-ins haven\'t reached your account yet, probably because you\'re offline. If you sign out now they will be lost. Connect and try again to keep them.}}'**
  String signOutUnsentBody(int count);

  /// No description provided for @signOutAnyway.
  ///
  /// In en, this message translates to:
  /// **'Sign out anyway'**
  String get signOutAnyway;

  /// No description provided for @youDeleteChats.
  ///
  /// In en, this message translates to:
  /// **'Delete all Eve chats'**
  String get youDeleteChats;

  /// No description provided for @youDeleteChatsSub.
  ///
  /// In en, this message translates to:
  /// **'Removes every conversation and memory note from this phone'**
  String get youDeleteChatsSub;

  /// No description provided for @deleteChatsTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete all Eve chats?'**
  String get deleteChatsTitle;

  /// No description provided for @deleteChatsBody.
  ///
  /// In en, this message translates to:
  /// **'Every conversation with Eve and everything she remembers will be removed from this phone. This can\'t be undone.'**
  String get deleteChatsBody;

  /// No description provided for @deleteChatsAction.
  ///
  /// In en, this message translates to:
  /// **'Delete chats'**
  String get deleteChatsAction;

  /// No description provided for @deleteChatsDone.
  ///
  /// In en, this message translates to:
  /// **'Eve chats deleted.'**
  String get deleteChatsDone;

  /// No description provided for @youDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get youDeleteAccount;

  /// No description provided for @youDeleteAccountSub.
  ///
  /// In en, this message translates to:
  /// **'Removes your account and everything stored with it'**
  String get youDeleteAccountSub;

  /// No description provided for @deleteAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete your account?'**
  String get deleteAccountTitle;

  /// No description provided for @deleteAccountBody.
  ///
  /// In en, this message translates to:
  /// **'This deletes your account and your check-ins, mood trend, journal and clinician links from the TherapyLink server, and clears Eve\'s conversations from this phone. This can\'t be undone.'**
  String get deleteAccountBody;

  /// No description provided for @deleteAccountAction.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccountAction;

  /// No description provided for @deleteAccountFailed.
  ///
  /// In en, this message translates to:
  /// **'Your account couldn\'t be deleted just now, and nothing was removed. Check your connection and try again.'**
  String get deleteAccountFailed;

  /// No description provided for @getHelpNow.
  ///
  /// In en, this message translates to:
  /// **'Get help now'**
  String get getHelpNow;

  /// No description provided for @youHelpSub.
  ///
  /// In en, this message translates to:
  /// **'Helplines and their numbers'**
  String get youHelpSub;

  /// PENDING LEGAL AND CLINICIAN REVIEW: placeholder consent wording, not yet approved.
  ///
  /// In en, this message translates to:
  /// **'Before you start'**
  String get consentTitle;

  /// Short app bar title for the consent screen. Keeps the bar uncluttered; full title appears as a heading in the scroll body.
  ///
  /// In en, this message translates to:
  /// **'Consent'**
  String get consentBarTitle;

  /// PENDING LEGAL AND CLINICIAN REVIEW: placeholder consent wording, not yet approved.
  ///
  /// In en, this message translates to:
  /// **'Eve is an AI, not a therapist'**
  String get consentAiTitle;

  /// PENDING CLINICIAN REVIEW: clinical/safety wording drafted by engineering, not yet approved.
  ///
  /// In en, this message translates to:
  /// **'Eve is a computer program. She can listen and suggest simple exercises, but she can\'t diagnose or treat anything, she doesn\'t replace a doctor or psychologist, and she can get things wrong.'**
  String get consentAiBody;

  /// PENDING CLINICIAN REVIEW: clinical/safety wording drafted by engineering, not yet approved.
  ///
  /// In en, this message translates to:
  /// **'Not for emergencies'**
  String get consentEmergencyTitle;

  /// PENDING CLINICIAN REVIEW: clinical/safety wording drafted by engineering, not yet approved.
  ///
  /// In en, this message translates to:
  /// **'Nobody watches your chats with Eve, and telling Eve you\'re in danger doesn\'t alert anyone. If you might hurt yourself or someone else, or you\'re in danger, call 1122 or a helpline from Get help now. Eve can\'t call anyone for you.'**
  String get consentEmergencyBody;

  /// PENDING LEGAL AND CLINICIAN REVIEW: placeholder consent wording, not yet approved.
  ///
  /// In en, this message translates to:
  /// **'What is stored where'**
  String get consentDataTitle;

  /// PENDING LEGAL AND CLINICIAN REVIEW: placeholder consent wording, not yet approved. API fact-checked 2026-10-03: no chat-messages table exists on the server (see api/therapylink_api/models.py); messages are processed in-memory only.
  ///
  /// In en, this message translates to:
  /// **'Your conversations with Eve are saved only on this phone. To answer each message, it is sent to the TherapyLink server with the memory notes that relate to it, and it is not stored there. Check-in scores, mood points, journal entries and your account details are stored on your TherapyLink account so they follow you to a new phone. A clinician sees only what you link them to and switch on.'**
  String get consentDataBody;

  /// PENDING LEGAL AND CLINICIAN REVIEW: placeholder consent wording, not yet approved.
  ///
  /// In en, this message translates to:
  /// **'I am 18 or older'**
  String get consentAge;

  /// PENDING LEGAL AND CLINICIAN REVIEW: placeholder consent wording, not yet approved.
  ///
  /// In en, this message translates to:
  /// **'I\'m under 18'**
  String get consentUnder18;

  /// PENDING LEGAL AND CLINICIAN REVIEW: placeholder consent wording, not yet approved.
  ///
  /// In en, this message translates to:
  /// **'I\'ve read the terms and privacy policy and agree to them'**
  String get consentAgree;

  /// No description provided for @consentTerms.
  ///
  /// In en, this message translates to:
  /// **'Terms of use'**
  String get consentTerms;

  /// No description provided for @consentPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get consentPrivacy;

  /// No description provided for @consentAccept.
  ///
  /// In en, this message translates to:
  /// **'Agree and continue'**
  String get consentAccept;

  /// PENDING CLINICIAN REVIEW: clinical/safety wording drafted by engineering, not yet approved.
  ///
  /// In en, this message translates to:
  /// **'TherapyLink is for adults'**
  String get under18Title;

  /// PENDING CLINICIAN REVIEW: clinical/safety wording drafted by engineering, not yet approved.
  ///
  /// In en, this message translates to:
  /// **'This app is made for people 18 and over, so Eve can\'t chat with you here. If something is hard right now, you deserve real support. Talk to an adult you trust, like a teacher, a relative or a neighbour, or call one of these:'**
  String get under18Body;

  /// PENDING CLINICIAN REVIEW: clinical/safety wording drafted by engineering, not yet approved.
  ///
  /// In en, this message translates to:
  /// **'Madadgaar child helpline · 1098'**
  String get under18CallChild;

  /// No description provided for @under18Back.
  ///
  /// In en, this message translates to:
  /// **'I entered my age wrong'**
  String get under18Back;

  /// No description provided for @signInOr.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get signInOr;

  /// No description provided for @authErrorMismatch.
  ///
  /// In en, this message translates to:
  /// **'That email and password don\'t match.'**
  String get authErrorMismatch;

  /// No description provided for @authErrorInUse.
  ///
  /// In en, this message translates to:
  /// **'There\'s already an account with that email. Try signing in.'**
  String get authErrorInUse;

  /// No description provided for @authErrorWeakPassword.
  ///
  /// In en, this message translates to:
  /// **'Use at least 8 characters.'**
  String get authErrorWeakPassword;

  /// No description provided for @authErrorInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'That doesn\'t look like an email address.'**
  String get authErrorInvalidEmail;

  /// No description provided for @authErrorTooMany.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Wait a minute and try again.'**
  String get authErrorTooMany;

  /// No description provided for @authErrorNetwork.
  ///
  /// In en, this message translates to:
  /// **'No connection. Check your network and try again.'**
  String get authErrorNetwork;

  /// No description provided for @authErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'That didn\'t work. Try again in a moment.'**
  String get authErrorGeneric;

  /// No description provided for @authErrorGoogle.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in didn\'t work on this phone. Use email for now.'**
  String get authErrorGoogle;

  /// No description provided for @resetNeedsEmail.
  ///
  /// In en, this message translates to:
  /// **'Type your email above first, then tap this again.'**
  String get resetNeedsEmail;

  /// No description provided for @validateEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter your email'**
  String get validateEmail;

  /// No description provided for @validatePassword.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters'**
  String get validatePassword;

  /// No description provided for @settingsTextSmaller.
  ///
  /// In en, this message translates to:
  /// **'Smaller text'**
  String get settingsTextSmaller;

  /// No description provided for @settingsTextLarger.
  ///
  /// In en, this message translates to:
  /// **'Larger text'**
  String get settingsTextLarger;

  /// No description provided for @cloudConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Use cloud mode?'**
  String get cloudConfirmTitle;

  /// No description provided for @cloudConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'In cloud mode your messages, and the memory notes that relate to them, leave this phone and are sent to the TherapyLink server to be answered. This is for testing only.'**
  String get cloudConfirmBody;

  /// No description provided for @cloudConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Use cloud mode'**
  String get cloudConfirmAction;

  /// No description provided for @careVerified.
  ///
  /// In en, this message translates to:
  /// **'Verified clinician'**
  String get careVerified;

  /// No description provided for @clinicianConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Switch to the clinician workspace?'**
  String get clinicianConfirmTitle;

  /// No description provided for @clinicianConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This is only for licensed clinicians. Your account becomes a clinician account and the patient tabs close. If you\'re here for yourself, you don\'t need this.'**
  String get clinicianConfirmBody;

  /// No description provided for @clinicianConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'I\'m a licensed clinician'**
  String get clinicianConfirmAction;

  /// No description provided for @clinicianRequests.
  ///
  /// In en, this message translates to:
  /// **'Link requests'**
  String get clinicianRequests;

  /// No description provided for @clinicianRequestsWaiting.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No one waiting} =1{1 patient waiting} other{{count} patients waiting}}'**
  String clinicianRequestsWaiting(int count);

  /// No description provided for @clinicianRequestsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No one is waiting. When a patient adds your invite code, they appear here.'**
  String get clinicianRequestsEmpty;

  /// No description provided for @clinicianRequestsHelp.
  ///
  /// In en, this message translates to:
  /// **'Accepting lets you see only what the patient chooses to share with you.'**
  String get clinicianRequestsHelp;

  /// No description provided for @clinicianRequestAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get clinicianRequestAccept;

  /// No description provided for @clinicianRequestDecline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get clinicianRequestDecline;

  /// No description provided for @clinicianRequestedOn.
  ///
  /// In en, this message translates to:
  /// **'Asked on {date}'**
  String clinicianRequestedOn(String date);

  /// No description provided for @carePendingTitle.
  ///
  /// In en, this message translates to:
  /// **'Waiting for approval'**
  String get carePendingTitle;

  /// No description provided for @carePendingBody.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the clinician to accept. They can\'t see anything of yours until they do, and after that only what you switch on.'**
  String get carePendingBody;

  /// No description provided for @carePendingCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel request'**
  String get carePendingCancel;

  /// No description provided for @careActiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Linked clinicians'**
  String get careActiveTitle;

  /// No description provided for @youExport.
  ///
  /// In en, this message translates to:
  /// **'Download my data'**
  String get youExport;

  /// No description provided for @youExportSub.
  ///
  /// In en, this message translates to:
  /// **'A copy of everything your account holds, as a file. It isn\'t locked, so keep it somewhere safe.'**
  String get youExportSub;

  /// No description provided for @youExportWorking.
  ///
  /// In en, this message translates to:
  /// **'Preparing your data…'**
  String get youExportWorking;

  /// No description provided for @youExportDone.
  ///
  /// In en, this message translates to:
  /// **'Saved to {path}'**
  String youExportDone(String path);

  /// No description provided for @youExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t download your data. Check your connection and try again.'**
  String get youExportFailed;

  /// PENDING CLINICIAN REVIEW: shown beside a PHQ-9/GAD-7 score answered in Roman Urdu. Wording drafted by engineering, not yet approved.
  ///
  /// In en, this message translates to:
  /// **'Unvalidated translation'**
  String get clinicianUnvalidatedTranslation;

  /// PENDING CLINICIAN REVIEW: tooltip for the unvalidated translation notice. Wording drafted by engineering, not yet approved.
  ///
  /// In en, this message translates to:
  /// **'Answered in the app\'s Roman Urdu wording. It follows the published Urdu versions where it can, but Roman Urdu wording has not itself been validated against the original questionnaire. Read the score and its band with care.'**
  String get clinicianUnvalidatedTranslationHelp;

  /// No description provided for @accessLogTitle.
  ///
  /// In en, this message translates to:
  /// **'Who viewed my data'**
  String get accessLogTitle;

  /// No description provided for @accessLogSub.
  ///
  /// In en, this message translates to:
  /// **'Each time a clinician was shown your data'**
  String get accessLogSub;

  /// No description provided for @accessLogIntro.
  ///
  /// In en, this message translates to:
  /// **'Each time a clinician you linked opens your page or their patient list, it\'s recorded here with what they were shown.'**
  String get accessLogIntro;

  /// No description provided for @accessLogEmpty.
  ///
  /// In en, this message translates to:
  /// **'No clinician has viewed your data.'**
  String get accessLogEmpty;

  /// No description provided for @accessLogSomeone.
  ///
  /// In en, this message translates to:
  /// **'A clinician'**
  String get accessLogSomeone;

  /// No description provided for @accessLogCaseload.
  ///
  /// In en, this message translates to:
  /// **'Saw you in their patient list'**
  String get accessLogCaseload;

  /// No description provided for @accessLogOverview.
  ///
  /// In en, this message translates to:
  /// **'Opened your page'**
  String get accessLogOverview;

  /// No description provided for @accessLogNothingShown.
  ///
  /// In en, this message translates to:
  /// **'Nothing you share was shown'**
  String get accessLogNothingShown;

  /// Screen-reader prefix for Eve's chat bubbles.
  ///
  /// In en, this message translates to:
  /// **'Eve said'**
  String get eveSaidLabel;

  /// Screen-reader prefix for the person's own chat bubbles.
  ///
  /// In en, this message translates to:
  /// **'You said'**
  String get youSaidLabel;

  /// PENDING CLINICIAN REVIEW: shown in place of the composer when a release build has no working trained safety check. Wording drafted by engineering, not yet approved.
  ///
  /// In en, this message translates to:
  /// **'Safety check not ready'**
  String get eveSafetyNotReadyTitle;

  /// PENDING CLINICIAN REVIEW: body of the paused-chat notice. Wording drafted by engineering, not yet approved.
  ///
  /// In en, this message translates to:
  /// **'Eve checks every message for signs of danger before she replies. That check isn\'t ready on this phone yet, so chat is paused. You can still do an exercise, or get help now.'**
  String get eveSafetyNotReadyBody;

  /// PENDING CLINICIAN REVIEW: shown in place of the composer when a release build has no fine-tuned Eve model. Wording drafted by engineering, not yet approved.
  ///
  /// In en, this message translates to:
  /// **'Eve isn\'t available in this version'**
  String get eveUnavailableTitle;

  /// PENDING CLINICIAN REVIEW: body of the Eve-unavailable notice. Wording drafted by engineering, not yet approved.
  ///
  /// In en, this message translates to:
  /// **'Eve\'s model for this app hasn\'t been released yet. Exercises, your journal and help are all still here.'**
  String get eveUnavailableBody;

  /// PENDING CLINICIAN REVIEW: safety-status line (Settings, and the paused-chat notice in release builds) when the trained Guardian failed to download, failed its install or hash check, or failed at runtime. Wording drafted by engineering, not yet approved.
  ///
  /// In en, this message translates to:
  /// **'The trained safety model couldn\'t be downloaded, set up or run on this phone, so the built-in keyword check is running on its own. Try downloading it again.'**
  String get guardianFailed;

  /// No description provided for @settingsPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy on this phone'**
  String get settingsPrivacy;

  /// No description provided for @appLockTitle.
  ///
  /// In en, this message translates to:
  /// **'App lock'**
  String get appLockTitle;

  /// PENDING CLINICIAN REVIEW: explains the opt-in app lock in Settings, including that crisis help stays reachable while locked. Wording drafted by engineering, not yet approved.
  ///
  /// In en, this message translates to:
  /// **'Ask for your fingerprint, face or phone PIN when the app opens, or when you come back after a minute away. Get help now still works while it\'s locked. While this is on, screenshots are blocked and the app is hidden in recent apps.'**
  String get appLockBody;

  /// No description provided for @appLockUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Set a screen lock on your phone first, then turn this on.'**
  String get appLockUnavailable;

  /// Neutral title of the lock screen. Deliberately does not name the app or what it is for.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get lockTitle;

  /// No description provided for @lockBody.
  ///
  /// In en, this message translates to:
  /// **'Unlock with your fingerprint, face or phone PIN.'**
  String get lockBody;

  /// No description provided for @lockUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get lockUnlock;

  /// No description provided for @lockFailed.
  ///
  /// In en, this message translates to:
  /// **'That didn\'t unlock. Try again.'**
  String get lockFailed;

  /// Shown by the phone's own fingerprint/PIN prompt. Neutral on purpose.
  ///
  /// In en, this message translates to:
  /// **'Unlock to continue'**
  String get lockReason;

  /// PENDING CLINICIAN REVIEW: name of the quick-exit button and setting, a safety feature for people whose screen may be watched. Wording drafted by engineering, not yet approved.
  ///
  /// In en, this message translates to:
  /// **'Quick exit'**
  String get quickExitTitle;

  /// PENDING CLINICIAN REVIEW: explains the quick-exit setting. Wording drafted by engineering, not yet approved.
  ///
  /// In en, this message translates to:
  /// **'Shows a button at the top of each page that hides this app straight away, for when someone might be looking at your screen.'**
  String get quickExitBody;

  /// PENDING CLINICIAN REVIEW: the only text on the neutral screen shown after a quick exit. Must not hint at what the app is. Wording drafted by engineering, not yet approved.
  ///
  /// In en, this message translates to:
  /// **'Nothing open right now.'**
  String get quickExitNeutral;

  /// Shown once when a database from an earlier version could not be encrypted. Nothing was lost.
  ///
  /// In en, this message translates to:
  /// **'Your chats on this phone couldn\'t be encrypted this time. They\'re still here, and the app will try again next time it opens.'**
  String get dbMigrationFailed;

  /// Shown once when the local database could not be opened with this phone's key.
  ///
  /// In en, this message translates to:
  /// **'Your earlier chats on this phone couldn\'t be opened, so a new, empty space was started. The old file has been kept.'**
  String get dbUnreadable;

  /// PENDING CLINICIAN REVIEW: shown when the local database could not be opened (key store or encryption failure). The app retries on next use. Wording drafted by engineering, not yet approved.
  ///
  /// In en, this message translates to:
  /// **'Your chats on this phone can\'t be opened right now, so nothing new is being saved. Try closing and reopening the app. If you need to talk to someone now, Get help now still works.'**
  String get dbOpenFailed;

  /// No description provided for @eveBusyTitle.
  ///
  /// In en, this message translates to:
  /// **'Eve is with someone else right now'**
  String get eveBusyTitle;

  /// No description provided for @eveBusyBody.
  ///
  /// In en, this message translates to:
  /// **'The server is busy. Wait a moment and try again.'**
  String get eveBusyBody;

  /// No description provided for @eveSlowTitle.
  ///
  /// In en, this message translates to:
  /// **'Eve is resting'**
  String get eveSlowTitle;

  /// No description provided for @eveSlowBody.
  ///
  /// In en, this message translates to:
  /// **'The connection timed out. Eve may be slow to respond right now. Try again in a moment.'**
  String get eveSlowBody;

  /// No description provided for @eveTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get eveTryAgain;

  /// No description provided for @evePrivacyInline.
  ///
  /// In en, this message translates to:
  /// **'This chat is saved only on this phone. Eve\'s replies come from our server, which doesn\'t keep them.'**
  String get evePrivacyInline;
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
      <String>['en', 'ur'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ur':
      return AppLocalizationsUr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
