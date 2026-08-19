import 'package:flutter_test/flutter_test.dart';
import 'package:relay_av_demo/features/transfers/transfer_screens.dart';

void main() {
  test('changing destination preserves drafted Asset lines', () {
    expect(
      transferOriginChangeNeedsAssetReset(
        changingOrigin: false,
        currentLocationId: 'destination-a',
        selectedLocationId: 'destination-b',
        hasAssetLines: true,
      ),
      isFalse,
    );
  });

  test('changing origin requires clearing drafted Asset lines', () {
    expect(
      transferOriginChangeNeedsAssetReset(
        changingOrigin: true,
        currentLocationId: 'warehouse-a',
        selectedLocationId: 'warehouse-b',
        hasAssetLines: true,
      ),
      isTrue,
    );
  });

  test('selecting the same origin keeps drafted Asset lines', () {
    expect(
      transferOriginChangeNeedsAssetReset(
        changingOrigin: true,
        currentLocationId: 'warehouse-a',
        selectedLocationId: 'warehouse-a',
        hasAssetLines: true,
      ),
      isFalse,
    );
  });
}
