// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Urdu (`ur`).
class AppLocalizationsUr extends AppLocalizations {
  AppLocalizationsUr([String locale = 'ur']) : super(locale);

  @override
  String get appName => 'TherapyLink';

  @override
  String get continueLabel => 'Aage barhein';

  @override
  String get retry => 'Dobara koshish karein';

  @override
  String get errorGeneric =>
      'Kuch ghalat ho gaya. Internet check kar ke dobara koshish karein.';

  @override
  String get notShared => 'Share nahi kiya';

  @override
  String get tabEve => 'Eve';

  @override
  String get tabToday => 'Aaj';

  @override
  String get tabJournal => 'Journal';

  @override
  String get tabYou => 'Aap';

  @override
  String get welcomeTitle => 'Baat karne ke liye koi, kisi bhi waqt';

  @override
  String get welcomeBody =>
      'Eve English ya Roman Urdu mein sunti hai. Us se aap ki baatein isi phone par save hoti hain. Har message jawab ke liye TherapyLink server ko bheja jata hai, aur wahan store nahi hota.';

  @override
  String get welcomeLanguage => 'Aap zyada kis mein likhte hain?';

  @override
  String get welcomeEnglish => 'English';

  @override
  String get welcomeRomanUrdu => 'Roman Urdu';

  @override
  String get signInTitle => 'Khush aamdeed';

  @override
  String get signInSubtitle =>
      'Sign in karein taake aap ke check-ins aur journal aap ke saath rahein.';

  @override
  String get continueWithGoogle => 'Google se jaari rakhein';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get signIn => 'Sign in';

  @override
  String get createAccount => 'Account banayein';

  @override
  String get haveAccount => 'Pehle se account hai? Sign in';

  @override
  String get noAccount => 'Naye hain? Account banayein';

  @override
  String get forgotPassword => 'Password bhool gaye?';

  @override
  String get resetSent => 'Reset email bhej di gayi.';

  @override
  String get signOut => 'Sign out';

  @override
  String get eveGreeting => 'Main Eve hoon. Kya chal raha hai?';

  @override
  String get eveComposerHint => 'Kuch bhi kahein…';

  @override
  String get eveListening => 'Eve sun rahi hai';

  @override
  String get evePrivacy =>
      'Isi phone par save hota hai. Har message jawab ke liye TherapyLink server ko jata hai.';

  @override
  String get evePrivacyCloud =>
      'Cloud mode: messages aap ke TherapyLink server ko bheje jaate hain.';

  @override
  String get modelMissingTitle => 'Eve abhi is device par nahi hai';

  @override
  String modelMissingBody(String gb) {
    return 'Sirf ek baar taqreeban $gb GB download hoga. Wi-Fi behtar hai. Uske baad Eve poori tarah offline chalti hai.';
  }

  @override
  String get modelDownload => 'Eve download karein';

  @override
  String modelDownloading(int percent) {
    return 'Eve download ho rahi hai · $percent%';
  }

  @override
  String get modelFailed =>
      'Download poora nahi hua. Internet check kar ke dobara koshish karein.';

  @override
  String get guardianTitle => 'Safety check';

  @override
  String get guardianHeuristic =>
      'Abhi built-in keyword check istemal ho raha hai.';

  @override
  String get guardianReady =>
      'Trained model installed hai. Har message se pehle isi device par chalta hai.';

  @override
  String get guardianDownload => 'Safety model download karein';

  @override
  String guardianDownloading(int percent) {
    return 'Safety model download ho raha hai · $percent%';
  }

  @override
  String get guardianUnavailable => 'Abhi publish nahi hua.';

  @override
  String get crisisCallUmang => 'Umang ko call karein · 0311 7786264';

  @override
  String get crisisCallEmergency => 'Emergency · 1122';

  @override
  String get crisisKeepTalking => 'Eve se baat jaari rakhein';

  @override
  String get todayMorning => 'Subah bakhair';

  @override
  String get todayAfternoon => 'Assalam o alaikum';

  @override
  String get todayEvening => 'Shaam bakhair';

  @override
  String get moodPrompt => 'Abhi aap kaise hain?';

  @override
  String get moodSaved => 'Note kar liya.';

  @override
  String get moodVeryLow => 'Bohat bura';

  @override
  String get moodLow => 'Bura';

  @override
  String get moodOkay => 'Theek';

  @override
  String get moodGood => 'Acha';

  @override
  String get moodGreat => 'Bohat acha';

  @override
  String get moodTrend => 'Pichlay 30 din';

  @override
  String get moodTrendWeek => 'Is hafte';

  @override
  String get moodTrendEmpty =>
      'Chand baar check-in karein, trend yahan nazar aayega.';

