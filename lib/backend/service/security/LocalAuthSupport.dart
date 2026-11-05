import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

/// Centralises local auth support checks for desktop platforms.
///
/// The local_auth plugin is not reliably available on Linux, so the app
/// disables the biometric gate there instead of crashing or blocking access.
class LocalAuthSupport {
  static bool isSupportedOnCurrentPlatform() {
    if (kIsWeb) return false;

    return switch (defaultTargetPlatform) {
      TargetPlatform.android ||
      TargetPlatform.iOS ||
      TargetPlatform.macOS ||
      TargetPlatform.windows => true,
      TargetPlatform.linux => false,
      _ => false,
    };
  }

  static Future<bool> canAuthenticate() async {
    if (!isSupportedOnCurrentPlatform()) {
      return true;
    }

    final localAuth = LocalAuthentication();
    try {
      return await localAuth.isDeviceSupported();
    } on LocalAuthException {
      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> authenticate(String localizedReason) async {
    if (!isSupportedOnCurrentPlatform()) {
      return true;
    }

    final localAuth = LocalAuthentication();
    try {
      final deviceSupported = await localAuth.isDeviceSupported();
      if (!deviceSupported) {
        return false;
      }

      return await localAuth.authenticate(
        localizedReason: localizedReason,
        persistAcrossBackgrounding: true,
      );
    } on LocalAuthException {
      return false;
    } catch (_) {
      return false;
    }
  }
}
