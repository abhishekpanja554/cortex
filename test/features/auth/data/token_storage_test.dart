import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cortex/features/auth/data/token_storage.dart';

void main() {
  group('TokenStorage', () {
    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});
    });

    test('write then read returns the same pair', () async {
      final secure = const FlutterSecureStorage();
      final prefs = await SharedPreferences.getInstance();
      final storage = TokenStorage(secure, prefs);

      final tokens = AuthTokens(
        accessToken: 'access_123',
        refreshToken: 'refresh_123',
      );

      await storage.write(tokens);
      final readTokens = await storage.read();

      expect(readTokens?.accessToken, 'access_123');
      expect(readTokens?.refreshToken, 'refresh_123');
    });

    test('clear then read returns null', () async {
      final secure = const FlutterSecureStorage();
      final prefs = await SharedPreferences.getInstance();
      final storage = TokenStorage(secure, prefs);

      final tokens = AuthTokens(
        accessToken: 'access_123',
        refreshToken: 'refresh_123',
      );

      await storage.write(tokens);
      await storage.clear();
      final readTokens = await storage.read();

      expect(readTokens, isNull);
    });

    test('First run, with secure storage already holding values: wipeIfFirstRun deletes them and sets the flag', () async {
      FlutterSecureStorage.setMockInitialValues({
        'cortex_tokens': jsonEncode({
          'access': 'old_access',
          'refresh': 'old_refresh'
        }),
      });

      final secure = const FlutterSecureStorage();
      final prefs = await SharedPreferences.getInstance();
      final storage = TokenStorage(secure, prefs);

      await storage.wipeIfFirstRun();

      final stored = await secure.read(key: 'cortex_tokens');
      expect(stored, isNull);
      
      final flag = prefs.getBool('has_run_before');
      expect(flag, isTrue);
    });

    test('Second run, flag already set: wipeIfFirstRun leaves the values alone', () async {
      SharedPreferences.setMockInitialValues({
        'has_run_before': true,
      });
      FlutterSecureStorage.setMockInitialValues({
        'cortex_tokens': jsonEncode({
          'access': 'new_access',
          'refresh': 'new_refresh'
        }),
      });

      final secure = const FlutterSecureStorage();
      final prefs = await SharedPreferences.getInstance();
      final storage = TokenStorage(secure, prefs);

      await storage.wipeIfFirstRun();

      final stored = await secure.read(key: 'cortex_tokens');
      expect(stored, isNotNull);
      
      final decoded = jsonDecode(stored!);
      expect(decoded['access'], 'new_access');
    });

    test('A fresh TokenStorage instance with the same mocks can read what another instance wrote', () async {
      final secure = const FlutterSecureStorage();
      final prefs = await SharedPreferences.getInstance();
      
      final storage1 = TokenStorage(secure, prefs);
      await storage1.write(AuthTokens(
        accessToken: 'cross_access',
        refreshToken: 'cross_refresh',
      ));

      final storage2 = TokenStorage(secure, prefs);
      final readTokens = await storage2.read();
      
      expect(readTokens?.accessToken, 'cross_access');
      expect(readTokens?.refreshToken, 'cross_refresh');
    });

    test('read race: clear during read sets cache to null', () async {
      final secure = const FlutterSecureStorage();
      final prefs = await SharedPreferences.getInstance();
      final storage1 = TokenStorage(secure, prefs);
      await storage1.write(AuthTokens(accessToken: 'a', refreshToken: 'r'));
      
      final storage2 = TokenStorage(secure, prefs);
      
      final readFuture = storage2.read();
      await storage2.clear(); // Same tick
      
      await readFuture;
      final tokens = await storage2.read();
      expect(tokens, isNull);
    });
    test('write race: clear during write prevents cache from setting old tokens', () async {
      final secure = const FlutterSecureStorage();
      final prefs = await SharedPreferences.getInstance();
      final storage = TokenStorage(secure, prefs);
      
      final writeFuture = storage.write(AuthTokens(accessToken: 'a', refreshToken: 'r'));
      await storage.clear(); // Same tick
      
      await writeFuture;
      
      expect(await storage.read(), isNull);
    });
  });
}
