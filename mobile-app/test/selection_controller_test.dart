import 'package:flutter_test/flutter_test.dart';
import 'package:relay_av_demo/shared/selection_controller.dart';

void main() {
  test('selection controller starts, toggles, cancels, and prunes ids', () {
    final controller = SelectionController<String>();
    addTearDown(controller.dispose);

    controller.start('a');
    controller.toggle('b');
    expect(controller.selecting, isTrue);
    expect(controller.selectedIds, {'a', 'b'});

    controller.clearMissing(['b']);
    expect(controller.selectedIds, {'b'});
    controller.toggle('b');
    expect(controller.selecting, isFalse);
    expect(controller.selectedIds, isEmpty);
  });
}
