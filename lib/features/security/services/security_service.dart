import 'dart:convert';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';

class SecurityService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final LocalAuthentication _auth = LocalAuthentication();

  static const _encryptionKeyKey = 'cortex_encryption_key';
  static const _isPrivateModeKey = 'cortex_private_mode_enabled';
  static const _appPinKey = 'cortex_app_pin';

  static const MethodChannel _securityChannel = MethodChannel(
    'com.example.cortex/security',
  );

  bool? _cachedIsPrivateMode;
  encrypt.Key? _cachedKey;

  Future<bool> get hasAppPin async {
    final pin = await _storage.read(key: _appPinKey);
    return pin != null && pin.isNotEmpty;
  }

  Future<void> setAppPin(String pin) async {
    await _storage.write(key: _appPinKey, value: pin);
  }

  Future<bool> verifyAppPin(String pin) async {
    final storedPin = await _storage.read(key: _appPinKey);
    return storedPin == pin;
  }

  Future<bool> get isDeviceSecurityAvailable async {
    final canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
    final isSupported = await _auth.isDeviceSupported();
    return canAuthenticateWithBiometrics || isSupported;
  }

  Future<bool> get isPrivateModeEnabled async {
    if (_cachedIsPrivateMode != null) return _cachedIsPrivateMode!;
    final val = await _storage.read(key: _isPrivateModeKey);
    _cachedIsPrivateMode = val == 'true';
    return _cachedIsPrivateMode!;
  }

  Future<void> setPrivateMode(bool enabled) async {
    await _storage.write(
      key: _isPrivateModeKey,
      value: enabled ? 'true' : 'false',
    );
    _cachedIsPrivateMode = enabled;
    if (enabled) {
      await _getOrCreateKey();
    }
    await _setNativeSafeMode(enabled);
  }

  Future<void> _setNativeSafeMode(bool enabled) async {
    try {
      await _securityChannel.invokeMethod('setSafeMode', enabled);
    } on PlatformException catch (_) {
      /// Ignore if not supported on this platform
    }
  }

  /// Ensures the native privacy flag (e.g. FLAG_SECURE) matches the current setting.
  /// Should be called on app startup/resume.
  Future<void> syncPrivacyState() async {
    final enabled = await isPrivateModeEnabled;
    await _setNativeSafeMode(enabled);
  }

  Future<encrypt.Key> _getOrCreateKey() async {
    if (_cachedKey != null) return _cachedKey!;
    String? keyBase64 = await _storage.read(key: _encryptionKeyKey);
    if (keyBase64 == null) {
      final key = encrypt.Key.fromSecureRandom(32);
      keyBase64 = base64Url.encode(key.bytes);
      await _storage.write(key: _encryptionKeyKey, value: keyBase64);
      _cachedKey = key;
      return key;
    }
    _cachedKey = encrypt.Key(base64Url.decode(keyBase64));
    return _cachedKey!;
  }

  Future<String> encryptData(String plaintext) async {
    final isEnabled = await isPrivateModeEnabled;
    if (!isEnabled) return plaintext;

    final key = await _getOrCreateKey();
    final iv = encrypt.IV.fromSecureRandom(12);
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

    if (!canAuthenticate) {
      return true; // fail open if no biometics setup
    }

    try {
      return await _auth.authenticate(
        localizedReason: 'Pls authenticate to access Cortex',
        authMessages: const [
          AndroidAuthMessages(
            signInTitle: 'Biometric authentication required',
            signInHint: 'Verify identity',
          ),
        ],
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } catch (e) {
      return false;
    }
  }
}
