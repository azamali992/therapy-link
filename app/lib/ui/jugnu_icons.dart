import 'package:flutter/material.dart';

/// Thin icon layer for Jugnu components, backed by Material icons.
///
/// Phosphor flutter (all published versions up to 2.1.0) fails to compile
/// on Flutter 3.22+ because PhosphorIconData extends IconData which is now
/// a final class. Until a compatible version is released, Material icons
/// serve as visual approximations. When phosphor_flutter ships a fix,
/// replace the IconData values here and the entire UI updates.
///
/// Convention: outlined/regular variant everywhere except active nav tab and
/// the crisis heart, which use filled variants.
abstract final class JugnuIcons {
  /// ph-heart-fill -- crisis sheet header, Get help button active state
  static const heartFill = Icons.favorite;

  /// ph-heart -- Get help button (regular weight)
  static const heart = Icons.favorite_border;

  /// ph-eye-slash -- Quick exit button
  static const eyeSlash = Icons.visibility_off_outlined;

  /// ph-arrow-right -- nested arrow inside primary button
  static const arrowRight = Icons.arrow_forward;

  /// ph-paper-plane-right -- send message
  static const send = Icons.send;

  /// ph-chat-teardrop-dots -- Eve tab (regular)
  static const chat = Icons.chat_bubble_outline;

  /// ph-sun -- Today tab (regular)
  static const today = Icons.wb_sunny_outlined;

  /// ph-notebook -- Journal tab (regular)
  static const journal = Icons.menu_book_outlined;

  /// ph-user -- You/Profile tab (regular)
  static const profile = Icons.person_outline;

  /// Active tab fill variants
  static const chatFill = Icons.chat_bubble;
  static const todayFill = Icons.wb_sunny;
  static const journalFill = Icons.menu_book;
  static const profileFill = Icons.person;

  /// ph-warning -- error/caution indicator (never red)
  static const warning = Icons.warning_amber_outlined;

  /// ph-info -- insight footnote, consent AI section
  static const info = Icons.info_outline;

  /// ph-lock -- private/protected
  static const lock = Icons.lock_outline;

  /// ph-device-mobile -- on-device storage (welcome fact 3, consent section)
  static const phoneLock = Icons.smartphone_outlined;

  /// ph-cloud -- account/cloud storage
  static const cloud = Icons.cloud_outlined;

  /// ph-user-gear -- clinician-visible row
  static const clinician = Icons.manage_accounts_outlined;

  /// ph-caret-right -- settings row chevron
  static const chevronRight = Icons.chevron_right;

  /// ph-x -- dismiss / close
  static const close = Icons.close;

  /// ph-copy -- copy helpline number
  static const copy = Icons.copy_outlined;

  /// ph-phone -- call helpline
  static const phone = Icons.phone_outlined;

  /// ph-dots-three -- thinking indicator (used in ThinkingLine)
  static const dots = Icons.more_horiz;

  /// ph-shield-check -- safe storage confirmation
  static const shieldCheck = Icons.verified_user_outlined;

  /// ph-translate -- language fact on welcome screen
  static const translate = Icons.translate_outlined;
}