  @override
  String get groundingOffer =>
      'Lagta hai bohat kuch chal raha hai. Ek minute saans par tawajjo se faida hoga?';

  @override
  String get groundingAccept => 'Karke dekhein';

  @override
  String get groundingDecline => 'Abhi nahi';

  @override
  String get insightMorning => 'subah';

  @override
  String get insightAfternoon => 'dopahar';

  @override
  String get insightEvening => 'shaam';

  @override
  String insightTimeOfDay(String worse, String better) {
    return 'Aap ki $worse aam tor par $better se zyada bhaari rahi hain.';
  }

  @override
  String get insightWeekUp =>
      'Yeh hafta pichlay hafte se thora halka raha hai.';

  @override
  String get insightWeekDown =>
      'Yeh hafta pichlay hafte se zyada bhaari raha hai.';

  @override
  String insightBasis(int n) {
    return '$n check-ins ki bunyaad par. Yeh ek pattern hai, diagnosis nahi.';
  }

  @override
  String get exercisesTitle => 'Sukoon';

  @override
  String get exercisesSub => 'Chand minute saans par tawajjo';

  @override
  String get exerciseSigh => 'Reset saans';

  @override
  String get exerciseSighSub =>
      'Do baar andar, ek lamba bahar · taqreeban 1 minute';

  @override
  String get exerciseBox => 'Box breathing';

  @override
  String get exerciseBoxSub => 'Barabar chaar ginti · taqreeban 2 minute';

  @override
  String get exerciseCalming => '4-7-8';

  @override
  String get exerciseCalmingSub => 'Lamba exhale · taqreeban 1 minute';

  @override
  String get breathIn => 'Saans andar';

  @override
  String get breathHold => 'Roke rakhein';

  @override
  String get breathOut => 'Saans bahar';

  @override
  String get breathRest => 'Thehrein';

  @override
  String get breathStart => 'Shuru karein';

  @override
  String get breathPause => 'Rokein';

  @override
  String get breathAgain => 'Dobara karein';

  @override
  String get breathRestart => 'Phir se shuru';

  @override
  String get breathDone => 'Ho gaya';

  @override
  String breathCycleOf(int n, int total) {
    return 'Round $n / $total';
  }

  @override
  String get breathResume => 'Dobara shuru';

  @override
  String get breathStop => 'Jab chahein rok sakte hain. Kuch count nahi hota.';

  @override
  String get breathNote =>
      'Jab chahein rok dein. Agar sar chakraye to normal saans lein.';

  @override
  String get assessmentsTitle => 'Check-ins';

  @override
  String get assessmentPhq9 => 'Mood check-in';

  @override
  String get assessmentPhq9Sub => 'PHQ-9 · 9 sawal · 2 minute';

  @override
  String get assessmentGad7 => 'Anxiety check-in';

  @override
  String get assessmentGad7Sub => 'GAD-7 · 7 sawal · 2 minute';

  @override
  String assessmentLast(int score, String band) {
    return 'Pichla: $score · $band';
  }

  @override
  String get assessmentNever => 'Abhi tak nahi liya';

  @override
  String get assessmentIntro =>
      'Pichlay do hafton mein, aap ko in cheezon ne kitni baar pareshan kiya?';

  @override
  String get assessmentNext => 'Agla';

  @override
  String get assessmentBack => 'Peeche';

  @override
  String get assessmentFinish => 'Nateeja dekhein';

  @override
  String assessmentQuestionOf(int n, int total) {
    return '$total mein se $n';
  }

  @override
  String get optNotAtAll => 'Bilkul nahi';

  @override
  String get optSeveralDays => 'Kuch din';

  @override
  String get optMoreThanHalf => 'Aadhe se zyada din';

  @override
  String get optNearlyEveryDay => 'Taqreeban har roz';

  @override
  String get resultTitle => 'Aap ka nateeja';

  @override
  String resultScore(int score, int max) {
    return '$max mein se $score';
  }

  @override
  String resultDelta(String delta) {
    return 'Pichli baar se $delta';
  }

  @override
  String get bandMinimal => 'Na hone ke barabar';

  @override
  String get bandMild => 'Halka';

  @override
  String get bandModerate => 'Darmiyana';

  @override
  String get bandModeratelySevere => 'Kaafi zyada';

  @override
  String get bandSevere => 'Shadeed';

  @override
  String get resultNote =>
      'Yeh ek screening score hai, diagnosis nahi. Waqt ke saath trend dekhna sab se mufeed hai.';

  @override
  String get resultFlagged =>
      'Aap ne bataya ke aap ko lagta hai mar jana behtar hoga ya khud ko nuqsan pohanchane ke khayal aaye. Yeh ahem hai, aur abhi log hain jo madad karna chahte hain.';

