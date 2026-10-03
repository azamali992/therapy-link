import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme/tokens.dart';
import '../../core/ml/guardian.dart';
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
Future<void> showCrisisSheet(BuildContext context, {CrisisKind kind = CrisisKind.suicide, CrisisCopy? copy}) {
  final text = copy ?? CrisisCopy.forContext(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: true,
    builder: (context) => _CrisisSheet(kind: kind, copy: text),
  );
}

/// Calls [line]. If the phone can't, the number is shown large with a way to copy it, so nobody is
/// left with a button that silently did nothing.
Future<void> callHelpline(BuildContext context, Helpline line, CrisisCopy copy) async {
  final ok = await helplineDialer(Uri(scheme: 'tel', path: line.number));
  if (ok || !context.mounted) return;
  await showDialog<void>(context: context, builder: (_) => _NumberDialog(line: line, copy: copy));
}

Future<void> copyHelpline(BuildContext context, Helpline line, CrisisCopy copy) async {
  await Clipboard.setData(ClipboardData(text: line.display));
  if (!context.mounted) return;
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(copy.numberCopied)));
}

class _CrisisSheet extends StatelessWidget {
  const _CrisisSheet({required this.kind, required this.copy});

  final CrisisKind kind;
  final CrisisCopy copy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final urgent = scheme.tertiary;
    final lines = helplinesFor(kind);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Tokens.s24, Tokens.s8, Tokens.s24, Tokens.s32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: urgent.withValues(alpha: 0.14), shape: BoxShape.circle),
            child: Icon(Icons.favorite_rounded, color: urgent),
          ),
          const SizedBox(height: Tokens.s20),
          Text(copy.title(kind), style: t.headlineSmall),
          const SizedBox(height: Tokens.s12),
          Text(copy.body(kind), style: t.bodyLarge),
          const SizedBox(height: Tokens.s24),
          for (var i = 0; i < lines.length; i++) ...[
            if (i > 0) const SizedBox(height: Tokens.s12),
            _CallButton(line: lines[i], copy: copy, primary: i == 0),
          ],
          const SizedBox(height: Tokens.s8),
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(copy.keepTalking)),
        ],
      ),
    );
  }
}

class _CallButton extends StatelessWidget {
  const _CallButton({required this.line, required this.copy, required this.primary});

  final Helpline line;
  final CrisisCopy copy;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = Text('${copy.call(line.name)} · ${line.display}');
    final icon = Icon(line.kinds.length == CrisisKind.values.length ? Icons.emergency_outlined : Icons.call);
    void onPressed() => callHelpline(context, line, copy);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        primary
            ? FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: scheme.tertiary, foregroundColor: scheme.surface),
                onPressed: onPressed,
                icon: icon,
                label: label,
              )
            : OutlinedButton.icon(onPressed: onPressed, icon: icon, label: label),
        if (kDebugMode && !line.verified) _Unverified(copy: copy),
      ],
    );
  }
}

/// Debug builds only: a line no human has confirmed is labelled wherever it appears.
class _Unverified extends StatelessWidget {
  const _Unverified({required this.copy});

  final CrisisCopy copy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(copy.unverified, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.error)),
    );
  }
}

class _NumberDialog extends StatelessWidget {
  const _NumberDialog({required this.line, required this.copy});

  final Helpline line;
  final CrisisCopy copy;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AlertDialog(
      title: Text(line.name),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(copy.callFailed, style: t.bodyMedium),
          const SizedBox(height: Tokens.s12),
          SelectableText(line.display, style: t.displaySmall?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
        ],
      ),
      actions: [
        TextButton.icon(onPressed: () => copyHelpline(context, line, copy), icon: const Icon(Icons.copy_rounded), label: Text(copy.copyNumber)),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(MaterialLocalizations.of(context).closeButtonLabel)),
      ],
    );
  }
}

/// The helplines as a card that stays in place: in Eve's transcript after a crisis turn, and under
/// a journal entry that showed risk.
class CrisisCard extends StatelessWidget {
  const CrisisCard({super.key, required this.kind, required this.copy});

  final CrisisKind kind;
  final CrisisCopy copy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(Tokens.s16),
        decoration: BoxDecoration(
          color: scheme.tertiary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(Tokens.rCard),
          border: Border.all(color: scheme.tertiary.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(copy.title(kind), style: t.titleMedium),
            const SizedBox(height: Tokens.s8),
            Text(copy.body(kind), style: t.bodyMedium),
            const SizedBox(height: Tokens.s12),
            for (final line in helplinesFor(kind)) _CardLine(line: line, copy: copy),
          ],
        ),
      ),
    );
  }
}

class _CardLine extends StatelessWidget {
  const _CardLine({required this.line, required this.copy});

  final Helpline line;
  final CrisisCopy copy;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Tokens.s4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.name, style: t.labelLarge),
                SelectableText(line.display, style: t.titleLarge?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
                if (kDebugMode && !line.verified) _Unverified(copy: copy),
              ],
            ),
          ),
          IconButton(
            tooltip: copy.copyNumber,
            onPressed: () => copyHelpline(context, line, copy),
            icon: const Icon(Icons.copy_rounded),
            style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
          ),
          const SizedBox(width: Tokens.s4),
          IconButton.filled(
            tooltip: copy.call(line.name),
            onPressed: () => callHelpline(context, line, copy),
            icon: const Icon(Icons.call),
            style: IconButton.styleFrom(minimumSize: const Size(48, 48), backgroundColor: scheme.tertiary, foregroundColor: scheme.surface),
          ),
        ],
      ),
    );
  }
}

/// One tap to help from anywhere: the app bar action on every standard page.
class GetHelpButton extends StatelessWidget {
  const GetHelpButton({super.key});

  @override
  Widget build(BuildContext context) {
    final copy = CrisisCopy.forContext(context);
    return IconButton(
      tooltip: copy.helpNow,
      onPressed: () => showCrisisSheet(context, copy: copy),
      icon: const Icon(Icons.support_rounded),
    );
  }
}
