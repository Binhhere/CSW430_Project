import 'dart:convert';

import 'package:excel_plus/excel_plus.dart';

import 'asset_import_models.dart';
import 'asset_import_template_service.dart';

class AssetImportDecoder {
  AssetImportDecodedFile decode(AssetImportRequest request) {
    if (request.bytes.length > request.limits.maxFileBytes) {
      throw AssetImportException(
        'file_too_large',
        'The import file exceeds the configured size limit.',
      );
    }
    final name = request.fileName.trim().toLowerCase();
    if (name.endsWith('.csv')) return _decodeCsv(request);
    if (name.endsWith('.xlsx')) return _decodeXlsx(request);
    throw AssetImportException(
      'unsupported_file_type',
      'Only .xlsx and .csv files are supported.',
    );
  }

  AssetImportDecodedFile _decodeCsv(AssetImportRequest request) {
    final text = utf8.decode(request.bytes, allowMalformed: false);
    final workbook = Excel.fromCsv(_withoutBom(text), inferTypes: false);
    final sheet =
        workbook[workbook.getDefaultSheet() ?? workbook.sheetOrder.first];
    return _decodeExternalRows(request, sheet.rows, const <String>['CSV']);
  }

  AssetImportDecodedFile _decodeXlsx(AssetImportRequest request) {
    final workbook = Excel.decodeBytes(request.bytes);
    final names = workbook.sheetOrder;
    for (final name in names) {
      final sheet = workbook.tables[name];
      if (sheet == null || sheet.visibility != SheetVisibility.visible) {
        continue;
      }
      final template = _decodeUnifiedTemplate(request, sheet, names);
      if (template != null) return template;
    }
    final sheet = _firstExternalSheet(workbook);
    if (sheet == null) {
      throw AssetImportException(
        'missing_data_sheet',
        'The workbook must contain a readable data sheet.',
      );
    }
    return _decodeExternalRows(request, sheet.rows, names);
  }

  Sheet? _firstExternalSheet(Excel workbook) {
    for (final name in workbook.sheetOrder) {
      final sheet = workbook.tables[name];
      if (sheet != null && sheet.visibility == SheetVisibility.visible) {
        return sheet;
      }
    }
    return null;
  }

  AssetImportDecodedFile? _decodeUnifiedTemplate(
    AssetImportRequest request,
    Sheet sheet,
    List<String> sheetNames,
  ) {
    final resources = AssetImportLocaleResources.forLocale(request.locale);
    final rows = [
      for (final row in sheet.rows)
        [for (final cell in row) _cellText(cell?.value)],
    ];
    final sections = <_TemplateSection>[];
    for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      final section = _sectionForHeader(rows[rowIndex], resources, rowIndex);
      if (section != null) sections.add(section);
    }
    if (sections.isEmpty) return null;

