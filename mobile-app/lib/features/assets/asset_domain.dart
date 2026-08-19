enum AssetMode {
  serialized('SERIALIZED'),
  bulk('BULK');

  const AssetMode(this.wireValue);
  final String wireValue;

  factory AssetMode.fromWire(String value) => switch (value) {
    'SERIALIZED' => AssetMode.serialized,
    'BULK' => AssetMode.bulk,
    _ => throw FormatException('Unknown Asset mode: $value'),
  };
}

enum AssetWorkingState {
  atWarehouse('AT_WAREHOUSE'),
  assigned('ASSIGNED'),
  inTransit('IN_TRANSIT'),
  archived('ARCHIVED');

  const AssetWorkingState(this.wireValue);
  final String wireValue;

  factory AssetWorkingState.fromWire(String value) => switch (value) {
    'AT_WAREHOUSE' => AssetWorkingState.atWarehouse,
    'ASSIGNED' => AssetWorkingState.assigned,
    'IN_TRANSIT' => AssetWorkingState.inTransit,
    'ARCHIVED' => AssetWorkingState.archived,
    _ => throw FormatException('Unknown Asset working state: $value'),
  };
}

enum AssetSaveAction {
  created('CREATED'),
  updated('UPDATED'),
  confirmRequired('CONFIRM_REQUIRED'),
  merged('MERGED');

  const AssetSaveAction(this.wireValue);
  final String wireValue;

  factory AssetSaveAction.fromWire(String value) => switch (value) {
    'CREATED' => AssetSaveAction.created,
    'UPDATED' => AssetSaveAction.updated,
    'CONFIRM_REQUIRED' => AssetSaveAction.confirmRequired,
    'MERGED' => AssetSaveAction.merged,
    _ => throw FormatException('Unknown Asset save action: $value'),
  };
}

class AssetRecord {
  const AssetRecord({
    required this.id,
    required this.mode,
    required this.name,
    required this.locationId,
    required this.locationName,
    required this.workingState,
    required this.stateRank,
    required this.createdAt,
    this.serialNumber,
    this.qrToken,
    this.quantity,
    this.storagePath,
  });

  factory AssetRecord.fromMap(Map<String, dynamic> value) => AssetRecord(
    id: value['id'] as String,
    mode: AssetMode.fromWire(value['mode'] as String),
    name: value['name'] as String,
    serialNumber: value['serial_number'] as String?,
    qrToken: value['qr_token'] as String?,
    quantity: (value['quantity'] as num?)?.toInt(),
    locationId: value['location_id'] as String,
    locationName: value['location_name'] as String,
    workingState: AssetWorkingState.fromWire(value['working_state'] as String),
    stateRank: (value['state_rank'] as num).toInt(),
    storagePath: value['storage_path'] as String?,
    createdAt: DateTime.parse(value['created_at'] as String),
  );

  final String id;
  final AssetMode mode;
  final String name;
  final String? serialNumber;
  final String? qrToken;
  final int? quantity;
  final String locationId;
  final String locationName;
  final AssetWorkingState workingState;
  final int stateRank;
  final String? storagePath;
  final DateTime createdAt;

  bool get isSerialized => mode == AssetMode.serialized;
  bool get isArchived => workingState == AssetWorkingState.archived;

  AssetRecord copyWith({
    String? name,
    String? locationId,
    String? locationName,
    AssetWorkingState? workingState,
    int? stateRank,
    int? quantity,
    String? storagePath,
    bool clearStoragePath = false,
  }) => AssetRecord(
    id: id,
    mode: mode,
    name: name ?? this.name,
    serialNumber: serialNumber,
    qrToken: qrToken,
    quantity: quantity ?? this.quantity,
    locationId: locationId ?? this.locationId,
    locationName: locationName ?? this.locationName,
    workingState: workingState ?? this.workingState,
    stateRank: stateRank ?? this.stateRank,
    storagePath: clearStoragePath ? null : storagePath ?? this.storagePath,
    createdAt: createdAt,
  );
}

class AssetSaveResult {
  const AssetSaveResult({
    required this.assetId,
    required this.action,
    this.currentQuantity,
    this.newQuantity,
  });

  factory AssetSaveResult.fromMap(Map<String, dynamic> value) =>
      AssetSaveResult(
        assetId: value['asset_id'] as String,
        action: AssetSaveAction.fromWire(value['action'] as String),
        currentQuantity: (value['current_quantity'] as num?)?.toInt(),
        newQuantity: (value['new_quantity'] as num?)?.toInt(),
      );

  final String assetId;
  final AssetSaveAction action;
  final int? currentQuantity;
  final int? newQuantity;
  bool get needsMergeConfirmation => action == AssetSaveAction.confirmRequired;
  bool get isMerged => action == AssetSaveAction.merged;
}
