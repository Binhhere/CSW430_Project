import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:relay_av_demo/app/theme.dart';
import 'package:relay_av_demo/shared/ledger_widgets.dart';

void main() {
  testWidgets('ledger shell remains usable at enlarged text', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: relayLightTheme(),
        home: const MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2)),
          child: LedgerPage(
            title: 'Configuración de la empresa',
            child: SingleChildScrollView(
              child: Column(
                children: [
                  LedgerSection(
                    title: 'Account',
                    children: [
                      LedgerRow(
                        title:
                            'Centro Internacional de Convenciones de Nha Trang',
                        subtitle: 'Long Company identity remains readable.',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Configuración de la empresa'), findsOneWidget);
    expect(find.textContaining('Centro Internacional'), findsOneWidget);
  });

  testWidgets('ledger action strip wraps instead of overflowing on a phone', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: relayLightTheme(),
        home: const MediaQuery(
          data: MediaQueryData(
            size: Size(360, 640),
            textScaler: TextScaler.linear(1.3),
          ),
          child: Scaffold(
            body: LedgerActionStrip(
              children: [
                Chip(label: Text('All')),
                Chip(label: Text('Serialized')),
                Chip(label: Text('Bulk')),
                OutlinedButton(onPressed: null, child: Text('Scan asset')),
                FilledButton(onPressed: null, child: Text('New asset')),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Scan asset'), findsOneWidget);
    expect(find.text('New asset'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('app themes use their canonical primary action tokens', () {
    expect(
      relayLightTheme().colorScheme.primary,
      RelayColors.lightActionPrimary,
    );
    expect(relayDarkTheme().colorScheme.primary, RelayColors.darkActionPrimary);
  });

  testWidgets('team administration rows remain usable on a narrow phone', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: relayLightTheme(),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 760),
            textScaler: TextScaler.linear(1.3),
          ),
          child: LedgerPage(
            title: 'Team',
            child: ListView(
              children: [
                LedgerSection(
                  title: 'Current team',
                  children: [
                    LedgerRow(
                      leading: const CircleAvatar(child: Text('A')),
                      title:
                          'Alexandra Montgomery Event Production Coordinator',
                      subtitle: 'Staff · Tap to manage',
                      trailing: const Icon(Icons.person_remove_outlined),
                      onTap: () {},
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.textContaining('Alexandra Montgomery'), findsOneWidget);
    expect(find.byIcon(Icons.person_remove_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
