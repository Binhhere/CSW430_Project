import 'asset_import_models.dart';
import 'asset_import_template_service.dart';

enum AssetImportPreviewRowStatus { valid, invalid, requiresConfirmation }

class AssetImportWarehouseOption {
  const AssetImportWarehouseOption({required this.name, this.id});

  final String name;
  final String? id;
}

class AssetImportExistingAsset {
  const AssetImportExistingAsset({
    required this.type,
    required this.name,
    required this.warehouse,
    this.serialCode,
    this.quantity,
  });

  final AssetImportType type;
  final String name;
  final String warehouse;
  final String? serialCode;
  final int? quantity;
}

class AssetImportPreviewContext {
  const AssetImportPreviewContext({
    required this.warehouses,
    required this.existingAssets,
    this.otherLocationNames = const <String>[],
  });

  final List<AssetImportWarehouseOption> warehouses;
  final List<AssetImportExistingAsset> existingAssets;
  final List<String> otherLocationNames;
}

class AssetImportPreviewRequest {
  const AssetImportPreviewRequest({
    required this.decoded,
    required this.context,
    this.mappingOverrides = const <int, String?>{},
    this.valueOverrides = const <int, Map<String, String?>>{},
  });

  final AssetImportDecodedFile decoded;
  final AssetImportPreviewContext context;
  final Map<int, String?> mappingOverrides;
  final Map<int, Map<String, String?>> valueOverrides;
}

class AssetImportPreviewIssue {
  const AssetImportPreviewIssue({
    required this.code,
    required this.message,
    this.fieldKey,
  });

  final String code;
  final String message;
  final String? fieldKey;
}

class AssetImportPreviewRow {
  const AssetImportPreviewRow({
    required this.rowNumber,
    required this.values,
    required this.canonicalValues,
    required this.status,
    required this.issues,
    this.type,
  });

  final int rowNumber;
  final List<String?> values;
  final Map<String, String?> canonicalValues;
  final AssetImportPreviewRowStatus status;
  final List<AssetImportPreviewIssue> issues;
  final AssetImportType? type;
}

extension AssetImportPreviewRowCommit on AssetImportPreviewRow {
  AssetImportBatchRow toBatchRow({bool confirmBulkMerge = false}) {
    final resolvedType = type;
    if (resolvedType == null) {
      throw StateError('Cannot commit an import row without a Mode.');
    }
    return AssetImportBatchRow(
      sourceRowNumber: rowNumber,
      type: resolvedType,
      name: canonicalValues['name'] ?? '',
      warehouse: canonicalValues['warehouse'] ?? '',
      serialCode: canonicalValues['serial_code'],
      quantity: canonicalValues['quantity'],
      confirmBulkMerge: confirmBulkMerge,
    );
  }
}

class AssetImportPreviewResult {
  const AssetImportPreviewResult({
    required this.mappings,
    required this.rows,
    required this.globalIssues,
  });

  final List<AssetImportColumnMapping> mappings;
  final List<AssetImportPreviewRow> rows;
  final List<AssetImportPreviewIssue> globalIssues;

  int get validRowCount => rows
      .where((row) => row.status == AssetImportPreviewRowStatus.valid)
      .length;

  int get invalidRowCount => rows
      .where((row) => row.status == AssetImportPreviewRowStatus.invalid)
      .length;

  int get confirmationRowCount => rows
      .where(
        (row) => row.status == AssetImportPreviewRowStatus.requiresConfirmation,
      )
      .length;

  bool get requiresConfirmation => confirmationRowCount > 0;

  bool get canCommit =>
      globalIssues.isEmpty &&
      (validRowCount > 0 || confirmationRowCount > 0) &&
      !requiresConfirmation;
}

