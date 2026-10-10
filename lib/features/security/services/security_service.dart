import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';

class SecurityService {
  final FlutterSecureStorage _storage;
  final LocalAuthentication _auth = LocalAuthentication();

  SecurityService(this._storage);

  static const _isPrivateModeKey = 'cortex_private_mode_enabled';
  static const _appPinKey = 'cortex_app_pin';

  static const MethodChannel _securityChannel = MethodChannel(
    'com.example.cortex/security',
  );

  bool? _cachedIsPrivateMode;

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
    await _setNativeSafeMode(enabled);
  }

  Future<void> _setNativeSafeMode(bool enabled) async {
    try {
      await _securityChannel.invokeMethod('setSafeMode', enabled);
    } on PlatformException catch (_) {
    } on MissingPluginException catch (_) {}
  }

  Future<void> clearAll() async {
    await _storage.delete(key: _appPinKey);
    await _storage.delete(key: _isPrivateModeKey);
    _cachedIsPrivateMode = null;
    await _setNativeSafeMode(false);
  }

  Future<void> syncPrivacyState() async {
    final enabled = await isPrivateModeEnabled;
    await _setNativeSafeMode(enabled);
  }

  Future<bool> authenticate() async {
    final canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
    final canAuthenticate =
        canAuthenticateWithBiometrics || await _auth.isDeviceSupported();

    if (!canAuthenticate) {
      return true;
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
