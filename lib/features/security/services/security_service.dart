import 'dart:convert';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class SecurityService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final LocalAuthentication _auth = LocalAuthentication();

  static const _encryptionKeyKey = 'cortex_encryption_key';
  static const _isPrivateModeKey = 'cortex_private_mode_enabled';

  Future<bool> get isPrivateModeEnabled async {
    final val = await _storage.read(key: _isPrivateModeKey);
    return val == 'true';
  }

  Future<void> setPrivateMode(bool enabled) async {
    await _storage.write(
      key: _isPrivateModeKey,
      value: enabled ? 'true' : 'false',
    );
    if (enabled) {
      await _getOrCreateKey();
    }
  }

  Future<encrypt.Key> _getOrCreateKey() async {
    String? keyBase64 = await _storage.read(key: _encryptionKeyKey);
    if (keyBase64 == null) {
      final key = encrypt.Key.fromSecureRandom(32);
      keyBase64 = base64Url.encode(key.bytes);
      await _storage.write(key: _encryptionKeyKey, value: keyBase64);
      return key;
    }
    return encrypt.Key(base64Url.decode(keyBase64));
  }

  Future<String> encryptData(String plaintext) async {
    final isEnabled = await isPrivateModeEnabled;
    if (!isEnabled) return plaintext;

    final key = await _getOrCreateKey();
    final iv = encrypt.IV.fromSecureRandom(12); // AES-GCM standard IV size
    final encrypter = encrypt.Encrypter(
      encrypt.AES(key, mode: encrypt.AESMode.gcm),
    );

    final encrypted = encrypter.encrypt(plaintext, iv: iv);

    final payload = '${base64Url.encode(iv.bytes)}:${encrypted.base64}';
    return payload;
  }

  Future<String> decryptData(String payload) async {
    if (!payload.contains(':')) return payload; // Not encrypted or malformed

    try {
      final parts = payload.split(':');
      if (parts.length != 2) return payload;

      final key = await _getOrCreateKey();
      final iv = encrypt.IV(base64Url.decode(parts[0]));
      final ciphertext = encrypt.Encrypted.fromBase64(parts[1]);

      final encrypter = encrypt.Encrypter(
        encrypt.AES(key, mode: encrypt.AESMode.gcm),
      );
      return encrypter.decrypt(ciphertext, iv: iv);
    } catch (e) {
      return payload;
    }
  }

  Future<bool> authenticate() async {
    final canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
    final canAuthenticate =
        canAuthenticateWithBiometrics || await _auth.isDeviceSupported();

    if (!canAuthenticate)
      return true; // Fail open if no biometrics setup (or prompt for PIN)

    try {
      return await _auth.authenticate(
        localizedReason: 'Please authenticate to access Cortex',
        persistAcrossBackgrounding: true,
        biometricOnly: false,
      );
    } catch (e) {
      return false;
    }
  }
}
