import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../../l10n/relay_localizations.dart';

const currentTermsVersion = '2026-07-26';
const currentPrivacyVersion = '2026-07-26';

String _localizedLegalUrl(BuildContext context, String path) {
  final languageCode = Localizations.localeOf(context).languageCode;
  final prefix = languageCode == 'ja' || languageCode == 'es'
      ? '/$languageCode'
      : '';
  return 'https://getrelayav.com$prefix$path';
}

class LegalConsentFields extends StatelessWidget {
  const LegalConsentFields({
    required this.termsAccepted,
    required this.privacyAccepted,
    required this.onTermsChanged,
    required this.onPrivacyChanged,
    super.key,
  });

  final bool termsAccepted;
  final bool privacyAccepted;
  final ValueChanged<bool> onTermsChanged;
  final ValueChanged<bool> onPrivacyChanged;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _LegalCheckbox(
        value: termsAccepted,
        onChanged: onTermsChanged,
        label: context.l10n.text('agreeBetaTerms'),
        linkLabel: context.l10n.text('termsShort'),
        onLinkTap: () => launchUrl(
          Uri.parse(_localizedLegalUrl(context, '/terms')),
          mode: LaunchMode.externalApplication,
        ),
      ),
      _LegalCheckbox(
        value: privacyAccepted,
        onChanged: onPrivacyChanged,
        label: context.l10n.text('acknowledgePrivacy'),
        linkLabel: context.l10n.text('privacyShort'),
        onLinkTap: () => launchUrl(
          Uri.parse(_localizedLegalUrl(context, '/privacy')),
          mode: LaunchMode.externalApplication,
        ),
      ),
    ],
  );
}

class LegalConsentPage extends StatefulWidget {
  const LegalConsentPage({required this.onAccepted, super.key});

  final Future<void> Function() onAccepted;

  @override
  State<LegalConsentPage> createState() => _LegalConsentPageState();
}

class _LegalConsentPageState extends State<LegalConsentPage> {
  bool _termsAccepted = false;
  bool _privacyAccepted = false;
  bool _busy = false;
  String? _error;

  Future<void> _accept() async {
    if (!_termsAccepted || !_privacyAccepted || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onAccepted();
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = context.l10n.text('legalConsentCouldNotSave');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: _LegalConsentContent(
                  termsAccepted: _termsAccepted,
                  privacyAccepted: _privacyAccepted,
                  busy: _busy,
                  error: _error,
                  onTermsChanged: (value) =>
                      setState(() => _termsAccepted = value),
                  onPrivacyChanged: (value) =>
                      setState(() => _privacyAccepted = value),
                  onContinue: _termsAccepted && _privacyAccepted && !_busy
                      ? _accept
                      : null,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _LegalConsentContent extends StatelessWidget {
  const _LegalConsentContent({
    required this.termsAccepted,
    required this.privacyAccepted,
    required this.onTermsChanged,
    required this.onPrivacyChanged,
    required this.onContinue,
    this.busy = false,
    this.error,
  });

  final bool termsAccepted;
  final bool privacyAccepted;
  final ValueChanged<bool> onTermsChanged;
  final ValueChanged<bool> onPrivacyChanged;
  final VoidCallback? onContinue;
  final bool busy;
  final String? error;

  Future<void> _open(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          Icons.shield_outlined,
          size: 32,
          color: context.relay.actionPrimary,
        ),
        const SizedBox(height: 12),
        Text(
          l10n.text('legalConsentTitle'),
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          l10n.text('legalConsentBody'),
          style: TextStyle(color: context.relay.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        _LegalCheckbox(
          value: termsAccepted,
          onChanged: onTermsChanged,
          label: l10n.text('agreeBetaTerms'),
          linkLabel: l10n.text('termsShort'),
          onLinkTap: () => _open(_localizedLegalUrl(context, '/terms')),
        ),
        _LegalCheckbox(
          value: privacyAccepted,
          onChanged: onPrivacyChanged,
          label: l10n.text('acknowledgePrivacy'),
          linkLabel: l10n.text('privacyShort'),
          onLinkTap: () => _open(_localizedLegalUrl(context, '/privacy')),
        ),
        if (error != null) ...[
          const SizedBox(height: 8),
          Text(
            error!,
            style: TextStyle(color: context.relay.danger),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 12),
        FilledButton(
          onPressed: onContinue,
          child: busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.text('legalContinue')),
        ),
      ],
    );
  }
}

class _LegalCheckbox extends StatelessWidget {
  const _LegalCheckbox({
    required this.value,
    required this.onChanged,
    required this.label,
    required this.linkLabel,
    required this.onLinkTap,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;
  final String linkLabel;
  final VoidCallback onLinkTap;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Checkbox(value: value, onChanged: (next) => onChanged(next ?? false)),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.only(top: 11),
          child: Wrap(
            children: [
              Text('$label '),
              InkWell(
                onTap: onLinkTap,
                child: Text(
                  linkLabel,
                  style: TextStyle(
                    color: context.relay.actionPrimary,
                    decoration: TextDecoration.underline,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}