  @override
  String get resultDone => 'Ho gaya';

  @override
  String get resultTalkToEve => 'Eve se baat karein';

  @override
  String get journalTitle => 'Journal';

  @override
  String get journalNew => 'Naya entry';

  @override
  String get journalEmptyTitle => 'Abhi yahan kuch nahi';

  @override
  String get journalEmptyBody =>
      'Chand sachi lines kaafi hain. Entries aap ke account mein save hoti hain, aur clinician unhein sirf tab dekhta hai jab aap khud share karein.';

  @override
  String get journalTitleHint => 'Title (optional)';

  @override
  String get journalBodyHint => 'Kya chal raha hai?';

  @override
  String get journalSave => 'Save';

  @override
  String get journalDelete => 'Entry delete karein';

  @override
  String get journalMood => 'Likhte waqt mood';

  @override
  String get youTitle => 'Aap';

  @override
  String get youCare => 'Aap ki care team';

  @override
  String get youCareSub => 'Kaun kya dekh sakta hai';

  @override
  String get youSettings => 'Settings';

  @override
  String get youDataTitle => 'Aap ka data kahan rehta hai';

  @override
  String get youDataBody =>
      'Eve se baatein aur us ke memory notes isi phone par save hote hain. Jawab dene ke liye har message aur us se jure notes TherapyLink server ko jaate hain, jo unhein store nahi karta. Check-in scores, mood trend aur journal entries aap ke account par store hote hain taake aap ke saath rahein, aur clinician unhein sirf tab dekhta hai jab aap use link kar ke on karein.';

  @override
  String get settingsLanguage => 'Zabaan';

  @override
  String get settingsLanguageSystem => 'System';

  @override
  String get settingsTextSize => 'Text ka size';

  @override
  String get settingsReduceMotion => 'Motion kam karein';

  @override
  String get settingsTheme => 'Look';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsModel => 'Eve chalti hai';

  @override
  String get settingsModelOnDevice => 'Isi device par';

  @override
  String get settingsModelCloud => 'Cloud mein';

  @override
  String get careTitle => 'Aap ki care team';

  @override
  String get careEmptyTitle => 'Koi clinician link nahi';

  @override
  String get careEmptyBody =>
      'Agar aap kisi clinician ke saath kaam kar rahe hain, un se un ka invite code lein aur yahan add karein. Jab tak aap on na karein, kuch share nahi hota.';

  @override
  String get careInvite => 'Clinician add karein';

  @override
  String get careInviteHint => 'Invite code';

  @override
  String get careConsentTitle => 'Woh kya dekh sakte hain';

  @override
  String get careShareAssessments => 'Check-in scores';

  @override
  String get careShareMood => 'Mood trend';

  @override
  String get careShareSummaries => 'Haftawar summaries';

  @override
  String get careShareJournal => 'Journal entries';

  @override
  String get careRevoke => 'Clinician hataayein';

  @override
  String get careRevoked => 'Hata diya';

  @override
  String get clinicianCaseload => 'Patients';

  @override
  String get clinicianPending =>
      'Aap ka clinician account verification ke intezar mein hai. Manzoori ke baad aap patients dekh sakenge.';

  @override
  String get clinicianEmpty =>
      'Abhi koi patient nahi. Patient ko apna invite code dein, woh apni app se aap ko add kar sakte hain.';

  @override
  String get clinicianYourId => 'Aap ka invite code';

  @override
  String get clinicianCopyId => 'Copy';

  @override
  String get clinicianCopied => 'Copy ho gaya';

  @override
  String get clinicianSharing => 'Share kiya hua';

  @override
  String get clinicianAssessments => 'Check-ins';

  @override
  String get clinicianMood => 'Mood trend';

  @override
  String get clinicianSummaries => 'Summaries';

  @override
  String get clinicianJournal => 'Journal';

  @override
  String get clinicianNoConsent => 'Is patient ne abhi kuch share nahi kiya.';

  @override
  String get youClinician => 'Main clinician hoon';

  @override
  String get youClinicianSub => 'Clinician workspace kholein';

  @override
  String get clinicianJoinTitle => 'Clinician workspace';

  @override
  String get clinicianJoinBody =>
      'Clinicians sirf wohi dekhte hain jo patient ne unhein link kar ke on kiya ho. Kisi bhi patient ka data khulne se pehle account licence number se check hota hai.';

  @override
  String get clinicianLicense => 'Licence number (maslan PMDC)';

  @override
  String get clinicianSpecialty => 'Specialty (optional)';

  @override
  String get clinicianLicenseRequired => 'Apna licence number likhein';

  @override
  String get clinicianJoinAction => 'Clinician ke taur par jaari rakhein';

  @override
  String get clinicianUsePatient => 'Patient view par jaayein';

