import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../jugnu_icons.dart';

/// Chat composer: pill text field + circular send button.
///
/// [enabled] = false shows the send button in the "Eve is generating" disabled
/// state (raised colour, ink3 icon). The field stays enabled so the user can
/// pre-type.
///
/// [onSend] is called with the trimmed text. The controller is cleared after
/// the callback returns. Pass [quickReplies] to show outlined chips above the
/// composer (max shown as passed; layout wraps).
class Composer extends StatefulWidget {
  const Composer({
    super.key,
    required this.onSend,
    this.enabled = true,
    this.hint = 'Kuch bhi likho…',
    this.quickReplies = const [],
    this.onQuickReply,
  });

  final ValueChanged<String> onSend;
  final bool enabled;
  final String hint;
  final List<String> quickReplies;
  final ValueChanged<String>? onQuickReply;

  @override
  State<Composer> createState() => _ComposerState();
}

class _ComposerState extends State<Composer> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _send() {
    final t = _ctrl.text.trim();
    if (t.isEmpty) return;
    _ctrl.clear();
    widget.onSend(t);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<JugnuColors>()!;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.quickReplies.isNotEmpty)
          SizedBox(
            height: Jugnu.minTarget + 12,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                  horizontal: Jugnu.s20, vertical: 6),
              itemCount: widget.quickReplies.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(width: Jugnu.s8),
              itemBuilder: (context, i) {
                final label = widget.quickReplies[i];
                return GestureDetector(
                  onTap: () => widget.onQuickReply?.call(label),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: Jugnu.minTarget),
                    padding: const EdgeInsets.symmetric(
                        horizontal: Jugnu.s16, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                          color: colors.hairStrong, width: 1.5),
                    ),
                    child: Center(
                      child: Text(label,
                          style: textTheme.labelMedium?.copyWith(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w600,
                          )),
                    ),
                  ),
                );
              },
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
              Jugnu.s16, 4, Jugnu.s16, Jugnu.s12),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: Jugnu.primaryButtonHeight,
                  child: TextField(
                    controller: _ctrl,
                    style: textTheme.bodyLarge,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: widget.hint,
                      hintStyle: textTheme.bodyLarge
                          ?.copyWith(color: colors.ink3),
                      filled: true,
                      fillColor: colors.surface,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999),
                        borderSide: BorderSide(color: colors.hair),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999),
                        borderSide: BorderSide(color: colors.hair),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999),
                        borderSide: BorderSide(
                            color: scheme.primary, width: 1.5),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: Jugnu.s8),
              GestureDetector(
                onTap: widget.enabled ? _send : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: Jugnu.primaryButtonHeight,
                  height: Jugnu.primaryButtonHeight,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.enabled ? scheme.primary : colors.raised,
                  ),
                  child: Center(
                    child: Icon(
                      JugnuIcons.send,
                      size: 22,
                      color: widget.enabled
                          ? scheme.onPrimary
                          : colors.ink3,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