class AssetImportPreviewer {
  AssetImportPreviewResult preview(AssetImportPreviewRequest request) {
    final decoded = request.decoded;
    final resources = AssetImportLocaleResources.forLocale(decoded.locale);
    final messages = _PreviewMessages.forLocale(decoded.locale);
    final mappings = _effectiveMappings(
      decoded.mappings,
      request.mappingOverrides,
    );
    final globalIssues = decoded.isTemplate
        ? const <AssetImportPreviewIssue>[]
        : _validateMappings(
            mappings,
            AssetImportSchemas.unified(resources),
            messages,
            requireMode:
                decoded.rows.isEmpty ||
                decoded.rows.any((row) => row.type == null),
          );
    if (globalIssues.isNotEmpty) {
      return AssetImportPreviewResult(
        mappings: List.unmodifiable(mappings),
        rows: [
          for (final row in decoded.rows)
            AssetImportPreviewRow(
              rowNumber: row.rowNumber,
              values: row.values,
              canonicalValues: const <String, String?>{},
              status: AssetImportPreviewRowStatus.invalid,
              issues: const <AssetImportPreviewIssue>[],
              type: row.type,
            ),
        ],
        globalIssues: List.unmodifiable(globalIssues),
      );
    }

    final valuesByRow = [
      for (final row in decoded.rows)
        _canonicalValues(row, mappings, request.valueOverrides[row.rowNumber]),
    ];
    final serialOccurrences = <String, int>{};
    final bulkOccurrences = <String, int>{};
    for (var index = 0; index < decoded.rows.length; index++) {
      final values = valuesByRow[index];
      final type = _rowType(decoded.rows[index], values);
      if (type == AssetImportType.serialized) {
        final serial = _normalized(values['serial_code']);
        if (serial != null) {
          serialOccurrences[serial] = (serialOccurrences[serial] ?? 0) + 1;
        }
      } else if (type == AssetImportType.bulk) {
        final key = _bulkKey(values['name'], values['warehouse']);
        if (key != null) bulkOccurrences[key] = (bulkOccurrences[key] ?? 0) + 1;
      }
    }

    final warehouseNames = {
      for (final warehouse in request.context.warehouses)
        _normalized(warehouse.name),
    };
    final otherLocationNames = {
      for (final name in request.context.otherLocationNames) _normalized(name),
    };
    final existingSerials = {
      for (final asset in request.context.existingAssets)
        if (asset.type == AssetImportType.serialized &&
            _normalized(asset.serialCode) != null)
          _normalized(asset.serialCode)!,
    };
    final existingBulkKeys = {
      for (final asset in request.context.existingAssets)
        if (asset.type == AssetImportType.bulk)
          _bulkKey(asset.name, asset.warehouse),
    };

    final rows = <AssetImportPreviewRow>[];
    for (var index = 0; index < decoded.rows.length; index++) {
      final sourceRow = decoded.rows[index];
      final values = valuesByRow[index];
      final type = _rowType(sourceRow, values);
      final issues = <AssetImportPreviewIssue>[];
      _validateCommon(
        values,
        type,
        sourceRow.expectedType,
        warehouseNames,
        otherLocationNames,
        messages,
        issues,
      );
      if (type == AssetImportType.serialized) {
        _validateSerialized(
          values,
          serialOccurrences,
          existingSerials,
          messages,
          issues,
        );
      } else if (type == AssetImportType.bulk) {
        _validateBulk(
          values,
          bulkOccurrences,
          existingBulkKeys,
          messages,
          issues,
        );
      }
      final needsConfirmation =
          issues.isNotEmpty &&
          issues.every((issue) => _confirmationCodes.contains(issue.code));
      rows.add(
        AssetImportPreviewRow(
          rowNumber: sourceRow.rowNumber,
          values: sourceRow.values,
          canonicalValues: Map.unmodifiable(values),
          status: !issues.isNotEmpty
              ? AssetImportPreviewRowStatus.valid
              : needsConfirmation
              ? AssetImportPreviewRowStatus.requiresConfirmation
              : AssetImportPreviewRowStatus.invalid,
          issues: List.unmodifiable(issues),
          type: type,
        ),
      );
    }
    return AssetImportPreviewResult(
      mappings: List.unmodifiable(mappings),
      rows: List.unmodifiable(rows),
      globalIssues: const <AssetImportPreviewIssue>[],
    );
  }

  List<AssetImportColumnMapping> _effectiveMappings(
    List<AssetImportColumnMapping> mappings,
    Map<int, String?> overrides,
  ) => [
    for (final mapping in mappings)
      AssetImportColumnMapping(
        sourceColumnIndex: mapping.sourceColumnIndex,
        sourceHeader: mapping.sourceHeader,
        canonicalKey: overrides.containsKey(mapping.sourceColumnIndex)
            ? overrides[mapping.sourceColumnIndex]
            : mapping.canonicalKey,
        isExact: overrides.containsKey(mapping.sourceColumnIndex)
            ? false
            : mapping.isExact,
        ambiguous: overrides.containsKey(mapping.sourceColumnIndex)
            ? false
            : mapping.ambiguous,
      ),
  ];

  List<AssetImportPreviewIssue> _validateMappings(
    List<AssetImportColumnMapping> mappings,
    AssetImportSchema schema,
    _PreviewMessages messages, {
    required bool requireMode,
  }) {
    final issues = <AssetImportPreviewIssue>[];
    final validKeys = schema.fieldKeys;
    final mappedKeys = <String>{};
    for (final mapping in mappings) {
      if (mapping.ambiguous) {
        issues.add(_issue(messages, 'ambiguous_mapping', mapping.sourceHeader));
        continue;
      }
      final key = mapping.canonicalKey;
      if (key == null) continue;
      if (!validKeys.contains(key)) {
        issues.add(_issue(messages, 'unknown_mapping', key));
        continue;
      }
      if (!mappedKeys.add(key)) {
        issues.add(_issue(messages, 'duplicate_mapping', key));
      }
    }
    for (final key in ['name', if (requireMode) 'mode', 'warehouse']) {
      if (!mappedKeys.contains(key)) {
        issues.add(_issue(messages, 'required_mapping', key));
      }
    }
    return issues;
  }

