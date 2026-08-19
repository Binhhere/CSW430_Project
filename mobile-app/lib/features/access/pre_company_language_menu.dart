import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/relay_localizations.dart';

class PreCompanyLanguageMenu extends ConsumerWidget {
  const PreCompanyLanguageMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => PopupMenuButton<String>(
    tooltip: context.l10n.text('language'),
    icon: const Icon(Icons.language_outlined),
    onSelected: (languageCode) => ref
        .read(relayLocaleProvider.notifier)
        .setLocale(
          languageCode == 'ja' ? const Locale('ja') : Locale(languageCode),
        ),
    itemBuilder: (context) => [
      PopupMenuItem(value: 'en', child: Text(context.l10n.text('english'))),
      PopupMenuItem(value: 'es', child: Text(context.l10n.text('spanish'))),
      PopupMenuItem(value: 'ja', child: Text(context.l10n.text('japanese'))),
    ],
  );
}
