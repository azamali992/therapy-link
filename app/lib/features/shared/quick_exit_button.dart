import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/security/privacy_settings.dart';
import '../../core/security/quick_exit.dart';
import '../../ui/components/jugnu_app_bar.dart' as jab;

/// One tap and the app is out of sight: a neutral screen covers it at once,
/// navigation goes back to the start underneath, and on Android the app closes
/// to the home screen.
///
/// Hidden when the person has turned quick exit off in settings. Uses the
/// [jab.QuickExitButton] visual from the design system — one visual
/// implementation shared everywhere.
class QuickExitButton extends ConsumerWidget {
  const QuickExitButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(privacySettingsProvider.select((s) => s.quickExit))) {
      return const SizedBox.shrink();
    }
    return jab.QuickExitButton(
      onPressed: () => ref.read(quickExitProvider.notifier).exit(),
    );
  }
}
