import 'package:flutter_test/flutter_test.dart';
import 'package:relay_av_demo/features/assets/asset_domain.dart';

void main() {
  test('Serialized Asset keeps its QR-backed identity fields', () {
    final asset = AssetRecord.fromMap({
      'id': 'asset-1',
      'mode': 'SERIALIZED',
      'name': 'Wireless Mic',
      'serial_number': 'WM-001',
      'location_id': 'location-1',
      'location_name': 'Main Warehouse',
      'working_state': 'AT_WAREHOUSE',
      'state_rank': 0,
      'storage_path': 'company-1/asset-1/cover.jpg',
      'created_at': '2026-07-17T00:00:00.000Z',
    });

    expect(asset.isSerialized, isTrue);
    expect(asset.serialNumber, 'WM-001');
    expect(asset.quantity, isNull);
    expect(asset.storagePath, 'company-1/asset-1/cover.jpg');
  });

  test('Bulk Asset keeps physical quantity and pagination sort state', () {
    final asset = AssetRecord.fromMap({
      'id': 'asset-2',
      'mode': 'BULK',
      'name': 'XLR Cable',
      'quantity': 24,
      'location_id': 'location-1',
      'location_name': 'Main Warehouse',
      'working_state': 'AT_WAREHOUSE',
      'state_rank': 0,
      'created_at': '2026-07-17T00:00:00.000Z',
    });

    expect(asset.isSerialized, isFalse);
    expect(asset.quantity, 24);
    expect(asset.stateRank, 0);
  });

  test('Assigned Asset accepts the database ASSIGNED state', () {
    final asset = AssetRecord.fromMap({
      'id': 'asset-3',
      'mode': 'SERIALIZED',
      'name': 'Wireless Mic',
      'serial_number': 'WM-003',
      'location_id': 'studio-1',
      'location_name': 'Midtown Studio',
      'working_state': 'ASSIGNED',
      'state_rank': 1,
      'created_at': '2026-07-17T00:00:00.000Z',
    });

    expect(asset.workingState, AssetWorkingState.assigned);
    expect(asset.isArchived, isFalse);
  });

  test('Bulk duplicate response requires explicit user confirmation', () {
    final result = AssetSaveResult.fromMap({
      'asset_id': 'asset-2',
      'action': 'CONFIRM_REQUIRED',
      'current_quantity': 24,
      'new_quantity': 30,
    });

    expect(result.needsMergeConfirmation, isTrue);
    expect(result.currentQuantity, 24);
    expect(result.newQuantity, 30);
  });

  test(
    'confirmed Bulk merge is identifiable so its original cover is kept',
    () {
      final result = AssetSaveResult.fromMap({
        'asset_id': 'asset-2',
        'action': 'MERGED',
        'current_quantity': 24,
        'new_quantity': 30,
      });

      expect(result.isMerged, isTrue);
      expect(result.needsMergeConfirmation, isFalse);
    },
  );

  test('archived Asset remains identifiable and can be restored in place', () {
    final archived = AssetRecord.fromMap({
      'id': 'asset-3',
      'mode': 'SERIALIZED',
      'name': 'Archived Camera',
      'serial_number': 'ARCH-001',
      'location_id': 'warehouse-1',
      'location_name': 'Main Warehouse',
      'working_state': 'ARCHIVED',
      'state_rank': 2,
      'created_at': '2026-07-17T00:00:00.000Z',
    });

    final restored = archived.copyWith(
      workingState: AssetWorkingState.atWarehouse,
      stateRank: 0,
    );

    expect(archived.isArchived, isTrue);
    expect(restored.isArchived, isFalse);
    expect(restored.id, archived.id);
    expect(restored.serialNumber, archived.serialNumber);
    expect(restored.locationId, archived.locationId);
  });
}
