import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../jugnu_icons.dart';

/// Standard Jugnu app bar.
///
/// Slot layout (LTR):  [leading?]  [title]  →  [GetHelpButton]  [QuickExitButton?]
///
/// The [GetHelpButton] is always present. [QuickExitButton] is shown only when
/// [showQuickExit] is true (the caller reads the privacy setting).
///
/// Neither button is animated and neither can be disabled — crisis controls
/// are never blocked, never badged, never hidden.
class JugnuAppBar extends StatelessWidget implements PreferredSizeWidget {
  const JugnuAppBar({
    super.key,
    required this.title,
    required this.onGetHelp,
    this.onQuickExit,
    this.showQuickExit = false,
    this.leading,
  });

  final Widget title;
  final VoidCallback onGetHelp;
  final VoidCallback? onQuickExit;

  /// When true and [onQuickExit] is non-null, the Quick exit button is shown
  /// 10 dp to the right of Get help.
  final bool showQuickExit;
  final Widget? leading;

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: leading,
      titleSpacing: leading != null ? null : Jugnu.s20,
      title: title,
      actions: [
        GetHelpButton(onPressed: onGetHelp),
        if (showQuickExit && onQuickExit != null) ...[
          const SizedBox(width: 10),
          QuickExitButton(onPressed: onQuickExit!),
        ],
        const SizedBox(width: Jugnu.s16),
      ],
    );
  }
}

/// "Get help / Madad" pill button. Always 48 dp tall, paper outline, heart icon.
///
/// Never animated. Never disabled. Never badged. Opens the crisis sheet.
/// Uses the [helpSurface] colour for both outline and text, so it reads as
/// the one help-coloured control on every screen.
class GetHelpButton extends StatelessWidget {
  const GetHelpButton({
    super.key,
    required this.onPressed,
    this.label = 'Get help',
  });

  final VoidCallback onPressed;

  /// Button label — defaults to English. Pass 'Madad' for Roman Urdu.
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<JugnuColors>()!;
    final textStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
          color: colors.helpSurface,
          fontWeight: FontWeight.w700,
        );

    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          height: Jugnu.minTarget,
          padding: const EdgeInsets.symmetric(horizontal: Jugnu.s16)
              .copyWith(left: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: colors.helpSurface, width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(JugnuIcons.heart,
                  size: 18, color: colors.helpSurface),
              const SizedBox(width: 6),
              Text(label, style: textStyle),
            ],
          ),
        ),
      ),
    );
  }
}

/// Quick exit button. 48 dp circle, eye-slash icon, labelled for
/// accessibility. Sits 10 dp right of [GetHelpButton].
class QuickExitButton extends StatelessWidget {
  const QuickExitButton({
    super.key,
    required this.onPressed,
  });

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<JugnuColors>()!;

    return Semantics(
      button: true,
      label: 'Quick exit',
      child: SizedBox(
        width: Jugnu.minTarget,
        height: Jugnu.minTarget,
        child: IconButton(
          icon: Icon(JugnuIcons.eyeSlash, size: 20),
          color: colors.ink2,
          tooltip: 'Quick exit',
          onPressed: onPressed,
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }
}
