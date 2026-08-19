import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relay_av_demo/app/theme.dart';
import 'package:relay_av_demo/l10n/relay_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('Spanish includes every English localization key', () {
    expect(RelayLocalizations.missingTranslationKeys('es'), isEmpty);
  });

  test('Japanese includes every English localization key', () {
    expect(RelayLocalizations.missingTranslationKeys('ja'), isEmpty);
  });

  test(
    'Japanese uses the approved rental-operation terminology and glyph fallback',
    () {
      final japanese = RelayLocalizations(const Locale('ja'));
      expect(japanese.text('asset'), '機材');
      expect(japanese.text('customer'), '顧客');
      expect(japanese.text('location'), '拠点');
      expect(japanese.text('transfer'), '機材移動');
      expect(
        relayLightTheme().textTheme.bodyMedium!.fontFamilyFallback,
        contains('Noto Sans JP'),
      );
      expect(
        relayDarkTheme().textTheme.bodyMedium!.fontFamilyFallback,
        contains('Noto Sans JP'),
      );
    },
  );

  test('language selection persists locally', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container
        .read(relayLocaleProvider.notifier)
        .setLocale(const Locale('es'));

    final preferences = await SharedPreferences.getInstance();
    expect(container.read(relayLocaleProvider), const Locale('es'));
    expect(preferences.getString('relay_locale'), 'es');
  });

  test('Japanese language selection persists locally', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container
        .read(relayLocaleProvider.notifier)
        .setLocale(const Locale('ja'));

    final preferences = await SharedPreferences.getInstance();
    expect(container.read(relayLocaleProvider), const Locale('ja'));
    expect(preferences.getString('relay_locale'), 'ja');
  });

  test('English is the default language after a cold start', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(relayLocaleProvider), const Locale('en'));
    await pumpEventQueue();
    expect(container.read(relayLocaleProvider), const Locale('en'));
  });
}
