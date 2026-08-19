import 'package:excel_plus/excel_plus.dart';

import 'asset_import_models.dart';

class AssetImportTemplateFile {
  const AssetImportTemplateFile({
    required this.bytes,
    required this.fileName,
    required this.locale,
    this.type,
  });

  final List<int> bytes;
  final String fileName;
  final String locale;
  final AssetImportType? type;
}

class AssetImportLocaleResources {
  const AssetImportLocaleResources({
    required this.locale,
    required this.instructions,
    required this.serializedNote,
    required this.bulkNote,
    required this.tableTitle,
    required this.serializedNoteColumn,
    required this.bulkNoteColumn,
    required this.labels,
    required this.aliases,
  });

  final String locale;
  final List<String> instructions;
  final String serializedNote;
  final String bulkNote;
  final String tableTitle;
  final String serializedNoteColumn;
  final String bulkNoteColumn;
  final Map<String, String> labels;
  final Map<String, List<String>> aliases;

  static AssetImportLocaleResources forLocale(String requestedLocale) {
    return switch (requestedLocale.toLowerCase().split('-').first) {
      'es' => _cleanSpanish,
      'ja' => _cleanJapanese,
      _ => _cleanEnglish,
    };
  }
}

class AssetImportSchemas {
  static AssetImportSchema unified(AssetImportLocaleResources resources) =>
      AssetImportSchema(
        type: AssetImportType.serialized,
        fields: [
          for (final key in const [
            'name',
            'mode',
            'serial_code',
            'quantity',
            'warehouse',
          ])
            AssetImportFieldDefinition(
              key: key,
              required: key == 'name' || key == 'mode' || key == 'warehouse',
              label: resources.labels[key]!,
              aliases: resources.aliases[key]!,
            ),
        ],
      );

  static AssetImportSchema forType(
    AssetImportType type,
    AssetImportLocaleResources resources,
  ) {
    final keys = switch (type) {
      AssetImportType.serialized => const [
        'name',
        'mode',
        'serial_code',
        'warehouse',
      ],
      AssetImportType.bulk => const ['name', 'mode', 'quantity', 'warehouse'],
    };
    final requiredKeys = {
      'name',
      'mode',
      'warehouse',
      if (type == AssetImportType.serialized) 'serial_code',
      if (type == AssetImportType.bulk) 'quantity',
    };
    return AssetImportSchema(
      type: type,
      fields: [
        for (final key in keys)
          AssetImportFieldDefinition(
            key: key,
            required: requiredKeys.contains(key),
            label: resources.labels[key]!,
            aliases: resources.aliases[key]!,
          ),
      ],
    );
  }
}

abstract final class _AssetImportTemplatePalette {
  static const textPrimary = '#112019';
  static const surfaceSubtle = '#E3EBE7';
  static const actionPrimary = '#155A48';
  static const interactive = '#00796F';
  static const warning = '#654B14';
  static const successContainer = '#E2F3E9';
  static const warningContainer = '#F4ECD8';
  static const textMuted = '#61726A';
  static const surface = '#FFFFFF';
}

