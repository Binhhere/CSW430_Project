import 'package:flutter_test/flutter_test.dart';
import 'package:relay_av_demo/features/assets/asset_domain.dart';

void main() {
  test('Serialized Asset maps its immutable QR token', () {
    final asset = AssetRecord.fromMap({
      'id': 'asset-1',
      'mode': 'SERIALIZED',
      'name': 'Camera A',
      'serial_number': 'CAM-A',
      'qr_token': 'ABCDEFGHJKMNPQRS',
      'location_id': 'location-1',
      'location_name': 'Main Warehouse',
      'working_state': 'AT_WAREHOUSE',
      'state_rank': 0,
      'created_at': '2026-07-18T00:00:00.000Z',
    });

    expect(asset.isSerialized, isTrue);
    expect(asset.qrToken, 'ABCDEFGHJKMNPQRS');
  });
}
