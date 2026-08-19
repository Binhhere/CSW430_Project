import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:relay_av_demo/app/theme.dart';
import 'package:relay_av_demo/features/catalog/catalog_models.dart';
import 'package:relay_av_demo/features/transfers/transfer_models.dart';
import 'package:relay_av_demo/features/transfers/transfer_screens.dart';
import 'package:relay_av_demo/l10n/relay_localizations.dart';

void main() {
  testWidgets('Transit transfer row wraps long content at 360dp', (
    tester,
  ) async {
    final transfer = TransferRecord(
      id: 'transfer-1',
      companyId: 'company-1',
      customer: CustomerRecord(
        id: 'customer-1',
        name:
            'A6R International Convention and Exhibition Management Corporation',
        createdAt: DateTime(2026, 7, 22),
        activeTransferCount: 1,
      ),
      origin: LocationRecord(
        id: 'origin-1',
        name:
            'A6R Main Equipment Warehouse Rear Loading Dock and Service Entrance',
        type: LocationType.warehouse,
        createdAt: DateTime(2026, 7, 22),
      ),
      destination: LocationRecord(
        id: 'destination-1',
        name: 'A6R Grand Ballroom Level Three Convention Center East Wing',
        type: LocationType.deliveryPlace,
        createdAt: DateTime(2026, 7, 22),
      ),
      direction: TransferDirection.toCustomer,
      status: TransferStatus.inTransit,
      startDate: DateTime(2026, 7, 23),
      endDate: DateTime(2026, 7, 24),
      assignedStaffId: 'staff-1',
      assignedStaffName: 'Assigned staff',
      createdBy: 'user-1',
      reference:
          'A6R IN TRANSIT Long Status Badge Responsive Verification Reference',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: relayLightTheme(),
        localizationsDelegates: const [RelayLocalizations.delegate],
        supportedLocales: RelayLocalizations.supportedLocales,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 640),
            textScaler: TextScaler.linear(1),
          ),
          child: SizedBox(
            width: 360,
            child: Material(
              child: TransferListRow(transfer: transfer, onTap: () {}),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Transit'), findsOneWidget);
    expect(
      find.textContaining('A6R IN TRANSIT Long Status Badge'),
      findsOneWidget,
    );
    expect(
      find.textContaining('International Convention and Exhibition'),
      findsOneWidget,
    );
    expect(find.textContaining('Rear Loading Dock'), findsOneWidget);
    expect(find.textContaining('Grand Ballroom Level Three'), findsOneWidget);
    expect(
      tester
          .getSize(
            find.text(
              'A6R Main Equipment Warehouse Rear Loading Dock and Service Entrance',
            ),
          )
          .width,
      greaterThan(70),
    );
    expect(
      tester.getSize(find.byType(TransferListRow)).height,
      greaterThan(200),
    );
  });

  testWidgets('damage attention remains readable beside Done at 360dp', (
    tester,
  ) async {
    final transfer = TransferRecord(
      id: 'return-1',
      companyId: 'company-1',
      customer: CustomerRecord(
        id: 'customer-1',
        name: 'Long Customer Name for Damage Follow-up',
        createdAt: DateTime(2026, 7, 23),
        activeTransferCount: 0,
      ),
      origin: LocationRecord(
        id: 'origin-1',
        name: 'Convention Center Loading Dock',
        type: LocationType.deliveryPlace,
        createdAt: DateTime(2026, 7, 23),
      ),
      destination: LocationRecord(
        id: 'destination-1',
        name: 'Main Equipment Warehouse',
        type: LocationType.warehouse,
        createdAt: DateTime(2026, 7, 23),
      ),
      direction: TransferDirection.toWarehouse,
      status: TransferStatus.done,
      startDate: DateTime(2026, 7, 23),
      endDate: DateTime(2026, 7, 24),
      assignedStaffId: 'staff-1',
      assignedStaffName: 'Assigned staff',
      createdBy: 'user-1',
      reference: 'Completed Return With Damaged Equipment',
      damageCase: TransferDamageCase(
        transferId: 'return-1',
        status: TransferDamageStatus.open,
        updatedAt: DateTime(2026, 7, 23),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: relayLightTheme(),
        localizationsDelegates: const [RelayLocalizations.delegate],
        supportedLocales: RelayLocalizations.supportedLocales,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 640),
            textScaler: TextScaler.linear(1),
          ),
          child: SizedBox(
            width: 360,
            child: Material(
              child: TransferListRow(
                transfer: transfer,
                onTap: () {},
                onDamageTap: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Done'), findsOneWidget);
    expect(find.text('DAMAGED'), findsOneWidget);
    expect(find.textContaining('Completed Return'), findsOneWidget);
  });
}
