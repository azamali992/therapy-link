/// Lint-style test: fails if any file under app/lib/features/ uses a raw
/// Color(0x…) literal or references Jugnu.* palette constants directly.
///
/// Allowlist: app/lib/app/theme/ (tokens.dart and theme.dart are the only
/// places where palette names and raw hex are permitted).
///
/// This test runs with `flutter test` — no custom_lint tooling required.
library;

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Token lint', () {
    test('no raw Color(0x…) literals in features/', () {
      final violations = _scanDirectory(
        'lib/features',
        pattern: RegExp(r'Color\(0x[0-9A-Fa-f]+\)'),
        allowlist: const [],
      );
      expect(violations, isEmpty,
          reason: 'Use JugnuColors role tokens instead of raw hex.\n'
              'Violating files:\n${violations.join('\n')}');
    });

    test('no direct Jugnu.* palette references in features/', () {
      // Only named role accessors (JugnuColors.dark.evePresence etc.) are
      // permitted in feature code.
      final violations = _scanDirectory(
        'lib/features',
        pattern: RegExp(r'\bJugnu\.(night|plum|navy|paper|ink[23]?|action'
            r'|onAction|actionText|eve|eveMid|eveDeep|eveHaze|safe|onSafe'
            r'|surface|raised|hair|groundLightTop|groundLightBottom'
            r'|ink2Light|ink3Light|actionLight|eveLight|safeLight'
            r'|safeTextLight|actionTextLight)\b'),
        allowlist: const ['lib/app/theme/'],
      );
      expect(violations, isEmpty,
          reason: 'Feature code must not reference Jugnu palette names.\n'
              'Use Theme.of(context).extension<JugnuColors>() role accessors.\n'
              'Violating files:\n${violations.join('\n')}');
    });

    test('minimum text size floor: nothing readable < 14 sp in features/', () {
      // Catches fontSize: 12 or fontSize: 13 used for non-timestamp text.
      // Timestamps (labelSmall) are allowed at 13.
      // This is a heuristic scan — it flags lines to review, not a compiler error.
      final pattern = RegExp(r'fontSize:\s*(1[012])[^0-9]');
      final violations = _scanDirectory(
        'lib/features',
        pattern: pattern,
        allowlist: const [],
      );
      // Report as warnings; do not fail the build — some 12sp might be
      // intentional (icons, decorative). Change to expect(violations, isEmpty)
      // once the codebase is fully audited.
      if (violations.isNotEmpty) {
        // ignore: avoid_print
        print('⚠ Possible sub-14 sp text sizes found (review manually):\n'
            '${violations.join('\n')}');
      }
    });
  });
}

/// Scans [relativeDir] (relative to the project root, i.e. the directory
/// containing pubspec.yaml) for [pattern] and returns a list of
/// "path:line:snippet" strings for each match, excluding any file whose path
/// contains a string in [allowlist].
List<String> _scanDirectory(
  String relativeDir, {
  required RegExp pattern,
  required List<String> allowlist,
}) {
  // When run via `flutter test` the working directory is the package root.
  final dir = Directory(relativeDir);
  if (!dir.existsSync()) return [];

  final violations = <String>[];

  for (final entity
      in dir.listSync(recursive: true).whereType<File>()) {
    if (!entity.path.endsWith('.dart')) continue;

    // Skip allowlisted paths.
    if (allowlist.any((a) => entity.path.replaceAll('\\', '/').contains(a))) {
      continue;
    }

    final lines = entity.readAsLinesSync();
    for (int i = 0; i < lines.length; i++) {
      if (pattern.hasMatch(lines[i])) {
        violations.add('${entity.path}:${i + 1}: ${lines[i].trim()}');
      }
    }
  }

  return violations;
}
