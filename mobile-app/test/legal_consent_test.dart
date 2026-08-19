import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relay_av_demo/app/theme.dart';
import 'package:relay_av_demo/features/access/legal_consent.dart';
import 'package:relay_av_demo/l10n/relay_localizations.dart';

void main() {
  testWidgets(
    'legal consent keeps continuation disabled until both are checked',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: relayLightTheme(),
          localizationsDelegates: const [RelayLocalizations.delegate],
          supportedLocales: RelayLocalizations.supportedLocales,
          home: LegalConsentPage(onAccepted: () async {}),
        ),
      );
      await tester.pump();

      expect(find.text('Before you continue'), findsOneWidget);
      var continueButton = tester.widget<FilledButton>(
        find.byType(FilledButton).last,
      );
      expect(continueButton.onPressed, isNull);

      await tester.tap(find.byType(Checkbox).at(0));
      await tester.pump();
      continueButton = tester.widget<FilledButton>(
        find.byType(FilledButton).last,
      );
      expect(continueButton.onPressed, isNull);

      await tester.tap(find.byType(Checkbox).at(1));
      await tester.pump();
      continueButton = tester.widget<FilledButton>(
        find.byType(FilledButton).last,
      );
      expect(continueButton.onPressed, isNotNull);
    },
  );
}
