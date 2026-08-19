import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relay_av_demo/app/theme.dart';
import 'package:relay_av_demo/features/catalog/catalog_models.dart';
import 'package:relay_av_demo/features/catalog/catalog_screens.dart';
import 'package:relay_av_demo/l10n/relay_localizations.dart';

Widget _app(Widget child) => ProviderScope(
  child: MaterialApp(
    theme: relayLightTheme(),
    locale: const Locale('en'),
    localizationsDelegates: const [RelayLocalizations.delegate],
    supportedLocales: RelayLocalizations.supportedLocales,
    home: child,
  ),
);

void main() {
  test('Customer and Location records preserve backend pagination fields', () {
    final customer = CustomerRecord.fromMap({
      'id': 'customer-1',
      'name': 'Northstar Events',
      'phone': '555-0100',
      'created_at': '2026-07-17T00:00:00.000Z',
      'active_transfer_count': 3,
    });
    final location = LocationRecord.fromMap({
      'id': 'location-1',
      'name': 'Main Warehouse',
      'type': 'WAREHOUSE',
      'created_at': '2026-07-17T00:00:00.000Z',
    });

    expect(customer.activeTransferCount, 3);
    expect(customer.phone, '555-0100');
    expect(location.type, LocationType.warehouse);
  });

  testWidgets('Customer create is a dedicated validated page', (tester) async {
    await tester.pumpWidget(
      _app(const CustomerFormPage(companyId: 'company-1')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save customer'));
    await tester.pump();

    expect(find.text('Create customer'), findsOneWidget);
    expect(find.text('Enter a name.'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(4));
  });

  testWidgets('Customer form protects unsaved edits on back', (tester) async {
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      const CustomerFormPage(companyId: 'company-1'),
                ),
              ),
              child: const Text('Open customer form'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open customer form'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'Northstar');
    await tester.pump();
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Discard unsaved changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('Create customer'), findsOneWidget);
  });

  testWidgets('Location form has only name and type fields', (tester) async {
    await tester.pumpWidget(
      _app(const LocationFormPage(companyId: 'company-1')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Create location'), findsOneWidget);
    expect(find.byType(TextFormField), findsOneWidget);
    expect(
      find.widgetWithText(RadioListTile<LocationType>, 'Warehouse'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(RadioListTile<LocationType>, 'Delivery place'),
      findsOneWidget,
    );
    expect(find.text('Customer'), findsNothing);
  });
}
