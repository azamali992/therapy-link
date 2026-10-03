import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../shared/widgets.dart';

/// /journal/new or /journal/:id — journal entry editor.
///
/// Pass [prompt] for a new entry pre-seeded with a prompt string, or
/// [entryId] to open an existing entry for editing.
///
/// TODO(core-team): wire to the drift database, add mood-while-writing picker
/// and auto-save.
class JournalEditorScreen extends StatelessWidget {
  const JournalEditorScreen({super.key, this.prompt, this.entryId});

  final String? prompt;
  final String? entryId;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isNew = entryId == null;

    return Screen(
      title: isNew ? l.journalNew : l.journalTitle,
      scroll: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            initialValue: null,
            decoration: InputDecoration(hintText: l.journalTitleHint),
          ),
          const SizedBox(height: Tokens.s12),
          Expanded(
            child: TextFormField(
              initialValue: prompt,
              maxLines: null,
              expands: true,
              decoration: InputDecoration(
                hintText: l.journalBodyHint,
                alignLabelWithHint: true,
              ),
              textAlignVertical: TextAlignVertical.top,
            ),
          ),
          const SizedBox(height: Tokens.s16),
          FilledButton(
            onPressed: () {
              // TODO(core-team): save entry to encrypted drift DB.
            },
            child: Text(l.journalSave),
          ),
        ],
      ),
    );
  }
}
