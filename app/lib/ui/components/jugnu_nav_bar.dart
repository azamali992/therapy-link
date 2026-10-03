import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../jugnu_icons.dart';

/// Jugnu bottom navigation bar: 4 tabs, each at least 52 dp tall.
///
/// Active tab: fill icon in [primaryActionText] on a 56 × 30 dp raised pill.
/// Inactive tabs: outline icon in [ink3].
/// Labels: 14 sp Atkinson 600.
class JugnuNavBar extends StatelessWidget {
  const JugnuNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _labels = ['Eve', 'Today', 'Journal', 'You'];
  static const _icons = [
    JugnuIcons.chat,
    JugnuIcons.today,
    JugnuIcons.journal,
    JugnuIcons.profile,
  ];
  static const _iconsFill = [
    JugnuIcons.chatFill,
    JugnuIcons.todayFill,
    JugnuIcons.journalFill,
    JugnuIcons.profileFill,
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<JugnuColors>()!;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF33213F) : Colors.white;

    return Material(
      color: bgColor,
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
                top: BorderSide(color: colors.hair, width: 1)),
          ),
          child: SizedBox(
            height: Jugnu.navBarHeight - MediaQuery.of(context).padding.bottom,
            child: Row(
              children: List.generate(4, (i) {
                final active = i == currentIndex;
                return Expanded(
                  child: Semantics(
                    label: _labels[i],
                    selected: active,
                    button: true,
                    child: GestureDetector(
                      onTap: () => onTap(i),
                      behavior: HitTestBehavior.opaque,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 56,
                            height: 30,
                            decoration: BoxDecoration(
                              color: active ? colors.raised : Colors.transparent,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Center(
                              child: Icon(
                                active ? _iconsFill[i] : _icons[i],
                                size: 22,
                                color: active
                                    ? colors.primaryActionText
                                    : colors.ink3,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _labels[i],
                            style: textTheme.labelMedium?.copyWith(
                              color: active
                                  ? colors.primaryActionText
                                  : colors.ink3,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
