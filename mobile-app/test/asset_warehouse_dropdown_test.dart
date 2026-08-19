import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relay_av_demo/app/theme.dart';
import 'package:relay_av_demo/features/assets/asset_screens.dart';
import 'package:relay_av_demo/features/catalog/catalog_models.dart';
import 'package:relay_av_demo/features/catalog/catalog_repository.dart';
import 'package:relay_av_demo/l10n/relay_localizations.dart';
import 'package:relay_av_demo/shared/entity_lifecycle.dart';
import 'package:relay_av_demo/data/local_backend_compat.dart';

final _shortWarehouse = LocationRecord(
  id: 'warehouse-short',
  name: 'Main Warehouse',
  type: LocationType.warehouse,
  createdAt: DateTime.utc(2026),
);

final _longWarehouse = LocationRecord(
  id: 'warehouse-long',
  name:
      'North Vietnam Regional Equipment Receiving and Climate Controlled '
      'Warehouse for Touring Productions and Long-Term Storage',
  type: LocationType.warehouse,
  createdAt: DateTime.utc(2026),
);

Widget _app() => ProviderScope(
  overrides: [
    catalogRepositoryProvider.overrideWithValue(
      _WarehouseCatalogRepository([_shortWarehouse, _longWarehouse]),
    ),
  ],
  child: MaterialApp(
    theme: relayLightTheme(),
    localizationsDelegates: const [RelayLocalizations.delegate],
    supportedLocales: RelayLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(1.3)),
      child: child!,
    ),
    home: const AssetFormPage(companyId: 'company-1'),
  ),
);

void main() {
  testWidgets(
    'warehouse dropdown keeps its arrow and selected long name within a 360dp form',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      final dropdown = find.byType(DropdownButtonFormField<String>);
      expect(dropdown, findsOneWidget);
      expect(find.byIcon(Icons.arrow_drop_down), findsOneWidget);

      await tester.tap(dropdown);
      await tester.pumpAndSettle();

      expect(find.text(_longWarehouse.name), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text(_longWarehouse.name));
      await tester.pumpAndSettle();

      final field = tester.state<FormFieldState<String>>(dropdown);
      expect(field.value, _longWarehouse.id);
      expect(find.byIcon(Icons.arrow_drop_down), findsOneWidget);

      final selectedLabel = tester.widget<Text>(
        find.descendant(of: dropdown, matching: find.text(_longWarehouse.name)),
      );
      expect(selectedLabel.maxLines, 1);
      expect(selectedLabel.overflow, TextOverflow.ellipsis);
      expect(tester.takeException(), isNull);
    },
  );
}

class _WarehouseCatalogRepository extends CatalogRepository {
  _WarehouseCatalogRepository(this._warehouses) : super(_testBackendClient());

  final List<LocationRecord> _warehouses;

  @override
  Future<List<LocationRecord>> locations({
    required String companyId,
    String? query,
    LocationType? type,
    LocationRecord? after,
    ArchiveScope archiveScope = ArchiveScope.working,
  }) async => _warehouses;
}

LocalBackendClient _testBackendClient() =>
    LocalBackendClient('http://localhost', 'test-key');
