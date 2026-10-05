import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plant_app/features/notifications/domain/push_support.dart';

void main() {
  test('enables push only on native Android', () {
    expect(isPushSupported(isWeb: false, platform: TargetPlatform.android), isTrue);
    expect(isPushSupported(isWeb: true, platform: TargetPlatform.android), isFalse);
  });

  test('keeps push disabled on platforms without firebase_messaging support', () {
    for (final platform in [
      TargetPlatform.windows,
      TargetPlatform.linux,
      TargetPlatform.iOS,
      TargetPlatform.macOS,
    ]) {
      expect(isPushSupported(isWeb: false, platform: platform), isFalse, reason: '$platform');
    }
  });
}