  @override
  String get clinicianCodeHelp =>
      'Patients yeh code Aap → Aap ki care team mein likhte hain.';

  @override
  String get clinicianNewCode => 'Naya invite code';

  @override
  String get clinicianNewCodeBody =>
      'Aap ka maujooda code kaam karna band kar dega. Jo patients pehle se link hain woh link rahenge.';

  @override
  String get clinicianNewCodeDone => 'Naya code tayyar hai';

  @override
  String get clinicianNotSharing => 'Check-ins share nahi kiye';

  @override
  String get clinicianNoCheckins => 'Abhi koi check-in nahi';

  @override
  String get clinicianAttentionRisk =>
      'Item 9 positive (khud ko nuqsan ke khayalat)';

  @override
  String get clinicianAttentionWorsened => 'Haalat bigar rahi hai';

  @override
  String get clinicianAttentionSevere => 'Severe range';

  @override
  String get careInviteNotFound =>
      'Is code wala koi approved clinician nahi mila. Un se code dobara check karein.';

  @override
  String get eveGreetingSub =>
      'Pehle main sunungi. Kisi chhoti si baat se bhi shuru karna bilkul theek hai.';

  @override
  String get eveSubtitleDevice => 'Isi phone par save';

  @override
  String get eveSubtitleCloud => 'Cloud mode · aap ke TherapyLink server se';

  @override
  String get eveNewConversation => 'Nayi baat cheet';

  @override
  String get eveExercises => 'Exercises';

  @override
  String get eveSend => 'Bhejein';

  @override
  String get eveTryHere => 'Yahin try karein';

  @override
  String get eveStarterAnxious => 'Mujhe bohat bechaini ho rahi hai';

  @override
  String get eveStarterSleep => 'Neend nahi aa rahi';

  @override
  String get eveStarterVent => 'Bas dil ki baat karni hai';

  @override
  String get eveStarterRelationship => 'Kisi qareebi ke saath kuch hua hai';

  @override
  String get eveStarterCalm => 'Mujhe sukoon chahiye';

  @override
  String get eveDateToday => 'Aaj';

  @override
  String get eveDateYesterday => 'Kal';

  @override
  String get exerciseSheetTitle => 'Ek minute apne liye';

  @override
  String get exerciseSheetBody =>
      'Yeh yahin chat mein chalti hain. Jab chahein rok dein.';

  @override
  String get groundingTitle => '5-4-3-2-1 grounding';

  @override
  String get groundingSub =>
      'Apne ird gird ko mehsoos karein · qareeb 2 minute';

  @override
  String get groundStep5 => '5 cheezein jo aap dekh sakte hain';

  @override
  String get groundStep4 => '4 cheezein jo aap chhoo sakte hain';

  @override
  String get groundStep3 => '3 aawazein jo aap sun sakte hain';

  @override
  String get groundStep2 => '2 khushbuein jo aap soongh sakte hain';

  @override
  String get groundStep1 => '1 lambi saans, andar aur bahar';

  @override
  String get groundHint => 'Chahein to likh lein, ya bas ghaur karein.';

  @override
  String get groundAnswerHint => 'Maslan: khirki, mera cup…';

  @override
  String get groundNext => 'Agla';

  @override
  String get groundFinish => 'Ho gaya';

  @override
  String get groundDone => 'Aap wapas kamre mein hain. Ab kaisa lag raha hai?';

  @override
  String get muscleTitle => 'Kaso aur chhoro';

  @override
  String get muscleSub => 'Saat hisson ke liye · qareeb 2 minute';

  @override
  String get muscleIntro =>
      'Har hisse ko paanch second ke liye kasein, phir poori tarah dheela chhor dein. Farq mehsoos karein.';

  @override
  String get muscleTense => 'Kasein';

  @override
  String get muscleRelease => 'Chhor dein';

  @override
  String get muscleHands => 'Aap ke haath';

  @override
  String get muscleArms => 'Aap ke baazu';

  @override
  String get muscleShoulders => 'Aap ke kandhe';

  @override
  String get muscleFace => 'Aap ka chehra';

  @override
  String get muscleStomach => 'Aap ka pait';

  @override
  String get muscleLegs => 'Aap ki taangein';

  @override
  String get muscleFeet => 'Aap ke paon';

  @override
  String get muscleDone =>
      'Mehsoos karein ke dheela hona kasne se kitna alag hai.';

  @override
  String get todayTakeAMinute => 'Ek minute apne liye';

  @override
  String moodLogged(String mood, String time) {
    return '$time par $mood likha gaya';
  }

  @override
  String get moodChange => 'Badlein';

  @override
  String assessmentAgo(int days) {
    return '$days din pehle';
  }

