import 'dart:convert';
import 'dart:typed_data';

import 'package:excel_plus/excel_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relay_av_demo/features/assets/asset_import/asset_import_models.dart';
import 'package:relay_av_demo/features/assets/asset_import/asset_import_preview.dart';
import 'package:relay_av_demo/features/assets/asset_import/asset_import_service.dart';

void main() {
  final service = AssetImportService();

  test('English template is one sheet with both import sections', () {
    final template = service.generateTemplate(locale: 'en');
    final decoded = service.decode(
      AssetImportRequest(
        bytes: Uint8List.fromList(template.bytes),
        fileName: template.fileName,
        locale: 'en',
      ),
    );

    expect(template.fileName, 'relay-asset-import-template-en.xlsx');
    expect(decoded.isTemplate, isTrue);
    expect(decoded.sheetNames, ['Import Template']);
    expect(decoded.rows, isEmpty);
    expect(decoded.mappings, isEmpty);
    expect(decoded.requiresManualMapping, isFalse);
  });

  test('Spanish template detects localized Serialized and Bulk headers', () {
    final template = service.generateTemplate(locale: 'es');
    final workbook = Excel.decodeBytes(template.bytes);
    final sheet = workbook['Import Template'];
    expect(
      sheet.cell(CellIndex.indexByString('A1')).value.toString(),
      contains('C\u00f3mo'),
    );
    expect(
      sheet.cell(CellIndex.indexByString('A5')).value.toString(),
      contains('f\u00edsico'),
    );
    _cell(sheet, 0, 11, 'Cámara');
    _cell(sheet, 1, 11, 'SERIALIZED');
    _cell(sheet, 2, 11, 'CAM-001');
    _cell(sheet, 3, 11, 'Almacén principal');
    _cell(sheet, 0, 15, 'Cable HDMI');
    _cell(sheet, 1, 15, 'BULK');
    _cell(sheet, 2, 15, '8');
    _cell(sheet, 3, 15, 'Almacén principal');

    final decoded = service.decode(
      AssetImportRequest(
        bytes: Uint8List.fromList(workbook.encode()!),
        fileName: template.fileName,
        locale: 'es',
      ),
    );

    expect(decoded.locale, 'es');
    expect(decoded.rows.map((row) => row.type), [
      AssetImportType.serialized,
      AssetImportType.bulk,
    ]);
    expect(decoded.rows.first.canonicalValues['serial_code'], 'CAM-001');
    expect(decoded.rows.last.canonicalValues['quantity'], '8');
  });

  test(
    'Japanese template preserves machine Mode values and decodes Japanese headers',
    () {
      final template = service.generateTemplate(locale: 'ja');
      final workbook = Excel.decodeBytes(template.bytes);
      final sheet = workbook['Import Template'];
      expect(
        sheet.cell(CellIndex.indexByString('A1')).value.toString(),
        contains('入力方法'),
      );
      expect(
        sheet.cell(CellIndex.indexByString('B11')).value.toString(),
        '管理方式',
      );
      _cell(sheet, 0, 11, 'カメラ');
      _cell(sheet, 1, 11, 'SERIALIZED');
      _cell(sheet, 2, 11, 'CAM-001');
      _cell(sheet, 3, 11, 'メイン倉庫');
      _cell(sheet, 0, 15, 'HDMIケーブル');
      _cell(sheet, 1, 15, 'BULK');
      _cell(sheet, 2, 15, '8');
      _cell(sheet, 3, 15, 'メイン倉庫');

      final decoded = service.decode(
        AssetImportRequest(
          bytes: Uint8List.fromList(workbook.encode()!),
          fileName: template.fileName,
          locale: 'ja',
        ),
      );

      expect(template.fileName, 'relay-asset-import-template-ja.xlsx');
      expect(decoded.locale, 'ja');
      expect(decoded.rows.map((row) => row.type), [
        AssetImportType.serialized,
        AssetImportType.bulk,
      ]);
    },
  );

  test('external mixed CSV infers Mode from explicit values', () {
    final csv = utf8.encode(
      'Name,Mode,Serial Number,Quantity,Warehouse\n'
      'Camera,SERIALIZED,CAM-001,,Main Warehouse\n'
      'Cable,BULK,,8,Main Warehouse\n',
    );
    final decoded = service.decode(
      AssetImportRequest(
        bytes: Uint8List.fromList(csv),
        fileName: 'mixed.csv',
        locale: 'en',
      ),
    );

    expect(decoded.rows.map((row) => row.type), [
      AssetImportType.serialized,
      AssetImportType.bulk,
    ]);
    expect(decoded.mappings.map((mapping) => mapping.canonicalKey), [
      'name',
      'mode',
      'serial_code',
      'quantity',
      'warehouse',
    ]);
  });

  test('external single-mode CSV can infer type without a Mode column', () {
    final csv = utf8.encode(
      'Name,Qty,Warehouse\nHDMI Cable,8,Main Warehouse\n',
    );
    final decoded = service.decode(
      AssetImportRequest(
        bytes: Uint8List.fromList(csv),
        fileName: 'bulk.csv',
        locale: 'en',
      ),
    );

    expect(decoded.rows.single.type, AssetImportType.bulk);
    expect(decoded.rows.single.canonicalValues['quantity'], '8');
  });

  test('batch payload includes each row Mode', () {
    const row = AssetImportBatchRow(
      sourceRowNumber: 12,
      type: AssetImportType.serialized,
      name: 'Wireless Mic',
      serialCode: 'WM-001',
      warehouse: 'Main Warehouse',
    );

    expect(row.toRpcMap(), {
      'source_row_number': 12,
      'mode': 'SERIALIZED',
      'name': 'Wireless Mic',
      'warehouse': 'Main Warehouse',
      'serial_code': 'WM-001',
    });
  });

  test('preview accepts valid mixed Serialized and Bulk rows', () {
    final decoded = service.decode(
      AssetImportRequest(
        bytes: Uint8List.fromList(
          utf8.encode(
            'Name,Mode,Serial Number,Quantity,Warehouse\n'
            'Camera,SERIALIZED,CAM-001,,Main Warehouse\n'
            'Cable,BULK,,8,Main Warehouse\n',
          ),
        ),
        fileName: 'valid.csv',
        locale: 'en',
      ),
    );
    final preview = service.preview(
      AssetImportPreviewRequest(
        decoded: decoded,
        context: const AssetImportPreviewContext(
          warehouses: [AssetImportWarehouseOption(name: 'Main Warehouse')],
          existingAssets: [],
        ),
      ),
    );

    expect(preview.globalIssues, isEmpty);
    expect(preview.validRowCount, 2);
    expect(
      preview.rows.every(
        (row) => row.status == AssetImportPreviewRowStatus.valid,
      ),
      isTrue,
    );
  });

  test('preview requires confirmation for a new Warehouse', () {
    final decoded = service.decode(
      AssetImportRequest(
        bytes: Uint8List.fromList(
          utf8.encode(
            'Name,Mode,Serial Number,Quantity,Warehouse\n'
            'Camera,SERIALIZED,CAM-001,,New Warehouse\n',
          ),
        ),
        fileName: 'new-warehouse.csv',
        locale: 'en',
      ),
    );
    final preview = service.preview(
      AssetImportPreviewRequest(
        decoded: decoded,
        context: const AssetImportPreviewContext(
          warehouses: [],
          existingAssets: [],
        ),
      ),
    );

    expect(
      preview.rows.single.status,
      AssetImportPreviewRowStatus.requiresConfirmation,
    );
    expect(preview.rows.single.issues.single.code, 'warehouse_new');
  });

  test('preview blocks a Warehouse name used by a Delivery Place', () {
    final decoded = service.decode(
      AssetImportRequest(
        bytes: Uint8List.fromList(
          utf8.encode(
            'Name,Mode,Serial Number,Quantity,Warehouse\n'
            'Camera,SERIALIZED,CAM-001,,Dock\n',
          ),
        ),
        fileName: 'location-conflict.csv',
        locale: 'en',
      ),
    );
    final preview = service.preview(
      AssetImportPreviewRequest(
        decoded: decoded,
        context: const AssetImportPreviewContext(
          warehouses: [],
          otherLocationNames: ['Dock'],
          existingAssets: [],
        ),
      ),
    );

    expect(preview.rows.single.status, AssetImportPreviewRowStatus.invalid);
    expect(preview.rows.single.issues.single.code, 'warehouse_type_conflict');
  });

  test('Bulk duplicate in Company requires merge confirmation', () {
    final decoded = service.decode(
      AssetImportRequest(
        bytes: Uint8List.fromList(
          utf8.encode(
            'Name,Mode,Serial Number,Quantity,Warehouse\n'
            'HDMI Cable,BULK,,8,Main Warehouse\n',
          ),
        ),
        fileName: 'bulk.csv',
        locale: 'en',
      ),
    );
    final preview = service.preview(
      AssetImportPreviewRequest(
        decoded: decoded,
        context: const AssetImportPreviewContext(
          warehouses: [AssetImportWarehouseOption(name: 'Main Warehouse')],
          existingAssets: [
            AssetImportExistingAsset(
              type: AssetImportType.bulk,
              name: 'HDMI Cable',
              warehouse: 'Main Warehouse',
              quantity: 4,
            ),
          ],
        ),
      ),
    );

    expect(
      preview.rows.single.status,
      AssetImportPreviewRowStatus.requiresConfirmation,
    );
    expect(preview.rows.single.issues.single.code, 'bulk_existing_duplicate');
  });

  test('Serialized duplicate serial remains blocked', () {
    final decoded = service.decode(
      AssetImportRequest(
        bytes: Uint8List.fromList(
          utf8.encode(
            'Name,Mode,Serial Number,Quantity,Warehouse\n'
            'Camera,SERIALIZED,S-001,,Main Warehouse\n'
            'Lens,SERIALIZED,S-001,,Main Warehouse\n',
          ),
        ),
        fileName: 'serialized.csv',
        locale: 'en',
      ),
    );
    final preview = service.preview(
      AssetImportPreviewRequest(
        decoded: decoded,
        context: const AssetImportPreviewContext(
          warehouses: [AssetImportWarehouseOption(name: 'Main Warehouse')],
          existingAssets: [],
        ),
      ),
    );

    expect(preview.invalidRowCount, 2);
    expect(
      preview.rows.every(
        (row) => row.issues.any((issue) => issue.code == 'duplicate_serial'),
      ),
      isTrue,
    );
  });
}

void _cell(Sheet sheet, int column, int row, String value) {
  sheet.updateCell(
    CellIndex.indexByColumnRow(columnIndex: column, rowIndex: row),
    TextCellValue(value),
  );
}
