import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme/tokens.dart';
import '../../app/theme/theme.dart' show jugnuNumberLarge;
import '../../core/ml/guardian.dart';
import '../../ui/components/crisis_sheet_view.dart';
import '../../ui/components/jugnu_app_bar.dart' as jab;
import 'crisis_copy.dart';
import 'helplines.dart';

/// Kept for callers that dial directly; the numbers themselves live in [helplines].
final umangNumber = helplines.firstWhere((h) => h.name == 'Umang').number;
final emergencyNumber = helplines.firstWhere((h) => h.name == 'Rescue').number;

/// Starts a phone call. Swapped in tests; a phone without a dialer (a tablet, no SIM) returns false.
@visibleForTesting
Future<bool> Function(Uri uri) helplineDialer = (uri) async {
  try {
    return await launchUrl(uri);
  } catch (e) {
    debugPrint('dialer unavailable: $e');
    return false;
  }
};

/// The one modal in the app. It interrupts on purpose, and the way out is one tap.
///
/// [kind] picks the lines that fit the danger; [copy] picks the language, which by default follows
/// the app's locale. Both are optional so existing callers keep working.
Future<void> showCrisisSheet(
  BuildContext context, {
  CrisisKind kind = CrisisKind.suicide,
  CrisisCopy? copy,
}) {
  final text = copy ?? CrisisCopy.forContext(context);
  final lines = helplinesFor(kind);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: true,
    builder: (ctx) => SingleChildScrollView(
      child: CrisisSheetView(
        helplines: _viewModels(kind),
        heading: text.title(kind),
        body: text.body(kind),
        backLabel: text.keepTalking,
        onBack: () => Navigator.of(ctx).pop(),
        onCall: (vm) {
          final line = lines.firstWhere((h) => h.display == vm.number, orElse: () => lines.first);
          callHelpline(ctx, line, text);
        },
        onCopy: (vm) {
          final line = lines.firstWhere((h) => h.display == vm.number, orElse: () => lines.first);
          copyHelpline(ctx, line, text);
        },
      ),
    ),
  );
}

List<HelplineViewModel> _viewModels(CrisisKind kind) => [
  for (final h in helplinesFor(kind))
    HelplineViewModel(name: h.name, number: h.display, scope: _scope(h, kind)),
];

String _scope(Helpline h, CrisisKind kind) => switch (h.number) {
  '1122' => 'Emergency',
  '15' => 'Police emergency',
  '1098' => 'Abuse, children, sexual violence',
  '1043' => 'Women facing violence',
  '1121' => 'Children at risk',
  _ => 'Mental health support',
};

/// Calls [line]. If the phone can't, the number is shown large with a way to copy it, so nobody is
/// left with a button that silently did nothing.
Future<void> callHelpline(
  BuildContext context,
  Helpline line,
  CrisisCopy copy,
) async {
  final ok = await helplineDialer(Uri(scheme: 'tel', path: line.number));
  if (ok || !context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (_) => _NumberDialog(line: line, copy: copy),
  );
}

Future<void> copyHelpline(
  BuildContext context,
  Helpline line,
  CrisisCopy copy,
) async {
  await Clipboard.setData(ClipboardData(text: line.display));
  if (!context.mounted) return;
  ScaffoldMessenger.maybeOf(context)
      ?.showSnackBar(SnackBar(content: Text(copy.numberCopied)));
}

class _NumberDialog extends StatelessWidget {
  const _NumberDialog({required this.line, required this.copy});

  final Helpline line;
  final CrisisCopy copy;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    // Dialog is always rendered on the help surface.
    return AlertDialog(
      title: Text(line.name),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(copy.callFailed, style: t.bodyMedium),
          const SizedBox(height: Tokens.s12),
          SelectableText(
            line.display,
            style: jugnuNumberLarge(Theme.of(context).colorScheme.onSurface),
          ),
        ],
      ),
      actions: [
        TextButton.icon(
          onPressed: () => copyHelpline(context, line, copy),
          icon: const Icon(Icons.copy_rounded),
          label: Text(copy.copyNumber),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).closeButtonLabel),
        ),
      ],
    );
  }
}

/// The helplines as a card that stays in place in Eve's transcript after a crisis turn,
/// and under a journal entry that showed risk. Uses the help surface colours.
class CrisisCard extends StatelessWidget {
  const CrisisCard({super.key, required this.kind, required this.copy});

  final CrisisKind kind;
  final CrisisCopy copy;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<JugnuColors>()!;
    final t = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(Tokens.s16),
        decoration: BoxDecoration(
          color: colors.helpSurface,
          borderRadius: BorderRadius.circular(Tokens.rCard),
          border: Border.all(color: colors.onHelpSurface.withValues(alpha: 0.14)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              copy.title(kind),
              style: t.titleMedium?.copyWith(color: colors.onHelpSurface),
            ),
            const SizedBox(height: Tokens.s8),
            Text(
              copy.body(kind),
              style: t.bodyMedium?.copyWith(color: colors.onHelpSurface),
            ),
            const SizedBox(height: Tokens.s12),
            for (final line in helplinesFor(kind))
              _CardLine(line: line, copy: copy, colors: colors),
          ],
        ),
      ),
    );
  }
}

class _CardLine extends StatelessWidget {
  const _CardLine({required this.line, required this.copy, required this.colors});

  final Helpline line;
  final CrisisCopy copy;
  final JugnuColors colors;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Tokens.s4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.name,
                  style: t.labelMedium?.copyWith(
                    color: colors.onHelpSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SelectableText(
                  line.display,
                  style: jugnuNumberLarge(colors.onHelpSurface),
                ),
                if (kDebugMode && !line.verified)
                  Text(
                    copy.unverified,
                    style: t.labelSmall?.copyWith(
                      color: colors.onHelpSurface.withValues(alpha: 0.6),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            width: Tokens.s48,
            height: Tokens.s48,
            child: IconButton(
              tooltip: copy.copyNumber,
              onPressed: () => copyHelpline(context, line, copy),
              icon: Icon(Icons.copy_rounded, color: colors.onHelpSurface),
              padding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(width: Tokens.s4),
          GestureDetector(
            onTap: () => callHelpline(context, line, copy),
            child: Semantics(
              button: true,
              label: copy.call(line.name),
              child: Container(
                width: Tokens.s48,
                height: Tokens.s48,
                decoration: BoxDecoration(
                  color: colors.onHelpSurface,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.call, size: 20, color: colors.helpSurface),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One tap to help from anywhere: the app bar action on every standard page.
/// Uses the [jab.GetHelpButton] visual (pill with heart icon) and opens
/// the crisis sheet when pressed.
class GetHelpButton extends StatelessWidget {
  const GetHelpButton({super.key});

  @override
  Widget build(BuildContext context) {
    final copy = CrisisCopy.forContext(context);
    return jab.GetHelpButton(
      label: copy.helpNow,
      onPressed: () => showCrisisSheet(context, copy: copy),
    );
  }
}