  @override
  String resultOutOf(int max) {
    return '$max mein se';
  }

  @override
  String get resultExplainMinimal =>
      'Aap ke jawab batate hain ke pichle do hafton mein alamaat bohat kam ya bilkul nahi thin. Yeh achhi baat hai; do hafte baad dobara check-in karna tasveer saaf rakhta hai.';

  @override
  String get resultExplainMild =>
      'Kuch alamaat nazar aayin, lekin is had tak jise bohat log khud sambhal lete hain. Neend, chalna phirna aur kisi se baat karna yahan sab se zyada asar karte hain.';

  @override
  String get resultExplainModerate =>
      'Alamaat itni baar aa rahi hain ke unhein sanjeedgi se lena chahiye. Is range mein psychologist ya doctor se baat karna aksar madad karta hai, chahe sab sambhalne layak lage.';

  @override
  String get resultExplainModeratelySevere =>
      'Alamaat aksar hain aur rozmarra zindagi mein rukawat ban rahi hongi. Jald psychologist ya doctor se milne ka sochein; is ka ilaaj achha asar karta hai.';

  @override
  String get resultExplainSevere =>
      'Aap ke jawab zyada tar dinon mein bhaari bojh batate hain. Aap sahi sahare ke haqdar hain, aur yeh madad karta hai: is hafte psychologist ya doctor se waqt lein.';

  @override
  String get resultTalk => 'Eve se is par baat karein';

  @override
  String get journalPromptsTitle => 'Shuru karne mein madad chahiye?';

  @override
  String get journalPrompt1 => 'Aaj mujhe kis cheez ne thaka diya';

  @override
  String get journalPrompt2 => 'Ek cheez jo theek rahi';

  @override
  String get journalPrompt3 => 'Apni jagah kisi dost ko main kya kehta';

  @override
  String get welcomePointPrivate =>
      'Eve se aap ki baatein isi phone par save hoti hain, aur har message jawab ke liye TherapyLink server ko jata hai. Journal entries aur check-ins aap ke account mein save hote hain.';

  @override
  String get welcomePointLanguage =>
      'English, Roman Urdu, ya dono, jaise aap asal mein likhte hain.';

  @override
  String get welcomePointHelp =>
      'Jab baat sanjeeda ho, asli madad ek tap door hoti hai.';

  @override
  String get memoryTitle => 'Eve ko kya yaad hai';

  @override
  String get memoryRowSub => 'Dekhein, mitayein, ya band karein';

  @override
  String get memoryIntro =>
      'Eve aap ki baaton se chand chhote notes rakhti hai, jaise aap ke liye kaun ahem hai aur aap ne kya try karne ka socha, taake har baar shuru se na batana pare. Yeh isi phone par save hote hain, aur message se jure notes us ke saath TherapyLink server ko jaate hain.';

  @override
  String get memoryToggle => 'Baaton ke darmiyan yaad rakhein';

  @override
  String get memoryToggleOn =>
      'Eve yeh notes use karti hai aur naye banati hai';

  @override
  String get memoryToggleOff => 'Kuch rakha ya use nahi hota';

  @override
  String get memoryEmptyTitle => 'Abhi kuch nahi';

  @override
  String get memoryEmptyBody =>
      'Jaise jaise aap Eve se baat karenge, yaad rakhne wali cheezein yahan nazar aayengi.';

  @override
  String get memoryDelete => 'Yeh bhula dein';

  @override
  String get memoryForgetAll => 'Sab bhula dein';

  @override
  String get memoryForgetAllTitle => 'Sab bhula dein?';

  @override
  String get memoryForgetAllBody =>
      'Eve pichli baaton ke saare notes kho degi. Aap ki chats rahengi.';

  @override
  String get memoryKindPerson => 'Log';

  @override
  String get memoryKindSituation => 'Kya chal raha hai';

  @override
  String get memoryKindGoal => 'Aap kya chahte hain';

  @override
  String get memoryKindHelped => 'Kya madadgaar raha';

  @override
  String get memoryKindPlan => 'Agle qadam jo tay hue';

  @override
  String get eveWrapUp => 'Baat samettein';

  @override
  String get eveWrapUpWorking => 'Aaj ki baat samet rahi hoon…';

  @override
  String get eveWrapUpFailed =>
      'Abhi baat samet nahi saki. Thori dair mein dobara koshish karein.';

  @override
  String eveNextStep(String step) {
    return 'Agla qadam: $step';
  }

  @override
  String eveFollowUp(String step) {
    return 'Pichli baar aap ne socha tha: $step';
  }

  @override
  String get eveFollowUpStart => 'Kaisa raha?';

  @override
  String eveFollowUpMessage(String step) {
    return 'Pichle qadam ke baare mein baat karte hain: $step';
  }

