import 'package:flutter/material.dart';

import '../shared/widgets.dart';

/// /eve/conversations — conversation history list.
///
/// TODO(core-team): wire to the local drift database.
class ConversationsScreen extends StatelessWidget {
  const ConversationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Screen(
      title: l.eveNewConversation,
      child: EmptyState(
        title: l.eveNewConversation,
        body: l.eveGreetingSub,
      ),
    );
  }
}
