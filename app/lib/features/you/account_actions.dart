import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../app/theme/tokens.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/session.dart';
import '../shared/widgets.dart';

/// Asks before anything that removes data. Returns true only on an explicit yes.
///
/// Uses Jugnu-compliant dialog styling: 48 dp minimum on the confirm button,
/// calm and specific copy on the caller's side.
Future<bool> confirmDestructive(BuildContext context,
    {required String title,
    required String body,
    required String action}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          style: TextButton.styleFrom(
              minimumSize: const Size(0, Tokens.s48)),
          child: Text(ctx.l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(
              minimumSize: const Size(0, Tokens.s48)),
          child: Text(action),
        ),
      ],
    ),
  );
  return ok == true;
}

/// Sign-out deletes this person's Eve data from the phone, so it asks first.
Future<void> signOutWithConfirm(BuildContext context, WidgetRef ref) async {
  final l = context.l10n;
  if (!await confirmDestructive(context, title: l.signOutConfirmTitle, body: l.signOutConfirmBody, action: l.signOut)) return;
  try {
    await ref.read(sessionProvider).signOut();
  } on UnsentMoodException catch (e) {
    if (!context.mounted) return;
    final body = l.signOutUnsentBody(e.count);
    if (!await confirmDestructive(context, title: l.signOutUnsentTitle, body: body, action: l.signOutAnyway)) return;
    await ref.read(sessionProvider).signOut(discardUnsent: true);
  }
}

Future<void> deleteChatsWithConfirm(BuildContext context, WidgetRef ref) async {
  final l = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  if (!await confirmDestructive(context, title: l.deleteChatsTitle, body: l.deleteChatsBody, action: l.deleteChatsAction)) return;
  await ref.read(sessionProvider).deleteAllEveData();
  messenger.showSnackBar(SnackBar(content: Text(l.deleteChatsDone)));
}

/// Writes the export somewhere the person can reach and returns the path.
final dataExportSaverProvider = Provider<Future<String> Function(String fileName, String contents)>((_) => _saveExport);

Future<String> _saveExport(String fileName, String contents) async {
  if (kIsWeb) throw UnsupportedError('saving a file is not supported on web');
  Directory? dir;
  try {
    dir = await getDownloadsDirectory();
  } catch (_) {}
  dir ??= await getApplicationDocumentsDirectory();
  final file = File('${dir.path}${Platform.pathSeparator}$fileName');
  await file.writeAsString(contents, flush: true);
  return file.path;
}

/// 'therapylink-export-2026-09-25.json'.
String exportFileName(DateTime now) =>
    'therapylink-export-${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}.json';

/// Fetches everything the server holds for this account and saves it as readable JSON.
Future<void> downloadMyData(BuildContext context, WidgetRef ref) async {
  final l = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(SnackBar(content: Text(l.youExportWorking)));
  try {
    final data = await ref.read(apiClientProvider).exportMe();
    final path = await ref.read(dataExportSaverProvider)(exportFileName(DateTime.now()), const JsonEncoder.withIndent('  ').convert(data));
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l.youExportDone(path)), duration: const Duration(seconds: 8)));
  } catch (e) {
    debugPrint('export failed: $e');
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l.youExportFailed)));
  }
}

Future<void> deleteAccountWithConfirm(BuildContext context, WidgetRef ref) async {
  final l = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  if (!await confirmDestructive(context, title: l.deleteAccountTitle, body: l.deleteAccountBody, action: l.deleteAccountAction)) return;
  try {
    await ref.read(sessionProvider).deleteAccount();
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(l.deleteAccountFailed)));
  }
}
