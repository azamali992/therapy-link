import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import '../../core/ml/onnx_guardian.dart';
import '../../ui/components/buttons.dart';
import 'widgets.dart';

/// Where the trained safety model stands, in one quiet block: a line of text, a progress bar while
/// it downloads, and the one action that fits. Used in Settings, and in Eve's paused notice when a
/// release build waits for the model.
class GuardianStatusPanel extends ConsumerWidget {
  const GuardianStatusPanel({super.key});

  static int _megabytes(int bytes) => (bytes / 1000000).ceil();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final colors = Theme.of(context).extension<JugnuColors>()!;
    final status = ref.watch(guardianModelManagerProvider);
    final manager = ref.read(guardianModelManagerProvider.notifier);

    final body = switch (status) {
      GuardianReady() => l.guardianReady,
      GuardianDownloading(:final percent) => l.guardianDownloading(percent),
      GuardianWaitingForWifi(:final bytes) => l.guardianWaitingForWifi(_megabytes(bytes)),
      GuardianNoSpace(:final bytes) => l.guardianNoSpace(_megabytes(bytes)),
      GuardianFailed() => l.guardianFailed,
      GuardianHeuristic() => l.guardianHeuristic,
    };
    final caption = t.bodySmall?.copyWith(color: colors.ink2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(body, style: t.bodyMedium?.copyWith(color: colors.ink2)),
        if (status is GuardianDownloading) ...[
          const SizedBox(height: Tokens.s8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: status.percent / 100, minHeight: 6),
          ),
          const SizedBox(height: Tokens.s8),
          Text(l.guardianMeanwhile, style: caption),
        ],
        if (status is GuardianWaitingForWifi) ...[
          const SizedBox(height: Tokens.s12),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: GhostButton(label: l.guardianDownloadOnData, onPressed: () => manager.download(allowMetered: true)),
          ),
        ],
        if (status is GuardianHeuristic || status is GuardianFailed || status is GuardianNoSpace) ...[
          const SizedBox(height: Tokens.s12),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: manager.available
                ? GhostButton(label: l.guardianDownload, onPressed: manager.download)
                : Text(l.guardianUnavailable, style: caption),
          ),
        ],
      ],
    );
  }
}
