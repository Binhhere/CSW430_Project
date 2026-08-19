import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_config.dart';
import '../../data/course_api_client.dart';
import '../../shared/request_timeout.dart';
import '../../shared/entity_lifecycle.dart';
import 'catalog_models.dart';

final catalogRepositoryProvider = Provider<CatalogRepository>(
  (_) => CatalogRepository(CourseApiClient(AppConfig.current.apiBaseUrl)),
);

class CatalogRepository {
  CatalogRepository(dynamic legacyClientOrApi, [CourseApiClient? api])
    : _client = legacyClientOrApi is CourseApiClient
          ? null
          : legacyClientOrApi,
      _api = legacyClientOrApi is CourseApiClient
          ? legacyClientOrApi
          : api ?? CourseApiClient(AppConfig.current.apiBaseUrl);
  final dynamic _client;
  final CourseApiClient _api;

  Future<List<CustomerRecord>> customers({
    required String companyId,
    String? query,
    CustomerRecord? after,
    ArchiveScope archiveScope = ArchiveScope.working,
  }) async {
    final data = await withRelayRequestTimeout(
      _api.get(
        '/api/v1/customers',
        query: {
          if (_emptyToNull(query) != null) 'query': _emptyToNull(query)!,
          'archiveScope': archiveScope.wireValue,
          'limit': '10',
        },
      ),
    );
    final rows = data is List ? data : const [];
    return [
      for (final row in rows)
        CustomerRecord.fromMap(Map<String, dynamic>.from(row as Map)),
    ];
  }

  Future<List<LocationRecord>> locations({
    required String companyId,
    String? query,
    LocationType? type,
    LocationRecord? after,
    ArchiveScope archiveScope = ArchiveScope.working,
  }) async {
    final rows = await withRelayRequestTimeout(
      _client.rpc(
        'list_locations',
        params: {
          'target_workspace_id': companyId,
          'query_text': _emptyToNull(query),
          'type_filter': type?.wireValue,
          'after_name': after?.name,
          'after_id': after?.id,
          'page_size': 10,
          'archive_scope': archiveScope.wireValue,
        },
      ),
    );
    return [
      for (final row in rows as List)
        LocationRecord.fromMap(Map<String, dynamic>.from(row as Map)),
    ];
  }

  Future<CustomerRecord?> customer(String companyId, String customerId) async {
    try {
      final row = await withRelayRequestTimeout(
        _api.get('/api/v1/customers/$customerId'),
      );
      return CustomerRecord.fromMap(row);
    } on CourseApiException catch (error) {
      if (error.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<LocationRecord?> location(String companyId, String locationId) async {
    final row = await withRelayRequestTimeout(
      _client
          .from('locations')
          .select('id,name,type,created_at,archived_at')
          .eq('workspace_id', companyId)
          .eq('id', locationId)
          .maybeSingle(),
    );
    return row == null ? null : LocationRecord.fromMap(row);
  }

  Future<CustomerRecord> saveCustomer({
    required String companyId,
    String? customerId,
    required String name,
    String? contactName,
    String? email,
    String? phone,
  }) async {
    final data = {
      'name': name.trim(),
      'contactName': _emptyToNull(contactName),
      'email': _emptyToNull(email),
      'phone': _emptyToNull(phone),
    };
    final row = await withRelayRequestTimeout(
      customerId == null
          ? _api.post('/api/v1/customers', data)
          : _api.put('/api/v1/customers/$customerId', data),
    );
    return CustomerRecord.fromMap(row);
  }

  Future<LocationRecord> saveLocation({
    required String companyId,
    String? locationId,
    required String name,
    required LocationType type,
  }) async {
    final rows = await withRelayRequestTimeout(
      _client.rpc(
        'save_location',
        params: {
          'target_workspace_id': companyId,
          'target_location_id': locationId,
          'target_name': name.trim(),
          'target_type': type.wireValue,
        },
      ),
    );
    return LocationRecord.fromMap(
      Map<String, dynamic>.from((rows as List).single as Map),
    );
  }

  Future<List<LifecyclePreview>> previewLifecycle({
    required LifecycleEntityType entityType,
    required List<String> ids,
    required LifecycleOperation operation,
  }) async {
    if (entityType == LifecycleEntityType.customer) {
      return [
        for (final id in ids)
          LifecyclePreview(
            entityType: entityType.wireValue,
            entityId: id,
            entityName: id,
            eligible: true,
            activeTransferCount: 0,
            historicalReferenceCount: 0,
            dependencyCount: 0,
          ),
      ];
    }
    final rows = await withRelayRequestTimeout(
      _client.rpc(
        'preview_catalog_lifecycle',
        params: {
          'target_type': entityType.wireValue,
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
    required LifecycleEntityType entityType,
    required List<String> ids,
    required LifecycleOperation operation,
  }) async {
    if (entityType == LifecycleEntityType.customer) {
      final results = <LifecycleResult>[];
      for (final id in ids) {
        if (operation == LifecycleOperation.delete) {
          await withRelayRequestTimeout(_api.delete('/api/v1/customers/$id'));
        } else {
          await withRelayRequestTimeout(
            _api.put('/api/v1/customers/$id', {
              'archived': operation == LifecycleOperation.archive,
            }),
          );
        }
        results.add(
          LifecycleResult(
            entityType: entityType.wireValue,
            entityId: id,
            entityName: id,
            applied: true,
          ),
        );
      }
      return results;
    }
    final rows = await withRelayRequestTimeout(
      _client.rpc(
        'apply_catalog_lifecycle',
        params: {
          'target_type': entityType.wireValue,
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

  String? _emptyToNull(String? value) {
    final result = value?.trim();
    return result == null || result.isEmpty ? null : result;
  }
}
