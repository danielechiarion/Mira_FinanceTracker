import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mira_finance_tracker/frontend/account/GoogleConnectionPage.dart';

void main() {
  group('Google connection support checks', () {
    test('Linux is not supported for Google sign-in', () {
      expect(
        isGoogleConnectionSupported(
          isWeb: false,
          platform: TargetPlatform.linux,
        ),
        isFalse,
      );
    });

    test('Android is supported for Google sign-in', () {
      expect(
        isGoogleConnectionSupported(
          isWeb: false,
          platform: TargetPlatform.android,
        ),
        isTrue,
      );
    });
  });
}
