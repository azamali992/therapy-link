import 'package:flutter/material.dart';

/// Thin icon layer for Jugnu components.
///
/// Icons are currently backed by Material Icons as visual approximations.
/// When `phosphor_flutter` is added to pubspec.yaml, replace the [IconData]
/// values here with their PhosphorIcons equivalents and the entire UI updates.
///
/// Phosphor weight convention: use `light` everywhere except the active nav tab
/// and the crisis heart (use `fill`).
abstract final class JugnuIcons {
  /// ph-heart-fill — crisis sheet header, Get help button
  static const heartFill = Icons.favorite;

  /// ph-heart — Get help button (light weight)
  static const heart = Icons.favorite_border;

  /// ph-eye-slash — Quick exit button
  static const eyeSlash = Icons.visibility_off_outlined;

  /// ph-arrow-right — nested arrow inside primary button
  static const arrowRight = Icons.arrow_forward;

  /// ph-paper-plane-right — send message
  static const send = Icons.send;

  /// ph-chat-teardrop-dots — Eve tab
  static const chat = Icons.chat_bubble_outline;

  /// ph-sun — Today tab
  static const today = Icons.wb_sunny_outlined;

  /// ph-book-open — Journal tab
  static const journal = Icons.menu_book_outlined;

  /// ph-user — You/Profile tab
  static const profile = Icons.person_outline;

  /// Active tab versions (fill weight)
  static const chatFill = Icons.chat_bubble;
  static const todayFill = Icons.wb_sunny;
  static const journalFill = Icons.menu_book;
  static const profileFill = Icons.person;

  /// ph-warning-circle — error icon (never red)
  static const warning = Icons.warning_amber_outlined;

  /// ph-info — insight footnote
  static const info = Icons.info_outline;

  /// ph-lock — private/protected
  static const lock = Icons.lock_outline;

  /// ph-device-mobile — on-device storage
  static const phoneLock = Icons.smartphone_outlined;

  /// ph-cloud — account storage
  static const cloud = Icons.cloud_outlined;

  /// ph-user-circle — clinician-visible
  static const clinician = Icons.manage_accounts_outlined;

  /// ph-caret-right — settings row chevron
  static const chevronRight = Icons.chevron_right;

  /// ph-x — dismiss / close
  static const close = Icons.close;

  /// ph-copy — copy helpline number
  static const copy = Icons.copy_outlined;

  /// ph-phone — call helpline
  static const phone = Icons.phone_outlined;

  /// ph-dots-three — thinking indicator (used in ThinkingLine)
  static const dots = Icons.more_horiz;

  /// ph-shield-check — safe storage confirmation
  static const shieldCheck = Icons.verified_user_outlined;
}
