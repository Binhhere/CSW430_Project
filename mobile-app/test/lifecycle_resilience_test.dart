import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:relay_av_demo/app/theme.dart';
import 'package:relay_av_demo/features/access/access_flow.dart';
import 'package:relay_av_demo/features/access/access_models.dart';
import 'package:relay_av_demo/features/access/access_repository.dart';
import 'package:relay_av_demo/features/assets/asset_domain.dart';
import 'package:relay_av_demo/features/catalog/catalog_models.dart';
import 'package:relay_av_demo/features/catalog/catalog_repository.dart';
import 'package:relay_av_demo/features/catalog/catalog_screens.dart';
import 'package:relay_av_demo/features/transfers/transfer_evidence_repository.dart';
import 'package:relay_av_demo/features/transfers/transfer_evidence_models.dart';
import 'package:relay_av_demo/features/transfers/transfer_evidence_screen.dart';
import 'package:relay_av_demo/features/transfers/transfer_models.dart';
import 'package:relay_av_demo/l10n/relay_localizations.dart';
import 'package:relay_av_demo/shared/async_ui_controller.dart';
import 'package:relay_av_demo/shared/request_timeout.dart';
import 'package:relay_av_demo/data/local_backend_compat.dart';

Widget _app(Widget child) => MaterialApp(
  theme: relayLightTheme(),
  localizationsDelegates: const [RelayLocalizations.delegate],
  supportedLocales: RelayLocalizations.supportedLocales,
  home: child,
);

