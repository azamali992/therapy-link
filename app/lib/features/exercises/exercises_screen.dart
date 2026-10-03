import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../shared/widgets.dart';

/// /today/exercises/:id — breathing / grounding exercise player.
///
/// [id] is the exercise pattern identifier (e.g. 'box', '478', 'grounding').
///
/// TODO(core-team): implement the animated breathing player and full
/// exercise library (box, 4-7-8, sigh, 5-4-3-2-1, muscle relaxation).
class ExercisesScreen extends StatelessWidget {
  const ExercisesScreen({super.key, this.id});

  final String? id;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Screen(
      title: l.exercisesTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: Tokens.s16),
          Text(l.exercisesSub,
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: Tokens.s24),
          for (final (exerciseId, title, sub) in [
            ('sigh', l.exerciseSigh, l.exerciseSighSub),
            ('box', l.exerciseBox, l.exerciseBoxSub),
            ('478', l.exerciseCalming, l.exerciseCalmingSub),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: Tokens.s12),
              child: Card(
                child: ListTile(
                  selected: id == exerciseId,
                  leading: const Icon(Icons.air_rounded),
                  title: Text(title),
                  subtitle: Text(sub),
                  trailing: const Icon(Icons.play_circle_outline_rounded),
                  onTap: () {
                    // TODO(core-team): start the breathing player animation.
                  },
                ),
              ),
            ),
          const SizedBox(height: Tokens.s24),
          Text(l.breathNote,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
