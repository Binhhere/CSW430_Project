import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../catalog/catalog_models.dart';
import '../../shared/request_timeout.dart';
import '../../data/local_backend_compat.dart';
import 'transfer_models.dart';

final transferRepositoryProvider = Provider<TransferRepository>(
  (_) => TransferRepository(LocalBackendClient()),
);

class _ReturnSummary {
  const _ReturnSummary({
    this.hasTransfer = false,
    this.attention = TransferAttention.none,
  });

  final bool hasTransfer;
  final TransferAttention attention;
}

class TransferRepository {
  TransferRepository(this._client);
  final dynamic _client;

  Future<List<TransferRecord>> list({
    required String companyId,
    TransferStatus? status,
    String? staffId,
    String? query,
    int offset = 0,
  }) async {
    dynamic request = _client
        .from('transfers')
        .select(
          'id,workspace_id,customer_id,origin_location_id,destination_location_id,direction,status,reference,scheduled_start_date,scheduled_end_date,assigned_staff_id,created_by,return_of_transfer_id',
        )
        .eq('workspace_id', companyId)
        .isFilter('cancelled_at', null);
    if (status != null) request = request.eq('status', status.wireValue);
    if (staffId != null) request = request.eq('assigned_staff_id', staffId);
    final trimmed = query?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      request = request.ilike('reference', '%$trimmed%');
    }
    final rows = await withRelayRequestTimeout(
      request
          .order('scheduled_start_date', ascending: false)
          .range(offset, offset + 9),
    );
    return _hydrate(List<Map<String, dynamic>>.from(rows));
  }

  Future<TransferRecord?> detail(String companyId, String transferId) async {
    final row = await withRelayRequestTimeout(
      _client
          .from('transfers')
          .select(
            'id,workspace_id,customer_id,origin_location_id,destination_location_id,direction,status,reference,scheduled_start_date,scheduled_end_date,assigned_staff_id,created_by,return_of_transfer_id',
          )
          .eq('workspace_id', companyId)
          .eq('id', transferId)
          .maybeSingle(),
    );
    if (row == null) return null;
    final results = await Future.wait([
      _hydrate([Map<String, dynamic>.from(row)]),
      withRelayRequestTimeout(
        _client
            .from('transfer_lines')
            .select(
              'id,asset_id,requested_quantity,dispatched_quantity,received_quantity,damaged_quantity',
            )
            .eq('transfer_id', transferId)
            .order('id'),
      ),
    ]);
    final transfer = (results[0] as List<TransferRecord>).single;
    final lineRows = results[1];
    final lines = List<Map<String, dynamic>>.from(lineRows);
    if (lines.isEmpty) return transfer;
    final assets = await _assetsByIds(
      lines.map((row) => row['asset_id'] as String),
    );
    return TransferRecord(
      id: transfer.id,
      companyId: transfer.companyId,
      customer: transfer.customer,
      origin: transfer.origin,
      destination: transfer.destination,
      direction: transfer.direction,
      status: transfer.status,
      startDate: transfer.startDate,
      endDate: transfer.endDate,
      assignedStaffId: transfer.assignedStaffId,
      createdBy: transfer.createdBy,
      reference: transfer.reference,
      assignedStaffName: transfer.assignedStaffName,
      returnOfTransferId: transfer.returnOfTransferId,
      hasReturnTransfer: transfer.hasReturnTransfer,
      linkedReturnAttention: transfer.linkedReturnAttention,
      damageCase: transfer.damageCase,
      integrityIssue: transfer.integrityIssue,
      lines: [
        for (final line in lines)
          if (assets.containsKey(line['asset_id']))
            TransferLineRecord(
              id: line['id'] as String,
              asset: assets[line['asset_id']]!,
              requested: (line['requested_quantity'] as num).toInt(),
              dispatched: (line['dispatched_quantity'] as num).toInt(),
              received: (line['received_quantity'] as num).toInt(),
              damaged: (line['damaged_quantity'] as num).toInt(),
            ),
      ],
    );
  }

  Future<List<TransferAssetSummary>> assetsAtOrigin({
    required String companyId,
    required String originId,
    String? query,
  }) async {
    dynamic request = _client
        .from('assets')
        .select('id,mode,name,serial_number,quantity,location_id,created_at')
        .eq('workspace_id', companyId)
        .eq('location_id', originId)
        .isFilter('archived_at', null);
    if (query?.trim().isNotEmpty == true) {
      final term = query!.trim();
      request = request.or('name.ilike.%$term%,serial_number.ilike.%$term%');
    }
    final rows = await withRelayRequestTimeout(request.order('name').limit(10));
    return [
      for (final raw in rows as List)
        TransferAssetSummary.fromMap({
          ...Map<String, dynamic>.from(raw as Map),
        }),
    ];
  }

  Future<String> create({
    required String customerId,
    required String originId,
    required String destinationId,
    required DateTime start,
    required DateTime end,
    required String? reference,
    required String assignedStaffId,
    required List<TransferDraftLine> lines,
    required String requestKey,
  }) async =>
      await withRelayRequestTimeout(
            _client.rpc(
              'create_transfer',
              params: {
                'target_customer_id': customerId,
                'target_origin_id': originId,
                'target_destination_id': destinationId,
                'target_start_date': _date(start),
                'target_end_date': _date(end),
                'target_reference': reference?.trim() ?? '',
                'target_assigned_staff_id': assignedStaffId,
                'requested_lines': _draftLines(lines),
                'request_key': requestKey,
              },
            ),
          )
          as String;

  Future<TransferRecord> update({
    required TransferRecord transfer,
    required String customerId,
    required String originId,
    required String destinationId,
    required DateTime start,
    required DateTime end,
    required String? reference,
    required String assignedStaffId,
    required List<TransferDraftLine> lines,
    required String requestKey,
  }) async {
    await withRelayRequestTimeout(
      _client.rpc(
        'update_prepare_transfer',
        params: {
          'target_transfer_id': transfer.id,
          'target_customer_id': customerId,
          'target_origin_id': originId,
          'target_destination_id': destinationId,
          'target_start_date': _date(start),
          'target_end_date': _date(end),
          'target_reference': reference?.trim() ?? '',
          'target_assigned_staff_id': assignedStaffId,
          'requested_lines': _draftLines(lines),
          'request_key': requestKey,
        },
      ),
    );
    final saved = await detail(transfer.companyId, transfer.id);
    if (saved == null) {
      throw StateError('Updated Transfer is not readable.');
    }
    return saved;
  }

  Future<void> dispatch(
    TransferRecord transfer,
    Map<String, int> actual, {
    required String requestKey,
  }) => withRelayRequestTimeout(
    _client.rpc(
      'dispatch_outbound_transfer',
      params: {
        'target_transfer_id': transfer.id,
        'actual_lines': [
          for (final line in transfer.lines)
            if ((actual[line.id] ?? line.requested) > 0)
              {
                'line_id': line.id,
                'quantity': actual[line.id] ?? line.requested,
              },
        ],
        'request_key': requestKey,
      },
    ),
  );

  Future<void> markDamageFixed(String transferId) => withRelayRequestTimeout(
    _client.rpc(
      'mark_transfer_damage_fixed',
      params: {'target_return_transfer_id': transferId},
    ),
  );

  Future<void> clearDamageAlert(String transferId) => withRelayRequestTimeout(
    _client.rpc(
      'clear_transfer_damage_alert',
      params: {'target_return_transfer_id': transferId},
    ),
  );

  Future<void> startReturn(
    TransferRecord transfer, {
    required String requestKey,
  }) => withRelayRequestTimeout(
    _client.rpc(
      'start_return_transfer',
      params: {'target_transfer_id': transfer.id, 'request_key': requestKey},
    ),
  );

  Future<void> completeReturn(
    TransferRecord transfer,
    Map<String, ({int received, int damaged})> values, {
    required String requestKey,
  }) => withRelayRequestTimeout(
    _client.rpc(
      'complete_return_transfer',
      params: {
        'target_transfer_id': transfer.id,
        'received_lines': [
          for (final line in transfer.lines)
            {
              'line_id': line.id,
              'received_quantity': values[line.id]?.received ?? 0,
              'damaged_quantity': values[line.id]?.damaged ?? 0,
            },
        ],
        'request_key': requestKey,
      },
    ),
  );

  Future<String> createReturn({
    required TransferRecord outbound,
    required DateTime start,
    required DateTime end,
    required String staffId,
    required String requestKey,
  }) async =>
      await withRelayRequestTimeout(
            _client.rpc(
              'create_return_transfer',
              params: {
                'target_outbound_transfer_id': outbound.id,
                'target_start_date': _date(start),
                'target_end_date': _date(end),
                'target_assigned_staff_id': staffId,
                'request_key': requestKey,
              },
            ),
          )
          as String;

  Future<List<TransferRecord>> _hydrate(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return const [];
    final customerIds = rows.map((row) => row['customer_id'] as String).toSet();
    final locationIds = rows
        .expand(
          (row) => [
            row['origin_location_id'] as String,
            row['destination_location_id'] as String,
          ],
        )
        .toSet();
    final peopleIds = rows
        .expand(
          (row) => [
            row['created_by'] as String,
            if (row['assigned_staff_id'] != null)
              row['assigned_staff_id'] as String,
          ],
        )
        .toSet();
    final transferIds = rows.map((row) => row['id'] as String).toList();
    final results = await Future.wait([
      withRelayRequestTimeout(
        _client
            .from('customers')
            .select('id,name,contact_name,email,phone,created_at')
            .inFilter('id', customerIds.toList()),
      ),
      withRelayRequestTimeout(
        _client
            .from('locations')
            .select('id,name,type,created_at')
            .inFilter('id', locationIds.toList()),
      ),
      withRelayRequestTimeout(
        _client
            .from('profiles')
            .select('user_id,display_name')
            .inFilter('user_id', peopleIds.toList()),
      ),
      withRelayRequestTimeout(
        _client
            .from('transfer_damage_cases')
            .select('return_transfer_id,status,fixed_at,cleared_at,updated_at')
            .inFilter('return_transfer_id', transferIds),
      ),
      _returnSummaries(transferIds),
    ]);
    final customerRows = results[0] as List;
    final locationRows = results[1] as List;
    final profileRows = results[2] as List;
    final damageRows = results[3] as List;
    final returnSummaries = results[4] as Map<String, _ReturnSummary>;
    final customers = {
      for (final raw in customerRows)
        (raw as Map)['id'] as String: CustomerRecord.fromMap({
          ...Map<String, dynamic>.from(raw),
          'active_transfer_count': 0,
        }),
    };
    final locations = {
      for (final raw in locationRows)
        (raw as Map)['id'] as String: LocationRecord.fromMap(
          Map<String, dynamic>.from(raw),
        ),
    };
    final damageCases = {
      for (final raw in damageRows)
        (raw as Map)['return_transfer_id'] as String:
            TransferDamageCase.fromMap(Map<String, dynamic>.from(raw)),
    };
    final names = {
      for (final raw in profileRows)
        (raw as Map)['user_id'] as String: raw['display_name'] as String?,
    };
    return [
      for (final row in rows)
        TransferRecord(
          id: row['id'] as String,
          companyId: row['workspace_id'] as String,
          customer: customers[row['customer_id']],
          origin: locations[row['origin_location_id']],
          destination: locations[row['destination_location_id']],
          direction: TransferDirection.fromWire(row['direction'] as String),
          status: TransferStatus.fromWire(row['status'] as String),
          reference: row['reference'] as String?,
          startDate: DateTime.parse(row['scheduled_start_date'] as String),
          endDate: DateTime.parse(row['scheduled_end_date'] as String),
          assignedStaffId: row['assigned_staff_id'] as String?,
          createdBy: row['created_by'] as String,
          assignedStaffName: names[row['assigned_staff_id']],
          returnOfTransferId: row['return_of_transfer_id'] as String?,
          hasReturnTransfer: returnSummaries[row['id']]?.hasTransfer ?? false,
          linkedReturnAttention:
              returnSummaries[row['id']]?.attention ?? TransferAttention.none,
          damageCase: damageCases[row['id']],
          integrityIssue:
              customers.containsKey(row['customer_id']) &&
                  locations.containsKey(row['origin_location_id']) &&
                  locations.containsKey(row['destination_location_id'])
              ? null
              : TransferIntegrityIssue.missingRelatedData,
        ),
    ];
  }

  Future<Map<String, _ReturnSummary>> _returnSummaries(
    Iterable<String> outboundIds,
  ) async {
    final ids = outboundIds.toSet().toList();
    if (ids.isEmpty) return const {};
    final rows = await withRelayRequestTimeout(
      _client
          .from('transfers')
          .select(
            'return_of_transfer_id,status,scheduled_start_date,scheduled_end_date',
          )
          .inFilter('return_of_transfer_id', ids)
          .isFilter('cancelled_at', null),
    );
    final summaries = <String, _ReturnSummary>{};
    final today = DateTime.now();
    for (final raw in rows as List) {
      final row = Map<String, dynamic>.from(raw as Map);
      final parentId = row['return_of_transfer_id'] as String?;
      if (parentId == null) continue;
      final attention = deriveTransferAttention(
        direction: TransferDirection.toWarehouse,
        status: TransferStatus.fromWire(row['status'] as String),
        startDate: DateTime.parse(row['scheduled_start_date'] as String),
        endDate: DateTime.parse(row['scheduled_end_date'] as String),
        today: today,
      );
      final previous = summaries[parentId];
      summaries[parentId] = _ReturnSummary(
        hasTransfer: true,
        attention: attention == TransferAttention.none
            ? previous?.attention ?? TransferAttention.none
            : attention,
      );
    }
    return summaries;
  }

  Future<Map<String, TransferAssetSummary>> _assetsByIds(
    Iterable<String> ids,
  ) async {
    final rows = await withRelayRequestTimeout(
      _client
          .from('assets')
          .select('id,mode,name,serial_number,quantity,location_id,created_at')
          .inFilter('id', ids.toSet().toList()),
    );
    return {
      for (final raw in rows as List)
        (raw as Map)['id'] as String: TransferAssetSummary.fromMap({
          ...Map<String, dynamic>.from(raw),
        }),
    };
  }

  List<Map<String, dynamic>> _draftLines(List<TransferDraftLine> lines) => [
    for (final line in lines)
      {'asset_id': line.asset.id, 'quantity': line.quantity},
  ];
  String _date(DateTime value) => value.toIso8601String().substring(0, 10);
}