void main() {
  test('network deadline fails a request that never completes', () async {
    await expectLater(
      withRelayRequestTimeout(
        Completer<void>().future,
        timeout: const Duration(milliseconds: 1),
      ),
      throwsA(isA<TimeoutException>()),
    );
  });

  test('latest request gate rejects an older completion', () {
    final gate = LatestRequestGate();
    final first = gate.begin();
    final second = gate.begin();

    expect(gate.isCurrent(first), isFalse);
    expect(gate.isCurrent(second), isTrue);

    gate.invalidate();
    expect(gate.isCurrent(second), isFalse);
  });

  testWidgets('password recovery form stays usable with the keyboard open', (
    tester,
  ) async {
    final repository = _PasswordRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [accessRepositoryProvider.overrideWithValue(repository)],
        child: MediaQuery(
          data: const MediaQueryData(viewInsets: EdgeInsets.only(bottom: 420)),
          child: _app(const UpdatePasswordPage()),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Save password'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'password123');
    await tester.scrollUntilVisible(
      find.text('Save password'),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Save password'));
    await tester.pumpAndSettle();

    expect(repository.updateCalls, 1);
    expect(repository.signOutCalls, 1);
    expect(find.text('Password updated successfully.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('company-scoped key replaces state when Company changes', (
    tester,
  ) async {
    final company = ValueNotifier('company-a');
    addTearDown(company.dispose);

    await tester.pumpWidget(
      MaterialApp(home: _CompanyKeyHost(company: company)),
    );
    await tester.tap(find.text('Increment'));
    await tester.pump();
    expect(find.text('Count 1'), findsOneWidget);

    company.value = 'company-b';
    await tester.pump();

    expect(companyShellKey('company-a'), isNot(companyShellKey('company-b')));
    expect(
      companyContentKey('transfers', 'company-a', 0),
      isNot(companyContentKey('transfers', 'company-b', 0)),
    );
    expect(find.text('Count 0'), findsOneWidget);
  });

  testWidgets('resume refreshes are coalesced while one is running', (
    tester,
  ) async {
    final release = Completer<void>();
    await tester.pumpWidget(MaterialApp(home: _ResumeProbe(release.future)));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('Refreshes 1'), findsOneWidget);

    release.complete();
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('Refreshes 2'), findsOneWidget);
  });

  testWidgets('failed resume refresh is contained and can be retried', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: _FailingResumeProbe()));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(find.text('Refreshes 1'), findsOneWidget);
    expect(tester.takeException(), isNull);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(find.text('Refreshes 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('newer Customer detail request wins over an older completion', (
    tester,
  ) async {
    final repository = _StaleCatalogRepository();
    final initial = CustomerRecord(
      id: 'customer-1',
      name: 'Initial Customer',
      createdAt: DateTime(2026, 7, 24),
      activeTransferCount: 0,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [catalogRepositoryProvider.overrideWithValue(repository)],
        child: _app(
          CustomerDetailPage(
            companyId: 'company-a',
            customerId: initial.id,
            initial: initial,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(repository.customerCalls, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(repository.customerCalls, 2);

    repository.completeSecond('New Customer');
    await tester.pump();
    await tester.pump();
    expect(find.text('New Customer'), findsOneWidget);

    repository.completeFirst('Old Customer');
    await tester.pump();
    await tester.pump();
    expect(find.text('New Customer'), findsOneWidget);
    expect(find.text('Old Customer'), findsNothing);
  });

  testWidgets('Customer Save is single-flight and blocks Back until complete', (
    tester,
  ) async {
    final repository = _DeferredCatalogRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [catalogRepositoryProvider.overrideWithValue(repository)],
        child: _app(
          Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<CustomerRecord>(
                    builder: (_) =>
                        const CustomerFormPage(companyId: 'company-a'),
                  ),
                ),
                child: const Text('Open form'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open form'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).first,
      'Northstar Events',
    );
    await tester.tap(find.text('Save customer'));
    await tester.tap(find.text('Save customer'));
    await tester.pump();

    expect(repository.saveCalls, 1);
    await tester.pageBack();
    await tester.pump();
    expect(find.text('Create customer'), findsOneWidget);

    repository.completeSave();
    await tester.pumpAndSettle();
    expect(find.text('Open form'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('detail refresh failure keeps the last confirmed Customer', (
    tester,
  ) async {
    final repository = _RefreshingCatalogRepository();
    final initial = CustomerRecord(
      id: 'customer-1',
      name: 'Initial Customer',
      createdAt: DateTime(2026, 7, 24),
      activeTransferCount: 0,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [catalogRepositoryProvider.overrideWithValue(repository)],
        child: _app(
          CustomerDetailPage(
            companyId: 'company-a',
            customerId: initial.id,
            initial: initial,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Confirmed Customer'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, 300));
    await tester.pumpAndSettle();

    expect(find.text('Confirmed Customer'), findsOneWidget);
    expect(find.text('We could not load this information.'), findsOneWidget);
  });

  testWidgets('successful Evidence upload reloads the visible photo list', (
    tester,
  ) async {
    final repository = _EvidenceRepository();
    final fixture = _transferFixture();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transferEvidenceRepositoryProvider.overrideWithValue(repository),
        ],
        child: _app(
          TransferEvidencePage(
            company: const RelayCompany(
              id: 'company-a',
              name: 'Company A',
              role: CompanyRole.owner,
            ),
            transfer: fixture,
            phase: EvidencePhase.departure,
            allowCapture: true,
            pickImage: (_) async => XFile.fromData(
              Uint8List.fromList(const [1, 2, 3]),
              mimeType: 'image/jpeg',
              name: 'evidence.jpg',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('0 of 7 photos'), findsOneWidget);
    await tester.tap(find.text('Add photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose from gallery'));
    await tester.pumpAndSettle();

    expect(repository.uploadCalls, 1);
    expect(repository.listCalls, greaterThanOrEqualTo(2));
    expect(find.text('1 of 7 photos'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _CompanyKeyHost extends StatelessWidget {
  const _CompanyKeyHost({required this.company});

  final ValueNotifier<String> company;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String>(
    valueListenable: company,
    builder: (context, companyId, _) => KeyedSubtree(
      key: companyShellKey(companyId),
      child: const _CounterProbe(),
    ),
  );
}

class _PasswordRepository extends AccessRepository {
  _PasswordRepository() : super(_testBackendClient(), 'https://example.com');

  var updateCalls = 0;
  var signOutCalls = 0;

  @override
  Future<void> updatePassword(String password) async {
    updateCalls++;
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
  }
}

class _CounterProbe extends StatefulWidget {
  const _CounterProbe();

  @override
  State<_CounterProbe> createState() => _CounterProbeState();
}

class _CounterProbeState extends State<_CounterProbe> {
  var _count = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        Text('Count $_count'),
        FilledButton(
          onPressed: () => setState(() => _count++),
          child: const Text('Increment'),
        ),
      ],
    ),
  );
}

class _ResumeProbe extends StatefulWidget {
  const _ResumeProbe(this.release);

  final Future<void> release;

  @override
  State<_ResumeProbe> createState() => _ResumeProbeState();
}

class _ResumeProbeState extends State<_ResumeProbe>
    with AppResumeRefreshMixin<_ResumeProbe> {
  var _refreshes = 0;

  @override
  Future<void> refreshAfterAppResume() async {
    setState(() => _refreshes++);
    await widget.release;
  }

  @override
  Widget build(BuildContext context) => Text('Refreshes $_refreshes');
}

class _FailingResumeProbe extends StatefulWidget {
  const _FailingResumeProbe();

  @override
  State<_FailingResumeProbe> createState() => _FailingResumeProbeState();
}

class _FailingResumeProbeState extends State<_FailingResumeProbe>
    with AppResumeRefreshMixin<_FailingResumeProbe> {
  var _refreshes = 0;

  @override
  Future<void> refreshAfterAppResume() async {
    setState(() => _refreshes++);
    throw StateError('offline');
  }

  @override
  Widget build(BuildContext context) => Text('Refreshes $_refreshes');
}

LocalBackendClient _testBackendClient() =>
    LocalBackendClient('http://localhost', 'test-key');

class _StaleCatalogRepository extends CatalogRepository {
  _StaleCatalogRepository() : super(_testBackendClient());

  final _first = Completer<CustomerRecord?>();
  final _second = Completer<CustomerRecord?>();
  var customerCalls = 0;

  @override
  Future<CustomerRecord?> customer(String companyId, String customerId) {
    customerCalls++;
    return customerCalls == 1 ? _first.future : _second.future;
  }

  void completeFirst(String name) => _first.complete(_customer(name));

  void completeSecond(String name) => _second.complete(_customer(name));

  CustomerRecord _customer(String name) => CustomerRecord(
    id: 'customer-1',
    name: name,
    createdAt: DateTime(2026, 7, 24),
    activeTransferCount: 0,
  );
}

class _DeferredCatalogRepository extends CatalogRepository {
  _DeferredCatalogRepository() : super(_testBackendClient());

  final _save = Completer<CustomerRecord>();
  var saveCalls = 0;

  @override
  Future<CustomerRecord> saveCustomer({
    required String companyId,
    String? customerId,
    required String name,
    String? contactName,
    String? email,
    String? phone,
  }) {
    saveCalls++;
    return _save.future;
  }

  void completeSave() {
    _save.complete(
      CustomerRecord(
        id: 'customer-1',
        name: 'Northstar Events',
        createdAt: DateTime(2026, 7, 24),
        activeTransferCount: 0,
      ),
    );
  }
}

class _RefreshingCatalogRepository extends CatalogRepository {
  _RefreshingCatalogRepository() : super(_testBackendClient());

  var customerCalls = 0;

  @override
  Future<CustomerRecord?> customer(String companyId, String customerId) async {
    customerCalls++;
    if (customerCalls > 1) throw StateError('refresh failed');
    return CustomerRecord(
      id: customerId,
      name: 'Confirmed Customer',
      createdAt: DateTime(2026, 7, 24),
      activeTransferCount: 0,
    );
  }
}

class _EvidenceRepository extends TransferEvidenceRepository {
  _EvidenceRepository() : super(_testBackendClient());

  final records = <TransferEvidenceRecord>[];
  var listCalls = 0;
  var uploadCalls = 0;

  @override
  Future<List<TransferEvidenceRecord>> list({
    required String transferId,
    required EvidencePhase phase,
    TransferEvidenceRecord? after,
  }) async {
    listCalls++;
    return List<TransferEvidenceRecord>.of(records);
  }

  @override
  Future<void> upload({
    required String companyId,
    required String transferId,
    required String lineId,
    required EvidencePhase phase,
    required Uint8List bytes,
    String? evidenceId,
  }) async {
    uploadCalls++;
    records.add(
      TransferEvidenceRecord(
        id: 'evidence-$uploadCalls',
        lineId: lineId,
        assetName: 'Wireless Mic',
        storagePath: 'full.jpg',
        thumbnailPath: 'thumb.png',
        createdAt: DateTime(2026, 7, 24),
      ),
    );
  }

  @override
  Future<Uint8List> thumbnailBytes(
    TransferEvidenceRecord evidence,
  ) async => base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
  );
}

TransferRecord _transferFixture() {
  final asset = TransferAssetSummary(
    id: 'asset-1',
    mode: AssetMode.serialized,
    name: 'Wireless Mic',
    serialNumber: 'WM-001',
    quantity: null,
    locationId: 'warehouse-1',
  );
  return TransferRecord(
    id: 'transfer-1',
    companyId: 'company-a',
    customer: CustomerRecord(
      id: 'customer-1',
      name: 'Northstar Events',
      createdAt: DateTime(2026, 7, 24),
      activeTransferCount: 1,
    ),
    origin: LocationRecord(
      id: 'warehouse-1',
      name: 'Main Warehouse',
      type: LocationType.warehouse,
      createdAt: DateTime(2026, 7, 24),
    ),
    destination: LocationRecord(
      id: 'venue-1',
      name: 'Convention Hall',
      type: LocationType.deliveryPlace,
      createdAt: DateTime(2026, 7, 24),
    ),
    direction: TransferDirection.toCustomer,
    status: TransferStatus.prepare,
    startDate: DateTime(2026, 7, 24),
    endDate: DateTime(2026, 7, 25),
    assignedStaffId: 'staff-1',
    createdBy: 'owner-1',
    lines: [
      TransferLineRecord(
        id: 'line-1',
        asset: asset,
        requested: 1,
        dispatched: 0,
        received: 0,
        damaged: 0,
      ),
    ],
  );
}
