import 'package:flutter_test/flutter_test.dart';
import 'package:relay_av_demo/shared/dirty_form_guard.dart';

void main() {
  test('clean idle form can pop without confirmation', () {
    final controller = DirtyFormController();

    expect(controller.canPop(busy: false, dirty: false), isTrue);
    expect(controller.canPop(busy: false, dirty: true), isFalse);
    expect(controller.canPop(busy: true, dirty: false), isFalse);
  });

  test('explicitly allowed pop overrides dirty and busy state', () {
    final controller = DirtyFormController()..allowPop();

    expect(controller.canPop(busy: true, dirty: true), isTrue);
  });
}
