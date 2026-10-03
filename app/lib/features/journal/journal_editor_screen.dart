import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/tokens.dart';
import '../../core/api/api_client.dart';
import '../../core/api/models.dart';
import '../../core/ml/guardian.dart';
import '../../core/ml/onnx_guardian.dart';
import '../shared/crisis_copy.dart';
import '../shared/widgets.dart';
import 'journal_providers.dart';

/// /journal/new or /journal/:id — journal entry editor.
///
/// Pass [prompt] for a new entry pre-seeded with a prompt string, or
/// [entryId] to open an existing entry for editing.
class JournalEditorScreen extends ConsumerStatefulWidget {
  const JournalEditorScreen({super.key, this.prompt, this.entryId});

  final String? prompt;
  final String? entryId;

  @override
  ConsumerState<JournalEditorScreen> createState() => _JournalEditorScreenState();
}

class _JournalEditorScreenState extends ConsumerState<JournalEditorScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  int? _mood;
  bool _saving = false;
  bool _loaded = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.prompt != null) _body.text = widget.prompt!;
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  void _hydrate(JournalEntry e) {
    if (_loaded) return;
    _loaded = true;
    _title.text = e.title ?? '';
    _body.text = e.body;
    _mood = e.mood;
  }

  Future<void> _save() async {
    if (_body.text.trim().isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final api = ref.read(apiClientProvider);
    final title = _title.text.trim().isEmpty ? null : _title.text.trim();
    var saved = false;
    try {
      if (widget.entryId == null) {
        await api.createJournal(title: title, body: _body.text.trim(), mood: _mood);
      } else {
        await api.updateJournal(widget.entryId!, title: title, body: _body.text.trim(), mood: _mood);
      }
      ref.invalidate(journalProvider);
      saved = true;
    } catch (_) {
      // Handled below, after the screening: a failed save must not skip the check.
    }
    // Run the safety screen on the phone so it works offline too.
    final text = [?title, _body.text.trim()].join('\n');
    final kind = await _screen(text);
    if (!mounted) return;
    if (kind != null) {
      setState(() => _saving = false);
      await showCrisisSheet(context, kind: kind, copy: CrisisCopy.forText(text));
      if (!mounted) return;
    }
    if (saved) {
      context.pop();
    } else {
      setState(() {
        _saving = false;
        _error = context.l10n.errorGeneric;
      });
    }
  }

  Future<CrisisKind?> _screen(String text) async {
    try {
      return (await ref.read(guardianProvider).classify(text)).kind;
    } catch (e) {
      debugPrint('journal screening skipped: $e');
      return null;
    }
  }

  Future<void> _delete() async {
    setState(() => _saving = true);
    try {
      await ref.read(apiClientProvider).deleteJournal(widget.entryId!);
      ref.invalidate(journalProvider);
      if (mounted) context.pop();
    } catch (_) {
      setState(() {
        _saving = false;
        _error = context.l10n.errorGeneric;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    if (widget.entryId != null && !_loaded) {
      final entries = ref.watch(journalProvider);
      final e = entries.value?.where((x) => x.id == widget.entryId).firstOrNull;
      if (e != null) _hydrate(e);
      if (entries.isLoading) return Screen(title: l.journalTitle, child: const SkeletonList(rows: 2));
    }

    return Screen(
      title: widget.entryId == null ? l.journalNew : l.journalTitle,
      scroll: false,
      actions: [
        if (widget.entryId != null)
          IconButton(tooltip: l.journalDelete, onPressed: _saving ? null : _delete, icon: const Icon(Icons.delete_outline_rounded)),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _title,
            style: t.titleLarge,
            decoration: InputDecoration(hintText: l.journalTitleHint, filled: false, border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none),
            textCapitalization: TextCapitalization.sentences,
          ),
          Expanded(
            child: TextField(
              controller: _body,
              autofocus: widget.entryId == null,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: t.bodyLarge,
              decoration: InputDecoration(hintText: l.journalBodyHint, filled: false, border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none),
              textCapitalization: TextCapitalization.sentences,
            ),
          ),
          Text(l.journalMood, style: t.labelLarge?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: Tokens.s8),
          MoodPicker(selected: _mood, onPick: (v) => setState(() => _mood = _mood == v ? null : v)),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: Tokens.s8), child: Text(_error!, style: TextStyle(color: scheme.error))),
          const SizedBox(height: Tokens.s12),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(l.journalSave),
          ),
          const SizedBox(height: Tokens.s8),
        ],
      ),
    );
  }
}