class AssetImportTemplateService {
  AssetImportTemplateFile generate({String? locale, AssetImportType? type}) {
    final resources = AssetImportLocaleResources.forLocale(locale ?? 'en');
    final workbook = Excel.createExcel();
    final initialSheet =
        workbook.getDefaultSheet() ?? workbook.sheetOrder.first;
    workbook.rename(initialSheet, 'Import Template');
    workbook.setDefaultSheet('Import Template');
    final sheet = workbook['Import Template'];

    final titleStyle = CellStyle(
      bold: true,
      fontSize: 13,
      fontColorHex: ExcelColor.fromHexString(
        _AssetImportTemplatePalette.textPrimary,
      ),
      backgroundColorHex: ExcelColor.fromHexString(
        _AssetImportTemplatePalette.surfaceSubtle,
      ),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      textWrapping: TextWrapping.WrapText,
    );
    final guideStyle = CellStyle(
      fontSize: 11,
      fontColorHex: ExcelColor.fromHexString(
        _AssetImportTemplatePalette.textPrimary,
      ),
      backgroundColorHex: ExcelColor.fromHexString(
        _AssetImportTemplatePalette.surfaceSubtle,
      ),
      horizontalAlign: HorizontalAlign.Left,
      verticalAlign: VerticalAlign.Center,
      textWrapping: TextWrapping.WrapText,
    );
    final sectionStyle = CellStyle(
      bold: true,
      fontSize: 14,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.fromHexString(
        _AssetImportTemplatePalette.actionPrimary,
      ),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );
    final serializedHeader = CellStyle(
      bold: true,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.fromHexString(
        _AssetImportTemplatePalette.interactive,
      ),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      textWrapping: TextWrapping.WrapText,
    );
    final bulkHeader = CellStyle(
      bold: true,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.fromHexString(
        _AssetImportTemplatePalette.warning,
      ),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      textWrapping: TextWrapping.WrapText,
    );
    final serializedInput = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString(
        _AssetImportTemplatePalette.successContainer,
      ),
    );
    final bulkInput = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString(
        _AssetImportTemplatePalette.warningContainer,
      ),
    );
    final noteStyle = CellStyle(
      italic: true,
      fontSize: 10,
      fontColorHex: ExcelColor.fromHexString(
        _AssetImportTemplatePalette.textMuted,
      ),
      backgroundColorHex: ExcelColor.fromHexString(
        _AssetImportTemplatePalette.surface,
      ),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      textWrapping: TextWrapping.WrapText,
    );

    for (var column = 0; column < 5; column++) {
      sheet.setColumnWidth(column, switch (column) {
        0 => 24,
        1 => 24,
        2 => 24,
        3 => 23,
        _ => 34,
      });
    }
    for (var row = 0; row < 50; row++) {
      sheet.setRowHeight(row, 22);
    }
    for (final row in [0, 1, 2]) {
      sheet.setRowHeight(row, 27);
    }
    sheet.setRowHeight(9, 30);
    sheet.setRowHeight(10, 30);
    sheet.setRowHeight(14, 30);

    _mergeText(sheet, 'A1', 'E1', resources.instructions[0], titleStyle);
    _mergeText(sheet, 'A2', 'E2', resources.instructions[1], guideStyle);
    _mergeText(sheet, 'A3', 'E3', resources.instructions[2], guideStyle);
    _mergeText(sheet, 'A5', 'D5', resources.serializedNote, guideStyle);
    _mergeText(sheet, 'A6', 'D6', resources.bulkNote, guideStyle);
    _mergeText(sheet, 'A10', 'E10', resources.tableTitle, sectionStyle);

    _writeRow(sheet, 10, [
      resources.labels['name']!,
      resources.labels['mode']!,
      resources.labels['serial_code']!,
      resources.labels['warehouse']!,
    ], serializedHeader);
    for (var row = 11; row <= 13; row++) {
      _writeRow(sheet, row, [null, null, null, null], serializedInput);
    }
    _mergeText(sheet, 'E12', 'E14', resources.serializedNoteColumn, noteStyle);

    _writeRow(sheet, 14, [
      resources.labels['name']!,
      resources.labels['mode']!,
      resources.labels['quantity']!,
      resources.labels['warehouse']!,
    ], bulkHeader);
    for (var row = 15; row <= 44; row++) {
      _writeRow(sheet, row, [null, null, null, null], bulkInput);
    }
    _mergeText(sheet, 'E16', 'E45', resources.bulkNoteColumn, noteStyle);

    return AssetImportTemplateFile(
      bytes: workbook.encode() ?? const <int>[],
      fileName: 'relay-asset-import-template-${resources.locale}.xlsx',
      locale: resources.locale,
      type: type,
    );
  }

  void _writeRow(
    Sheet sheet,
    int rowIndex,
    List<String?> values,
    CellStyle style,
  ) {
    for (var column = 0; column < values.length; column++) {
      sheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: column, rowIndex: rowIndex),
        values[column] == null ? null : TextCellValue(values[column]!),
        cellStyle: style,
      );
    }
  }

  void _mergeText(
    Sheet sheet,
    String start,
    String end,
    String value,
    CellStyle style,
  ) {
    final startIndex = CellIndex.indexByString(start);
    sheet.merge(startIndex, CellIndex.indexByString(end));
    sheet.updateCell(startIndex, TextCellValue(value), cellStyle: style);
    sheet.setMergedCellStyle(startIndex, style);
  }
}

