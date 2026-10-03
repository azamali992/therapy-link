/// /consent — versioned consent screen shown to all users before the app opens.
///
/// Shows three information sections, an age gate (18+), links to terms and
/// privacy as plain-text URLs, and an agreement checkbox before accept.
///
/// Under-18 path: shows helplines inline without dismissing the screen.
/// The Crisis "Get help" button is always reachable here.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme/tokens.dart';
import '../../core/settings/settings.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/components/buttons.dart';
import '../../ui/components/jugnu_app_bar.dart';
import '../../ui/components/jugnu_scaffold.dart';
import '../../ui/jugnu_icons.dart';
import '../shared/crisis_sheet.dart';

const _kTermsUrl = 'https://therapylink.pk/terms';
const _kPrivacyUrl = 'https://therapylink.pk/privacy';

class ConsentScreen extends ConsumerStatefulWidget {
  const ConsentScreen({super.key});

  @override
  ConsumerState<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends ConsumerState<ConsentScreen> {
  /// Whether the user checked "I've read the terms and privacy policy".
  bool _agreed = false;

  /// True when the user tapped "I'm under 18" — shows the under-18 view.
  bool _showUnder18 = false;

  void _accept() async {
    if (!_agreed || _showUnder18) return;
    final settings = ref.read(settingsProvider.notifier);
    await settings.setOnboarded(true);
    await settings.acceptConsent();
    if (mounted) context.go('/sign-in');
  }

  void _under18() {
    setState(() => _showUnder18 = true);
  }

  void _backFromUnder18() {
    setState(() => _showUnder18 = false);
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return JugnuScaffold(
      appBar: JugnuAppBar(
        title: _showUnder18
            ? Text(l.under18Title)
            : Text(l.consentTitle),
        onGetHelp: () => showCrisisSheet(context),
      ),
      body: _showUnder18
          ? _Under18View(
              l: l,
              onBack: _backFromUnder18,
            )
          : _ConsentBody(
              l: l,
              consentVersion: kConsentVersion,
              agreed: _agreed,
              onAgreedChanged: (v) => setState(() => _agreed = v),
              onAccept: _agreed ? _accept : null,
              onUnder18: _under18,
              onLaunchTerms: () => _launch(_kTermsUrl),
              onLaunchPrivacy: () => _launch(_kPrivacyUrl),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Main consent body
// ---------------------------------------------------------------------------

class _ConsentBody extends StatelessWidget {
  const _ConsentBody({
    required this.l,
    required this.consentVersion,
    required this.agreed,
    required this.onAgreedChanged,
    required this.onAccept,
    required this.onUnder18,
    required this.onLaunchTerms,
    required this.onLaunchPrivacy,
  });

  final AppLocalizations l;
  final String consentVersion;
  final bool agreed;
  final ValueChanged<bool> onAgreedChanged;
  final VoidCallback? onAccept;
  final VoidCallback onUnder18;
  final VoidCallback onLaunchTerms;
  final VoidCallback onLaunchPrivacy;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final colors = Theme.of(context).extension<JugnuColors>()!;
    final scheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          Jugnu.s20, Jugnu.s8, Jugnu.s20, Jugnu.s48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Version metadata
          Text(
            'Version $consentVersion',
            style: t.labelSmall?.copyWith(color: colors.ink3),
          ),
          const SizedBox(height: Jugnu.s16),

          // Info sections
          _ConsentSection(
            icon: JugnuIcons.info,
            title: l.consentAiTitle,
            body: l.consentAiBody,
          ),
          const SizedBox(height: Jugnu.s12),
          _ConsentSection(
            icon: Icons.warning_amber_rounded,
            title: l.consentEmergencyTitle,
            body: l.consentEmergencyBody,
          ),
          const SizedBox(height: Jugnu.s12),
          _ConsentSection(
            icon: JugnuIcons.phoneLock,
            title: l.consentDataTitle,
            body: l.consentDataBody,
          ),

          const SizedBox(height: Jugnu.s24),

          // Links: plain-text URLs
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onLaunchTerms,
                  child: Semantics(
                    button: true,
                    label: '${l.consentTerms}: $_kTermsUrl',
                    child: Container(
                      constraints:
                          const BoxConstraints(minHeight: Jugnu.minTarget),
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(l.consentTerms,
                              style: t.labelMedium?.copyWith(
                                  color: colors.primaryActionText)),
                          Text(_kTermsUrl,
                              style: t.bodySmall?.copyWith(
                                  color: colors.ink3, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: onLaunchPrivacy,
                  child: Semantics(
                    button: true,
                    label: '${l.consentPrivacy}: $_kPrivacyUrl',
                    child: Container(
                      constraints:
                          const BoxConstraints(minHeight: Jugnu.minTarget),
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(l.consentPrivacy,
                              style: t.labelMedium?.copyWith(
                                  color: colors.primaryActionText)),
                          Text(_kPrivacyUrl,
                              style: t.bodySmall?.copyWith(
                                  color: colors.ink3, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: Jugnu.s16),

          // Agreement checkbox
          GestureDetector(
            onTap: () => onAgreedChanged(!agreed),
            behavior: HitTestBehavior.opaque,
            child: Semantics(
              checked: agreed,
              label: l.consentAgree,
              child: Row(
                children: [
                  SizedBox.square(
                    dimension: Jugnu.minTarget,
                    child: Checkbox(
                      value: agreed,
                      onChanged: (v) => onAgreedChanged(v ?? false),
                      activeColor: scheme.primary,
                      side: BorderSide(color: colors.hairStrong, width: 1.5),
                    ),
                  ),
                  const SizedBox(width: Jugnu.s8),
                  Expanded(
                    child: Text(l.consentAgree,
                        style:
                            t.bodyMedium?.copyWith(color: scheme.onSurface)),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: Jugnu.s16),

          // Primary CTA: agree (18+)
          PrimaryButton(
            label: l.consentAge,
            onPressed: onAccept ?? () {},
          ),
          const SizedBox(height: Jugnu.s8),

          // Under-18 path
          GhostButton(
            label: l.consentUnder18,
            onPressed: onUnder18,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Info section card
// ---------------------------------------------------------------------------

class _ConsentSection extends StatelessWidget {
  const _ConsentSection({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final colors = Theme.of(context).extension<JugnuColors>()!;

    return Container(
      padding: const EdgeInsets.all(Jugnu.slabPadding),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(Jugnu.rSlab),
        border: Border.all(color: colors.hair, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: Theme.of(context).colorScheme.onSurface),
          const SizedBox(width: Jugnu.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: t.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface)),
                const SizedBox(height: Jugnu.s8),
                Text(body,
                    style: t.bodyMedium?.copyWith(color: colors.ink2)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Under-18 inline view
// ---------------------------------------------------------------------------

class _Under18View extends StatelessWidget {
  const _Under18View({required this.l, required this.onBack});

  final AppLocalizations l;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final colors = Theme.of(context).extension<JugnuColors>()!;
    final scheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          Jugnu.s20, Jugnu.s16, Jugnu.s20, Jugnu.s48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title
          Text(l.under18Title,
              style: t.headlineSmall?.copyWith(color: scheme.onSurface)),
          const SizedBox(height: Jugnu.s16),

          // Body
          Text(l.under18Body,
              style: t.bodyLarge?.copyWith(color: colors.ink2)),
          const SizedBox(height: Jugnu.s24),

          // Child helpline chip — in the help surface colour since it is a
          // crisis-adjacent action. Help UI never animates.
          Container(
            padding: const EdgeInsets.all(Jugnu.slabPadding),
            decoration: BoxDecoration(
              color: colors.helpSurface,
              borderRadius: BorderRadius.circular(Jugnu.rSlab),
            ),
            child: Row(
              children: [
                Icon(JugnuIcons.phone,
                    size: 20, color: colors.onHelpSurface),
                const SizedBox(width: Jugnu.s12),
                Expanded(
                  child: Text(
                    l.under18CallChild,
                    style: t.bodyMedium?.copyWith(
                      color: colors.onHelpSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Jugnu.s32),

          // "I entered my age wrong" — back to age gate
          GhostButton(
            label: l.under18Back,
            onPressed: onBack,
          ),
        ],
      ),
    );
  }
}
