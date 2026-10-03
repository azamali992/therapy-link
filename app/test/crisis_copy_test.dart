import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:therapylink/core/ml/guardian.dart';
import 'package:therapylink/features/shared/crisis_copy.dart';
import 'package:therapylink/features/shared/helplines.dart';
import 'package:therapylink/l10n/app_localizations.dart';

void main() {
  group('crisis copy follows the language of the message, not the phone', () {
    test('Roman Urdu, even a few words of it, gets Roman Urdu', () {
      for (final text in ['marna chahti hoon', 'mujhe zinda nahi rehna', 'bas ab sab khatam kar dun', 'zeher kha lun']) {
        expect(crisisLanguageOf(text), CrisisLanguage.romanUrdu, reason: text);
      }
    });

    test('Urdu script gets the closest the app has', () {
      expect(crisisLanguageOf('میں خودکشی کرنا چاہتا ہوں'), CrisisLanguage.romanUrdu);
    });

    test('English stays English, including the English word "main"', () {
      for (final text in ['I want to end my life', "I don't want to live anymore", 'the main thing is I cannot go on like this']) {
        expect(crisisLanguageOf(text), CrisisLanguage.en, reason: text);
      }
    });

    test('the locale maps across for the always-there help action', () {
      expect(crisisLanguageForLocale(const Locale('ur')), CrisisLanguage.romanUrdu);
      expect(crisisLanguageForLocale(const Locale('en')), CrisisLanguage.en);
      expect(CrisisCopy.forText('marna chahti hoon').language, CrisisLanguage.romanUrdu);
    });
  });

  test('every kind has a title and body in both languages, and none makes an unverified promise', () {
    for (final copy in [CrisisCopy.en, CrisisCopy.romanUrdu]) {
      for (final kind in CrisisKind.values) {
        final text = '${copy.title(kind)} ${copy.body(kind)}';
        expect(text, isNotEmpty);
        expect(text.toLowerCase(), isNot(contains('free')));
        expect(text.toLowerCase(), isNot(contains('muft')));
        expect(text, isNot(contains('24/7')));
        // Numbers come from the helplines table only.
        expect(RegExp(r'\d').hasMatch(text), isFalse, reason: text);
      }
    }
  });

  test('the paused-chat notices follow the app locale from the ARB files and promise nothing unverified', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final ur = lookupAppLocalizations(const Locale('ur'));
    expect(en.eveSafetyNotReadyTitle, 'Safety check not ready');
    expect(ur.eveSafetyNotReadyTitle, 'Safety check abhi tayyar nahi');
    expect(en.eveUnavailableTitle, "Eve isn't available in this version");
    expect(ur.eveUnavailableTitle, 'Eve is version mein dastiyab nahi');
    for (final l in [en, ur]) {
      final text = [l.eveSafetyNotReadyTitle, l.eveSafetyNotReadyBody, l.eveUnavailableTitle, l.eveUnavailableBody].join(' ');
      expect(text.toLowerCase(), isNot(contains('free')));
      expect(text.toLowerCase(), isNot(contains('muft')));
      expect(text, isNot(contains('24/7')));
      expect(RegExp(r'\d').hasMatch(text), isFalse, reason: text);
    }
    expect(en.eveSafetyNotReadyBody, isNot(ur.eveSafetyNotReadyBody));
  });

  group('helplines table', () {
    test('child and abuse lead with Madadgaar 1098; suicide leads with Umang; Rescue is always last', () {
      expect(helplinesFor(CrisisKind.child).map((h) => h.number), ['1098', '1122']);
      expect(helplinesFor(CrisisKind.abuse).first.number, '1098');
      expect(helplinesFor(CrisisKind.suicide).map((h) => h.number), ['03117786264', '1122']);
      for (final kind in CrisisKind.values) {
        expect(helplinesFor(kind).last.number, '1122');
      }
    });

    test('no line is marked verified until a person has checked it', () {
      expect(helplines.where((h) => h.verified), isEmpty);
    });

    test('numbers compare equal however they are written', () {
      expect(isKnownHelpline('+92 311 7786264'), isTrue);
      expect(isKnownHelpline('0311-7786264'), isTrue);
      expect(isKnownHelpline('1098'), isTrue);
      expect(isKnownHelpline('800-273-8255'), isFalse);
    });
  });
}
