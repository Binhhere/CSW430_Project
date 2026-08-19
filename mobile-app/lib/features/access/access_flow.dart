import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/theme.dart';
import '../../app/theme_controller.dart';
import '../../app/relay_ui.dart';
import '../../config/app_config.dart';
import '../../data/course_api_client.dart';
import '../../data/local_backend_compat.dart';
import '../assets/asset_domain.dart';
import '../assets/asset_screens.dart';
import '../assets/qr_screens.dart';
import '../catalog/catalog_models.dart';
import '../catalog/catalog_screens.dart';
import '../transfers/transfer_screens.dart';
import '../../l10n/relay_localizations.dart';
import '../../shared/async_ui_controller.dart';
import '../../shared/company_list_scope_state.dart';
import '../../shared/entity_lifecycle.dart';
import '../../shared/ledger_widgets.dart';
import '../../shared/request_timeout.dart';
import '../../shared/relay_failure.dart';
import 'access_models.dart';
import 'access_repository.dart';
import 'legal_consent.dart';
import 'pre_company_language_menu.dart';

part 'access_session.dart';
part 'auth_pages.dart';
part 'company_gateway.dart';
part 'company_announcements.dart';
part 'company_management_pages.dart';
part 'company_shell.dart';
part 'company_shell_navigation.dart';
part 'account_page.dart';
part 'company_settings_page.dart';
part 'team_page.dart';
part 'invitation_scanner.dart';
part 'access_widgets.dart';

final accessRepositoryProvider = Provider<AccessRepository>((ref) {
  final config = AppConfig.current;
  return AccessRepository.local(CourseApiClient(config.apiBaseUrl));
});

final accessAuthProvider = StreamProvider<LocalAuthState>((ref) async* {
  final repository = ref.watch(accessRepositoryProvider);
  await repository.restoreLocalSession();
  yield LocalAuthState(LocalAuthEvent.initialSession, repository.session);
  yield* repository.authChanges;
});

final accessCompaniesProvider = FutureProvider<List<RelayCompany>>((ref) async {
  ref.watch(accessAuthProvider);
  return ref.watch(accessRepositoryProvider).companies();
});

final developerAnnouncementsProvider =
    FutureProvider<List<DeveloperAnnouncement>>((ref) async {
      ref.watch(accessAuthProvider);
      final repository = ref.watch(accessRepositoryProvider);
      return _loadMergedDeveloperAnnouncements(repository);
    });

final developerAnnouncementStatusProvider =
    FutureProvider<DeveloperAnnouncementStatus>((ref) async {
      ref.watch(accessAuthProvider);
      final repository = ref.watch(accessRepositoryProvider);
      final announcements = await _loadMergedDeveloperAnnouncements(repository);
      return DeveloperAnnouncementStatus(
        unreadCount: announcements.where((item) => item.isUnread).length,
        totalCount: announcements.length,
      );
    });

Future<List<DeveloperAnnouncement>> _loadMergedDeveloperAnnouncements(
  AccessRepository repository,
) async {
  final userId = repository.session?.user.id;
  final results = await Future.wait([
    repository.developerAnnouncements(),
    _bundledDeveloperAnnouncements(userId),
  ]);
  return mergeDeveloperAnnouncements(results[1], results[0]);
}

List<DeveloperAnnouncement> mergeDeveloperAnnouncements(
  List<DeveloperAnnouncement> bundled,
  List<DeveloperAnnouncement> remote,
) {
  final byKey = <String, DeveloperAnnouncement>{};
  for (final announcement in bundled) {
    byKey[announcement.announcementKey] = announcement;
  }
  for (final announcement in remote) {
    byKey[announcement.announcementKey] = announcement;
  }
  final merged = byKey.values.toList();
  merged.sort((a, b) {
    final published = b.publishedAt.compareTo(a.publishedAt);
    if (published != 0) return published;
    final id = b.id.compareTo(a.id);
    if (id != 0) return id;
    return b.announcementKey.compareTo(a.announcementKey);
  });
  return merged;
}

final activeCompanyIdProvider = StateProvider<String?>((_) => null);
final pendingLegalAcceptanceMethodProvider = StateProvider<String?>(
  (_) => null,
);
final pendingAuthNoticeProvider = StateProvider<String?>((_) => null);

const _bundledAnnouncementStorageKeyPrefix =
    'relay_bundled_announcement_seen_keys_v1';

@visibleForTesting
DateTime Function() debugBundledAnnouncementsNow = () => DateTime.now().toUtc();

@visibleForTesting
List<DeveloperAnnouncement>? debugBundledAnnouncementsOverride;

