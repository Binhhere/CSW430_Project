import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../shared/request_timeout.dart';
import '../../data/local_backend_compat.dart';
import 'transfer_evidence_models.dart';
import 'transfer_models.dart';

final transferEvidenceRepositoryProvider = Provider<TransferEvidenceRepository>(
  (_) => TransferEvidenceRepository(LocalBackendClient()),
);

class TransferEvidenceRepository {
  TransferEvidenceRepository(this._client);
  final dynamic _client;

  Future<List<TransferEvidenceRecord>> list({
    required String transferId,
    required EvidencePhase phase,
    TransferEvidenceRecord? after,
  }) async {
    final rows = await withRelayRequestTimeout(
      _client.rpc(
        'list_transfer_evidence',
        params: {
          'target_transfer_id': transferId,
          'target_phase': phase.wireValue,
          'after_created_at': after?.createdAt.toIso8601String(),
          'after_id': after?.id,
          'page_size': 10,
        },
      ),
    );
    return [
      for (final row in rows as List)
        TransferEvidenceRecord.fromMap(Map<String, dynamic>.from(row as Map)),
    ];
  }

  Future<Uint8List> thumbnailBytes(TransferEvidenceRecord evidence) =>
      withRelayRequestTimeout(
        _client.storage
            .from('transfer-evidence')
            .download(evidence.thumbnailPath),
      );

  Future<Uint8List> fullBytes(TransferEvidenceRecord evidence) =>
      withRelayRequestTimeout(
        _client.storage
            .from('transfer-evidence')
            .download(evidence.storagePath),
      );

  Future<void> upload({
    required String companyId,
    required String transferId,
    required String lineId,
    required EvidencePhase phase,
    required Uint8List bytes,
    String? evidenceId,
  }) async {
    await withRelayRequestTimeout(
      _client.functions.invoke(
        'upload-transfer-evidence',
        body: bytes,
        headers: {
          'x-relay-workspace-id': companyId,
          'x-relay-transfer-id': transferId,
          'x-relay-transfer-line-id': lineId,
          'x-relay-evidence-phase': phase.wireValue,
          'x-relay-evidence-id': evidenceId ?? const Uuid().v4(),
          'x-relay-image-type': 'image/jpeg',
          'Content-Type': 'application/octet-stream',
        },
      ),
    );
  }
}
