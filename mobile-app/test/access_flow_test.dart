import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:relay_av_demo/app/theme.dart';
import 'package:relay_av_demo/features/access/access_flow.dart';
import 'package:relay_av_demo/features/access/access_models.dart';
import 'package:relay_av_demo/features/access/access_repository.dart';
import 'package:relay_av_demo/features/transfers/transfer_models.dart';
import 'package:relay_av_demo/features/transfers/transfer_repository.dart';
import 'package:relay_av_demo/l10n/relay_localizations.dart';
import 'package:relay_av_demo/shared/ledger_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:relay_av_demo/data/local_backend_compat.dart';

Widget _app(
  Widget child, {
  Locale locale = const Locale('en'),
  bool disableAnimations = true,
}) => MaterialApp(
  locale: locale,
  theme: relayLightTheme(),
  localizationsDelegates: const [
    RelayLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: RelayLocalizations.supportedLocales,
  home: disableAnimations
      ? MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: child,
        )
      : child,
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    debugBundledAnnouncementsOverride = const [];
    debugBundledAnnouncementsNow = () => DateTime.utc(2026, 7, 30, 12);
  });

  tearDown(() {
    debugBundledAnnouncementsOverride = null;
    debugBundledAnnouncementsNow = () => DateTime.now().toUtc();
  });

  testWidgets('Company Gateway exposes account deletion without a Company', (
    tester,
  ) async {
    final repository = _FakeAccessRepository();
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [accessRepositoryProvider.overrideWithValue(repository)],
        child: _app(const CompanyGateway(companies: [])),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Create company'), findsOneWidget);
    expect(find.text('Join company'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Delete account'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Delete account'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Company Gateway hides account deletion with a Company', (
    tester,
  ) async {
    final repository = _FakeAccessRepository();
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [accessRepositoryProvider.overrideWithValue(repository)],
        child: _app(
          const CompanyGateway(
            companies: [
              RelayCompany(
                id: 'company-1',
                name: 'Relay Smoke Alpha',
                role: CompanyRole.owner,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Delete account'), findsNothing);
    expect(find.text('Create another company'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Company Gateway shows announcement badge and clears it after seen all',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      debugBundledAnnouncementsOverride = const [];
      debugBundledAnnouncementsNow = () => DateTime.utc(2026, 7, 30, 12);
      addTearDown(() {
        debugBundledAnnouncementsOverride = null;
        debugBundledAnnouncementsNow = () => DateTime.now().toUtc();
      });
      final repository = _FakeAccessRepository()
        ..developerAnnouncementList = [
          DeveloperAnnouncement(
            id: 'announcement-1',
            announcementKey: 'beta-capacity',
            titleEn: 'Beta limits updated',
            bodyEn: 'Company limits were updated for beta testing.',
            titleEs: 'Límites beta actualizados',
            bodyEs:
                'Los límites de la empresa se actualizaron para las pruebas beta.',
            titleJa: 'ベータ版の上限を更新しました',
            bodyJa: 'ベータテストのため会社の上限を更新しました。',
            publishedAt: DateTime(2026, 7, 28),
            expiresAt: null,
            seenAt: null,
            isUnread: true,
          ),
        ]
        ..developerAnnouncementStatusValue = const DeveloperAnnouncementStatus(
          unreadCount: 1,
          totalCount: 1,
        );
      addTearDown(repository.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [accessRepositoryProvider.overrideWithValue(repository)],
          child: _app(
            const CompanyGateway(
              companies: [
                RelayCompany(
                  id: 'company-1',
                  name: 'Relay Smoke Alpha',
                  role: CompanyRole.owner,
                ),
              ],
            ),
            disableAnimations: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.notifications_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Beta limits updated'), findsOneWidget);
      expect(find.text('Seen all'), findsOneWidget);

      await tester.tap(find.text('Seen all'));
      await tester.pumpAndSettle();

      expect(repository.markAllDeveloperAnnouncementsSeenCalls, 1);
      expect(find.text('Seen all'), findsNothing);
      expect(find.text('1'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Seen all leaves future bundled announcements unread until they are published',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      debugBundledAnnouncementsOverride = [
        DeveloperAnnouncement(
          id: 'bundled:current',
          announcementKey: 'bundled_current',
          titleEn: 'Current bundled announcement',
          bodyEn: 'Visible right now.',
          titleEs: 'Anuncio integrado actual',
          bodyEs: 'Visible ahora mismo.',
          titleJa: '現在のバンドル済みお知らせ',
          bodyJa: '現在表示されています。',
          publishedAt: DateTime.utc(2026, 7, 30, 12),
          expiresAt: null,
          seenAt: null,
          isUnread: true,
        ),
        DeveloperAnnouncement(
          id: 'bundled:future',
          announcementKey: 'bundled_future',
          titleEn: 'Future bundled announcement',
          bodyEn: 'Visible later.',
          titleEs: 'Anuncio integrado futuro',
          bodyEs: 'Visible mas tarde.',
          titleJa: '今後のバンドル済みお知らせ',
          bodyJa: '後で表示されます。',
          publishedAt: DateTime.utc(2026, 8, 1, 12),
          expiresAt: null,
          seenAt: null,
          isUnread: true,
        ),
      ];
      debugBundledAnnouncementsNow = () => DateTime.utc(2026, 7, 31, 12);
      addTearDown(() {
        debugBundledAnnouncementsOverride = null;
        debugBundledAnnouncementsNow = () => DateTime.now().toUtc();
      });
      final repository = _FakeAccessRepository()
        ..developerAnnouncementStatusValue = const DeveloperAnnouncementStatus(
          unreadCount: 0,
          totalCount: 0,
        );
      addTearDown(repository.dispose);
      var gatewayPumpCount = 0;

      Future<void> pumpGateway() async {
        await tester.pumpWidget(
          ProviderScope(
            key: ValueKey('gateway-scope-${gatewayPumpCount++}'),
            overrides: [accessRepositoryProvider.overrideWithValue(repository)],
            child: _app(
              const CompanyGateway(
                companies: [
                  RelayCompany(
                    id: 'company-1',
                    name: 'Relay Smoke Alpha',
                    role: CompanyRole.owner,
                  ),
                ],
              ),
              disableAnimations: true,
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await pumpGateway();

      await tester.tap(find.byIcon(Icons.notifications_outlined));
      await tester.pumpAndSettle();

      await _pumpUntilVisible(
        tester,
        find.text('Current bundled announcement'),
      );
      expect(find.text('Future bundled announcement'), findsNothing);

      await tester.tap(find.text('Seen all'));
      await tester.pumpAndSettle();

      debugBundledAnnouncementsNow = () => DateTime.utc(2026, 8, 2, 12);
      await pumpGateway();

      await tester.tap(find.byIcon(Icons.notifications_outlined));
      await tester.pumpAndSettle();
      await _pumpUntilVisible(tester, find.text('Future bundled announcement'));
      await _pumpUntilVisible(tester, find.text('Seen all'));
      final preferences = await SharedPreferences.getInstance();
      final seenKeys =
          preferences.getStringList(
            'relay_bundled_announcement_seen_keys_v1:user-1',
          ) ??
          const <String>[];
      expect(seenKeys, contains('bundled_current'));
      expect(seenKeys, isNot(contains('bundled_future')));
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'announcement provider keeps remote as canonical for duplicate keys',
    () async {
      debugBundledAnnouncementsOverride = [
        _announcement(
          id: 'bundled:beta-capacity',
          announcementKey: 'beta-capacity',
          titleEn: 'Bundled copy',
          publishedAt: DateTime.utc(2026, 7, 29),
        ),
      ];
      final repository = _FakeAccessRepository()
        ..developerAnnouncementList = [
          _announcement(
            id: 'remote-beta-capacity',
            announcementKey: 'beta-capacity',
            titleEn: 'Remote canonical copy',
            publishedAt: DateTime.utc(2026, 7, 30),
          ),
        ]
        ..developerAnnouncementStatusValue = const DeveloperAnnouncementStatus(
          unreadCount: 1,
          totalCount: 1,
        );
      addTearDown(repository.dispose);
      final container = ProviderContainer(
        overrides: [accessRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final items = await container.read(developerAnnouncementsProvider.future);

      expect(items, hasLength(1));
      expect(items.single.id, 'remote-beta-capacity');
      expect(items.single.titleEn, 'Remote canonical copy');
    },
  );

  test(
    'announcement status counts duplicate logical announcements once',
    () async {
      final cases = [
        (bundledSeen: false, remoteUnread: true, expectedUnread: 1),
        (bundledSeen: true, remoteUnread: true, expectedUnread: 1),
        (bundledSeen: false, remoteUnread: false, expectedUnread: 0),
      ];

      for (final testCase in cases) {
        SharedPreferences.setMockInitialValues(
          testCase.bundledSeen
              ? {
                  'relay_bundled_announcement_seen_keys_v1:user-1': [
                    'shared-key',
                  ],
                }
              : {},
        );
        debugBundledAnnouncementsOverride = [
          _announcement(
            id: 'bundled:shared-key',
            announcementKey: 'shared-key',
            titleEn: 'Bundled announcement',
          ),
        ];
        final repository = _FakeAccessRepository()
          ..developerAnnouncementList = [
            _announcement(
              id: 'remote-shared-key',
              announcementKey: 'shared-key',
              titleEn: 'Remote announcement',
              isUnread: testCase.remoteUnread,
            ),
          ]
          ..developerAnnouncementStatusValue = DeveloperAnnouncementStatus(
            unreadCount: testCase.remoteUnread ? 1 : 0,
            totalCount: 1,
          );
        addTearDown(repository.dispose);
        final container = ProviderContainer(
          overrides: [accessRepositoryProvider.overrideWithValue(repository)],
        );
        addTearDown(container.dispose);

        final status = await container.read(
          developerAnnouncementStatusProvider.future,
        );

        expect(status.totalCount, 1);
        expect(status.unreadCount, testCase.expectedUnread);
      }
    },
  );

  test('announcement provider keeps distinct keys from both sources', () async {
    debugBundledAnnouncementsOverride = [
      _announcement(
        id: 'bundled:limits',
        announcementKey: 'limits',
        titleEn: 'Bundled limits',
      ),
    ];
    final repository = _FakeAccessRepository()
      ..developerAnnouncementList = [
        _announcement(
          id: 'remote-maintenance',
          announcementKey: 'maintenance',
          titleEn: 'Remote maintenance',
        ),
      ]
      ..developerAnnouncementStatusValue = const DeveloperAnnouncementStatus(
        unreadCount: 1,
        totalCount: 1,
      );
    addTearDown(repository.dispose);
    final container = ProviderContainer(
      overrides: [accessRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final items = await container.read(developerAnnouncementsProvider.future);

    expect(items.map((item) => item.announcementKey), {
      'limits',
      'maintenance',
    });
  });

  testWidgets('failed remote Seen all does not persist bundled seen state', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    debugBundledAnnouncementsOverride = [
      _announcement(
        id: 'bundled:local-only',
        announcementKey: 'local-only',
        titleEn: 'Local-only announcement',
      ),
    ];
    final repository = _FakeAccessRepository()
      ..developerAnnouncementList = [
        _announcement(
          id: 'remote-only',
          announcementKey: 'remote-only',
          titleEn: 'Remote-only announcement',
        ),
      ]
      ..developerAnnouncementStatusValue = const DeveloperAnnouncementStatus(
        unreadCount: 1,
        totalCount: 1,
      )
      ..failMarkAllDeveloperAnnouncementsSeen = true;
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [accessRepositoryProvider.overrideWithValue(repository)],
        child: _app(
          const CompanyGateway(
            companies: [
              RelayCompany(
                id: 'company-1',
                name: 'Relay Smoke Alpha',
                role: CompanyRole.owner,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.notifications_outlined));
    await tester.pumpAndSettle();
    await _pumpUntilVisible(tester, find.text('Seen all'));

    await tester.tap(find.text('Seen all'));
    await tester.pumpAndSettle();

    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getStringList(
        'relay_bundled_announcement_seen_keys_v1:user-1',
      ),
      isNull,
    );
    expect(find.text('Seen all'), findsOneWidget);
    expect(
      find.text('We could not mark these announcements as seen. Try again.'),
      findsOneWidget,
    );
  });

  testWidgets('legal acceptance is resolved again when the user changes', (
    tester,
  ) async {
    final repository = _FakeAccessRepository()..legalAccepted = true;
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [accessRepositoryProvider.overrideWithValue(repository)],
        child: _app(const AccessSessionGate()),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.legalAcceptanceChecks, 1);
    expect(find.text('Create company'), findsOneWidget);

    repository
      ..legalAccepted = false
      ..emitSignedIn('user-2');
    await tester.pumpAndSettle();

    expect(repository.legalAcceptanceChecks, 2);
    expect(find.text('Before you continue'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Create Company returns its id to the parent route', (
    tester,
  ) async {
    final repository = _FakeAccessRepository();
    addTearDown(repository.dispose);
    String? result;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [accessRepositoryProvider.overrideWithValue(repository)],
        child: _app(
          Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                result = await Navigator.of(context).push<String>(
                  MaterialPageRoute(builder: (_) => const CreateCompanyPage()),
                );
              },
              child: const Text('Open create'),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Open create'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Relay Smoke Beta');
    await tester.tap(find.widgetWithText(BusyButton, 'Create company'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(result, 'company-2');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Join Company returns its id to the parent route', (
    tester,
  ) async {
    final repository = _FakeAccessRepository()
      ..invitationPreview = InvitationPreview(
        workspaceId: 'company-3',
        companyName: 'Relay Smoke Gamma',
        expiresAt: DateTime(2026, 8, 1),
      );
    addTearDown(repository.dispose);
    String? result;
    await initializeDateFormatting('en');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [accessRepositoryProvider.overrideWithValue(repository)],
        child: _app(
          Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                result = await Navigator.of(context).push<String>(
                  MaterialPageRoute(builder: (_) => const JoinCompanyPage()),
                );
              },
              child: const Text('Open join'),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Open join'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'ABCD-1234');
    await tester.tap(find.widgetWithText(BusyButton, 'Review invitation'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(BusyButton, 'Join company'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(result, 'company-3');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Account settings does not expose account deletion', (
    tester,
  ) async {
    final repository = _FakeAccessRepository();
    repository.completeNextProfile('Initial profile');
    addTearDown(repository.dispose);

    await _openAccount(tester, repository);

    expect(
      find.descendant(
        of: find.byType(AccountPage),
        matching: find.text('Delete account'),
      ),
      findsNothing,
    );
  });

  testWidgets('embedded Settings omits the redundant page header', (
    tester,
  ) async {
    final repository = _FakeAccessRepository();
    repository.completeNextProfile('Initial profile');
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [accessRepositoryProvider.overrideWithValue(repository)],
        child: _app(const AccountPage(embedded: true)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsNothing);
    expect(find.text('Initial profile'), findsOneWidget);
    expect(find.text('Delete account'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Company shell exposes Settings in the five-item phone bar', (
    tester,
  ) async {
    final repository = _FakeAccessRepository()
      ..completeNextProfile('Initial profile');
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accessRepositoryProvider.overrideWithValue(repository),
          activeCompanyIdProvider.overrideWith((_) => 'company-1'),
          transferRepositoryProvider.overrideWithValue(
            _NavigationTransferRepository(),
          ),
        ],
        child: _app(
          SizedBox(
            width: 390,
            child: MediaQuery(
              data: const MediaQueryData(
                size: Size(390, 844),
                disableAnimations: true,
              ),
              child: const CompanyShell(
                company: RelayCompany(
                  id: 'company-1',
                  name: 'Relay Smoke Alpha',
                  role: CompanyRole.owner,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.byType(AccountPage), findsOneWidget);
    expect(find.text('Initial profile'), findsOneWidget);
    expect(find.text('Change company'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Company shell exposes Settings in the five-item tablet rail', (
    tester,
  ) async {
    final repository = _FakeAccessRepository()
      ..completeNextProfile('Initial profile');
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accessRepositoryProvider.overrideWithValue(repository),
          activeCompanyIdProvider.overrideWith((_) => 'company-1'),
          transferRepositoryProvider.overrideWithValue(
            _NavigationTransferRepository(),
          ),
        ],
        child: _app(
          SizedBox(
            width: 800,
            child: MediaQuery(
              data: const MediaQueryData(
                size: Size(800, 900),
                disableAnimations: true,
              ),
              child: const CompanyShell(
                company: RelayCompany(
                  id: 'company-1',
                  name: 'Relay Smoke Alpha',
                  role: CompanyRole.owner,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final label in [
      'Transfer',
      'Customer',
      'Location',
      'Asset',
      'Settings',
    ]) {
      expect(find.text(label), findsWidgets);
    }
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.byType(AccountPage), findsOneWidget);
    expect(find.text('Initial profile'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('successful account deletion returns to Auth', (tester) async {
    final repository = _FakeAccessRepository();
    repository.completeNextProfile('Initial profile');
    repository.deletionPreview = const AccountDeletionPreview(
      action: DeletionAction.deleteNow,
      reasons: [],
      companyCount: 0,
    );
    repository.deletionResult = const AccountDeletionResult(
      action: DeletionAction.deleted,
    );
    final signOut = repository.addSignOutRequest();
    addTearDown(() {
      if (!signOut.isCompleted) signOut.complete();
      repository.dispose();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [accessRepositoryProvider.overrideWithValue(repository)],
        child: _app(const AccessSessionGate()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Delete account'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Delete account'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Delete account?'), findsOneWidget);
    expect(
      find.text(
        'Your account will be permanently deleted. Any retained Company history will no longer identify you.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Delete account'));
    await tester.pump();
    expect(repository.deleteAccountCalls, 1);

    signOut.complete();
    repository.emitSignedOut();
    await tester.pump();
    await tester.pump();

    expect(find.byType(AuthPage), findsOneWidget);
    expect(find.byType(AccountPage), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Owner Company settings exposes Company deletion', (
    tester,
  ) async {
    final repository = _FakeAccessRepository();
    repository.companyList = const [
      RelayCompany(
        id: 'company-1',
        name: 'Relay Smoke Alpha',
        role: CompanyRole.owner,
      ),
    ];
    addTearDown(repository.dispose);

    await _openCompanySettings(tester, repository);

    expect(find.text('Delete Company'), findsOneWidget);
    expect(find.text('DANGER ZONE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('blocked Company deletion shows localized reason codes', (
    tester,
  ) async {
    final repository = _FakeAccessRepository();
    repository.companyList = const [
      RelayCompany(
        id: 'company-1',
        name: 'Relay Smoke Alpha',
        role: CompanyRole.owner,
      ),
    ];
    repository.companyDeletionPreview = const CompanyDeletionPreview(
      action: DeletionAction.blocked,
      reasons: [DeletionReason.companyHasStaff],
      companyName: 'Relay Smoke Alpha',
      staffCount: 1,
      activeTransferCount: 0,
      unresolvedDamageCount: 0,
    );
    addTearDown(repository.dispose);

    await _openCompanySettings(tester, repository, locale: const Locale('es'));
    await tester.tap(find.text('Eliminar empresa'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('No se puede eliminar la empresa'), findsOneWidget);
    expect(
      find.text('Elimina a todo el personal antes de eliminar esta empresa.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  test('blocked Company deletion payload parses typed reasons', () {
    final preview = CompanyDeletionPreview.fromRow({
      'action': 'BLOCKED',
      'reasons': ['COMPANY_HAS_ACTIVE_TRANSFERS'],
      'company_name': 'Relay Smoke Alpha',
      'staff_count': 0,
      'active_transfer_count': 1,
      'unresolved_damage_count': 0,
    });

    expect(preview.action, DeletionAction.blocked);
    expect(preview.reasons, [DeletionReason.companyHasActiveTransfers]);
  });

  testWidgets('Staff Company settings does not expose Company deletion', (
    tester,
  ) async {
    final repository = _FakeAccessRepository();
    repository.companyList = const [
      RelayCompany(
        id: 'company-1',
        name: 'Relay Smoke Alpha',
        role: CompanyRole.staff,
      ),
    ];
    addTearDown(repository.dispose);

    await _openCompanySettings(tester, repository);

    expect(find.text('Delete Company'), findsNothing);
    expect(find.text('DANGER ZONE'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Owner can request ownership transfer for a Staff member', (
    tester,
  ) async {
    await initializeDateFormatting('en');
    final repository = _FakeAccessRepository()
      ..teamMembers = const [
        RelayMember(
          userId: 'user-1',
          displayName: 'Current Owner',
          role: CompanyRole.owner,
        ),
        RelayMember(
          userId: 'staff-1',
          displayName: 'Promoted Staff',
          role: CompanyRole.staff,
        ),
      ];
    repository.onRequestCompanyOwnerTransfer = (companyId, userId) async {
      repository.ownerTransferRequestList = [
        CompanyOwnerTransferRequest(
          requestId: 'request-1',
          requestedByUserId: 'user-1',
          requestedByDisplayName: 'Current Owner',
          targetUserId: userId,
          targetDisplayName: 'Promoted Staff',
          requestedAt: DateTime.utc(2026, 7, 29, 0),
          expiresAt: DateTime.utc(2026, 8, 5, 0),
          state: CompanyOwnerTransferRequestState.pending,
          canCancel: true,
          canAccept: false,
        ),
      ];
    };
    addTearDown(repository.dispose);

    await _openTeamPage(
      tester,
      repository,
      const RelayCompany(
        id: 'company-1',
        name: 'Relay Smoke Alpha',
        role: CompanyRole.owner,
      ),
    );

    await tester.tap(find.text('Promoted Staff'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transfer ownership'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Transfer ownership'));
    await tester.pump();
    await _pumpUntilVisible(
      tester,
      find.text('Ownership transfer request sent to Promoted Staff.'),
    );

    expect(repository.requestOwnerTransferCalls, 1);
    expect(repository.lastRequestedOwnerTransferUserId, 'staff-1');
    expect(
      find.text('Ownership transfer request sent to Promoted Staff.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Owner can cancel a pending ownership transfer request', (
    tester,
  ) async {
    await initializeDateFormatting('en');
    final repository = _FakeAccessRepository()
      ..teamMembers = const [
        RelayMember(
          userId: 'user-1',
          displayName: 'Current Owner',
          role: CompanyRole.owner,
        ),
        RelayMember(
          userId: 'staff-1',
          displayName: 'Promoted Staff',
          role: CompanyRole.staff,
        ),
      ]
      ..ownerTransferRequestList = [
        CompanyOwnerTransferRequest(
          requestId: 'request-1',
          requestedByUserId: 'user-1',
          requestedByDisplayName: 'Current Owner',
          targetUserId: 'staff-1',
          targetDisplayName: 'Promoted Staff',
          requestedAt: DateTime.utc(2026, 7, 29, 0),
          expiresAt: DateTime.utc(2026, 8, 5, 0),
          state: CompanyOwnerTransferRequestState.pending,
          canCancel: true,
          canAccept: false,
        ),
      ];
    repository.onCancelCompanyOwnerTransferRequest = (requestId) async {
      repository.ownerTransferRequestList = [
        CompanyOwnerTransferRequest(
          requestId: requestId,
          requestedByUserId: 'user-1',
          requestedByDisplayName: 'Current Owner',
          targetUserId: 'staff-1',
          targetDisplayName: 'Promoted Staff',
          requestedAt: DateTime.utc(2026, 7, 29, 0),
          expiresAt: DateTime.utc(2026, 8, 5, 0),
          state: CompanyOwnerTransferRequestState.cancelled,
          canCancel: false,
          canAccept: false,
        ),
      ];
    };
    addTearDown(repository.dispose);

    await _openTeamPage(
      tester,
      repository,
      const RelayCompany(
        id: 'company-1',
        name: 'Relay Smoke Alpha',
        role: CompanyRole.owner,
      ),
    );

    await tester.tap(find.text('Promoted Staff'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(SimpleDialog),
        matching: find.text('Cancel ownership transfer'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(FilledButton, 'Cancel ownership transfer'),
    );
    await tester.pump();
    await _pumpUntilVisible(
      tester,
      find.text('Ownership transfer request cancelled.'),
    );

    expect(repository.cancelOwnerTransferCalls, 1);
    expect(repository.lastCancelledOwnerTransferRequestId, 'request-1');
    expect(find.text('Ownership transfer request cancelled.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Requested Staff can accept ownership transfer', (tester) async {
    await initializeDateFormatting('en');
    final repository = _FakeAccessRepository()
      ..emitSignedIn('staff-1')
      ..teamMembers = const [
        RelayMember(
          userId: 'user-1',
          displayName: 'Current Owner',
          role: CompanyRole.owner,
        ),
        RelayMember(
          userId: 'staff-1',
          displayName: 'Promoted Staff',
          role: CompanyRole.staff,
        ),
      ]
      ..ownerTransferRequestList = [
        CompanyOwnerTransferRequest(
          requestId: 'request-1',
          requestedByUserId: 'user-1',
          requestedByDisplayName: 'Current Owner',
          targetUserId: 'staff-1',
          targetDisplayName: 'Promoted Staff',
          requestedAt: DateTime.utc(2026, 7, 29, 0),
          expiresAt: DateTime.utc(2026, 8, 5, 0),
          state: CompanyOwnerTransferRequestState.pending,
          canCancel: false,
          canAccept: true,
        ),
      ];
    addTearDown(repository.dispose);

    await _openTeamPage(
      tester,
      repository,
      const RelayCompany(
        id: 'company-1',
        name: 'Relay Smoke Alpha',
        role: CompanyRole.staff,
      ),
    );

    await tester.tap(find.text('Accept ownership'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Accept ownership'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(repository.acceptOwnerTransferCalls, 1);
    expect(repository.lastAcceptedOwnerTransferRequestId, 'request-1');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Account sign-out ignores a pending refresh and reaches Auth', (
    tester,
  ) async {
    final repository = _FakeAccessRepository();
    final initialProfile = repository.addProfileRequest();
    final pendingRefresh = repository.addProfileRequest();
    final signOut = repository.addSignOutRequest();
    addTearDown(() {
      if (!pendingRefresh.isCompleted) pendingRefresh.complete('Late profile');
      if (!signOut.isCompleted) signOut.complete();
      repository.dispose();
    });

    await _openAccount(tester, repository);
    initialProfile.completeError(StateError('profile failed'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Could not load your profile.'), findsOneWidget);
    await tester.tap(find.text('Could not load your profile.'));
    await tester.pump();
    expect(repository.profileCalls, 2);

    await tester.tap(
      find.descendant(
        of: find.byType(AccountPage),
        matching: find.text('Sign out'),
      ),
    );
    await tester.pump();
    expect(
      find.descendant(
        of: find.byType(AccountPage),
        matching: find.text('Signing out…'),
      ),
      findsOneWidget,
    );

    repository.emitSignedOut();
    await tester.pump();
    await tester.pump();

    expect(find.byType(AuthPage), findsOneWidget);
    pendingRefresh.complete('Late profile');
    signOut.complete();
    await tester.pump();
    expect(find.text('Late profile'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Account sign-out failure restores a usable retry action', (
    tester,
  ) async {
    final repository = _FakeAccessRepository();
    repository.completeNextProfile('Initial profile');
    final failedSignOut = repository.addSignOutRequest();
    addTearDown(repository.dispose);

    await _openAccount(tester, repository);
    await _tapAccountSignOut(tester);
    failedSignOut.completeError(StateError('offline'));
    await tester.pump();
    await tester.pump();

    expect(find.byType(AccountPage), findsOneWidget);
    expect(find.text('We could not sign out. Try again.'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AccountPage),
        matching: find.text('Sign out'),
      ),
      findsOneWidget,
    );

    final retry = repository.addSignOutRequest();
    await _tapAccountSignOut(tester);
    expect(repository.signOutCalls, 2);
    retry.complete();
  });

  testWidgets('repeated Account sign-out taps use one request', (tester) async {
    final repository = _FakeAccessRepository();
    repository.completeNextProfile('Initial profile');
    final signOut = repository.addSignOutRequest();
    addTearDown(() {
      if (!signOut.isCompleted) signOut.complete();
      repository.dispose();
    });

    await _openAccount(tester, repository);
    await _tapAccountSignOut(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(AccountPage),
        matching: find.text('Signing out…'),
      ),
    );
    await tester.pump();

    expect(repository.signOutCalls, 1);
    signOut.complete();
    await tester.pump();
    await tester.pump();
  });

  testWidgets(
    'AccessSessionGate handles signed-out auth without build errors',
    (tester) async {
      final repository = _FakeAccessRepository();
      addTearDown(repository.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [accessRepositoryProvider.overrideWithValue(repository)],
          child: _app(const AccessSessionGate()),
        ),
      );
      await tester.pumpAndSettle();

      repository.emitSignedOut();
      await tester.pump();
      await tester.pump();

      expect(find.byType(AuthPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _openAccount(
  WidgetTester tester,
  _FakeAccessRepository repository,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [accessRepositoryProvider.overrideWithValue(repository)],
      child: _app(const AccessSessionGate()),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Account'));
  await tester.pumpAndSettle();
}

Future<void> _tapAccountSignOut(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(AccountPage),
      matching: find.text('Sign out'),
    ),
  );
  await tester.pump();
}

Future<void> _openCompanySettings(
  WidgetTester tester,
  _FakeAccessRepository repository, {
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [accessRepositoryProvider.overrideWithValue(repository)],
      child: _app(
        const CompanySettingsPage(companyId: 'company-1'),
        locale: locale,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openTeamPage(
  WidgetTester tester,
  _FakeAccessRepository repository,
  RelayCompany company, {
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [accessRepositoryProvider.overrideWithValue(repository)],
      child: _app(TeamPage(company: company), locale: locale),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpUntilVisible(
  WidgetTester tester,
  Finder finder, {
  Duration step = const Duration(milliseconds: 100),
  int maxPumps = 40,
}) async {
  for (var i = 0; i < maxPumps; i++) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.pump(step);
  }
  fail('Timed out waiting for expected widget to become visible.');
}

class _FakeAccessRepository extends AccessRepository {
  _FakeAccessRepository() : super(_client(), '');

  final _auth = StreamController<LocalAuthState>.broadcast();
  final _profiles = Queue<Completer<String?>>();
  final _signOuts = Queue<Completer<void>>();
  LocalSession? _session = _sessionFixture();
  List<RelayCompany> companyList = const [];
  AccountDeletionPreview? deletionPreview;
  AccountDeletionResult? deletionResult;
  CompanyDeletionPreview? companyDeletionPreview;
  InvitationPreview? invitationPreview;
  InvitationStatus invitationStatusValue = const InvitationStatus(
    active: false,
  );
  List<DeveloperAnnouncement> developerAnnouncementList = const [];
  DeveloperAnnouncementStatus developerAnnouncementStatusValue =
      const DeveloperAnnouncementStatus(unreadCount: 0, totalCount: 0);
  List<RelayMember> teamMembers = const [];
  List<CompanyOwnerTransferRequest> ownerTransferRequestList = const [];
  Future<void> Function(String companyId, String userId)?
  onRequestCompanyOwnerTransfer;
  Future<void> Function(String requestId)? onCancelCompanyOwnerTransferRequest;
  var profileCalls = 0;
  var signOutCalls = 0;
  var deleteAccountCalls = 0;
  var legalAccepted = true;
  var legalAcceptanceChecks = 0;
  var requestOwnerTransferCalls = 0;
  var cancelOwnerTransferCalls = 0;
  var acceptOwnerTransferCalls = 0;
  var removeStaffCalls = 0;
  var markDeveloperAnnouncementSeenCalls = 0;
  var markAllDeveloperAnnouncementsSeenCalls = 0;
  var failMarkAllDeveloperAnnouncementsSeen = false;
  String? lastRequestedOwnerTransferUserId;
  String? lastCancelledOwnerTransferRequestId;
  String? lastAcceptedOwnerTransferRequestId;
  String? lastSeenAnnouncementId;

  @override
  LocalSession? get session => _session;

  @override
  Stream<LocalAuthState> get authChanges => _auth.stream;

  @override
  Future<List<RelayCompany>> companies() async => companyList;

  @override
  Future<List<DeveloperAnnouncement>> developerAnnouncements({
    DateTime? afterPublishedAt,
    String? afterId,
    int pageSize = 20,
  }) async => developerAnnouncementList;

  @override
  Future<DeveloperAnnouncementStatus> developerAnnouncementStatus() async =>
      developerAnnouncementStatusValue;

  @override
  Future<void> markDeveloperAnnouncementSeen(String announcementId) async {
    markDeveloperAnnouncementSeenCalls++;
    lastSeenAnnouncementId = announcementId;
    developerAnnouncementList = [
      for (final announcement in developerAnnouncementList)
        if (announcement.id == announcementId)
          DeveloperAnnouncement(
            id: announcement.id,
            announcementKey: announcement.announcementKey,
            titleEn: announcement.titleEn,
            bodyEn: announcement.bodyEn,
            titleEs: announcement.titleEs,
            bodyEs: announcement.bodyEs,
            titleJa: announcement.titleJa,
            bodyJa: announcement.bodyJa,
            publishedAt: announcement.publishedAt,
            expiresAt: announcement.expiresAt,
            seenAt: DateTime(2026, 7, 29),
            isUnread: false,
          )
        else
          announcement,
    ];
    developerAnnouncementStatusValue = DeveloperAnnouncementStatus(
      unreadCount: developerAnnouncementList
          .where((item) => item.isUnread)
          .length,
      totalCount: developerAnnouncementList.length,
    );
  }

  @override
  Future<int> markAllDeveloperAnnouncementsSeen() async {
    markAllDeveloperAnnouncementsSeenCalls++;
    if (failMarkAllDeveloperAnnouncementsSeen) {
      throw StateError('remote mark-all failed');
    }
    developerAnnouncementList = [
      for (final announcement in developerAnnouncementList)
        DeveloperAnnouncement(
          id: announcement.id,
          announcementKey: announcement.announcementKey,
          titleEn: announcement.titleEn,
          bodyEn: announcement.bodyEn,
          titleEs: announcement.titleEs,
          bodyEs: announcement.bodyEs,
          titleJa: announcement.titleJa,
          bodyJa: announcement.bodyJa,
          publishedAt: announcement.publishedAt,
          expiresAt: announcement.expiresAt,
          seenAt: DateTime(2026, 7, 29),
          isUnread: false,
        ),
    ];
    developerAnnouncementStatusValue = DeveloperAnnouncementStatus(
      unreadCount: 0,
      totalCount: developerAnnouncementList.length,
    );
    return developerAnnouncementList.length;
  }

  @override
  Future<String> createCompany(String name) async => 'company-2';

  @override
  Future<InvitationPreview?> previewInvitation(String code) async =>
      invitationPreview;

  @override
  Future<String?> acceptInvitation(String code) async => 'company-3';

  @override
  Future<List<RelayMember>> members(String companyId) async => teamMembers;

  @override
  Future<InvitationStatus> invitationStatus(String companyId) async =>
      invitationStatusValue;

  @override
  Future<List<CompanyOwnerTransferRequest>> ownerTransferRequests(
    String companyId,
  ) async => ownerTransferRequestList;

  @override
  Future<void> requestCompanyOwnerTransfer(
    String companyId,
    String userId,
  ) async {
    requestOwnerTransferCalls++;
    lastRequestedOwnerTransferUserId = userId;
    await onRequestCompanyOwnerTransfer?.call(companyId, userId);
  }

  @override
  Future<void> cancelCompanyOwnerTransferRequest(String requestId) async {
    cancelOwnerTransferCalls++;
    lastCancelledOwnerTransferRequestId = requestId;
    await onCancelCompanyOwnerTransferRequest?.call(requestId);
  }

  @override
  Future<void> acceptCompanyOwnerTransferRequest(String requestId) async {
    acceptOwnerTransferCalls++;
    lastAcceptedOwnerTransferRequestId = requestId;
  }

  @override
  Future<void> removeStaffMember(String companyId, String userId) async {
    removeStaffCalls++;
  }

  @override
  Future<bool> hasCurrentLegalAcceptance() async {
    legalAcceptanceChecks++;
    return legalAccepted;
  }

  @override
  Future<void> recordCurrentLegalAcceptance(String method) async {}

  @override
  Future<String?> profileName() {
    profileCalls++;
    return _profiles.removeFirst().future;
  }

  @override
  Future<void> signOut() {
    signOutCalls++;
    return _signOuts.removeFirst().future;
  }

  @override
  Future<AccountDeletionPreview> previewAccountDeletion() async =>
      deletionPreview!;

  @override
  Future<AccountDeletionResult> deleteAccount() async {
    deleteAccountCalls++;
    return deletionResult!;
  }

  @override
  Future<CompanyDeletionPreview> previewCompanyDeletion(
    String companyId,
  ) async => companyDeletionPreview!;

  void completeNextProfile(String? value) {
    final request = addProfileRequest();
    request.complete(value);
  }

  Completer<String?> addProfileRequest() {
    final request = Completer<String?>();
    _profiles.add(request);
    return request;
  }

  Completer<void> addSignOutRequest() {
    final request = Completer<void>();
    _signOuts.add(request);
    return request;
  }

  void emitSignedOut() {
    _session = null;
    _auth.add(const LocalAuthState(LocalAuthEvent.signedOut, null));
  }

  void emitSignedIn(String userId) {
    _session = _sessionFixture(userId);
    _auth.add(LocalAuthState(LocalAuthEvent.signedIn, _session));
  }

  void dispose() => _auth.close();
}

class _NavigationTransferRepository extends TransferRepository {
  _NavigationTransferRepository() : super(_client());

  @override
  Future<List<TransferRecord>> list({
    required String companyId,
    TransferStatus? status,
    String? staffId,
    String? query,
    int offset = 0,
  }) async => const [];
}

DeveloperAnnouncement _announcement({
  required String id,
  required String announcementKey,
  required String titleEn,
  DateTime? publishedAt,
  bool isUnread = true,
}) => DeveloperAnnouncement(
  id: id,
  announcementKey: announcementKey,
  titleEn: titleEn,
  bodyEn: '$titleEn body',
  titleEs: '$titleEn ES',
  bodyEs: '$titleEn ES body',
  titleJa: '$titleEn 日本語',
  bodyJa: '$titleEn 日本語の本文',
  publishedAt: publishedAt ?? DateTime.utc(2026, 7, 30),
  expiresAt: null,
  seenAt: isUnread ? null : DateTime.utc(2026, 7, 31),
  isUnread: isUnread,
);

LocalBackendClient _client() =>
    LocalBackendClient('http://localhost', 'test-key');

LocalSession _sessionFixture([String userId = 'user-1']) => LocalSession(
  accessToken: 'access-token',
  user: LocalUser(
    id: userId,
    email: 'user@example.com',
    displayName: 'Test User',
  ),
);