final List<_BundledAnnouncementDefinition>
_defaultBundledAnnouncementDefinitions = [
  _BundledAnnouncementDefinition(
    id: 'bundled:closed-testing-limits-2026-07-29',
    announcementKey: 'closed_testing_limits_2026_07_29',
    titleEn: 'Closed testing is active',
    bodyEn:
        'Etrelay: Rental Operations is currently in closed testing. In this '
        'phase, one account can create up to 2 Companies and join unlimited '
        'Companies. Each Company can have up to 8 members and 150 active '
        'Assets. Billing is not enabled in this build yet. Thanks for testing '
        'and sharing feedback.',
    titleEs: 'Las pruebas cerradas estan activas',
    bodyEs:
        'Etrelay: Rental Operations se encuentra actualmente en pruebas '
        'cerradas. En esta fase, una cuenta puede crear hasta 2 Empresas y '
        'unirse a una cantidad ilimitada de Empresas. Cada Empresa puede '
        'tener hasta 8 miembros y 150 Activos activos. La facturacion aun no '
        'esta habilitada en esta version. Gracias por probar la app y '
        'compartir comentarios.',
    titleJa: 'クローズド テストを実施中です',
    bodyJa:
        'Etrelay：レンタル業務管理は現在クローズド テスト中です。この期間は、1つのアカウントで最大2社の会社を作成でき、参加する会社の数に制限はありません。各会社には最大8人のメンバーと150件の稼働中機材を登録できます。このビルドでは請求機能はまだ有効ではありません。テストとフィードバックへのご協力ありがとうございます。',
    publishedAt: DateTime.utc(2026, 7, 29, 12),
  ),
];

Future<List<DeveloperAnnouncement>> _bundledDeveloperAnnouncements(
  String? userId,
) async {
  if (userId == null) return const [];
  final preferences = await SharedPreferences.getInstance();
  final seenKeys =
      preferences
          .getStringList(_bundledAnnouncementStorageKey(userId))
          ?.toSet() ??
      <String>{};
  final now = debugBundledAnnouncementsNow();
  return [
    for (final announcement in _visibleBundledAnnouncementSeeds(now))
      _bundledAnnouncementWithSeenState(
        announcement,
        seenAt: seenKeys.contains(announcement.announcementKey)
            ? announcement.publishedAt
            : null,
      ),
  ];
}

Future<void> markBundledAnnouncementSeen(
  String userId,
  String announcementKey,
) async {
  final preferences = await SharedPreferences.getInstance();
  final storageKey = _bundledAnnouncementStorageKey(userId);
  final seenKeys = preferences.getStringList(storageKey)?.toSet() ?? <String>{};
  if (seenKeys.add(announcementKey)) {
    await preferences.setStringList(storageKey, seenKeys.toList()..sort());
  }
}

Future<int> markAllBundledAnnouncementsSeen(String userId) async {
  final preferences = await SharedPreferences.getInstance();
  final storageKey = _bundledAnnouncementStorageKey(userId);
  final seenKeys = preferences.getStringList(storageKey)?.toSet() ?? <String>{};
  var inserted = 0;
  for (final announcement in _visibleBundledAnnouncementSeeds(
    debugBundledAnnouncementsNow(),
  )) {
    if (seenKeys.add(announcement.announcementKey)) {
      inserted += 1;
    }
  }
  if (inserted > 0) {
    await preferences.setStringList(storageKey, seenKeys.toList()..sort());
  }
  return inserted;
}

String _bundledAnnouncementStorageKey(String userId) =>
    '$_bundledAnnouncementStorageKeyPrefix:$userId';

List<DeveloperAnnouncement> _visibleBundledAnnouncementSeeds(DateTime now) => [
  for (final announcement in _bundledAnnouncementSeeds())
    if (!announcement.publishedAt.isAfter(now)) announcement,
];

List<DeveloperAnnouncement> _bundledAnnouncementSeeds() {
  final overrides = debugBundledAnnouncementsOverride;
  if (overrides != null) {
    return overrides;
  }
  return [
    for (final definition in _defaultBundledAnnouncementDefinitions)
      definition.toAnnouncement(),
  ];
}

DeveloperAnnouncement _bundledAnnouncementWithSeenState(
  DeveloperAnnouncement announcement, {
  required DateTime? seenAt,
}) => DeveloperAnnouncement(
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
  seenAt: seenAt,
  isUnread: seenAt == null,
);

class _BundledAnnouncementDefinition {
  const _BundledAnnouncementDefinition({
    required this.id,
    required this.announcementKey,
    required this.titleEn,
    required this.bodyEn,
    required this.titleEs,
    required this.bodyEs,
    required this.titleJa,
    required this.bodyJa,
    required this.publishedAt,
  });

  final String id;
  final String announcementKey;
  final String titleEn;
  final String bodyEn;
  final String titleEs;
  final String bodyEs;
  final String titleJa;
  final String bodyJa;
  final DateTime publishedAt;

  DeveloperAnnouncement toAnnouncement() => DeveloperAnnouncement(
    id: id,
    announcementKey: announcementKey,
    titleEn: titleEn,
    bodyEn: bodyEn,
    titleEs: titleEs,
    bodyEs: bodyEs,
    titleJa: titleJa,
    bodyJa: bodyJa,
    publishedAt: publishedAt,
    expiresAt: null,
    seenAt: null,
    isUnread: true,
  );
}
