import 'dart:typed_data';

const assetImportTemplateVersion = 1;

enum AssetImportType { serialized, bulk }

extension AssetImportTypeWire on AssetImportType {
  String get wireValue => switch (this) {
    AssetImportType.serialized => 'SERIALIZED',
    AssetImportType.bulk => 'BULK',
  };
}

class AssetImportFieldDefinition {
  const AssetImportFieldDefinition({
    required this.key,
    required this.required,
    required this.label,
    required this.aliases,
  });

  final String key;
  final bool required;
  final String label;
  final List<String> aliases;
}

class AssetImportSchema {
  const AssetImportSchema({required this.type, required this.fields});

  final AssetImportType type;
  final List<AssetImportFieldDefinition> fields;

  Set<String> get fieldKeys => {for (final field in fields) field.key};
}

class AssetImportLimits {
  const AssetImportLimits({
    this.maxRows = 500,
    this.maxFileBytes = 5 * 1024 * 1024,
  });

  final int maxRows;
  final int maxFileBytes;
}

class AssetImportRequest {
  const AssetImportRequest({
    required this.bytes,
    required this.fileName,
    required this.locale,
    this.type,
    this.limits = const AssetImportLimits(),
  });

  final Uint8List bytes;
  final String fileName;
  final AssetImportType? type;
  final String locale;
  final AssetImportLimits limits;
}

class AssetImportBatchRow {
  const AssetImportBatchRow({
    required this.sourceRowNumber,
    required this.type,
    required this.name,
    required this.warehouse,
    this.serialCode,
    this.quantity,
    this.confirmBulkMerge = false,
  });

  final int sourceRowNumber;
  final AssetImportType type;
  final String name;
  final String warehouse;
  final String? serialCode;
  final String? quantity;
  final bool confirmBulkMerge;

  Map<String, dynamic> toRpcMap() => {
    'source_row_number': sourceRowNumber,
    'mode': type.wireValue,
    'name': name,
    'warehouse': warehouse,
    if (serialCode != null) 'serial_code': serialCode,
    if (quantity != null) 'quantity': quantity,
    if (confirmBulkMerge) 'confirm_bulk_merge': true,
  };
}

class AssetImportBatchCommitRequest {
  const AssetImportBatchCommitRequest({
    required this.companyId,
    required this.fileName,
    required this.fileHash,
    required this.fileSizeBytes,
    required this.batchKey,
    required this.rows,
  });

  final String companyId;
  final String fileName;
  final String fileHash;
  final int fileSizeBytes;
  final String batchKey;
  final List<AssetImportBatchRow> rows;
}

class AssetImportBatchRowResult {
  const AssetImportBatchRowResult({
    required this.batchId,
    required this.sourceRowNumber,
    required this.status,
    this.assetId,
    this.action,
    this.errorCode,
    this.errorMessage,
  });

  factory AssetImportBatchRowResult.fromMap(Map<String, dynamic> map) {
    return AssetImportBatchRowResult(
      batchId: map['batch_id'] as String,
      sourceRowNumber: (map['source_row_number'] as num).toInt(),
      status: map['status'] as String,
      assetId: map['asset_id'] as String?,
      action: map['action'] as String?,
      errorCode: map['error_code'] as String?,
      errorMessage: map['error_message'] as String?,
    );
  }

  final String batchId;
  final int sourceRowNumber;
  final String status;
  final String? assetId;
  final String? action;
  final String? errorCode;
  final String? errorMessage;
}

class AssetImportColumnMapping {
  const AssetImportColumnMapping({
    required this.sourceColumnIndex,
    required this.sourceHeader,
    required this.canonicalKey,
    required this.isExact,
    required this.ambiguous,
  });

  final int sourceColumnIndex;
  final String sourceHeader;
  final String? canonicalKey;
  final bool isExact;
  final bool ambiguous;
}

class AssetImportDecodedRow {
  const AssetImportDecodedRow({
    required this.rowNumber,
    required this.values,
    this.type,
    this.expectedType,
    this.canonicalValues = const <String, String?>{},
  });

  final int rowNumber;
  final List<String?> values;
  final AssetImportType? type;
  final AssetImportType? expectedType;
  final Map<String, String?> canonicalValues;
}

class AssetImportDecodedFile {
  const AssetImportDecodedFile({
    this.type,
    required this.locale,
    required this.isTemplate,
    required this.metadataValid,
    required this.metadataHidden,
    required this.templateVersion,
    required this.sheetNames,
    required this.headers,
    required this.rows,
    required this.mappings,
    required this.requiresManualMapping,
    required this.metadata,
  });

  final AssetImportType? type;
  final String locale;
  final bool isTemplate;
  final bool metadataValid;
  final bool metadataHidden;
  final int? templateVersion;
  final List<String> sheetNames;
  final List<String> headers;
  final List<AssetImportDecodedRow> rows;
  final List<AssetImportColumnMapping> mappings;
  final bool requiresManualMapping;
  final Map<String, String> metadata;
}

class AssetImportException extends FormatException {
  AssetImportException(this.code, String message) : super(message);

  final String code;
}
