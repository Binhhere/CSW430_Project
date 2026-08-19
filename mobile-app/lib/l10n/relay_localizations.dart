import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'relay_locale_controller.dart';
import 'relay_localizations_en.dart';
import 'relay_localizations_es.dart';
import 'relay_localizations_ja.dart';

export 'relay_locale_controller.dart';

class RelayLocalizations {
  RelayLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = [Locale('en'), Locale('es'), Locale('ja')];
  static const delegate = RelayLocalizationsDelegate();

  static bool isSupportedLanguage(String languageCode) =>
      supportedLocales.any((locale) => locale.languageCode == languageCode);

  static List<String> missingTranslationKeys(String languageCode) {
    final translation = _strings[languageCode] ?? const <String, String>{};
    return [
      for (final key in _strings['en']!.keys)
        if (!translation.containsKey(key)) key,
    ];
  }

  static RelayLocalizations of(BuildContext context) =>
      Localizations.of<RelayLocalizations>(context, RelayLocalizations)!;

  String text(String key) =>
      (_strings[locale.languageCode] ?? _strings['en'])![key] ??
      (_strings['en']![key] ?? key);

  String date(DateTime value) =>
      DateFormat.yMMMd(locale.languageCode).format(value);

  String number(num value) =>
      NumberFormat.decimalPattern(locale.languageCode).format(value);

  static const _strings = <String, Map<String, String>>{
    'en': relayEnglishStrings,
    'es': relaySpanishStrings,
    'ja': relayJapaneseStrings,
  };
}

extension RelayLocalizationsContext on BuildContext {
  RelayLocalizations get l10n => RelayLocalizations.of(this);
}
