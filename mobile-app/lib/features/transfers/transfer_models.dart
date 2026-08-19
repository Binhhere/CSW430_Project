import '../assets/asset_domain.dart';
import '../catalog/catalog_models.dart';

enum TransferDirection {
  toCustomer('TO_CUSTOMER'),
  toWarehouse('TO_WAREHOUSE');

  const TransferDirection(this.wireValue);
  final String wireValue;

  factory TransferDirection.fromWire(String value) => switch (value) {
    'TO_CUSTOMER' => TransferDirection.toCustomer,
    'TO_WAREHOUSE' => TransferDirection.toWarehouse,
    _ => throw FormatException('Unknown Transfer direction: $value'),
  };
}

enum TransferStatus {
  prepare('PREPARE'),
  inTransit('IN_TRANSIT'),
  done('DONE');

  const TransferStatus(this.wireValue);
  final String wireValue;

  factory TransferStatus.fromWire(String value) => switch (value) {
    'PREPARE' => TransferStatus.prepare,
    'IN_TRANSIT' => TransferStatus.inTransit,
    'DONE' => TransferStatus.done,
    _ => throw FormatException('Unknown Transfer status: $value'),
  };
}

enum TransferDamageStatus {
  open('OPEN'),
  fixed('FIXED'),
  cleared('CLEARED');

  const TransferDamageStatus(this.wireValue);
  final String wireValue;

  factory TransferDamageStatus.fromWire(String value) => switch (value) {
    'OPEN' => TransferDamageStatus.open,
    'FIXED' => TransferDamageStatus.fixed,
    'CLEARED' => TransferDamageStatus.cleared,
    _ => throw FormatException('Unknown damage status: $value'),
  };
}

enum EvidencePhase {
  departure('DEPARTURE'),
  arrival('ARRIVAL');

  const EvidencePhase(this.wireValue);
  final String wireValue;
}

class TransferLineRecord {
  const TransferLineRecord({
    required this.id,
    required this.asset,
    required this.requested,
    required this.dispatched,
    required this.received,
    required this.damaged,
  });
  final String id;
  final TransferAssetSummary asset;
  final int requested;
  final int dispatched;
  final int received;
  final int damaged;
}

class TransferDamageCase {
  const TransferDamageCase({
    required this.transferId,
    required this.status,
    required this.updatedAt,
    this.fixedAt,
    this.clearedAt,
  });

  factory TransferDamageCase.fromMap(Map<String, dynamic> value) =>
      TransferDamageCase(
        transferId: value['return_transfer_id'] as String,
        status: TransferDamageStatus.fromWire(value['status'] as String),
        fixedAt: value['fixed_at'] == null
            ? null
            : DateTime.parse(value['fixed_at'] as String),
        clearedAt: value['cleared_at'] == null
            ? null
            : DateTime.parse(value['cleared_at'] as String),
        updatedAt: DateTime.parse(value['updated_at'] as String),
      );

  final String transferId;
  final TransferDamageStatus status;
  final DateTime? fixedAt;
  final DateTime? clearedAt;
  final DateTime updatedAt;

  bool get isOpen => status == TransferDamageStatus.open;
  bool get isFixed => status == TransferDamageStatus.fixed;
  bool get isCleared => status == TransferDamageStatus.cleared;
}

enum TransferAttention {
  none,
  dispatchOverdue,
  deliveryOverdue,
  returnPickupOverdue,
  returnOverdue,
}

enum TransferIntegrityIssue { missingRelatedData }

TransferAttention deriveTransferAttention({
  required TransferDirection direction,
  required TransferStatus status,
  required DateTime startDate,
  required DateTime endDate,
  required DateTime today,
  bool hasReturnTransfer = false,
  TransferAttention linkedReturnAttention = TransferAttention.none,
}) {
  final day = DateTime(today.year, today.month, today.day);
  final start = DateTime(startDate.year, startDate.month, startDate.day);
  final end = DateTime(endDate.year, endDate.month, endDate.day);
  final isOutbound = direction == TransferDirection.toCustomer;

  switch (status) {
    case TransferStatus.prepare:
      if (day.isAfter(start)) {
        return isOutbound
            ? TransferAttention.dispatchOverdue
            : TransferAttention.returnPickupOverdue;
      }
    case TransferStatus.inTransit:
      if (isOutbound && day.isAfter(start)) {
        return TransferAttention.deliveryOverdue;
      }
      if (!isOutbound && day.isAfter(end)) {
        return TransferAttention.returnOverdue;
      }
    case TransferStatus.done:
      if (isOutbound) {
        if (linkedReturnAttention != TransferAttention.none) {
          return linkedReturnAttention;
        }
        if (!hasReturnTransfer && day.isAfter(end)) {
          return TransferAttention.returnOverdue;
        }
      }
  }
  return TransferAttention.none;
}

