import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/tokens.dart';
import '../shared/widgets.dart';

/// /eve — AI companion chat screen.
///
/// TODO(core-team): wire to the inference client, Guardian safety classifier,
/// streaming output, memory notes and conversation list.
class EveScreen extends StatelessWidget {
  const EveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.tabEve),
        actions: [
          IconButton(
            icon: const Icon(Icons.forum_outlined),
            tooltip: l.eveNewConversation,
            onPressed: () => context.go('/eve/conversations'),
          ),
          const QuickExitButton(),
          const GetHelpButton(),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(maxWidth: Tokens.readingWidth),
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(Tokens.s16),
                  children: [
                    const SizedBox(height: Tokens.s48),
                    Text(
                      l.eveGreeting,
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: Tokens.s8),
                    Text(
                      l.eveGreetingSub,
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: Tokens.s32),
                    // Starter prompt chips
                    Wrap(
                      spacing: Tokens.s8,
                      runSpacing: Tokens.s8,
                      children: [
                        l.eveStarterAnxious,
                        l.eveStarterSleep,
                        l.eveStarterVent,
                        l.eveStarterCalm,
                      ]
                          .map((text) => ActionChip(
                                label: Text(text),
                                onPressed: () {
                                  // TODO(core-team): seed the composer.
                                },
                              ))
                          .toList(),
                    ),
                  ],
                ),
              ),
              // Composer bar placeholder
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    Tokens.s16, Tokens.s8, Tokens.s8, Tokens.s16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: l.eveComposerHint,
                        ),
                      ),
                    ),
                    const SizedBox(width: Tokens.s8),
                    IconButton.filled(
                      icon: const Icon(Icons.send_rounded),
                      onPressed: () {
                        // TODO(core-team): send message via inference client.
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
