import '../../../shared/request_timeout.dart';
import 'asset_import_models.dart';

class AssetImportBatchRepository {
  AssetImportBatchRepository(this._client);

  final dynamic _client;

  Future<List<AssetImportBatchRowResult>> commit(
    AssetImportBatchCommitRequest request,
  ) async {
    final rows = await withRelayRequestTimeout(
      _client.rpc(
        'commit_unified_asset_import_batch',
        params: {
          'target_workspace_id': request.companyId,
          'target_file_name': request.fileName,
          'target_file_hash': request.fileHash,
          'target_file_size_bytes': request.fileSizeBytes,
          'batch_key': request.batchKey,
          'import_rows': [for (final row in request.rows) row.toRpcMap()],
        },
      ),
    );
    return [
      for (final row in rows as List)
        AssetImportBatchRowResult.fromMap(
          Map<String, dynamic>.from(row as Map),
        ),
    ];
  }
}
