import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/request_timeout.dart';
import '../../shared/entity_lifecycle.dart';
import '../../data/local_backend_compat.dart';
import 'asset_domain.dart';

final assetCatalogRepositoryProvider = Provider<AssetCatalogRepository>(
  (_) => AssetCatalogRepository(LocalBackendClient()),
);

class AssetCatalogRepository {
  AssetCatalogRepository(this._client);
  final dynamic _client;

  Future<List<AssetRecord>> assets({
    required String companyId,
    String? query,
    AssetMode? mode,
    ArchiveScope archiveScope = ArchiveScope.working,
    AssetRecord? after,
  }) async {
    final rows = await withRelayRequestTimeout(
      _client.rpc(
        'list_assets',
        params: {
          'target_workspace_id': companyId,
          'query_text': _emptyToNull(query),
          'mode_filter': mode?.wireValue,
          'archive_scope': archiveScope.wireValue,
          'after_state_rank': after?.stateRank,
          'after_name': after?.name,
          'after_id': after?.id,
          'page_size': 10,
        },
      ),
    );
    return [
      for (final row in rows as List)
        AssetRecord.fromMap(Map<String, dynamic>.from(row as Map)),
    ];
  }

  Future<AssetRecord?> asset(String companyId, String assetId) async {
    final rows = await withRelayRequestTimeout(
      _client.rpc(
        'get_asset',
        params: {'target_workspace_id': companyId, 'target_asset_id': assetId},
      ),
    );
    if ((rows as List).isEmpty) return null;
    return AssetRecord.fromMap(Map<String, dynamic>.from(rows.single as Map));
  }

  Future<AssetSaveResult> saveAsset({
    required String companyId,
    String? assetId,
    required AssetMode mode,
    required String name,
    required String locationId,
    String? serialNumber,
    int? quantity,
    bool confirmBulkMerge = false,
    required String requestKey,
  }) async {
    final rows = await withRelayRequestTimeout(
      _client.rpc(
        'save_asset',
        params: {
          'target_workspace_id': companyId,
          'target_asset_id': assetId,
          'target_mode': mode.wireValue,
          'target_name': name.trim(),
          'target_location_id': locationId,
          'target_serial_number': _emptyToNull(serialNumber),
          'target_quantity': quantity,
          'confirm_bulk_merge': confirmBulkMerge,
          'request_key': requestKey,
        },
      ),
    );
    return AssetSaveResult.fromMap(
      Map<String, dynamic>.from((rows as List).single as Map),
    );
  }

  Future<AssetRecord> archiveAsset({
    required String companyId,
    required String assetId,
  }) async {
    await withRelayRequestTimeout(
      _client.rpc('archive_asset', params: {'target_asset_id': assetId}),
    );
    final saved = await asset(companyId, assetId);
    if (saved == null) throw StateError('Archived Asset is not readable');
    return saved;
  }

  Future<AssetRecord> restoreAsset({
    required String companyId,
    required String assetId,
  }) async {
    await withRelayRequestTimeout(
      _client.rpc('restore_asset', params: {'target_asset_id': assetId}),
    );
    final saved = await asset(companyId, assetId);
    if (saved == null) throw StateError('Restored Asset is not readable');
    return saved;
  }

  Future<List<LifecyclePreview>> previewLifecycle({
    required List<String> ids,
    required LifecycleOperation operation,
  }) async {
    final rows = await withRelayRequestTimeout(
      _client.rpc(
        'preview_catalog_lifecycle',
        params: {
          'target_type': LifecycleEntityType.asset.wireValue,
          'target_ids': ids,
          'target_operation': operation.wireValue,
        },
      ),
    );
    return [
      for (final row in rows as List)
        LifecyclePreview.fromMap(Map<String, dynamic>.from(row as Map)),
    ];
  }

  Future<List<LifecycleResult>> applyLifecycle({
    required List<String> ids,
    required LifecycleOperation operation,
  }) async {
    final rows = await withRelayRequestTimeout(
      _client.rpc(
        'apply_catalog_lifecycle',
        params: {
          'target_type': LifecycleEntityType.asset.wireValue,
          'target_ids': ids,
          'target_operation': operation.wireValue,
        },
      ),
    );
    return [
      for (final row in rows as List)
        LifecycleResult.fromMap(Map<String, dynamic>.from(row as Map)),
    ];
  }

  Future<AssetRecord?> resolveAssetQr({
    required String companyId,
    required String rawToken,
  }) async {
    final rows = await withRelayRequestTimeout(
      _client.rpc(
        'resolve_asset_qr',
        params: {
          'target_workspace_id': companyId,
          'raw_qr_token': rawToken.trim(),
        },
      ),
    );
    if ((rows as List).isEmpty) return null;
    final resolved = Map<String, dynamic>.from(rows.single as Map);
    return asset(companyId, resolved['id'] as String);
  }

  Future<Uint8List> coverBytes(String storagePath) => withRelayRequestTimeout(
    _client.storage.from('asset-covers').download(storagePath),
  );

  Future<void> uploadCover({
    required String companyId,
    required String assetId,
    required Uint8List bytes,
  }) async {
    await withRelayRequestTimeout(
      _client.functions.invoke(
        'upload-asset-cover',
        body: bytes,
        headers: {
          'x-relay-workspace-id': companyId,
          'x-relay-asset-id': assetId,
          'x-relay-action': 'upload',
          'x-relay-image-type': 'image/jpeg',
          'Content-Type': 'application/octet-stream',
        },
      ),
    );
  }

  Future<void> removeCover({
    required String companyId,
    required String assetId,
  }) async {
    await withRelayRequestTimeout(
      _client.functions.invoke(
        'upload-asset-cover',
        headers: {
          'x-relay-workspace-id': companyId,
          'x-relay-asset-id': assetId,
          'x-relay-action': 'remove',
        },
      ),
    );
  }

  String? _emptyToNull(String? value) {
    final result = value?.trim();
    return result == null || result.isEmpty ? null : result;
  }
}