    final decodedRows = <AssetImportDecodedRow>[];
    for (var sectionIndex = 0; sectionIndex < sections.length; sectionIndex++) {
      final section = sections[sectionIndex];
      final end = sectionIndex + 1 < sections.length
          ? sections[sectionIndex + 1].headerRow
          : rows.length;
      for (var rowIndex = section.headerRow + 1; rowIndex < end; rowIndex++) {
        final row = rows[rowIndex];
        final values = _padRow(row, section.width);
        final canonical = <String, String?>{
          'name': _valueAt(row, section.nameColumn),
          'mode': _valueAt(row, section.modeColumn),
          'warehouse': _valueAt(row, section.warehouseColumn),
          if (section.type == AssetImportType.serialized)
            'serial_code': _valueAt(row, section.detailColumn),
          if (section.type == AssetImportType.bulk)
            'quantity': _valueAt(row, section.detailColumn),
        };
        if (canonical.values.every(_blank)) continue;
        final mode = _parseMode(canonical['mode']);
        decodedRows.add(
          AssetImportDecodedRow(
            rowNumber: rowIndex + 1,
            values: List.unmodifiable(values),
            type: mode,
            expectedType: section.type,
            canonicalValues: Map.unmodifiable(canonical),
          ),
        );
      }
    }
    if (decodedRows.length > request.limits.maxRows) {
      throw AssetImportException(
        'too_many_rows',
        'The import file exceeds the configured row limit.',
      );
    }
    return AssetImportDecodedFile(
      type: _singleType(decodedRows.map((row) => row.type)),
      locale: resources.locale,
      isTemplate: true,
      metadataValid: true,
      metadataHidden: false,
      templateVersion: assetImportTemplateVersion,
      sheetNames: List.unmodifiable(sheetNames),
      headers: List.unmodifiable([
        for (final value in rows[sections.first.headerRow]) value ?? '',
      ]),
      rows: List.unmodifiable(decodedRows),
      mappings: const [],
      requiresManualMapping: false,
      metadata: const {},
    );
  }

  _TemplateSection? _sectionForHeader(
    List<String?> row,
    AssetImportLocaleResources resources,
    int rowIndex,
  ) {
    final nameColumn = _findColumn(row, 'name', resources);
    final modeColumn = _findColumn(row, 'mode', resources);
    final warehouseColumn = _findColumn(row, 'warehouse', resources);
    final serialColumn = _findColumn(row, 'serial_code', resources);
    final quantityColumn = _findColumn(row, 'quantity', resources);
    if (nameColumn == null || modeColumn == null || warehouseColumn == null) {
      return null;
    }
    if (serialColumn != null && quantityColumn == null) {
      return _TemplateSection(
        headerRow: rowIndex,
        type: AssetImportType.serialized,
        nameColumn: nameColumn,
        modeColumn: modeColumn,
        detailColumn: serialColumn,
        warehouseColumn: warehouseColumn,
        width: row.length,
      );
    }
    if (quantityColumn != null && serialColumn == null) {
      return _TemplateSection(
        headerRow: rowIndex,
        type: AssetImportType.bulk,
        nameColumn: nameColumn,
        modeColumn: modeColumn,
        detailColumn: quantityColumn,
        warehouseColumn: warehouseColumn,
        width: row.length,
      );
    }
    return null;
  }

  AssetImportDecodedFile _decodeExternalRows(
    AssetImportRequest request,
    List<List<Data?>> sourceRows,
    List<String> sheetNames,
  ) {
    final rows = [
      for (final row in sourceRows)
        [for (final cell in row) _cellText(cell?.value)],
    ];
    while (rows.isNotEmpty && rows.last.every(_blank)) {
      rows.removeLast();
    }
    if (rows.isEmpty || rows.first.every(_blank)) {
      throw AssetImportException(
        'missing_header',
        'The import file has no header row.',
      );
    }
    final headers = [for (final value in rows.first) value?.trim() ?? ''];
    final dataRows = rows
        .skip(1)
        .where((row) => row.any((cell) => !_blank(cell)))
        .toList();
    if (dataRows.length > request.limits.maxRows) {
      throw AssetImportException(
        'too_many_rows',
        'The import file exceeds the configured row limit.',
      );
    }
    final resources = AssetImportLocaleResources.forLocale(request.locale);
    final schema = AssetImportSchemas.unified(resources);
    final mappings = _smartMappings(headers, schema);
    final decodedRows = <AssetImportDecodedRow>[];
    for (var index = 0; index < dataRows.length; index++) {
      final values = _padRow(dataRows[index], headers.length);
      final canonical = _canonicalValues(values, mappings);
      final type =
          request.type ??
          _parseMode(canonical['mode']) ??
          _inferType(canonical);
      if (type != null && _blank(canonical['mode'])) {
        canonical['mode'] = type.wireValue;
      }
      decodedRows.add(
        AssetImportDecodedRow(
          rowNumber: index + 2,
          values: List.unmodifiable(values),
          type: type,
          canonicalValues: Map.unmodifiable(canonical),
        ),
      );
    }
    return AssetImportDecodedFile(
      type: _singleType(decodedRows.map((row) => row.type)),
      locale: resources.locale,
      isTemplate: false,
      metadataValid: false,
      metadataHidden: false,
      templateVersion: null,
      sheetNames: List.unmodifiable(sheetNames),
      headers: List.unmodifiable(headers),
      rows: List.unmodifiable(decodedRows),
      mappings: List.unmodifiable(mappings),
      requiresManualMapping: true,
      metadata: const {},
    );
  }

  List<AssetImportColumnMapping> _smartMappings(
    List<String> headers,
    AssetImportSchema schema,
  ) {
    final aliases = <String, String>{};
    for (final field in schema.fields) {
      final allAliases = {
        ...field.aliases,
        ...(AssetImportLocaleResources.forLocale('en').aliases[field.key] ??
            const <String>[]),
        ...(AssetImportLocaleResources.forLocale('es').aliases[field.key] ??
            const <String>[]),
        ...(AssetImportLocaleResources.forLocale('ja').aliases[field.key] ??
            const <String>[]),
      };
      for (final alias in allAliases) {
        aliases[_normalizeHeader(alias)] = field.key;
      }
    }
    final usedKeys = <String>{};
    return [
      for (var index = 0; index < headers.length; index++)
        _mappingForHeader(index, headers[index], aliases, usedKeys),
    ];
  }

  AssetImportColumnMapping _mappingForHeader(
    int sourceColumnIndex,
    String header,
    Map<String, String> aliases,
    Set<String> usedKeys,
  ) {
    final key = aliases[_normalizeHeader(header)];
    final duplicate = key != null && !usedKeys.add(key);
    return AssetImportColumnMapping(
      sourceColumnIndex: sourceColumnIndex,
      sourceHeader: header,
      canonicalKey: duplicate ? null : key,
      isExact: key != null && !duplicate,
      ambiguous: duplicate,
    );
  }

  Map<String, String?> _canonicalValues(
    List<String?> values,
    List<AssetImportColumnMapping> mappings,
  ) {
    final result = <String, String?>{};
    for (final mapping in mappings) {
      final key = mapping.canonicalKey;
      if (key == null || mapping.ambiguous) continue;
      if (mapping.sourceColumnIndex < values.length) {
        result[key] = _normalizeValue(values[mapping.sourceColumnIndex]);
      }
    }
    return result;
  }

  int? _findColumn(
    List<String?> headers,
    String key,
    AssetImportLocaleResources resources,
  ) {
    final aliases = {
      for (final locale in ['en', 'es', 'ja'])
        for (final alias
            in AssetImportLocaleResources.forLocale(locale).aliases[key] ??
                <String>[])
          _normalizeHeader(alias),
      for (final alias in resources.aliases[key] ?? <String>[])
        _normalizeHeader(alias),
    };
    for (var index = 0; index < headers.length; index++) {
      if (aliases.contains(_normalizeHeader(headers[index] ?? ''))) {
        return index;
      }
    }
    return null;
  }

  AssetImportType? _inferType(Map<String, String?> values) {
    final hasSerial = !_blank(values['serial_code']);
    final hasQuantity = !_blank(values['quantity']);
    if (hasSerial && !hasQuantity) return AssetImportType.serialized;
    if (hasQuantity && !hasSerial) return AssetImportType.bulk;
    return null;
  }

  AssetImportType? _parseMode(String? value) {
    final normalized = _normalizeHeader(value ?? '').replaceAll(' ', '');
    return switch (normalized) {
      'serialized' || 'serialised' => AssetImportType.serialized,
      'bulk' => AssetImportType.bulk,
      _ => null,
    };
  }

  AssetImportType? _singleType(Iterable<AssetImportType?> values) {
    final types = values.whereType<AssetImportType>().toSet();
    return types.length == 1 ? types.single : null;
  }

  List<String?> _padRow(List<String?> row, int width) => [
    for (var index = 0; index < width; index++)
      index < row.length ? _normalizeValue(row[index]) : null,
  ];

  String? _valueAt(List<String?> row, int index) =>
      index < row.length ? _normalizeValue(row[index]) : null;

  String _withoutBom(String value) =>
      value.startsWith('\uFEFF') ? value.substring(1) : value;

  bool _blank(String? value) => value == null || value.trim().isEmpty;

  String _normalizeHeader(String value) {
    var result = value.trim().toLowerCase();
    const replacements = {
      'á': 'a',
      'é': 'e',
      'í': 'i',
      'ó': 'o',
      'ú': 'u',
      'ü': 'u',
      'ñ': 'n',
      'Ã¡': 'a',
      'Ã©': 'e',
      'Ã­': 'i',
      'Ã³': 'o',
      'Ãº': 'u',
      'Ã¼': 'u',
      'Ã±': 'n',
    };
    for (final entry in replacements.entries) {
      result = result.replaceAll(entry.key, entry.value);
    }
    return result
        .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
        .trim();
  }

  String? _normalizeValue(String? value) {
    final result = value?.trim();
    return result == null || result.isEmpty ? null : result;
  }

  String? _cellText(CellValue? value) {
    if (value == null) return null;
    if (value is TextCellValue) return value.value.toString();
    if (value is IntCellValue) return value.value.toString();
    if (value is DoubleCellValue) return value.value.toString();
    if (value is BoolCellValue) return value.value.toString();
    if (value is FormulaCellValue) return value.cachedValue ?? value.formula;
    return value.toString();
  }
}

class _TemplateSection {
  const _TemplateSection({
    required this.headerRow,
    required this.type,
    required this.nameColumn,
    required this.modeColumn,
    required this.detailColumn,
    required this.warehouseColumn,
    required this.width,
  });

  final int headerRow;
  final AssetImportType type;
  final int nameColumn;
  final int modeColumn;
  final int detailColumn;
  final int warehouseColumn;
  final int width;
}
