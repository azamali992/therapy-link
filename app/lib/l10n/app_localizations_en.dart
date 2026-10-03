// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'TherapyLink';

  @override
  String get continueLabel => 'Continue';

  @override
  String get retry => 'Try again';

  @override
  String get errorGeneric =>
      'Something went wrong. Check your connection and try again.';

  @override
  String get notShared => 'Not shared';

  @override
  String get tabEve => 'Eve';

  @override
  String get tabToday => 'Today';

  @override
  String get tabJournal => 'Journal';

  @override
  String get tabYou => 'You';

  @override
  String get welcomeTitle => 'Someone to talk to, any hour';

  @override
  String get welcomeBody =>
      'Eve listens in English or Roman Urdu. Your conversations with her are saved on this phone. Each message is sent to the TherapyLink server so she can answer, and it isn\'t stored there.';

  @override
  String get welcomeLanguage => 'Which do you type in most?';

  @override
  String get welcomeEnglish => 'English';

  @override
  String get welcomeRomanUrdu => 'Roman Urdu';

  @override
  String get signInTitle => 'Welcome back';

  @override
  String get signInSubtitle =>
      'Sign in to keep your check-ins and journal with you.';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get signIn => 'Sign in';

  @override
  String get createAccount => 'Create account';

  @override
  String get haveAccount => 'Already have an account? Sign in';

  @override
  String get noAccount => 'New here? Create an account';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get resetSent => 'Reset email sent.';

  @override
  String get signOut => 'Sign out';

  @override
  String get eveGreeting => 'I\'m Eve. What\'s going on?';

  @override
  String get eveComposerHint => 'Say anything…';

  @override
  String get eveListening => 'Eve is listening';

  @override
  String get evePrivacy =>
      'Saved on this phone. Each message goes to the TherapyLink server to be answered.';

  @override
  String get evePrivacyCloud =>
      'Cloud mode: messages are sent to your TherapyLink server.';

  @override
  String get modelMissingTitle => 'Eve isn\'t on this device yet';

  @override
  String modelMissingBody(String gb) {
    return 'One-time download of about $gb GB. Wi-Fi recommended. After that, Eve works fully offline.';
  }

  @override
  String get modelDownload => 'Download Eve';

  @override
  String modelDownloading(int percent) {
    return 'Downloading Eve · $percent%';
  }

  @override
  String get modelFailed =>
      'The download didn\'t finish. Check your connection and try again.';

  @override
  String get guardianTitle => 'Safety check';

  @override
  String get guardianHeuristic => 'Using the built-in keyword check.';

  @override
  String get guardianReady =>
      'Trained model installed. Runs on this device before every message.';

  @override
  String get guardianDownload => 'Download safety model';

  @override
  String guardianDownloading(int percent) {
    return 'Downloading safety model · $percent%';
  }

  @override
  String get guardianUnavailable => 'Not published yet.';

  @override
  String guardianWaitingForWifi(int megabytes) {
    return 'Waiting for Wi-Fi to download the safety model ($megabytes MB). The built-in keyword check runs until then.';
  }

  @override
  String get guardianDownloadOnData => 'Download on mobile data';

  @override
  String guardianNoSpace(int megabytes) {
    return 'There isn\'t enough space on this phone for the safety model. Free up about $megabytes MB, then try again. The built-in keyword check runs until then.';
  }

  @override
  String get guardianMeanwhile =>
      'The built-in keyword check runs until it\'s ready.';

  @override
  String get crisisCallUmang => 'Call Umang · 0311 7786264';

  @override
  String get crisisCallEmergency => 'Emergency · 1122';

  @override
  String get crisisKeepTalking => 'Keep talking to Eve';

  @override
  String get todayMorning => 'Good morning';

  @override
  String get todayAfternoon => 'Good afternoon';

  @override
  String get todayEvening => 'Good evening';

  @override
  String get moodPrompt => 'How are you right now?';

  @override
  String get moodSaved => 'Noted.';

  @override
  String get moodVeryLow => 'Very low';

  @override
  String get moodLow => 'Low';

  @override
  String get moodOkay => 'Okay';

  @override
  String get moodGood => 'Good';

  @override
  String get moodGreat => 'Great';

  @override
  String get moodTrend => 'Last 30 days';

  @override
  String get moodTrendWeek => 'This week';

  @override
  String get moodTrendEmpty =>
      'Check in a few times and a trend will appear here.';

  @override
  String get groundingOffer =>
      'That sounds like a lot to sit with. Would a minute of paced breathing help?';

  @override
  String get groundingAccept => 'Try it';

  @override
  String get groundingDecline => 'Not now';

  @override
  String get insightMorning => 'mornings';

  @override
  String get insightAfternoon => 'afternoons';

  @override
  String get insightEvening => 'evenings';

  @override
  String insightTimeOfDay(String worse, String better) {
    return 'Your $worse have tended to be harder than your $better.';
  }

  @override
  String get insightWeekUp =>
      'This week has been a little lighter than last week.';

  @override
  String get insightWeekDown => 'This week has been heavier than last week.';

  @override
  String insightBasis(int n) {
    return 'Based on $n check-ins. A pattern, not a diagnosis.';
  }

  @override
  String get exercisesTitle => 'Grounding';

  @override
  String get exercisesSub => 'A few minutes of paced breathing';

  @override
  String get exerciseSigh => 'Reset breath';

  @override
  String get exerciseSighSub => 'Two inhales, one long exhale · about 1 minute';

  @override
  String get exerciseBox => 'Box breathing';

  @override
  String get exerciseBoxSub => 'Even four counts · about 2 minutes';

  @override
  String get exerciseCalming => '4-7-8';

  @override
  String get exerciseCalmingSub => 'Long exhale · about 1 minute';

  @override
  String get breathIn => 'Breathe in';

  @override
  String get breathHold => 'Hold';

  @override
  String get breathOut => 'Breathe out';

  @override
  String get breathRest => 'Rest';

  @override
  String get breathStart => 'Start';

  @override
  String get breathPause => 'Pause';

  @override
  String get breathAgain => 'Go again';

  @override
  String get breathRestart => 'Start over';

  @override
  String get breathDone => 'Done';

  @override
  String breathCycleOf(int n, int total) {
    return 'Round $n of $total';
  }

  @override
  String get breathResume => 'Resume';

  @override
  String get breathStop => 'Stop whenever you like. Nothing is counted.';

  @override
  String get breathNote =>
      'Stop any time. If you feel light-headed, breathe normally.';

  @override
  String get assessmentsTitle => 'Check-ins';

  @override
  String get assessmentPhq9 => 'Mood check-in';

  @override
  String get assessmentPhq9Sub => 'PHQ-9 · 9 questions · 2 minutes';

  @override
  String get assessmentGad7 => 'Anxiety check-in';

  @override
  String get assessmentGad7Sub => 'GAD-7 · 7 questions · 2 minutes';

  @override
  String assessmentLast(int score, String band) {
    return 'Last: $score · $band';
  }

  @override
  String get assessmentNever => 'Not taken yet';

  @override
  String get assessmentIntro =>
      'Over the last two weeks, how often have you been bothered by the following?';

  @override
  String get assessmentNext => 'Next';

  @override
  String get assessmentBack => 'Back';

  @override
  String get assessmentFinish => 'See result';

  @override
  String assessmentQuestionOf(int n, int total) {
    return '$n of $total';
  }

  @override
  String get optNotAtAll => 'Not at all';

  @override
  String get optSeveralDays => 'Several days';

  @override
  String get optMoreThanHalf => 'More than half the days';

  @override
  String get optNearlyEveryDay => 'Nearly every day';

  @override
  String get resultTitle => 'Your result';

  @override
  String resultScore(int score, int max) {
    return '$score out of $max';
  }

  @override
  String resultDelta(String delta) {
    return '$delta since last time';
  }

  @override
  String get bandMinimal => 'Minimal';

  @override
  String get bandMild => 'Mild';

  @override
  String get bandModerate => 'Moderate';

  @override
  String get bandModeratelySevere => 'Moderately severe';

  @override
  String get bandSevere => 'Severe';

  @override
  String get resultNote =>
      'This is a screening score, not a diagnosis. It\'s most useful as a trend over time.';

  @override
  String get resultFlagged =>
      'You answered that you\'ve had thoughts of being better off dead or of hurting yourself. That matters, and there are people who want to help right now.';

  @override
  String get resultDone => 'Done';

  @override
  String get resultTalkToEve => 'Talk it through with Eve';

  @override
  String get journalTitle => 'Journal';

  @override
  String get journalNew => 'New entry';

  @override
  String get journalEmptyTitle => 'Nothing here yet';

  @override
  String get journalEmptyBody =>
      'A few honest lines are enough. Entries are saved to your account, and a clinician sees them only if you choose to share them.';

  @override
  String get journalTitleHint => 'Title (optional)';

  @override
  String get journalBodyHint => 'What\'s going on?';

  @override
  String get journalSave => 'Save';

  @override
  String get journalDelete => 'Delete entry';

  @override
  String get journalMood => 'Mood while writing';

  @override
  String get youTitle => 'You';

  @override
  String get youCare => 'Your care team';

  @override
  String get youCareSub => 'Who can see what';

  @override
  String get youSettings => 'Settings';

  @override
  String get youDataTitle => 'Where your data lives';

  @override
  String get youDataBody =>
      'Conversations with Eve and her memory notes are saved on this phone. To answer you, each message and the notes that relate to it are sent to the TherapyLink server, which doesn\'t store them. Check-in scores, your mood trend and journal entries are stored on your account so they follow you, and a clinician sees them only if you link one and switch that on.';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageSystem => 'System';

  @override
  String get settingsTextSize => 'Text size';

  @override
  String get settingsReduceMotion => 'Reduce motion';

  @override
  String get settingsTheme => 'Appearance';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsModel => 'Eve runs';

  @override
  String get settingsModelOnDevice => 'On this device';

  @override
  String get settingsModelCloud => 'In the cloud';

  @override
  String get careTitle => 'Your care team';

  @override
  String get careEmptyTitle => 'No clinician linked';

  @override
  String get careEmptyBody =>
      'If you\'re working with a clinician, ask them for their invite code and add it here. Nothing is shared until you switch it on.';

  @override
  String get careInvite => 'Add a clinician';

  @override
  String get careInviteHint => 'Invite code';

  @override
  String get careConsentTitle => 'What they can see';

  @override
  String get careShareAssessments => 'Check-in scores';

  @override
  String get careShareMood => 'Mood trend';

  @override
  String get careShareSummaries => 'Weekly summaries';

  @override
  String get careShareJournal => 'Journal entries';

  @override
  String get careRevoke => 'Remove clinician';

  @override
  String get careRevoked => 'Removed';

  @override
  String get clinicianCaseload => 'Patients';

  @override
  String get clinicianPending =>
      'Your clinician account is awaiting verification. You\'ll be able to see patients once it\'s approved.';

  @override
  String get clinicianEmpty =>
      'No patients yet. Give a patient your invite code and they can add you from their app.';

  @override
  String get clinicianYourId => 'Your invite code';

  @override
  String get clinicianCopyId => 'Copy';

  @override
  String get clinicianCopied => 'Copied';

  @override
  String get clinicianSharing => 'Sharing';

  @override
  String get clinicianAssessments => 'Check-ins';

  @override
  String get clinicianMood => 'Mood trend';

  @override
  String get clinicianSummaries => 'Summaries';

  @override
  String get clinicianJournal => 'Journal';

  @override
  String get clinicianNoConsent => 'This patient hasn\'t shared anything yet.';

  @override
  String get youClinician => 'I\'m a clinician';

  @override
  String get youClinicianSub => 'Open the clinician workspace';

  @override
  String get clinicianJoinTitle => 'Clinician workspace';

  @override
  String get clinicianJoinBody =>
      'Clinicians only see what a patient has linked them to and switched on. Accounts are checked against the licence number before any patient data opens.';

  @override
  String get clinicianLicense => 'Licence number (e.g. PMDC)';

  @override
  String get clinicianSpecialty => 'Specialty (optional)';

  @override
  String get clinicianLicenseRequired => 'Enter your licence number';

  @override
  String get clinicianJoinAction => 'Continue as clinician';

  @override
  String get clinicianUsePatient => 'Switch to patient view';

  @override
  String get clinicianCodeHelp =>
      'Patients enter this under You → Your care team.';

  @override
  String get clinicianNewCode => 'New invite code';

  @override
  String get clinicianNewCodeBody =>
      'Your current code will stop working. Patients already linked stay linked.';

  @override
  String get clinicianNewCodeDone => 'New code ready';

  @override
  String get clinicianNotSharing => 'Check-ins not shared';

  @override
  String get clinicianNoCheckins => 'No check-ins yet';

  @override
  String get clinicianAttentionRisk => 'Item 9 endorsed (self-harm thoughts)';

  @override
  String get clinicianAttentionWorsened => 'Worsening';

  @override
  String get clinicianAttentionSevere => 'Severe range';

  @override
  String get careInviteNotFound =>
      'No approved clinician has that code. Check it with them.';

  @override
  String get eveGreetingSub =>
      'I\'ll listen first. You can start with something small.';

  @override
  String get eveSubtitleDevice => 'Saved on this phone';

  @override
  String get eveSubtitleCloud => 'Cloud mode · via your TherapyLink server';

  @override
  String get eveNewConversation => 'New conversation';

  @override
  String get eveExercises => 'Exercises';

  @override
  String get eveSend => 'Send';

  @override
  String get eveTryHere => 'Try it here';

  @override
  String get eveStarterAnxious => 'I\'ve been feeling anxious';

  @override
  String get eveStarterSleep => 'I can\'t sleep';

  @override
  String get eveStarterVent => 'I just need to vent';

  @override
  String get eveStarterRelationship => 'Something happened with someone close';

  @override
  String get eveStarterCalm => 'Help me calm down';

  @override
  String get eveDateToday => 'Today';

  @override
  String get eveDateYesterday => 'Yesterday';

  @override
  String get exerciseSheetTitle => 'Take a minute';

  @override
  String get exerciseSheetBody =>
      'These run right here in the chat. Stop any time.';

  @override
  String get groundingTitle => '5-4-3-2-1 grounding';

  @override
  String get groundingSub => 'Notice what\'s around you · about 2 minutes';

  @override
  String get groundStep5 => 'Name 5 things you can see';

  @override
  String get groundStep4 => '4 things you can feel or touch';

  @override
  String get groundStep3 => '3 things you can hear';

  @override
  String get groundStep2 => '2 things you can smell';

  @override
  String get groundStep1 => '1 slow breath, in and out';

  @override
  String get groundHint => 'Type them if it helps, or just notice them.';

  @override
  String get groundAnswerHint => 'For example: the window, my cup…';

  @override
  String get groundNext => 'Next';

  @override
  String get groundFinish => 'Done';

  @override
  String get groundDone => 'You\'re back in the room. How does it feel now?';

  @override
  String get muscleTitle => 'Tense and release';

  @override
  String get muscleSub => 'Seven muscle groups · about 2 minutes';

  @override
  String get muscleIntro =>
      'Squeeze each muscle group for five seconds, then let it go completely. Notice the difference.';

  @override
  String get muscleTense => 'Squeeze';

  @override
  String get muscleRelease => 'Let go';

  @override
  String get muscleHands => 'Your hands';

  @override
  String get muscleArms => 'Your arms';

  @override
  String get muscleShoulders => 'Your shoulders';

  @override
  String get muscleFace => 'Your face';

  @override
  String get muscleStomach => 'Your stomach';

  @override
  String get muscleLegs => 'Your legs';

  @override
  String get muscleFeet => 'Your feet';

  @override
  String get muscleDone => 'Notice how loose feels different from tight.';

  @override
  String get todayTakeAMinute => 'Take a minute';

  @override
  String moodLogged(String mood, String time) {
    return 'Logged $mood at $time';
  }

  @override
  String get moodChange => 'Change';

  @override
  String assessmentAgo(int days) {
    return '$days days ago';
  }

  @override
  String resultOutOf(int max) {
    return 'out of $max';
  }

  @override
  String get resultExplainMinimal =>
      'Your answers point to few or no symptoms over the last two weeks. That\'s a good place to be; checking in again in a fortnight keeps the picture honest.';

  @override
  String get resultExplainMild =>
      'Some symptoms showed up, but at a level many people manage on their own. Sleep, movement and someone to talk to tend to matter most here.';

  @override
  String get resultExplainModerate =>
      'Symptoms are affecting you often enough to be worth taking seriously. This is the range where talking to a psychologist or doctor usually helps, even if it feels manageable.';

  @override
  String get resultExplainModeratelySevere =>
      'Symptoms are frequent and are likely getting in the way of daily life. Please consider seeing a psychologist or doctor soon; this responds well to treatment.';

  @override
  String get resultExplainSevere =>
      'Your answers describe a heavy load, most days. You deserve proper support for this, and it helps: please book time with a psychologist or doctor this week.';

  @override
  String get resultTalk => 'Talk it through with Eve';

  @override
  String get journalPromptsTitle => 'Need a start?';

  @override
  String get journalPrompt1 => 'What drained me today';

  @override
  String get journalPrompt2 => 'One thing that went okay';

  @override
  String get journalPrompt3 => 'What I\'d tell a friend in my place';

  @override
  String get welcomePointPrivate =>
      'Your conversations with Eve are saved on this phone, and each message is sent to the TherapyLink server to be answered. Journal entries and check-ins are saved to your account.';

  @override
  String get welcomePointLanguage =>
      'English, Roman Urdu, or both, the way you actually type.';

  @override
  String get welcomePointHelp =>
      'When something is serious, real help is one tap away.';

  @override
  String get memoryTitle => 'What Eve remembers';

  @override
  String get memoryRowSub => 'See, delete, or switch off';

  @override
  String get memoryIntro =>
      'Eve keeps a few short notes from your conversations, like who matters to you and what you agreed to try, so you don\'t have to start from zero each time. They\'re saved on this phone, and the notes that relate to a message are sent with it to the TherapyLink server.';

  @override
  String get memoryToggle => 'Remember between conversations';

  @override
  String get memoryToggleOn => 'Eve uses these notes and adds new ones';

  @override
  String get memoryToggleOff => 'Nothing is kept or used';

  @override
  String get memoryEmptyTitle => 'Nothing yet';

  @override
  String get memoryEmptyBody =>
      'As you talk with Eve, the things worth remembering will show up here.';

  @override
  String get memoryDelete => 'Forget this';

  @override
  String get memoryForgetAll => 'Forget everything';

  @override
  String get memoryForgetAllTitle => 'Forget everything?';

  @override
  String get memoryForgetAllBody =>
      'Eve will lose all notes from earlier conversations. Your chats stay.';

  @override
  String get memoryKindPerson => 'People';

  @override
  String get memoryKindSituation => 'What\'s going on';

  @override
  String get memoryKindGoal => 'What you want';

  @override
  String get memoryKindHelped => 'What helped';

  @override
  String get memoryKindPlan => 'Next steps you agreed';

  @override
  String get eveWrapUp => 'Wrap up';

  @override
  String get eveWrapUpWorking => 'Pulling today together…';

  @override
  String get eveWrapUpFailed =>
      'Couldn\'t wrap up just now. Try again in a moment.';

  @override
  String eveNextStep(String step) {
    return 'Next step: $step';
  }

  @override
  String eveFollowUp(String step) {
    return 'Last time you planned to: $step';
  }

  @override
  String get eveFollowUpStart => 'How did it go?';

  @override
  String eveFollowUpMessage(String step) {
    return 'Let\'s talk about how my last step went: $step';
  }

  @override
  String get eveBreakNudge =>
      'We\'ve been talking a while. It can help to take a break, or to share some of this with someone you trust.';

  @override
  String get eveBreakDismiss => 'Keep talking';

  @override
  String get cancel => 'Cancel';

  @override
  String get signOutConfirmTitle => 'Sign out?';

  @override
  String get signOutConfirmBody =>
      'Your conversations with Eve and her memory notes will be deleted from this phone. Check-ins, mood trend and journal stay on your account.';

  @override
  String get signOutUnsentTitle => 'Some check-ins haven\'t been sent';

  @override
  String signOutUnsentBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count check-ins haven\'t reached your account yet, probably because you\'re offline. If you sign out now they will be lost. Connect and try again to keep them.',
      one: '1 check-in hasn\'t reached your account yet, probably because you\'re offline. If you sign out now it will be lost. Connect and try again to keep it.',
    );
    return '$_temp0';
  }

  @override
  String get signOutAnyway => 'Sign out anyway';

  @override
  String get youDeleteChats => 'Delete all Eve chats';

  @override
  String get youDeleteChatsSub =>
      'Removes every conversation and memory note from this phone';

  @override
  String get deleteChatsTitle => 'Delete all Eve chats?';

  @override
  String get deleteChatsBody =>
      'Every conversation with Eve and everything she remembers will be removed from this phone. This can\'t be undone.';

  @override
  String get deleteChatsAction => 'Delete chats';

  @override
  String get deleteChatsDone => 'Eve chats deleted.';

  @override
  String get youDeleteAccount => 'Delete account';

  @override
  String get youDeleteAccountSub =>
      'Removes your account and everything stored with it';

  @override
  String get deleteAccountTitle => 'Delete your account?';

  @override
  String get deleteAccountBody =>
      'This deletes your account and your check-ins, mood trend, journal and clinician links from the TherapyLink server, and clears Eve\'s conversations from this phone. This can\'t be undone.';

  @override
  String get deleteAccountAction => 'Delete account';

  @override
  String get deleteAccountFailed =>
      'Your account couldn\'t be deleted just now, and nothing was removed. Check your connection and try again.';

  @override
  String get getHelpNow => 'Get help now';

  @override
  String get youHelpSub => 'Helplines and their numbers';

  @override
  String get consentTitle => 'Before you start';

  @override
  String get consentBarTitle => 'Consent';

  @override
  String get consentAiTitle => 'Eve is an AI, not a therapist';

  @override
  String get consentAiBody =>
      'Eve is a computer program. She can listen and suggest simple exercises, but she can\'t diagnose or treat anything, she doesn\'t replace a doctor or psychologist, and she can get things wrong.';

  @override
  String get consentEmergencyTitle => 'Not for emergencies';

  @override
  String get consentEmergencyBody =>
      'Nobody watches your chats with Eve, and telling Eve you\'re in danger doesn\'t alert anyone. If you might hurt yourself or someone else, or you\'re in danger, call 1122 or a helpline from Get help now. Eve can\'t call anyone for you.';

  @override
  String get consentDataTitle => 'What is stored where';

  @override
  String get consentDataBody =>
      'Your conversations with Eve are saved only on this phone. To answer each message, it is sent to the TherapyLink server with the memory notes that relate to it, and it is not stored there. Check-in scores, mood points, journal entries and your account details are stored on your TherapyLink account so they follow you to a new phone. A clinician sees only what you link them to and switch on.';

  @override
  String get consentAge => 'I am 18 or older';

  @override
  String get consentUnder18 => 'I\'m under 18';

  @override
  String get consentAgree =>
      'I\'ve read the terms and privacy policy and agree to them';

  @override
  String get consentTerms => 'Terms of use';

  @override
  String get consentPrivacy => 'Privacy policy';

  @override
  String get consentAccept => 'Agree and continue';

  @override
  String get under18Title => 'TherapyLink is for adults';

  @override
  String get under18Body =>
      'This app is made for people 18 and over, so Eve can\'t chat with you here. If something is hard right now, you deserve real support. Talk to an adult you trust, like a teacher, a relative or a neighbour, or call one of these:';

  @override
  String get under18CallChild => 'Madadgaar child helpline · 1098';

  @override
  String get under18Back => 'I entered my age wrong';

  @override
  String get signInOr => 'or';

  @override
  String get authErrorMismatch => 'That email and password don\'t match.';

  @override
  String get authErrorInUse =>
      'There\'s already an account with that email. Try signing in.';

  @override
  String get authErrorWeakPassword => 'Use at least 8 characters.';

  @override
  String get authErrorInvalidEmail =>
      'That doesn\'t look like an email address.';

  @override
  String get authErrorTooMany =>
      'Too many attempts. Wait a minute and try again.';

  @override
  String get authErrorNetwork =>
      'No connection. Check your network and try again.';

  @override
  String get validateEmail => 'Enter your email';

  @override
  String get validatePassword => 'At least 8 characters';

  @override
  String get settingsTextSmaller => 'Smaller text';

  @override
  String get settingsTextLarger => 'Larger text';

  @override
  String get cloudConfirmTitle => 'Use cloud mode?';

  @override
  String get cloudConfirmBody =>
      'In cloud mode your messages, and the memory notes that relate to them, leave this phone and are sent to the TherapyLink server to be answered. This is for testing only.';

  @override
  String get cloudConfirmAction => 'Use cloud mode';

  @override
  String get careVerified => 'Verified clinician';

  @override
  String get clinicianConfirmTitle => 'Switch to the clinician workspace?';

  @override
  String get clinicianConfirmBody =>
      'This is only for licensed clinicians. Your account becomes a clinician account and the patient tabs close. If you\'re here for yourself, you don\'t need this.';

  @override
  String get clinicianConfirmAction => 'I\'m a licensed clinician';

  @override
  String get clinicianRequests => 'Link requests';

  @override
  String clinicianRequestsWaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count patients waiting',
      one: '1 patient waiting',
      zero: 'No one waiting',
    );
    return '$_temp0';
  }

  @override
  String get clinicianRequestsEmpty =>
      'No one is waiting. When a patient adds your invite code, they appear here.';

  @override
  String get clinicianRequestsHelp =>
      'Accepting lets you see only what the patient chooses to share with you.';

  @override
  String get clinicianRequestAccept => 'Accept';

  @override
  String get clinicianRequestDecline => 'Decline';

  @override
  String clinicianRequestedOn(String date) {
    return 'Asked on $date';
  }

  @override
  String get carePendingTitle => 'Waiting for approval';

  @override
  String get carePendingBody =>
      'Waiting for the clinician to accept. They can\'t see anything of yours until they do, and after that only what you switch on.';

  @override
  String get carePendingCancel => 'Cancel request';

  @override
  String get careActiveTitle => 'Linked clinicians';

  @override
  String get youExport => 'Download my data';

  @override
  String get youExportSub =>
      'A copy of everything your account holds, as a file. It isn\'t locked, so keep it somewhere safe.';

  @override
  String get youExportWorking => 'Preparing your data…';

  @override
  String youExportDone(String path) {
    return 'Saved to $path';
  }

  @override
  String get youExportFailed =>
      'Couldn\'t download your data. Check your connection and try again.';

  @override
  String get clinicianUnvalidatedTranslation => 'Unvalidated translation';

  @override
  String get clinicianUnvalidatedTranslationHelp =>
      'Answered in the app\'s Roman Urdu wording. It follows the published Urdu versions where it can, but Roman Urdu wording has not itself been validated against the original questionnaire. Read the score and its band with care.';

  @override
  String get accessLogTitle => 'Who viewed my data';

  @override
  String get accessLogSub => 'Each time a clinician was shown your data';

  @override
  String get accessLogIntro =>
      'Each time a clinician you linked opens your page or their patient list, it\'s recorded here with what they were shown.';

  @override
  String get accessLogEmpty => 'No clinician has viewed your data.';

  @override
  String get accessLogSomeone => 'A clinician';

  @override
  String get accessLogCaseload => 'Saw you in their patient list';

  @override
  String get accessLogOverview => 'Opened your page';

  @override
  String get accessLogNothingShown => 'Nothing you share was shown';

  @override
  String get eveSaidLabel => 'Eve said';

  @override
  String get youSaidLabel => 'You said';

  @override
  String get eveSafetyNotReadyTitle => 'Safety check not ready';

  @override
  String get eveSafetyNotReadyBody =>
      'Eve checks every message for signs of danger before she replies. That check isn\'t ready on this phone yet, so chat is paused. You can still do an exercise, or get help now.';

  @override
  String get eveUnavailableTitle => 'Eve isn\'t available in this version';

  @override
  String get eveUnavailableBody =>
      'Eve\'s model for this app hasn\'t been released yet. Exercises, your journal and help are all still here.';

  @override
  String get guardianFailed =>
      'The trained safety model couldn\'t be downloaded, set up or run on this phone, so the built-in keyword check is running on its own. Try downloading it again.';

  @override
  String get settingsPrivacy => 'Privacy on this phone';

  @override
  String get appLockTitle => 'App lock';

  @override
  String get appLockBody =>
      'Ask for your fingerprint, face or phone PIN when the app opens, or when you come back after a minute away. Get help now still works while it\'s locked. While this is on, screenshots are blocked and the app is hidden in recent apps.';

  @override
  String get appLockUnavailable =>
      'Set a screen lock on your phone first, then turn this on.';

  @override
  String get lockTitle => 'Locked';

  @override
  String get lockBody => 'Unlock with your fingerprint, face or phone PIN.';

  @override
  String get lockUnlock => 'Unlock';

  @override
  String get lockFailed => 'That didn\'t unlock. Try again.';

  @override
  String get lockReason => 'Unlock to continue';

  @override
  String get quickExitTitle => 'Quick exit';

  @override
  String get quickExitBody =>
      'Shows a button at the top of each page that hides this app straight away, for when someone might be looking at your screen.';

  @override
  String get quickExitNeutral => 'Nothing open right now.';

  @override
  String get dbMigrationFailed =>
      'Your chats on this phone couldn\'t be encrypted this time. They\'re still here, and the app will try again next time it opens.';

  @override
  String get dbUnreadable =>
      'Your earlier chats on this phone couldn\'t be opened, so a new, empty space was started. The old file has been kept.';

  @override
  String get dbOpenFailed =>
      'Your chats on this phone can\'t be opened right now, so nothing new is being saved. Try closing and reopening the app. If you need to talk to someone now, Get help now still works.';

  @override
  String get eveBusyTitle => 'Eve is with someone else right now';

  @override
  String get eveBusyBody => 'The server is busy. Wait a moment and try again.';

  @override
  String get eveSlowTitle => 'Eve is resting';

  @override
  String get eveSlowBody =>
      'The connection timed out. Eve may be slow to respond right now. Try again in a moment.';

  @override
  String get eveTryAgain => 'Try again';

  @override
  String get evePrivacyInline =>
      'This chat is saved only on this phone. Eve\'s replies come from our server, which doesn\'t keep them.';
}
