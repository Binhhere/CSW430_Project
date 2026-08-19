enum ArchiveScope {
  working('WORKING'),
  archived('ARCHIVED');

  const ArchiveScope(this.wireValue);
  final String wireValue;
}

enum LifecycleEntityType {
  asset('ASSET'),
  customer('CUSTOMER'),
  location('LOCATION');

  const LifecycleEntityType(this.wireValue);
  final String wireValue;
}

enum LifecycleOperation {
  archive('ARCHIVE'),
  restore('RESTORE'),
  delete('DELETE');

  const LifecycleOperation(this.wireValue);
  final String wireValue;
}

class LifecyclePreview {
  const LifecyclePreview({
    required this.entityType,
    required this.entityId,
    required this.entityName,
    required this.eligible,
    this.reason,
    required this.activeTransferCount,
    required this.historicalReferenceCount,
    required this.dependencyCount,
  });

  factory LifecyclePreview.fromMap(Map<String, dynamic> value) =>
      LifecyclePreview(
        entityType: value['entity_type'] as String,
        entityId: value['entity_id'] as String,
        entityName: value['entity_name'] as String,
        eligible: value['eligible'] as bool,
        reason: value['reason'] as String?,
        activeTransferCount:
            (value['active_transfer_count'] as num?)?.toInt() ?? 0,
        historicalReferenceCount:
            (value['historical_reference_count'] as num?)?.toInt() ?? 0,
        dependencyCount: (value['dependency_count'] as num?)?.toInt() ?? 0,
      );

  final String entityType;
  final String entityId;
  final String entityName;
  final bool eligible;
  final String? reason;
  final int activeTransferCount;
  final int historicalReferenceCount;
  final int dependencyCount;
}

class LifecycleResult {
  const LifecycleResult({
    required this.entityType,
    required this.entityId,
    required this.entityName,
    required this.applied,
    this.reason,
  });

  factory LifecycleResult.fromMap(Map<String, dynamic> value) =>
      LifecycleResult(
        entityType: value['entity_type'] as String,
        entityId: value['entity_id'] as String,
        entityName: value['entity_name'] as String,
        applied: value['applied'] as bool,
        reason: value['reason'] as String?,
      );

  final String entityType;
  final String entityId;
  final String entityName;
  final bool applied;
  final String? reason;
}
