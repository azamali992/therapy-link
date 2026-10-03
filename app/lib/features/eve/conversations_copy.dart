import 'package:flutter/widgets.dart';

import '../../app/locale.dart';

/// Strings for the conversation list, in English and Roman Urdu.
///
/// TODO(l10n): move these into app_en.arb / app_ur.arb once the ARB owner merges; they live here
/// only because this stream does not own the ARB files. Keys are named the way they would be there.
class ConversationsCopy {
  const ConversationsCopy._({
    required this.conversationsMenu,
    required this.conversationsTitle,
    required this.conversationsIntro,
    required this.conversationsEmptyTitle,
    required this.conversationsEmptyBody,
    required this.conversationsStart,
    required this.conversationsLoadFailed,
    required this.conversationsRetry,
    required this.conversationsOpenNow,
    required this.conversationsDelete,
    required this.conversationsDeleteTitle,
    required this.conversationsDeleteBody,
    required this.conversationsDeleteConfirm,
    required this.conversationsDeleted,
    required this.conversationsDeleteFailed,
    required this.conversationsBusy,
    required String Function(int n) messageCount,
  }) : _messageCount = messageCount;

  final String conversationsMenu;
  final String conversationsTitle;
  final String conversationsIntro;
  final String conversationsEmptyTitle;
  final String conversationsEmptyBody;
  final String conversationsStart;
  final String conversationsLoadFailed;
  final String conversationsRetry;
  final String conversationsOpenNow;
  final String conversationsDelete;
  final String conversationsDeleteTitle;
  final String conversationsDeleteBody;
  final String conversationsDeleteConfirm;
  final String conversationsDeleted;
  final String conversationsDeleteFailed;
  final String conversationsBusy;
  final String Function(int n) _messageCount;

  /// "3 messages": counts what the person and Eve said, not cards.
  String conversationsMessageCount(int n) => _messageCount(n);

  static ConversationsCopy of(BuildContext context) => isRomanUrdu(Localizations.localeOf(context)) ? romanUrdu : en;

  static final en = ConversationsCopy._(
    conversationsMenu: 'Your conversations',
    conversationsTitle: 'Your conversations',
    conversationsIntro: 'Kept on this phone only. Tap one to pick it up again.',
    conversationsEmptyTitle: 'No conversations yet',
    conversationsEmptyBody: 'When you talk with Eve, your conversations are kept here, on this phone only.',
    conversationsStart: 'Talk to Eve',
    conversationsLoadFailed: "Your conversations couldn't be loaded. Nothing has been lost.",
    conversationsRetry: 'Try again',
    conversationsOpenNow: 'Open now',
    conversationsDelete: 'Delete conversation',
    conversationsDeleteTitle: 'Delete this conversation?',
    conversationsDeleteBody:
        "Its messages will be removed from this phone and can't be brought back. What Eve remembers from it stays; you can see or delete those notes under You > What Eve remembers.",
    conversationsDeleteConfirm: 'Delete',
    conversationsDeleted: 'Conversation deleted',
    conversationsDeleteFailed: "That conversation couldn't be deleted. Try again.",
    conversationsBusy: 'Eve is still replying. Try again in a moment.',
    messageCount: (n) => n == 1 ? '1 message' : '$n messages',
  );

  static final romanUrdu = ConversationsCopy._(
    conversationsMenu: 'Aap ki baat cheet',
    conversationsTitle: 'Aap ki baat cheet',
    conversationsIntro: 'Sirf is phone par rakhi hai. Kisi ko tap karein aur wahin se shuru karein.',
    conversationsEmptyTitle: 'Abhi koi baat cheet nahi',
    conversationsEmptyBody: 'Jab aap Eve se baat karenge, aap ki baat cheet yahan, sirf is phone par, rakhi jayegi.',
    conversationsStart: 'Eve se baat karein',
    conversationsLoadFailed: 'Aap ki baat cheet load nahi ho saki. Kuch zaya nahi hua.',
    conversationsRetry: 'Dobara koshish karein',
    conversationsOpenNow: 'Abhi khuli hai',
    conversationsDelete: 'Baat cheet mitayein',
    conversationsDeleteTitle: 'Yeh baat cheet mita dein?',
    conversationsDeleteBody:
        'Is ke paighaam is phone se hat jayenge aur wapas nahi aa sakenge. Eve ko is mein se jo yaad hai woh rahega; woh notes Aap > Eve ko kya yaad hai mein dekh ya mita sakte hain.',
    conversationsDeleteConfirm: 'Mitayein',
    conversationsDeleted: 'Baat cheet mita di gayi',
    conversationsDeleteFailed: 'Yeh baat cheet mit nahi saki. Dobara koshish karein.',
    conversationsBusy: 'Eve abhi jawab de rahi hai. Thori der mein dobara koshish karein.',
    messageCount: (n) => n == 1 ? '1 paighaam' : '$n paighaam',
  );
}
