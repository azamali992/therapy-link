import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/security/privacy_settings.dart';
import '../../core/security/quick_exit.dart';
import 'widgets.dart';

/// One tap and the app is out of sight: a neutral screen covers it at once, navigation goes back
/// to the start underneath, and on Android the app closes to the home screen. For an app bar;
/// [Screen] carries it on every standard page. Hidden when the person has turned it off.
class QuickExitButton extends ConsumerWidget {
  const QuickExitButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(privacySettingsProvider.select((s) => s.quickExit))) return const SizedBox.shrink();
    return IconButton(
      tooltip: context.l10n.quickExitTitle,
      onPressed: () => ref.read(quickExitProvider.notifier).exit(),
      icon: const Icon(Icons.visibility_off_outlined),
    );
  }
}