  Map<String, String?> _canonicalValues(
    AssetImportDecodedRow row,
    List<AssetImportColumnMapping> mappings,
    Map<String, String?>? overrides,
  ) {
    final values = <String, String?>{...row.canonicalValues};
    for (final mapping in mappings) {
      final key = mapping.canonicalKey;
      if (key == null || mapping.ambiguous) continue;
      if (mapping.sourceColumnIndex < row.values.length) {
        values[key] = row.values[mapping.sourceColumnIndex];
      }
    }
    if (overrides != null) values.addAll(overrides);
    return values;
  }

  AssetImportType? _rowType(
    AssetImportDecodedRow row,
    Map<String, String?> values,
  ) {
    if (row.type != null) return row.type;
    final mode = _normalized(values['mode']);
    return switch (mode) {
      'serialized' || 'serialised' => AssetImportType.serialized,
      'bulk' => AssetImportType.bulk,
      _ => null,
    };
  }

  void _validateCommon(
    Map<String, String?> values,
    AssetImportType? type,
    AssetImportType? expectedType,
    Set<String?> warehouseNames,
    Set<String?> otherLocationNames,
    _PreviewMessages messages,
    List<AssetImportPreviewIssue> issues,
  ) {
    final name = _normalized(values['name']);
    if (name == null) {
      issues.add(_issue(messages, 'required_field', 'name'));
    } else if (name.length > 160) {
      issues.add(_issue(messages, 'value_too_long', 'name'));
    }
    if (type == null) {
      issues.add(_issue(messages, 'mode_invalid', 'mode'));
    } else if (expectedType != null && type != expectedType) {
      issues.add(_issue(messages, 'mode_mismatch', 'mode'));
    }
    final warehouse = _normalized(values['warehouse']);
    if (warehouse == null) {
      issues.add(_issue(messages, 'required_field', 'warehouse'));
    } else if (otherLocationNames.contains(warehouse)) {
      issues.add(_issue(messages, 'warehouse_type_conflict', 'warehouse'));
    } else if (!warehouseNames.contains(warehouse)) {
      issues.add(_issue(messages, 'warehouse_new', 'warehouse'));
    }
  }

  void _validateSerialized(
    Map<String, String?> values,
    Map<String, int> occurrences,
    Set<String> existingSerials,
    _PreviewMessages messages,
    List<AssetImportPreviewIssue> issues,
  ) {
    final serial = _normalized(values['serial_code']);
    if (serial == null) {
      issues.add(_issue(messages, 'required_field', 'serial_code'));
    } else if (serial.length > 160) {
      issues.add(_issue(messages, 'value_too_long', 'serial_code'));
    } else if ((occurrences[serial] ?? 0) > 1 ||
        existingSerials.contains(serial)) {
      issues.add(_issue(messages, 'duplicate_serial', 'serial_code'));
    }
    if (!_blank(values['quantity'])) {
      issues.add(_issue(messages, 'wrong_field_for_mode', 'quantity'));
    }
  }

  void _validateBulk(
    Map<String, String?> values,
    Map<String, int> occurrences,
    Set<String?> existingBulkKeys,
    _PreviewMessages messages,
    List<AssetImportPreviewIssue> issues,
  ) {
    final quantity = _normalized(values['quantity']);
    if (quantity == null) {
      issues.add(_issue(messages, 'required_field', 'quantity'));
    } else {
      final parsed = int.tryParse(quantity);
      if (parsed == null) {
        issues.add(_issue(messages, 'quantity_invalid', 'quantity'));
      } else if (parsed < 0) {
        issues.add(_issue(messages, 'quantity_negative', 'quantity'));
      }
    }
    if (!_blank(values['serial_code'])) {
      issues.add(_issue(messages, 'wrong_field_for_mode', 'serial_code'));
    }
    final key = _bulkKey(values['name'], values['warehouse']);
    if (key != null &&
        ((occurrences[key] ?? 0) > 1 || existingBulkKeys.contains(key))) {
      issues.add(
        _issue(
          messages,
          existingBulkKeys.contains(key)
              ? 'bulk_existing_duplicate'
              : 'bulk_file_duplicate',
          'name',
        ),
      );
    }
  }

  AssetImportPreviewIssue _issue(
    _PreviewMessages messages,
    String code,
    String fieldKey,
  ) => AssetImportPreviewIssue(
    code: code,
    fieldKey: fieldKey,
    message: messages.text(code),
  );

