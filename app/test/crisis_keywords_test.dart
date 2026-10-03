import 'package:flutter_test/flutter_test.dart';
import 'package:therapylink/core/ml/guardian.dart';

/// The keyword floor under the trained Guardian. Until that model is installed this is the whole
/// crisis check, so each phrasing the ship review found it missing is pinned here.
void main() {
  final g = HeuristicGuardian();

  Future<CrisisKind?> kind(String text) async => (await g.classify(text)).kind;

  group('suicide and self-harm', () {
    const english = [
      'I want to end my life',
      "I don't want to live anymore",
      'dont want to live like this',
      'honestly kms',
      'i just want to unalive myself',
      'I want to take my own life',
      'everyone would be better off dead without me, me included',
      'I keep thinking I should hang myself',
    ];
    const romanUrdu = [
      // Both genders: the masculine-only pattern missed every woman.
      'marna chahta hoon',
      'marna chahti hoon',
      'bas mar jaun to acha hai',
      'main mar jana chahti hoon',
      'khud ko khatam kar dun',
      'apni jaan le lun gi',
      'jaan de dunga main',
      'mujhe zinda nahi rehna',
      'zeher kha lun',
      'saari goliyan ek saath kha lun?',
      'khudkushi ka soch raha hoon',
    ];
    const urduScript = ['میں خودکشی کرنا چاہتا ہوں', 'مجھے مرنا ہے'];

    for (final text in [...english, ...romanUrdu, ...urduScript]) {
      test('flags "$text"', () async => expect(await kind(text), CrisisKind.suicide));
    }
  });

  group('abuse routes to its own kind', () {
    test('violence at home is abuse', () async {
      expect(await kind('my husband beats me when he is angry'), CrisisKind.abuse);
      expect(await kind('woh mujhe maarta hai roz'), CrisisKind.abuse);
    });

    test('sexual violence is its own kind', () async {
      expect(await kind('I was raped last year and never told anyone'), CrisisKind.sexualViolence);
      expect(await kind('mere saath zabardasti hui'), CrisisKind.sexualViolence);
    });

    test('a child disclosing abuse gets the child route', () async {
      expect(await kind("I'm 14 and my stepdad touched me"), CrisisKind.child);
      expect(await kind('main 12 saal ki hoon aur abbu mujhe maarte hain'), CrisisKind.child);
    });

    test('the same verbs still count when a person is doing them', () async {
      expect(await kind('my dad hits me when he drinks'), CrisisKind.abuse);
      expect(await kind('she slapped me in front of everyone'), CrisisKind.abuse);
      expect(await kind('my husband is physically abusive'), CrisisKind.abuse);
      expect(await kind('I was abused for years'), CrisisKind.abuse);
      expect(await kind('my boyfriend keeps touching me when I say no'), CrisisKind.sexualViolence);
      expect(await kind('usne mujhe galat jagah chhua'), CrisisKind.sexualViolence);
      expect(await kind('he touched me there'), CrisisKind.sexualViolence);
    });

    test('suicide risk takes precedence when both appear', () async {
      expect(await kind('he beats me and I want to die'), CrisisKind.suicide);
    });
  });

  group('idioms are not crises', () {
    const idioms = [
      'this exam is killing me',
      'mar gaye hanste hanste',
      'kaam ne maar diya aaj',
      'I am dying to see that movie',
      'we killed it at the match today',
      'main roz chai peeta hoon',
      'uski baat sun ke hans hans ke bura haal ho gaya',
      // Abuse and touch words in their everyday senses. Each of these used to open the crisis route.
      'honestly beats me why she left',
      'it hits me every night how alone I am',
      'I used to abuse alcohol in college',
      'my boss is verbally abusive',
      'your message really touched me',
      'mera train chhuta aaj',
      'meri naukri chhuti',
      // 'jaan le' is also "find out", and 'zeher' is slang for brilliant.
      'pehle sach jaan le phir bol',
      'yeh gaana zeher hai yaar',
    ];
    for (final text in idioms) {
      test('does not flag "$text"', () async => expect((await g.classify(text)).crisis, isFalse));
    }
  });

  test('a verdict without a crisis has no kind, and an unlabelled crisis reads as suicide risk', () {
    expect(GuardianVerdict.none.kind, isNull);
    expect(const GuardianVerdict(crisis: true, crisisScores: {}, valence: -2).kind, CrisisKind.suicide);
    expect(CrisisKind.fromLabel('sexual_violence'), CrisisKind.sexualViolence);
  });
}
