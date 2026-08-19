import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/access/access_flow.dart';
import '../l10n/relay_localizations.dart';
import 'theme.dart';
import 'theme_controller.dart';
import 'relay_ui.dart';

Widget _systemUiBuilder(BuildContext context, Widget? child) {
  final brightness = Theme.of(context).brightness;
  final iconBrightness = brightness == Brightness.dark
      ? Brightness.light
      : Brightness.dark;

  return AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarBrightness: brightness,
      statusBarIconBrightness: iconBrightness,
      systemNavigationBarIconBrightness: iconBrightness,
    ),
    child: child ?? const SizedBox.shrink(),
  );
}

class RelayAvApp extends ConsumerWidget {
  const RelayAvApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Etrelay: Rental Operations',
      debugShowCheckedModeBanner: false,
      theme: relayLightTheme(),
      darkTheme: relayDarkTheme(),
      themeMode: ref.watch(themeModeProvider),
      builder: _systemUiBuilder,
      locale: ref.watch(relayLocaleProvider),
      supportedLocales: RelayLocalizations.supportedLocales,
      localizationsDelegates: const [
        RelayLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      onGenerateRoute: (settings) {
        if (settings.name?.startsWith('/auth/callback') ?? false) {
          return RelayPageRoute<void>(
            settings: settings,
            builder: (_) => const AccessSessionGate(),
          );
        }
        return null;
      },
      home: const AccessSessionGate(),
    );
  }
}
