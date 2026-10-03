import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/tokens.dart';
import '../jugnu_icons.dart';
import '../../app/theme/theme.dart';

/// View-model for a single helpline entry in the crisis sheet.
class HelplineViewModel {
  const HelplineViewModel({
    required this.name,
    required this.number,
    required this.scope,
  });

  /// Displayed helpline name, e.g. "Umang".
  final String name;

  /// Number string, e.g. "0311-7786264". Rendered in mono and selectable.
  final String number;

  /// One-line scope, e.g. "Suicide prevention".
  final String scope;
}

/// The crisis sheet content: paper/navy help surface with helpline rows.
///
/// This widget is the content of the bottom sheet — the caller is responsible
/// for displaying it inside a [showModalBottomSheet] or similar.
///
/// Rules (from DESIGN.md):
/// - helpBg fill, 24 top radius, drag handle.
/// - Heading 22 Atkinson 700 with a filled heart.
/// - Body 16 sp.
/// - Per helpline: name 700 15, number mono 600 26 selectable, scope 14.
/// - Call (filled) and Copy (outlined) buttons, 48 dp, 8 dp apart.
/// - Back/dismiss button 48 dp.
/// - No 3D, no motion, no Unbounded inside this widget.
/// - No red, no error styling.
class CrisisSheetView extends StatelessWidget {
  const CrisisSheetView({
    super.key,
    required this.helplines,
    this.heading = 'Help is here',
    this.body = 'You can talk to someone right now.',
    this.backLabel = 'Wapas chat par',
    this.onBack,
    this.onCall,
    this.onCopy,
  });

  final List<HelplineViewModel> helplines;
  final String heading;
  final String body;
  final String backLabel;
  final VoidCallback? onBack;

  /// Called when the person taps the Call button for a helpline.
  final void Function(HelplineViewModel)? onCall;

  /// Called when the person taps the Copy button for a helpline.
  final void Function(HelplineViewModel)? onCopy;

