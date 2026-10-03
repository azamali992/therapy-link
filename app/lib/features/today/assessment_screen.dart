import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../shared/widgets.dart';

/// /today/assess/:id — PHQ-9 or GAD-7 assessment flow.
///
/// [id] must be 'phq9' or 'gad7'; the router redirect guards against other values.
///
/// TODO(core-team): implement the full question/answer flow, scoring, band
/// display, item-9 flag, and API submission.
class AssessmentScreen extends StatelessWidget {
  const AssessmentScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final title =
        id == 'phq9' ? l.assessmentPhq9 : l.assessmentGad7;

    return Screen(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: Tokens.s24),
          Text(l.assessmentIntro,
              style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: Tokens.s32),
          // Placeholder question card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Tokens.s16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l.assessmentQuestionOf(1,
                        id == 'phq9' ? 9 : 7),
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: Tokens.s12),
                  Text(
                    '— ${id.toUpperCase()} placeholder question —',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: Tokens.s24),
                  for (final opt in [
                    l.optNotAtAll,
                    l.optSeveralDays,
                    l.optMoreThanHalf,
                    l.optNearlyEveryDay,
                  ])
                    Padding(
                      padding:
                          const EdgeInsets.only(bottom: Tokens.s8),
                      child: OutlinedButton(
                        onPressed: () {
                          // TODO(core-team): record answer, advance.
                        },
                        child: Text(opt),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
