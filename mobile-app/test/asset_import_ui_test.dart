import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relay_av_demo/app/theme.dart';
import 'package:relay_av_demo/features/assets/asset_domain.dart';
import 'package:relay_av_demo/features/assets/asset_screens.dart';
import 'package:relay_av_demo/features/catalog/catalog_models.dart';
import 'package:relay_av_demo/features/catalog/catalog_repository.dart';
import 'package:relay_av_demo/l10n/relay_localizations.dart';
import 'package:relay_av_demo/shared/entity_lifecycle.dart';
import 'package:relay_av_demo/data/local_backend_compat.dart';

LocalBackendClient _testClient() =>
    LocalBackendClient('http://example.invalid', 'test-key');

Widget _app(Widget child, {required double width}) => ProviderScope(
  overrides: [
    catalogRepositoryProvider.overrideWithValue(_EmptyCatalogRepository()),
    assetCatalogRepositoryProvider.overrideWithValue(
      _EmptyAssetCatalogRepository(),
    ),
  ],
  child: MaterialApp(
    theme: relayLightTheme(),
    locale: const Locale('en'),
    localizationsDelegates: const [RelayLocalizations.delegate],
    supportedLocales: RelayLocalizations.supportedLocales,
    home: SizedBox(
      width: width,
      child: MediaQuery(
        data: MediaQueryData(size: Size(width, 900), disableAnimations: true),
        child: child,
      ),
    ),
  ),
);

void main() {
  testWidgets('Import screen keeps the reduced schema on phone', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const AssetImportPage(companyId: 'company-1'), width: 390),
    );
    await tester.pumpAndSettle();

    expect(find.text('Import Assets'), findsOneWidget);
    expect(find.text('Download template'), findsOneWidget);
    expect(find.text('Choose XLSX or CSV'), findsOneWidget);
    expect(find.text('Import type'), findsNothing);
    expect(find.text('Category'), findsNothing);
    expect(find.text('Notes'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Import screen remains usable at tablet width', (tester) async {
    await tester.pumpWidget(
      _app(const AssetImportPage(companyId: 'company-1'), width: 800),
    );
    await tester.pumpAndSettle();

    expect(find.text('Import Assets'), findsOneWidget);
    expect(find.text('Import type'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _EmptyCatalogRepository extends CatalogRepository {
  _EmptyCatalogRepository() : super(_testClient());

  @override
  Future<List<LocationRecord>> locations({
    required String companyId,
    String? query,
    LocationType? type,
    LocationRecord? after,
    ArchiveScope archiveScope = ArchiveScope.working,
  }) async => [];
}

class _EmptyAssetCatalogRepository extends AssetCatalogRepository {
  _EmptyAssetCatalogRepository() : super(_testClient());

  @override
  Future<List<AssetRecord>> assets({
    required String companyId,
    String? query,
    AssetMode? mode,
    ArchiveScope archiveScope = ArchiveScope.working,
    AssetRecord? after,
  }) async => [];
}
