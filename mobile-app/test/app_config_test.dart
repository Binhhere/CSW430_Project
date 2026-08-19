import 'package:flutter_test/flutter_test.dart';
import 'package:relay_av_demo/config/app_config.dart';

void main() {
  test('default API target is the Android Studio emulator', () {
    final config = AppConfig.fromEnvironment();

    expect(config.apiBaseUrl, 'http://10.0.2.2:3000');
  });
}
