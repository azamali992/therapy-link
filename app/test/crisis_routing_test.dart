import 'package:flutter_test/flutter_test.dart';
import 'package:therapylink/core/ml/guardian.dart';
import 'package:therapylink/features/eve/eve_controller.dart';
import 'package:therapylink/features/shared/crisis_copy.dart';
import 'package:therapylink/features/shared/helplines.dart';

/// A model verdict with these labels fired at these scores.
GuardianVerdict model(Map<String, double> fired, {Map<String, double> others = const {}}) => GuardianVerdict(
  crisis: fired.isNotEmpty,
  crisisScores: {...others, ...fired},
  valence: fired.isEmpty ? 0 : -2,
  kind: routeCrisis(fired.keys, fired),
  labels: fired.keys.toSet(),
);

List<String> _numbers(CrisisKind kind) => [for (final h in helplinesFor(kind)) h.number];

void main() {
  group('every Guardian label has a route of its own', () {
    test('each crisis label maps to its own kind, and back', () {
      const labels = ['suicidal', 'self_harm', 'abuse', 'child', 'sexual_violence', 'harm_to_others', 'medical'];
      final kinds = [for (final l in labels) CrisisKind.fromLabel(l)];
      expect(kinds, everyElement(isNotNull));
      expect(kinds.toSet(), hasLength(labels.length), reason: 'no two labels share a kind');
      for (final l in labels) {
        expect(CrisisKind.fromLabel(l)!.label, l);
        expect(routeCrisis([l], {l: 0.9}), CrisisKind.fromLabel(l));
      }
      expect(CrisisKind.fromLabel('none'), isNull);
      expect(routeCrisis(['none'], {'none': 0.9}), isNull);
    });

    test('a single label from the model routes to its own kind, not to suicide', () {
      expect(model({'self_harm': 0.8}).kind, CrisisKind.selfHarm);
      expect(model({'harm_to_others': 0.7}).kind, CrisisKind.harmToOthers);
      expect(model({'medical': 0.9}).kind, CrisisKind.medical);
      expect(model({'abuse': 0.6}).kind, CrisisKind.abuse);
      expect(model({'child': 0.6}).kind, CrisisKind.child);
      expect(model({'sexual_violence': 0.6}).kind, CrisisKind.sexualViolence);
    });

    test('the lines follow the clinical table (GUARDIAN_LABELS.md section 1)', () {
      expect(_numbers(CrisisKind.suicide), ['03117786264', '1122']);
      expect(_numbers(CrisisKind.selfHarm), ['03117786264', '1122']);
      expect(_numbers(CrisisKind.abuse), ['1098', '1043', '03117786264', '1122']);
      expect(_numbers(CrisisKind.sexualViolence), ['1098', '1043', '03117786264', '1122']);
      expect(_numbers(CrisisKind.child), ['1098', '1121', '1122']);
      // Danger to a body now: Rescue first.
      expect(_numbers(CrisisKind.harmToOthers), ['1122', '15']);
      expect(_numbers(CrisisKind.medical), ['1122']);
    });

    test('police 15 shows only where the danger is from a person to someone else', () {
      for (final kind in CrisisKind.values) {
        expect(_numbers(kind).contains('15'), kind == CrisisKind.harmToOthers, reason: '$kind');
      }
      expect(isKnownHelpline('15'), isTrue);
    });

    test('a crisis card round-trips every kind', () {
      for (final kind in CrisisKind.values) {
        for (final lang in CrisisLanguage.values) {
          expect(parseCrisis(crisisContent(kind, lang)), (kind: kind, language: lang));
        }
      }
    });
  });

  group('several labels: the most urgent the model is sure of routes', () {
    test('the priority runs medical, suicide, harm to others, child, sexual violence, abuse, self-harm', () {
      expect(crisisPriority, [
        CrisisKind.medical,
        CrisisKind.suicide,
        CrisisKind.harmToOthers,
        CrisisKind.child,
        CrisisKind.sexualViolence,
        CrisisKind.abuse,
        CrisisKind.selfHarm,
      ]);
      expect(crisisPriority.toSet(), CrisisKind.values.toSet(), reason: 'every kind has a place');
    });

    test('an overdose already taken goes to Rescue first, even when suicidal scores higher', () {
      expect(model({'suicidal': 0.97, 'medical': 0.71}).kind, CrisisKind.medical);
    });

    test('a child being harmed gets the child lines, not the adult abuse lines', () {
      expect(model({'abuse': 0.9, 'child': 0.8}).kind, CrisisKind.child);
      expect(model({'sexual_violence': 0.9, 'child': 0.6}).kind, CrisisKind.child);
    });

    test('a threat to a sister routes to harm to others; beaten and raped routes to sexual violence', () {
      expect(model({'abuse': 0.8, 'harm_to_others': 0.6}).kind, CrisisKind.harmToOthers);
      expect(model({'abuse': 0.9, 'sexual_violence': 0.8}).kind, CrisisKind.sexualViolence);
    });

    test('self-harm with suicidal thoughts routes to suicide', () {
      expect(model({'self_harm': 0.9, 'suicidal': 0.6}).kind, CrisisKind.suicide);
    });

    test('a label fired only by the low recall threshold does not outrank one the model is sure of', () {
      // v1b fires every label at 0.02: 'medical' at 0.03 on a suicidal message is noise.
      expect(model({'suicidal': 0.93, 'medical': 0.03}).kind, CrisisKind.suicide);
      expect(model({'self_harm': 0.8, 'harm_to_others': 0.04, 'medical': 0.05}).kind, CrisisKind.selfHarm);
    });

    test('when the model is sure of nothing, its highest-scoring label routes', () {
      expect(model({'suicidal': 0.1, 'medical': 0.3}).kind, CrisisKind.medical);
      expect(model({'abuse': 0.4, 'medical': 0.05}).kind, CrisisKind.abuse);
      // A tie goes to the more urgent kind.
      expect(routeCrisis(['abuse', 'suicidal'], {'abuse': 0.2, 'suicidal': 0.2}), CrisisKind.suicide);
    });

    test('a bundle can move the confidence line', () {
      expect(routeCrisis(['suicidal', 'medical'], {'suicidal': 0.9, 'medical': 0.3}), CrisisKind.suicide);
      expect(routeCrisis(['suicidal', 'medical'], {'suicidal': 0.9, 'medical': 0.3}, confident: 0.25), CrisisKind.medical);
    });

    test('windows of a long message are routed again from all their labels', () {
      final merged = mergeVerdicts([model({'suicidal': 0.9}), model({}), model({'medical': 0.8})]);
      expect(merged.crisis, isTrue);
      expect(merged.labels, {'suicidal', 'medical'});
      expect(merged.kind, CrisisKind.medical);
    });
  });

  group('copy for the new routes', () {
    test('every kind has its own title in both languages', () {
      for (final copy in [CrisisCopy.en, CrisisCopy.romanUrdu]) {
        final titles = {for (final k in CrisisKind.values) copy.title(k)};
        // Self-harm and suicide may share warmth but not words.
        expect(titles, hasLength(CrisisKind.values.length), reason: '${copy.language}');
      }
    });

    test('every body asks a safety question, and nothing uses a dash', () {
      for (final copy in [CrisisCopy.en, CrisisCopy.romanUrdu]) {
        for (final kind in CrisisKind.values) {
          final text = '${copy.title(kind)} ${copy.body(kind)}';
          expect(copy.body(kind), contains('?'), reason: '$kind ${copy.language}');
          expect(text, isNot(matches(RegExp('[–—]'))), reason: '$kind ${copy.language}');
        }
      }
    });

    test('medical and harm to others tell the person to call Rescue now; medical gives no medical advice', () {
      expect(CrisisCopy.en.body(CrisisKind.medical), contains('call Rescue now'));
      expect(CrisisCopy.romanUrdu.body(CrisisKind.medical), contains('abhi Rescue ko call karein'));
      expect(CrisisCopy.en.body(CrisisKind.harmToOthers), contains('Police'));
      expect(CrisisCopy.romanUrdu.body(CrisisKind.harmToOthers), contains('Police'));
      for (final copy in [CrisisCopy.en, CrisisCopy.romanUrdu]) {
        final text = copy.body(CrisisKind.medical).toLowerCase();
        for (final advice in ['vomit', 'ulti', 'water', 'paani', 'milk', 'doodh', 'dose', 'tablet', 'pill', 'goli']) {
          expect(text, isNot(contains(advice)), reason: advice);
        }
      }
    });

    test('self-harm asks directly about suicide (red line R5)', () {
      expect(CrisisCopy.en.body(CrisisKind.selfHarm), contains('thoughts of ending your life'));
      expect(CrisisCopy.romanUrdu.body(CrisisKind.selfHarm), contains('apni jaan lene ka khayal'));
    });
  });

}
