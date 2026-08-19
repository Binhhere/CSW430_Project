import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'relay_localizations.dart';

const _localePreferenceKey = 'relay_locale';

final relayLocaleProvider = NotifierProvider<RelayLocaleController, Locale>(
  RelayLocaleController.new,
);

class RelayLocaleController extends Notifier<Locale> {
  bool _selectionMade = false;

  @override
  Locale build() {
    unawaited(_restore());
    return const Locale('en');
  }

  Future<void> _restore() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final saved = preferences.getString(_localePreferenceKey);
      if (!_selectionMade &&
          saved != null &&
          RelayLocalizations.isSupportedLanguage(saved)) {
        state = Locale(saved);
      }
    } catch (_) {}
  }

  Future<void> setLocale(Locale locale) async {
    _selectionMade = true;
    state = locale;
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_localePreferenceKey, locale.languageCode);
    } catch (_) {}
  }
}

class RelayLocalizationsDelegate
    extends LocalizationsDelegate<RelayLocalizations> {
  const RelayLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => RelayLocalizations.supportedLocales.any(
    (supported) => supported.languageCode == locale.languageCode,
  );

  @override
  Future<RelayLocalizations> load(Locale locale) async =>
      RelayLocalizations(locale);

  @override
  bool shouldReload(RelayLocalizationsDelegate old) => false;
}
