import 'package:flutter/widgets.dart';

import '../../core/ml/guardian.dart';

// ai-clinical-review 2026-10-03. Licensed clinician sign-off: PENDING. The wording below was
// reviewed and rewritten by the AI team acting in the clinical-lead role (docs/clinical/red-lines.md
// R5, R11; docs/clinical/AI_REVIEW_LOG.md). It is not a licensed clinician's approval, and a
// Pakistan-licensed psychologist must sign it before real patients see it. It lives here as Dart constants rather than in the ARB
// files because the language is chosen from what the person wrote, not from the app's locale.
// Wording that follows the app's locale, such as the notices shown while Eve's chat is paused,
// lives in the ARB files instead (eveSafetyNotReady*, eveUnavailable*), still pending review.
//
// The selfHarm, harmToOthers and medical titles and bodies came later (2026-10-03, with Guardian v1).
// ai-clinical-review 2026-10-03: approved against red-lines.md R5, R7 and R11 (worry, a direct safety
// question, the right line by name, no medical advice, no claims about the services); medical now
// covers someone else being hurt too. Licensed clinician sign-off: PENDING.
//
// Numbers never appear in these strings: they come from helplines.dart, the one table a human
// verifies. Nothing here says "free" or "24/7"; those claims wait for that verification.

enum CrisisLanguage { en, romanUrdu }

/// Ported from ROMAN_URDU in ml/therapylink_ml/eval/safety_rules.py, with the words people use when
/// they are in distress added, because a crisis message is often a few words long.
final _romanUrdu = RegExp(
  r'\b(hai|hain|hoon|hun|nahi|nahin|mujhe|tum|aap|kya|kyun|bohat|bahut|theek|thik|yaar|acha|main|mai|ke|ki|ka|ko|se|aur|lekin|'
  r'magar|mein|mera|meri|mere|apni|apna|raha|rahi|karna|dun|lun|chahta|chahti|bas|sab|kuch|koi|yeh|woh|kar|kha)\b',
  caseSensitive: false,
);
final _urduScript = RegExp(r'[؀-ۿ]');

/// The language to answer a crisis in, read from the person's own message: someone writing Roman
/// Urdu on an English phone gets Roman Urdu. Urdu script gets Roman Urdu too, the closest the app has.
CrisisLanguage crisisLanguageOf(String text) {
  if (_urduScript.hasMatch(text)) return CrisisLanguage.romanUrdu;
  final hits = _romanUrdu.allMatches(text).length;
  final words = text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  // The eval wants three such words in a whole reply; a message in crisis is often one short line,
  // so two, or one in a message of a few words, is enough.
  return hits >= 2 || (hits == 1 && words <= 4) ? CrisisLanguage.romanUrdu : CrisisLanguage.en;
}

/// The app's 'ur' locale is Roman Urdu, so it maps straight across.
CrisisLanguage crisisLanguageForLocale(Locale locale) => locale.languageCode == 'ur' ? CrisisLanguage.romanUrdu : CrisisLanguage.en;

@immutable
class CrisisCopy {
  const CrisisCopy._({
    required this.language,
    required this.helpNow,
    required this.helpBar,
    required this.helpBarBody,
    required this.keepTalking,
    required this.copyNumber,
    required this.numberCopied,
    required this.callFailed,
    required this.unverified,
    required this.numberRemoved,
    required String Function(String name) call,
    required Map<CrisisKind, String> titles,
    required Map<CrisisKind, String> bodies,
  })  : _call = call,
        _titles = titles,
        _bodies = bodies;

  final CrisisLanguage language;

  /// The always-there help action's tooltip and label.
  final String helpNow;

  /// The bar above the composer while crisis mode is on.
  final String helpBar;
  final String helpBarBody;
  final String keepTalking;
  final String copyNumber;
  final String numberCopied;

  /// Shown above the number, large, when the phone could not start a call.
  final String callFailed;

  /// Debug builds only: marks a helpline no human has confirmed yet.
  final String unverified;

  /// Put where a phone number Eve should not have given was taken out of her reply.
  final String numberRemoved;

  final String Function(String name) _call;
  final Map<CrisisKind, String> _titles;
  final Map<CrisisKind, String> _bodies;

  String call(String name) => _call(name);
  String title(CrisisKind kind) => _titles[kind]!;
  String body(CrisisKind kind) => _bodies[kind]!;

  static CrisisCopy of(CrisisLanguage language) => switch (language) {
    CrisisLanguage.en => en,
    CrisisLanguage.romanUrdu => romanUrdu,
  };

  static CrisisCopy forText(String text) => of(crisisLanguageOf(text));

  static CrisisCopy forContext(BuildContext context) => of(crisisLanguageForLocale(Localizations.localeOf(context)));