  String? _bulkKey(String? name, String? warehouse) {
    final normalizedName = _normalized(name);
    final normalizedWarehouse = _normalized(warehouse);
    if (normalizedName == null || normalizedWarehouse == null) return null;
    return '$normalizedName::$normalizedWarehouse';
  }

  String? _normalized(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  bool _blank(String? value) => value == null || value.trim().isEmpty;
}

const _confirmationCodes = {
  'warehouse_new',
  'bulk_existing_duplicate',
  'bulk_file_duplicate',
};

class _PreviewMessages {
  const _PreviewMessages(this._values);

  final Map<String, String> _values;

  static _PreviewMessages forLocale(String locale) =>
      switch (locale.toLowerCase().split('-').first) {
        'es' => const _PreviewMessages(_spanishPreviewMessages),
        'ja' => const _PreviewMessages(_japanesePreviewMessages),
        _ => const _PreviewMessages(_englishPreviewMessages),
      };

  String text(String code) => _values[code] ?? code;
}

const _englishPreviewMessages = <String, String>{
  'ambiguous_mapping': 'This column mapping is ambiguous.',
  'unknown_mapping': 'This column mapping is not supported.',
  'duplicate_mapping': 'More than one column maps to this field.',
  'required_mapping': 'A required field is not mapped.',
  'required_field': 'A required value is missing.',
  'value_too_long': 'This value is longer than 160 characters.',
  'mode_invalid': 'Mode must be SERIALIZED or BULK.',
  'mode_mismatch': 'Mode does not match this template section.',
  'wrong_field_for_mode': 'This field must be empty for the selected Mode.',
  'warehouse_new': 'This Warehouse will be created after confirmation.',
  'warehouse_type_conflict':
      'This name belongs to a Delivery Place, not a Warehouse.',
  'duplicate_serial':
      'This serial already exists or is duplicated in the file.',
  'quantity_invalid': 'Quantity must be a whole number.',
  'quantity_negative': 'Quantity cannot be negative.',
  'bulk_existing_duplicate': 'A matching Bulk Asset exists and can be merged.',
  'bulk_file_duplicate':
      'This Bulk appears more than once in the file and can be merged.',
};

const _spanishPreviewMessages = <String, String>{
  'ambiguous_mapping': 'La asignación de esta columna es ambigua.',
  'unknown_mapping': 'La asignación de esta columna no es compatible.',
  'duplicate_mapping': 'Más de una columna usa este campo.',
  'required_mapping': 'Falta asignar un campo obligatorio.',
  'required_field': 'Falta un valor obligatorio.',
  'value_too_long': 'Este valor supera los 160 caracteres.',
  'mode_invalid': 'El tipo debe ser SERIALIZED o BULK.',
  'mode_mismatch': 'El tipo no coincide con esta sección de la plantilla.',
  'wrong_field_for_mode':
      'Este campo debe estar vacío para el tipo seleccionado.',
  'warehouse_new': 'Este almacén se creará después de confirmar.',
  'warehouse_type_conflict':
      'Este nombre pertenece a un lugar de entrega, no a un almacén.',
  'duplicate_serial': 'Esta serie ya existe o está duplicada en el archivo.',
  'quantity_invalid': 'La cantidad debe ser un número entero.',
  'quantity_negative': 'La cantidad no puede ser negativa.',
  'bulk_existing_duplicate':
      'Ya existe un Bulk coincidente y se puede combinar.',
  'bulk_file_duplicate':
      'Este Bulk aparece más de una vez y se puede combinar.',
};

const _japanesePreviewMessages = <String, String>{
  'ambiguous_mapping': 'この列のマッピングはあいまいです。',
  'unknown_mapping': 'この列のマッピングには対応していません。',
  'duplicate_mapping': '複数の列がこのフィールドにマッピングされています。',
  'required_mapping': '必須フィールドがマッピングされていません。',
  'required_field': '必須の値がありません。',
  'value_too_long': 'この値は160文字を超えています。',
  'mode_invalid': '管理方式は SERIALIZED または BULK にしてください。',
  'mode_mismatch': '管理方式がこのテンプレートのセクションと一致しません。',
  'wrong_field_for_mode': '選択した管理方式では、このフィールドを空にしてください。',
  'warehouse_new': '確認後、この倉庫を作成します。',
  'warehouse_type_conflict': 'この名称は倉庫ではなく納品先に使用されています。',
  'duplicate_serial': 'このシリアル番号はすでに存在するか、ファイル内で重複しています。',
  'quantity_invalid': '数量は整数にしてください。',
  'quantity_negative': '数量を負の値にすることはできません。',
  'bulk_existing_duplicate': '一致する数量管理機材があり、統合できます。',
  'bulk_file_duplicate': 'この数量管理機材はファイル内に複数あり、統合できます。',
};