// Keep generated workbook copy separate from the app's legacy mojibake strings.
// These resources are the only ones selected by forLocale above.
const _cleanEnglish = AssetImportLocaleResources(
  locale: 'en',
  instructions: [
    'How to fill Name, Mode and Warehouse',
    'Mode: type SERIALIZED or BULK.',
    'Warehouse: type an existing Warehouse name or a new name to create.',
  ],
  serializedNote: 'Serialized: one asset per row \u2022 enter Serial Number',
  bulkNote: 'Bulk: one asset type per row \u2022 enter Quantity',
  tableTitle: 'Table for import',
  serializedNoteColumn: 'Enter Serialized assets here',
  bulkNoteColumn: 'Enter Bulk assets here',
  labels: {
    'name': 'Name',
    'mode': 'Mode',
    'serial_code': 'Serial Number',
    'quantity': 'Quantity',
    'warehouse': 'Warehouse',
  },
  aliases: {
    'name': ['Name', 'Asset Name', 'Item'],
    'mode': ['Mode', 'Type', 'Asset Type'],
    'serial_code': ['Serial', 'Serial Number', 'Code', 'Serial / Code'],
    'quantity': ['Quantity', 'Qty'],
    'warehouse': ['Warehouse', 'Location'],
  },
);

const _cleanSpanish = AssetImportLocaleResources(
  locale: 'es',
  instructions: [
    'C\u00f3mo completar Nombre, Tipo y Almac\u00e9n',
    'Tipo: escribe SERIALIZED o BULK.',
    'Almac\u00e9n: escribe un almac\u00e9n existente o un nombre nuevo para crearlo.',
  ],
  serializedNote:
      'Serialized: un equipo f\u00edsico por fila \u2022 escribe el n\u00famero de serie',
  bulkNote: 'Bulk: un tipo de equipo por fila \u2022 escribe la cantidad',
  tableTitle: 'Tabla para importar',
  serializedNoteColumn: 'Escribe aqu\u00ed los equipos Serialized',
  bulkNoteColumn: 'Escribe aqu\u00ed los equipos Bulk',
  labels: {
    'name': 'Nombre',
    'mode': 'Tipo',
    'serial_code': 'N\u00famero de serie',
    'quantity': 'Cantidad',
    'warehouse': 'Almac\u00e9n',
  },
  aliases: {
    'name': ['Nombre', 'Nombre del activo', 'Art\u00edculo', 'Item'],
    'mode': ['Tipo', 'Modo', 'Tipo de activo'],
    'serial_code': [
      'Serie',
      'N\u00famero de serie',
      'C\u00f3digo',
      'Serie / C\u00f3digo',
    ],
    'quantity': ['Cantidad', 'Cant.'],
    'warehouse': ['Almac\u00e9n', 'Ubicaci\u00f3n', 'Warehouse'],
  },
);

const _cleanJapanese = AssetImportLocaleResources(
  locale: 'ja',
  instructions: [
    '名称、管理方式、倉庫の入力方法',
    '管理方式：SERIALIZED または BULK を入力してください。',
    '倉庫：既存の倉庫名、または新しく作成する倉庫名を入力してください。',
  ],
  serializedNote: '個品管理：1行に1台・シリアル番号を入力',
  bulkNote: '数量管理：1行に1種類・数量を入力',
  tableTitle: 'インポート用テーブル',
  serializedNoteColumn: 'ここに個品管理の機材を入力',
  bulkNoteColumn: 'ここに数量管理の機材を入力',
  labels: {
    'name': '名称',
    'mode': '管理方式',
    'serial_code': 'シリアル番号',
    'quantity': '数量',
    'warehouse': '倉庫',
  },
  aliases: {
    'name': ['名称', '機材名', '品名', '名前'],
    'mode': ['管理方式', '方式', 'モード', '種別'],
    'serial_code': ['シリアル番号', 'シリアル', '製造番号', 'コード'],
    'quantity': ['数量', '個数', '台数'],
    'warehouse': ['倉庫', '保管場所'],
  },
);
