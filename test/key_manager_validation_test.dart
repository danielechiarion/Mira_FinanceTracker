import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mira_finance_tracker/backend/service/KeyManager.dart';
import 'package:mira_finance_tracker/frontend/account/GoogleConnectionPage.dart';

void main() {
  late Map<String, dynamic> keyData;
  const password = 'test-decryption-key';
  final userKey = List<int>.generate(32, (index) => index);

  setUp(() async {
    final salt = List<int>.generate(16, (index) => index + 1);
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: 100000,
      bits: 256,
    );
    final lockerKey = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
    final encryptedKey = await AesGcm.with256bits().encrypt(
      userKey,
      secretKey: lockerKey,
    );

    keyData = {
      'username': 'test-user',
      'salt': base64Encode(salt),
      'userKey': base64Encode(encryptedKey.concatenation()),
    };
  });

  test('validates and returns a complete 256-bit key', () async {
    final decryptedKey = await KeyManager().validateKeyData(password, keyData);

    expect(decryptedKey, userKey);
  });

  test('rejects an incorrect decryption key', () async {
    final decryptedKey = await KeyManager().validateKeyData(
      'incorrect-key',
      keyData,
    );

    expect(decryptedKey, isNull);
  });

  test('rejects incomplete cloud key data', () async {
    expect(
      () => KeyManager().validateKeyData(password, {'salt': keyData['salt']}),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects decrypted keys that are not 256 bits', () async {
    final salt = base64Decode(keyData['salt'] as String);
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: 100000,
      bits: 256,
    );
    final lockerKey = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
    final encryptedKey = await AesGcm.with256bits().encrypt(
      List<int>.filled(16, 1),
      secretKey: lockerKey,
    );

    expect(
      () => KeyManager().validateKeyData(password, {
        ...keyData,
        'userKey': base64Encode(encryptedKey.concatenation()),
      }),
      throwsA(isA<FormatException>()),
    );
  });

  test('treats Linux desktop as supported for Google connection', () {
    expect(
      isGoogleConnectionSupported(isWeb: false, platform: TargetPlatform.linux),
      isTrue,
    );
  });

  test('keeps unsupported platforms blocked', () {
    expect(
      isGoogleConnectionSupported(isWeb: false, platform: TargetPlatform.fuchsia),
      isFalse,
    );
  });
}
