enum LocationType {
  warehouse('WAREHOUSE'),
  deliveryPlace('DELIVERY_PLACE');

  const LocationType(this.wireValue);
  final String wireValue;

  factory LocationType.fromWire(String value) => switch (value) {
    'WAREHOUSE' => LocationType.warehouse,
    'DELIVERY_PLACE' => LocationType.deliveryPlace,
    _ => throw FormatException('Unknown Location type: $value'),
  };
}

class CustomerRecord {
  const CustomerRecord({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.activeTransferCount,
    this.archivedAt,
    this.contactName,
    this.email,
    this.phone,
  });

  factory CustomerRecord.fromMap(Map<String, dynamic> value) => CustomerRecord(
    id: value['id'] as String,
    name: value['name'] as String,
    contactName: value['contact_name'] as String?,
    email: value['email'] as String?,
    phone: value['phone'] as String?,
    createdAt: DateTime.parse(value['created_at'] as String),
    archivedAt: value['archived_at'] == null
        ? null
        : DateTime.parse(value['archived_at'] as String),
    activeTransferCount: (value['active_transfer_count'] as num?)?.toInt() ?? 0,
  );

  final String id;
  final String name;
  final String? contactName;
  final String? email;
  final String? phone;
  final DateTime createdAt;
  final DateTime? archivedAt;
  final int activeTransferCount;

  bool get isArchived => archivedAt != null;
}

class LocationRecord {
  const LocationRecord({
    required this.id,
    required this.name,
    required this.type,
    required this.createdAt,
    this.archivedAt,
  });

  factory LocationRecord.fromMap(Map<String, dynamic> value) => LocationRecord(
    id: value['id'] as String,
    name: value['name'] as String,
    type: LocationType.fromWire(value['type'] as String),
    createdAt: DateTime.parse(value['created_at'] as String),
    archivedAt: value['archived_at'] == null
        ? null
        : DateTime.parse(value['archived_at'] as String),
  );

  final String id;
  final String name;
  final LocationType type;
  final DateTime createdAt;
  final DateTime? archivedAt;

  bool get isArchived => archivedAt != null;
}
