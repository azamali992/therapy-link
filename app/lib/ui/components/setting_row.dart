import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../jugnu_icons.dart';

/// A settings row with a title, optional subtitle, and a [JugnuSwitch].
///
/// Minimum height 48 dp.
class SettingRow extends StatelessWidget {
  const SettingRow({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<JugnuColors>()!;
    final textTheme = Theme.of(context).textTheme;
    final ink = Theme.of(context).colorScheme.onSurface;

    return Semantics(
      label: '$title${subtitle != null ? '. $subtitle' : ''}',
      child: InkWell(
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 2, vertical: 6),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 22, color: ink),
                const SizedBox(width: Jugnu.s12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: textTheme.bodyLarge?.copyWith(color: ink)),
                    if (subtitle != null)
                      Text(subtitle!,
                          style: textTheme.bodyMedium
                              ?.copyWith(color: colors.ink2)),
                  ],
                ),
              ),
              const SizedBox(width: Jugnu.s12),
              JugnuSwitch(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}

/// Jugnu-flavoured switch: lime track when on, raised+hairline when off.
/// 52 × 32 dp pill. Knob: onSafe when on, ink3 when off.
class JugnuSwitch extends StatelessWidget {
  const JugnuSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    // Use Flutter's Switch and let the [switchTheme] in [buildTheme] apply the
    // Jugnu colours automatically.
    return Switch(
      value: value,
      onChanged: onChanged,
    );
  }
}

/// "Where your things are kept" three-row storage summary.
///
/// Rows:
/// 1. Only on this phone — Eve chats and mood from them.
/// 2. In your account — check-ins, journal, assessments.
/// 3. With a clinician — nothing until the switch is on.
class StorageRow extends StatelessWidget {
  const StorageRow({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<JugnuColors>()!;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Row(
          icon: JugnuIcons.phoneLock,
          title: 'Only on this phone',
          detail: 'Eve chats and mood from them',
          colors: colors,
          textTheme: textTheme,
          safe: true,
        ),
        const SizedBox(height: Jugnu.s8),
        _Row(
          icon: JugnuIcons.cloud,
          title: 'In your account',
          detail: 'Check-ins you log, journal, assessments',
          colors: colors,
          textTheme: textTheme,
        ),
        const SizedBox(height: Jugnu.s8),
        _Row(
          icon: JugnuIcons.clinician,
          title: 'With a clinician',
          detail: 'Nothing until you switch it on',
          colors: colors,
          textTheme: textTheme,
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    required this.detail,
    required this.colors,
    required this.textTheme,
    this.safe = false,
  });

  final IconData icon;
  final String title;
  final String detail;
  final JugnuColors colors;
  final TextTheme textTheme;
  final bool safe;

  @override
  Widget build(BuildContext context) {
    final ink = Theme.of(context).colorScheme.onSurface;
    final iconColor = safe ? colors.safeText : colors.ink2;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 22, color: iconColor),
        ),
        const SizedBox(width: Jugnu.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: textTheme.bodyLarge?.copyWith(
                    color: ink,
                    fontWeight: FontWeight.w700,
                  )),
              Text(detail,
                  style: textTheme.bodyMedium
                      ?.copyWith(color: colors.ink2)),
            ],
          ),
        ),
      ],
    );
  }
}