  static final en = CrisisCopy._(
    language: CrisisLanguage.en,
    helpNow: 'Get help now',
    helpBar: 'Help is here',
    helpBarBody: 'Call one of these numbers to talk to a person.',
    keepTalking: 'Keep talking to Eve',
    copyNumber: 'Copy number',
    numberCopied: 'Number copied',
    callFailed: "This phone couldn't start the call. Dial this number:",
    unverified: 'unverified',
    numberRemoved: '(see the numbers below)',
    call: (name) => 'Call $name',
    titles: {
      CrisisKind.suicide: "I'm worried about you, and I'm glad you told me",
      CrisisKind.abuse: "What's happening to you is not your fault",
      CrisisKind.child: 'You did the right thing by telling someone',
      CrisisKind.sexualViolence: 'What happened is not your fault',
      CrisisKind.selfHarm: "I'm glad you told me, and I'm worried about you",
      CrisisKind.harmToOthers: 'Thank you for telling me. Safety comes first',
      CrisisKind.medical: 'Please call Rescue now',
    },
    bodies: {
      CrisisKind.suicide: "You don't have to carry this alone. Are you safe right now? You can talk to someone at one of these numbers.",
      CrisisKind.abuse: "You deserve to be safe. Are you safe right now? If you are in danger, call Rescue. These lines can help.",
      CrisisKind.child: 'Are you safe right now? These lines help children, and a grown-up you trust, like a teacher or a relative, can help too.',
      CrisisKind.sexualViolence: 'You deserve support and to be safe. Are you safe right now? These lines can help.',
      CrisisKind.selfHarm:
          "You don't have to carry this alone. Are you hurt right now? Are you having thoughts of ending your life? If you are hurt, call Rescue. You can also talk to someone at one of these numbers.",
      CrisisKind.harmToOthers:
          'Is anyone in danger right now, you or someone else? If someone could get hurt, call Rescue or the Police now. If you feel you might hurt someone, move away from them now and talk to someone at one of these numbers.',
      CrisisKind.medical:
          "If you or someone with you has taken something or is hurt, call Rescue now. Don't wait to see if it passes. Is someone near you who can stay with you?",
    },
  );

  static final romanUrdu = CrisisCopy._(
    language: CrisisLanguage.romanUrdu,
    helpNow: 'Abhi madad lein',
    helpBar: 'Madad yahan hai',
    helpBarBody: 'Kisi insaan se baat karne ke liye in mein se kisi number par call karein.',
    keepTalking: 'Eve se baat jaari rakhein',
    copyNumber: 'Number copy karein',
    numberCopied: 'Number copy ho gaya',
    callFailed: 'Is phone se call shuru nahi ho saki. Yeh number milayein:',
    unverified: 'unverified',
    numberRemoved: '(neeche diye gaye numbers dekhein)',
    call: (name) => '$name ko call karein',
    titles: {
      CrisisKind.suicide: 'Mujhe aap ki fikar hai, aur acha kiya aap ne bataya',
      CrisisKind.abuse: 'Jo aap ke saath ho raha hai, us mein aap ka koi qasoor nahi',
      CrisisKind.child: 'Aap ne kisi ko bata kar bilkul theek kiya',
      CrisisKind.sexualViolence: 'Jo hua, us mein aap ka koi qasoor nahi',
      CrisisKind.selfHarm: 'Acha kiya aap ne bataya, mujhe aap ki fikar hai',
      CrisisKind.harmToOthers: 'Bataane ka shukriya. Sab se pehle hifazat',
      CrisisKind.medical: 'Abhi Rescue ko call karein',
    },
    bodies: {
      CrisisKind.suicide: 'Yeh bojh akele nahi uthana. Kya aap abhi mehfooz hain? In numbers par kisi se baat ho sakti hai.',
      CrisisKind.abuse: 'Aap mehfooz rehne ke haqdar hain. Kya aap abhi mehfooz hain? Agar khatra hai to Rescue ko call karein. Yeh lines madad kar sakti hain.',
      CrisisKind.child: 'Kya aap abhi mehfooz hain? Yeh lines bachon ki madad karti hain, aur koi bara jis par bharosa ho, jaise teacher ya rishtedaar, woh bhi madad kar sakta hai.',
      CrisisKind.sexualViolence: 'Aap sahara aur hifazat ke haqdar hain. Kya aap abhi mehfooz hain? Yeh lines madad kar sakti hain.',
      CrisisKind.selfHarm:
          'Yeh bojh akele nahi uthana. Kya aap ko abhi chot lagi hai? Kya aap ke dil mein apni jaan lene ka khayal aa raha hai? Agar chot lagi hai to Rescue ko call karein. In numbers par kisi se baat bhi ho sakti hai.',
      CrisisKind.harmToOthers:
          'Kya abhi kisi ki jaan ko khatra hai, aap ki ya kisi aur ki? Agar kisi ko nuqsan pohanch sakta hai to abhi Rescue ya Police ko call karein. Agar aap ko lagta hai ke aap kisi ko nuqsan pohancha sakte hain, to abhi un se door ho jayein aur in numbers par kisi se baat karein.',
      CrisisKind.medical:
          'Agar aap ne ya aap ke paas kisi ne kuch kha ya pi liya hai, ya kisi ko chot lagi hai, to abhi Rescue ko call karein. Intezar na karein ke khud theek ho jayega. Kya aap ke paas koi hai jo aap ke saath reh sake?',
    },
  );
}