class TransferRecord {
  const TransferRecord({
    required this.id,
    required this.companyId,
    this.customer,
    this.origin,
    this.destination,
    required this.direction,
    required this.status,
    required this.startDate,
    required this.endDate,
    required this.assignedStaffId,
    required this.createdBy,
    this.reference,
    this.assignedStaffName,
    this.returnOfTransferId,
    this.hasReturnTransfer = false,
    this.linkedReturnAttention = TransferAttention.none,
    this.damageCase,
    this.lines = const [],
    this.integrityIssue,
  });
  final String id;
  final String companyId;
  final CustomerRecord? customer;
  final LocationRecord? origin;
  final LocationRecord? destination;
  final TransferDirection direction;
  final TransferStatus status;
  final DateTime startDate;
  final DateTime endDate;
  final String? reference;
  final String? assignedStaffId;
  final String createdBy;
  final String? assignedStaffName;
  final String? returnOfTransferId;
  final bool hasReturnTransfer;
  final TransferAttention linkedReturnAttention;
  final TransferDamageCase? damageCase;
  final List<TransferLineRecord> lines;
  final TransferIntegrityIssue? integrityIssue;

  bool get isReturn => direction == TransferDirection.toWarehouse;
  bool get isPrepare => status == TransferStatus.prepare;
  bool get isInTransit => status == TransferStatus.inTransit;
  bool get isDone => status == TransferStatus.done;
  String get displayTitle => reference?.trim().isNotEmpty == true
      ? reference!.trim()
      : customer?.name ?? 'Transfer';
  String get customerName => customer?.name ?? 'Unavailable';
  String get originName => origin?.name ?? 'Unavailable';
  String get destinationName => destination?.name ?? 'Unavailable';
  bool get hasVisibleDamageAlert =>
      damageCase != null && !damageCase!.isCleared;

  TransferAttention attention({DateTime? today}) => deriveTransferAttention(
    direction: direction,
    status: status,
    startDate: startDate,
    endDate: endDate,
    today: today ?? DateTime.now(),
    hasReturnTransfer: hasReturnTransfer,
    linkedReturnAttention: linkedReturnAttention,
  );

  TransferRecord copyWith({
    CustomerRecord? customer,
    LocationRecord? origin,
    LocationRecord? destination,
    TransferDirection? direction,
    TransferStatus? status,
    DateTime? startDate,
    DateTime? endDate,
    String? reference,
    String? assignedStaffId,
    String? assignedStaffName,
    bool? hasReturnTransfer,
    TransferAttention? linkedReturnAttention,
    List<TransferLineRecord>? lines,
    TransferDamageCase? damageCase,
    TransferIntegrityIssue? integrityIssue,
  }) => TransferRecord(
    id: id,
    companyId: companyId,
    customer: customer ?? this.customer,
    origin: origin ?? this.origin,
    destination: destination ?? this.destination,
    direction: direction ?? this.direction,
    status: status ?? this.status,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    assignedStaffId: assignedStaffId ?? this.assignedStaffId,
    createdBy: createdBy,
    reference: reference ?? this.reference,
    assignedStaffName: assignedStaffName ?? this.assignedStaffName,
    returnOfTransferId: returnOfTransferId,
    hasReturnTransfer: hasReturnTransfer ?? this.hasReturnTransfer,
    linkedReturnAttention: linkedReturnAttention ?? this.linkedReturnAttention,
    damageCase: damageCase ?? this.damageCase,
    lines: lines ?? this.lines,
    integrityIssue: integrityIssue ?? this.integrityIssue,
  );
}

class TransferDraftLine {
  const TransferDraftLine({required this.asset, required this.quantity});
  final TransferAssetSummary asset;
  final int quantity;
  TransferDraftLine copyWith({int? quantity}) =>
      TransferDraftLine(asset: asset, quantity: quantity ?? this.quantity);
}

class TransferAssetSummary {
  const TransferAssetSummary({
    required this.id,
    required this.mode,
    required this.name,
    required this.serialNumber,
    required this.quantity,
    required this.locationId,
  });

  factory TransferAssetSummary.fromMap(Map<String, dynamic> value) =>
      TransferAssetSummary(
        id: value['id'] as String,
        mode: AssetMode.fromWire(value['mode'] as String),
        name: value['name'] as String,
        serialNumber: value['serial_number'] as String?,
        quantity: (value['quantity'] as num?)?.toInt(),
        locationId: value['location_id'] as String,
      );

  final String id;
  final AssetMode mode;
  final String name;
  final String? serialNumber;
  final int? quantity;
  final String locationId;

  bool get isSerialized => mode == AssetMode.serialized;
}
