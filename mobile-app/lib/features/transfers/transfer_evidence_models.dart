class TransferEvidenceRecord {
  const TransferEvidenceRecord({
    required this.id,
    required this.lineId,
    required this.assetName,
    required this.storagePath,
    required this.thumbnailPath,
    required this.createdAt,
    this.expiresAt,
    this.fileDeletedAt,
  });

  factory TransferEvidenceRecord.fromMap(Map<String, dynamic> value) =>
      TransferEvidenceRecord(
        id: value['id'] as String,
        lineId: value['transfer_line_id'] as String,
        assetName: value['asset_name'] as String,
        storagePath: value['storage_path'] as String,
        thumbnailPath: value['thumbnail_path'] as String,
        createdAt: DateTime.parse(value['created_at'] as String),
        expiresAt: value['expires_at'] == null
            ? null
            : DateTime.parse(value['expires_at'] as String),
        fileDeletedAt: value['file_deleted_at'] == null
            ? null
            : DateTime.parse(value['file_deleted_at'] as String),
      );

  final String id;
  final String lineId;
  final String assetName;
  final String storagePath;
  final String thumbnailPath;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final DateTime? fileDeletedAt;
  bool get isExpired => fileDeletedAt != null;
}