  @override
  Widget build(BuildContext context) {
    // Crisis sheet always uses help colours regardless of the ambient theme.
    // We build a local theme that applies the help palette.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final helpBg = isDark ? Jugnu.paper : Jugnu.navy;
    final helpInk = isDark ? Jugnu.navy : Jugnu.paper;

    final headingStyle = TextStyle(
      fontFamily: 'AtkinsonHyperlegibleNext',
      fontSize: 22,
      height: 28 / 22,
      fontWeight: FontWeight.w700,
      color: helpInk,
    );
    final bodyStyle = TextStyle(
      fontFamily: 'AtkinsonHyperlegibleNext',
      fontSize: 16,
      height: 24 / 16,
      fontWeight: FontWeight.w400,
      color: helpInk,
    );
    final nameStyle = TextStyle(
      fontFamily: 'AtkinsonHyperlegibleNext',
      fontSize: 15,
      height: 1.3,
      fontWeight: FontWeight.w700,
      color: helpInk,
    );
    final scopeStyle = TextStyle(
      fontFamily: 'AtkinsonHyperlegibleNext',
      fontSize: 14,
      height: 1.4,
      fontWeight: FontWeight.w400,
      color: helpInk.withValues(alpha: 0.88),
    );
    final numberStyle = jugnuNumberLarge(helpInk);
    final backStyle = TextStyle(
      fontFamily: 'AtkinsonHyperlegibleNext',
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: helpInk,
      decoration: TextDecoration.underline,
      decorationColor: helpInk,
    );

    final dividerColor = helpInk.withValues(alpha: 0.14);

    return Material(
      color: helpBg,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(Jugnu.rSheet)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Jugnu.s20, 10, Jugnu.s20, Jugnu.s24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: helpInk.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: Jugnu.s16),

              // Heading
              Row(
                children: [
                  Icon(JugnuIcons.heartFill, size: 24, color: helpInk),
                  const SizedBox(width: 10),
                  Flexible(child: Text(heading, style: headingStyle)),
                ],
              ),
              const SizedBox(height: Jugnu.s8),
              Text(body, style: bodyStyle),

              // Helpline rows
              for (final hl in helplines)
                _HelplineRow(
                  vm: hl,
                  dividerColor: dividerColor,
                  helpBg: helpBg,
                  helpInk: helpInk,
                  nameStyle: nameStyle,
                  numberStyle: numberStyle,
                  scopeStyle: scopeStyle,
                  onCall: onCall,
                  onCopy: onCopy,
                ),

              // Back / dismiss
              const SizedBox(height: 2),
              GestureDetector(
                onTap: onBack ?? () => Navigator.of(context).pop(),
                child: SizedBox(
                  height: Jugnu.minTarget,
                  child: Center(child: Text(backLabel, style: backStyle)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HelplineRow extends StatelessWidget {
  const _HelplineRow({
    required this.vm,
    required this.dividerColor,
    required this.helpBg,
    required this.helpInk,
    required this.nameStyle,
    required this.numberStyle,
    required this.scopeStyle,
    this.onCall,
    this.onCopy,
  });

  final HelplineViewModel vm;
  final Color dividerColor;
  final Color helpBg;
  final Color helpInk;
  final TextStyle nameStyle;
  final TextStyle numberStyle;
  final TextStyle scopeStyle;
  final void Function(HelplineViewModel)? onCall;
  final void Function(HelplineViewModel)? onCopy;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(color: dividerColor, height: 1, thickness: 1),
        const SizedBox(height: Jugnu.s12),
        Text(vm.name, style: nameStyle),
        const SizedBox(height: 4),
        SelectableText(
          vm.number,
          style: numberStyle,
        ),
        const SizedBox(height: 2),
        Text(vm.scope, style: scopeStyle),
        const SizedBox(height: Jugnu.s8),
        Row(
          children: [
            _CallButton(number: vm.number, helpBg: helpBg, helpInk: helpInk, onCall: onCall == null ? null : () => onCall!(vm)),
            const SizedBox(width: Jugnu.s8),
            _CopyButton(number: vm.number, helpBg: helpBg, helpInk: helpInk, onCopy: onCopy == null ? null : () => onCopy!(vm)),
          ],
        ),
        const SizedBox(height: Jugnu.s12),
      ],
    );
  }
}

class _CallButton extends StatelessWidget {
  const _CallButton({
    required this.number,
    required this.helpBg,
    required this.helpInk,
    this.onCall,
  });
  final String number;
  final Color helpBg;
  final Color helpInk;
  final VoidCallback? onCall;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Call $number',
      child: GestureDetector(
        onTap: onCall,
        child: Container(
          height: Jugnu.minTarget,
          padding: const EdgeInsets.symmetric(horizontal: Jugnu.s20),
          decoration: BoxDecoration(
            color: helpInk,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(JugnuIcons.phone, size: 16, color: helpBg),
              const SizedBox(width: Jugnu.s8),
              Text('Call', style: TextStyle(
                fontFamily: 'AtkinsonHyperlegibleNext',
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: helpBg,
              )),
            ],
          ),
        ),
      ),
    );
  }
}

class _CopyButton extends StatelessWidget {
  const _CopyButton({
    required this.number,
    required this.helpBg,
    required this.helpInk,
    this.onCopy,
  });
  final String number;
  final Color helpBg;
  final Color helpInk;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Copy $number',
      child: GestureDetector(
        onTap: onCopy ?? () => Clipboard.setData(ClipboardData(text: number)),
        child: Container(
          height: Jugnu.minTarget,
          padding: const EdgeInsets.symmetric(horizontal: Jugnu.s20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: helpInk, width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(JugnuIcons.copy, size: 16, color: helpInk),
              const SizedBox(width: Jugnu.s8),
              Text('Copy', style: TextStyle(
                fontFamily: 'AtkinsonHyperlegibleNext',
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: helpInk,
              )),
            ],
          ),
        ),
      ),
    );
  }
}