  @override
  String get eveBreakNudge =>
      'Hum kaafi dair se baat kar rahe hain. Thora waqfa lena, ya is mein se kuch kisi bharosemand shakhs se share karna, madadgaar ho sakta hai.';

  @override
  String get eveBreakDismiss => 'Baat jaari rakhein';

  @override
  String get cancel => 'Cancel';

  @override
  String get signOutConfirmTitle => 'Sign out karein?';

  @override
  String get signOutConfirmBody =>
      'Eve se aap ki baatein aur us ke memory notes is phone se delete ho jayenge. Check-ins, mood trend aur journal aap ke account par rahenge.';

  @override
  String get signOutUnsentTitle => 'Kuch check-ins abhi bheje nahin gaye';

  @override
  String signOutUnsentBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count check-ins abhi aap ke account tak nahin pohnche, shayad aap offline hain. Abhi sign out kiya to yeh zaya ho jayenge. Inhein bachane ke liye connect ho kar dobara koshish karein.',
      one: '1 check-in abhi aap ke account tak nahin pohncha, shayad aap offline hain. Abhi sign out kiya to yeh zaya ho jayega. Isay bachane ke liye connect ho kar dobara koshish karein.',
    );
    return '$_temp0';
  }

  @override
  String get signOutAnyway => 'Phir bhi sign out karein';

  @override
  String get youDeleteChats => 'Eve ki saari chats delete karein';

  @override
  String get youDeleteChatsSub =>
      'Is phone se har baat-cheet aur memory note hata deta hai';

  @override
  String get deleteChatsTitle => 'Eve ki saari chats delete karein?';

  @override
  String get deleteChatsBody =>
      'Eve se har baat-cheet aur jo kuch woh yaad rakhti hai, sab is phone se hat jayega. Yeh wapas nahi ho sakta.';

  @override
  String get deleteChatsAction => 'Chats delete karein';

  @override
  String get deleteChatsDone => 'Eve ki chats delete ho gayin.';

  @override
  String get youDeleteAccount => 'Account delete karein';

  @override
  String get youDeleteAccountSub =>
      'Aap ka account aur us ke saath store sab kuch hata deta hai';

  @override
  String get deleteAccountTitle => 'Apna account delete karein?';

  @override
  String get deleteAccountBody =>
      'Is se aap ka account, aur TherapyLink server se aap ke check-ins, mood trend, journal aur clinician links delete ho jayenge, aur Eve ki baatein is phone se saaf ho jayengi. Yeh wapas nahi ho sakta.';

  @override
  String get deleteAccountAction => 'Account delete karein';

  @override
  String get deleteAccountFailed =>
      'Abhi account delete nahi ho saka, aur kuch nahi hataya gaya. Connection check kar ke dobara koshish karein.';

  @override
  String get getHelpNow => 'Abhi madad lein';

  @override
  String get youHelpSub => 'Helplines aur un ke numbers';

  @override
  String get consentTitle => 'Shuru karne se pehle';

  @override
  String get consentBarTitle => 'Consent';

  @override
  String get consentAiTitle => 'Eve AI hai, therapist nahi';

  @override
  String get consentAiBody =>
      'Eve ek computer program hai. Woh sun sakti hai aur aasaan exercises bata sakti hai, lekin woh diagnosis ya ilaaj nahi kar sakti, doctor ya psychologist ki jagah nahi le sakti, aur us se ghalti ho sakti hai.';

  @override
  String get consentEmergencyTitle => 'Emergency ke liye nahi';

  @override
  String get consentEmergencyBody =>
      'Eve se aap ki baatein koi nahi dekhta, aur Eve ko khatre ka batane se kisi ko itla nahi hoti. Agar khud ko ya kisi aur ko nuqsan pohanchane ka khatra ho, ya aap khatre mein hon, to abhi 1122 ya \'Abhi madad lein\' mein di gayi kisi helpline par call karein. Eve kisi ko call nahi kar sakti.';

  @override
  String get consentDataTitle => 'Kya kahan store hota hai';

  @override
  String get consentDataBody =>
      'Eve se aap ki baatein sirf isi phone par save hoti hain. Har message ka jawab dene ke liye woh, us se jure memory notes ke saath, TherapyLink server ko bheja jata hai, aur wahan store nahi hota. Check-in scores, mood points, journal entries aur account ki tafseel aap ke TherapyLink account par store hoti hain taake naye phone par bhi aap ke saath rahein. Clinician sirf woh dekhta hai jo aap link kar ke on karein.';

  @override
  String get consentAge => 'Meri umar 18 saal ya us se zyada hai';

  @override
  String get consentUnder18 => 'Meri umar 18 se kam hai';

  @override
  String get consentAgree =>
      'Main ne terms aur privacy policy parh li hain aur un se mutafiq hoon';

  @override
  String get consentTerms => 'Terms of use';

  @override
  String get consentPrivacy => 'Privacy policy';

  @override
  String get consentAccept => 'Mutafiq hoon, aage chalein';

  @override
  String get under18Title => 'TherapyLink baaligon ke liye hai';

  @override
  String get under18Body =>
      'Yeh app 18 saal aur us se bare logon ke liye hai, is liye Eve yahan aap se baat nahi kar sakti. Agar abhi kuch mushkil hai to aap asal madad ke haqdaar hain. Kisi bharosemand bare se baat karein, jaise teacher, koi rishtedaar ya parosi, ya in mein se kisi ko call karein:';

  @override
  String get under18CallChild => 'Madadgaar, bachon ki helpline · 1098';

  @override
  String get under18Back => 'Main ne umar ghalat chuni thi';

  @override
  String get signInOr => 'ya';

  @override
  String get authErrorMismatch => 'Yeh email aur password match nahi karte.';

  @override
  String get authErrorInUse =>
      'Is email se pehle hi account hai. Sign in kar ke dekhein.';

  @override
  String get authErrorWeakPassword => 'Kam az kam 8 characters rakhein.';

  @override
  String get authErrorInvalidEmail => 'Yeh email address nahi lagta.';

  @override
  String get authErrorTooMany =>
      'Bohat zyada koshishein. Ek minute ruk kar dobara karein.';

  @override
  String get authErrorNetwork =>
      'Connection nahi hai. Network check kar ke dobara koshish karein.';

  @override
  String get validateEmail => 'Apni email likhein';

  @override
  String get validatePassword => 'Kam az kam 8 characters';

  @override
  String get settingsTextSmaller => 'Chhota text';

  @override
  String get settingsTextLarger => 'Bara text';

  @override
  String get cloudConfirmTitle => 'Cloud mode istemal karein?';

  @override
  String get cloudConfirmBody =>
      'Cloud mode mein aap ke messages, aur un se jure memory notes, is phone se nikal kar jawab ke liye TherapyLink server ko jaate hain. Yeh sirf testing ke liye hai.';

  @override
  String get cloudConfirmAction => 'Cloud mode istemal karein';

  @override
  String get careVerified => 'Verified clinician';

  @override
  String get clinicianConfirmTitle => 'Clinician workspace par jayein?';

  @override
  String get clinicianConfirmBody =>
      'Yeh sirf licensed clinicians ke liye hai. Aap ka account clinician account ban jayega aur patient tabs band ho jayengi. Agar aap apne liye yahan hain to is ki zaroorat nahi.';

  @override
  String get clinicianConfirmAction => 'Main licensed clinician hoon';

  @override
  String get clinicianRequests => 'Link ki darkhwastein';

  @override
  String clinicianRequestsWaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count patients intezar mein',
      one: '1 patient intezar mein',
      zero: 'Koi intezar mein nahi',
    );
    return '$_temp0';
  }

  @override
  String get clinicianRequestsEmpty =>
      'Koi intezar mein nahi. Jab koi patient aap ka invite code daale ga, woh yahan nazar aaye ga.';

  @override
  String get clinicianRequestsHelp =>
      'Qubool karne ke baad aap sirf woh dekh sakenge jo patient aap ke saath share karna chune.';

  @override
  String get clinicianRequestAccept => 'Qubool karein';

  @override
  String get clinicianRequestDecline => 'Inkaar karein';

  @override
  String clinicianRequestedOn(String date) {
    return '$date ko darkhwast ki';
  }

  @override
  String get carePendingTitle => 'Manzoori ka intezar';

  @override
  String get carePendingBody =>
      'Clinician ke qubool karne ka intezar hai. Jab tak woh qubool na karein, aap ka kuch nahi dekh sakte, aur us ke baad bhi sirf woh jo aap on karein.';

  @override
  String get carePendingCancel => 'Darkhwast wapas lein';

  @override
  String get careActiveTitle => 'Linked clinicians';

  @override
  String get youExport => 'Mera data download karein';

  @override
  String get youExportSub =>
      'Aap ke account mein jo kuch hai us ki copy, ek file mein. Yeh file lock nahi hoti, is liye isay mehfooz jagah rakhein.';

  @override
  String get youExportWorking => 'Aap ka data tayyar ho raha hai…';

  @override
  String youExportDone(String path) {
    return '$path par save ho gaya';
  }

  @override
  String get youExportFailed =>
      'Aap ka data download nahi ho saka. Connection check kar ke dobara koshish karein.';

  @override
  String get clinicianUnvalidatedTranslation => 'Ghair tasdeeq shuda tarjuma';

  @override
  String get clinicianUnvalidatedTranslationHelp =>
      'App ke Roman Urdu alfaaz mein jawab diya gaya. Yeh jahan mumkin ho shaya shuda Urdu versions ke mutabiq hain, lekin Roman Urdu alfaaz ki apni tasdeeq asal questionnaire ke muqable mein nahi hui. Score aur us ki band ko ehtiyat se parhein.';

  @override
  String get accessLogTitle => 'Mera data kis ne dekha';

  @override
  String get accessLogSub =>
      'Har baar jab kisi clinician ko aap ka data dikhaya gaya';

  @override
  String get accessLogIntro =>
      'Jab bhi aap ka linked clinician aap ka page ya apni patient list kholta hai, yahan likha jata hai ke use kya dikhaya gaya.';

  @override
  String get accessLogEmpty => 'Kisi clinician ne aap ka data nahi dekha.';

  @override
  String get accessLogSomeone => 'Ek clinician';

  @override
  String get accessLogCaseload => 'Apni patient list mein aap ko dekha';

  @override
  String get accessLogOverview => 'Aap ka page khola';

  @override
  String get accessLogNothingShown =>
      'Aap ki share ki hui koi cheez nahi dikhayi gayi';

  @override
  String get eveSaidLabel => 'Eve ne kaha';

  @override
  String get youSaidLabel => 'Aap ne kaha';

  @override
  String get eveSafetyNotReadyTitle => 'Safety check abhi tayyar nahi';

  @override
  String get eveSafetyNotReadyBody =>
      'Eve har message ko jawab dene se pehle khatre ki alamaat ke liye check karti hai. Is phone par yeh check abhi tayyar nahi, is liye chat ruki hui hai. Exercise ab bhi ki ja sakti hai, aur abhi madad bhi li ja sakti hai.';

  @override
  String get eveUnavailableTitle => 'Eve is version mein dastiyab nahi';

  @override
  String get eveUnavailableBody =>
      'Is app ke liye Eve ka model abhi release nahi hua. Exercises, journal aur madad sab yahan maujood hain.';

  @override
  String get guardianFailed =>
      'Trained safety model is phone par download, set up ya run nahi ho saka, is liye sirf built-in keyword check chal raha hai. Isay dobara download kar ke dekhein.';

  @override
  String get settingsPrivacy => 'Is phone par privacy';

  @override
  String get appLockTitle => 'App lock';

  @override
  String get appLockBody =>
      'App khulne par, ya ek minute baad wapas aane par, fingerprint, chehra ya phone ka PIN maangein. Lock hone par bhi \'Abhi madad lein\' kaam karta hai. Jab yeh on ho, screenshots band hote hain aur app recent apps mein chhupi rehti hai.';

  @override
  String get appLockUnavailable =>
      'Pehle apne phone par screen lock lagayein, phir isay on karein.';

  @override
  String get lockTitle => 'Locked';

  @override
  String get lockBody => 'Fingerprint, chehre ya phone ke PIN se kholein.';

  @override
  String get lockUnlock => 'Kholein';

  @override
  String get lockFailed => 'Nahi khula. Dobara koshish karein.';

  @override
  String get lockReason => 'Aage barhne ke liye kholein';

  @override
  String get quickExitTitle => 'Quick exit';

  @override
  String get quickExitBody =>
      'Har page ke upar ek button dikhata hai jo app ko foran chhupa deta hai, jab koi aap ki screen dekh raha ho.';

  @override
  String get quickExitNeutral => 'Abhi kuch khula nahi.';

  @override
  String get dbMigrationFailed =>
      'Is phone par aap ki chats is baar encrypt nahi ho sakin. Woh yahin maujood hain, aur app agli baar khulne par dobara koshish karegi.';

  @override
  String get dbUnreadable =>
      'Is phone par aap ki pichli chats khul nahi sakin, is liye nayi khaali jagah shuru ki gayi. Purani file rakh li gayi hai.';

  @override
  String get dbOpenFailed =>
      'Is waqt is phone par aap ki chats khul nahi rahin, is liye naya kuch save nahi ho raha. App band kar ke dobara kholein. Agar abhi kisi se baat karni hai to \'Abhi madad lein\' ab bhi kaam karta hai.';

  @override
  String get eveBusyTitle => 'Eve abhi kisi aur se baat kar rahi hai';

  @override
  String get eveBusyBody =>
      'Server masroof hai. Thori dair ruk kar dobara koshish karein.';

  @override
  String get eveSlowTitle => 'Eve araam kar rahi hai';

  @override
  String get eveSlowBody =>
      'Connection time out ho gaya. Eve abhi dheere jawab de sakti hai. Thori dair baad dobara koshish karein.';
}
