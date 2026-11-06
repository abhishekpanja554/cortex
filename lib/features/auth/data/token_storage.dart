import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthTokens {
  final String accessToken;
  final String refreshToken;

  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
  });

  Map<String, dynamic> toJson() => {
        'access': accessToken,
        'refresh': refreshToken,
      };

  factory AuthTokens.fromJson(Map<String, dynamic> json) => AuthTokens(
        accessToken: json['access'] as String,
        refreshToken: json['refresh'] as String,
      );
}

class TokenStorage {
  final FlutterSecureStorage _secure;
  final SharedPreferences _prefs;
  
  static const _key = 'cortex_tokens';
  static const _emailKey = 'cortex_user_email';
  static const _flag = 'has_run_before';

  AuthTokens? _cached;
  String? _cachedEmail;

  TokenStorage(this._secure, this._prefs);

  Future<void> wipeIfFirstRun() async {
    final hasRunBefore = _prefs.getBool(_flag) ?? false;
    if (!hasRunBefore) {
      await _secure.deleteAll();
      await _prefs.setBool(_flag, true);
    }
  }

  int _version = 0;

  Future<AuthTokens?> read() async {
    if (_cached != null) return _cached;
    
    final currentVersion = _version;
    final value = await _secure.read(
      key: _key,
    );
    
    if (value == null) return null;
    
    try {
      final json = jsonDecode(value);
      final tokens = AuthTokens.fromJson(json);
      if (_version == currentVersion) {
        _cached = tokens;
      }
      return tokens;
    } catch (_) {
      return null;
    }
  }

  Future<void> write(AuthTokens tokens) async {
    _version++;
    final currentVersion = _version;
    final value = jsonEncode(tokens.toJson());
    await _secure.write(
      key: _key, 
      value: value,
    );
    if (_version == currentVersion) {
      _cached = tokens;
    }
  }

  Future<String?> readEmail() async {
    if (_cachedEmail != null) return _cachedEmail;
    final value = await _secure.read(key: _emailKey);
    _cachedEmail = value;
    return value;
  }

  Future<void> writeEmail(String email) async {
    _cachedEmail = email;
    await _secure.write(key: _emailKey, value: email);
  }

  Future<void> clear() async {
    _version++;
    _cached = null;
    _cachedEmail = null;
    await _secure.delete(
      key: _key,
    );
    await _secure.delete(
      key: _emailKey,
    );
  }
}
