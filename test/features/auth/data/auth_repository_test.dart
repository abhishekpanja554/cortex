import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cortex/features/auth/data/auth_repository.dart';
import 'package:cortex/features/auth/data/token_storage.dart';
import 'package:cortex/features/auth/domain/auth_failure.dart';

class FakeHttpClientAdapter implements HttpClientAdapter {
  int callCount = 0;
  String? nextResponseJson;
  int? nextResponseStatus;
  DioException? nextError;
  Duration? delay;
  
  RequestOptions? lastOptions;
  String? lastBody;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    callCount++;
    lastOptions = options;
    if (requestStream != null) {
      final bytes = await requestStream.expand((element) => element).toList();
      lastBody = utf8.decode(bytes);
    } else {
      lastBody = null;
    }

    if (delay != null) {
      await Future.delayed(delay!);
    }
    if (nextError != null) throw nextError!;
    if (nextResponseJson != null && nextResponseStatus != null) {
      return ResponseBody.fromString(
        nextResponseJson!,
        nextResponseStatus!,
        headers: nextResponseJson!.startsWith('<')
            ? {Headers.contentTypeHeader: ['text/html']}
            : {Headers.contentTypeHeader: ['application/json']},
      );
    }
    throw UnimplementedError('Set response or nextError');
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('AuthRepository', () {
    late FakeHttpClientAdapter adapter;
    late Dio dio;
    late TokenStorage storage;
    late AuthRepository repo;
    late FlutterSecureStorage secure;

    setUp(() async {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});
      secure = const FlutterSecureStorage();
      final prefs = await SharedPreferences.getInstance();
      storage = TokenStorage(secure, prefs);
      
      adapter = FakeHttpClientAdapter();
      dio = Dio()..httpClientAdapter = adapter;
      repo = AuthRepository(dio, storage);
    });

    test('Login success -> tokens saved', () async {
      adapter.nextResponseStatus = 200;
      adapter.nextResponseJson = jsonEncode({
        'status': 'SUCCESS', 
        'data': {'accessToken': 'acc', 'refreshToken': 'ref'}
      });

      await repo.login('test@test.com', 'password');

      expect(adapter.lastOptions?.path, '/auth/login');
      final reqBody = jsonDecode(adapter.lastBody!);
      expect(reqBody['email'], 'test@test.com');
      expect(reqBody['password'], 'password');

      final tokens = await storage.read();
      expect(tokens?.accessToken, 'acc');
      expect(tokens?.refreshToken, 'ref');
    });

    test('Login 401 INVALID_CREDENTIALS -> InvalidCredentials, storage unchanged', () async {
      adapter.nextResponseStatus = 401;
      adapter.nextResponseJson = jsonEncode({
        'status': 'ERROR', 
        'errorDetails': {'code': 'INVALID_CREDENTIALS', 'requestId': 'req-1'}
      });

      await expectLater(() => repo.login('test@test.com', 'password'), throwsA(isA<InvalidCredentials>()));
      
      final tokens = await storage.read();
      expect(tokens, isNull);
    });

    test('Register 409 -> EmailAlreadyInUse', () async {
      adapter.nextResponseStatus = 409;
      adapter.nextResponseJson = jsonEncode({
        'status': 'ERROR', 
        'errorDetails': {'code': 'EMAIL_ALREADY_IN_USE', 'requestId': 'req-1'}
      });

      await expectLater(() => repo.register('test@test.com', 'password'), throwsA(isA<EmailAlreadyInUse>()));
      expect(adapter.lastOptions?.path, '/auth/register');
    });

    test('Register 400 -> ValidationFailed with server message', () async {
      adapter.nextResponseStatus = 400;
      adapter.nextResponseJson = jsonEncode({
        'status': 'ERROR', 
        'errorDetails': {'code': 'METHOD_ARG_NOT_VALID', 'message': 'Invalid email format', 'requestId': 'req-1'}
      });

      try {
        await repo.register('test', 'password');
        fail('Should throw');
      } on ValidationFailed catch (e) {
        expect(e.message, 'Invalid email format');
      }
    });

    test('Connection error -> NetworkUnavailable', () async {
      adapter.nextError = DioException(
        requestOptions: RequestOptions(path: '/auth/login'),
        type: DioExceptionType.connectionError,
      );

      await expectLater(() => repo.login('test@test.com', 'password'), throwsA(isA<NetworkUnavailable>()));
    });

    test('Refresh 401 -> SessionExpired', () async {
      await storage.write(const AuthTokens(accessToken: 'old', refreshToken: 'old'));
      
      adapter.nextResponseStatus = 401;
      adapter.nextResponseJson = jsonEncode({
        'status': 'ERROR', 
        'errorDetails': {'code': 'INVALID_REFRESH_TOKEN', 'requestId': 'req-1'}
      });

      await expectLater(() => repo.refresh(), throwsA(isA<SessionExpired>()));
      expect(adapter.lastOptions?.path, '/auth/refresh');
      final reqBody = jsonDecode(adapter.lastBody!);
      expect(reqBody['refreshToken'], 'old');
    });

    test('Refresh with connection error -> NetworkUnavailable, tokens not touched', () async {
      await storage.write(const AuthTokens(accessToken: 'old', refreshToken: 'old'));
      
      adapter.nextError = DioException(
        requestOptions: RequestOptions(path: '/auth/refresh'),
        type: DioExceptionType.connectionTimeout,
      );

      await expectLater(() => repo.refresh(), throwsA(isA<NetworkUnavailable>()));
      
      final tokens = await storage.read();
      expect(tokens?.accessToken, 'old');
    });

    test('No stored tokens -> SessionExpired, adapter called 0 times', () async {
      await expectLater(() => repo.refresh(), throwsA(isA<SessionExpired>()));
      expect(adapter.callCount, 0);
    });

    test('3 concurrent refresh calls, adapter waits 100ms -> adapter called exactly once', () async {
      await storage.write(const AuthTokens(accessToken: 'old', refreshToken: 'old'));
      
      adapter.delay = const Duration(milliseconds: 100);
      adapter.nextResponseStatus = 200;
      adapter.nextResponseJson = jsonEncode({
        'status': 'SUCCESS', 
        'data': {'accessToken': 'new_acc', 'refreshToken': 'new_ref'}
      });

      final futures = [
        repo.refresh(),
        repo.refresh(),
        repo.refresh(),
      ];

      final results = await Future.wait(futures);
      
      expect(adapter.callCount, 1);
      expect(results[0].accessToken, 'new_acc');
      expect(results[1].accessToken, 'new_acc');
      expect(results[2].accessToken, 'new_acc');
      
      expect(identical(results[0], results[1]), isTrue);
      expect(identical(results[1], results[2]), isTrue);

      final tokens = await storage.read();
      expect(tokens?.refreshToken, 'new_ref');
    });

    test('After a failed refresh, a later refresh calls network again', () async {
      await storage.write(const AuthTokens(accessToken: 'old', refreshToken: 'old'));
      
      adapter.nextError = DioException(
        requestOptions: RequestOptions(path: '/auth/refresh'),
        type: DioExceptionType.connectionError,
      );

      await expectLater(() => repo.refresh(), throwsA(isA<NetworkUnavailable>()));
      expect(adapter.callCount, 1);

      // Now it should succeed
      adapter.nextError = null;
      adapter.nextResponseStatus = 200;
      adapter.nextResponseJson = jsonEncode({
        'status': 'SUCCESS', 
        'data': {'accessToken': 'new', 'refreshToken': 'new'}
      });

      final result = await repo.refresh();
      expect(result.accessToken, 'new');
      expect(adapter.callCount, 2);
    });

    test('ServerError: 500 Spring default', () async {
      adapter.nextResponseStatus = 500;
      adapter.nextResponseJson = jsonEncode({
        'timestamp': '2026-10-10T00:00:00.000Z',
        'status': 500,
        'error': 'Internal Server Error',
        'message': '',
        'path': '/auth/login'
      });

      try {
        await repo.login('a@b.com', 'pwd');
        fail('Should throw');
      } on ServerError catch (e) {
        expect(e.status, 500);
        expect(e.requestId, isNull);
      }
    });

    test('ServerError: ERROR with unhandled code and requestId', () async {
      adapter.nextResponseStatus = 403;
      adapter.nextResponseJson = jsonEncode({
        'status': 'ERROR', 
        'errorDetails': {'code': 'SOME_WEIRD_CODE', 'requestId': 'req-999'}
      });

      try {
        await repo.login('a@b.com', 'pwd');
        fail('Should throw');
      } on ServerError catch (e) {
        expect(e.status, 403);
        expect(e.requestId, 'req-999');
      }
    });

    test('Logout clears storage', () async {
      await storage.write(const AuthTokens(accessToken: 'old', refreshToken: 'old'));
      await repo.logout();
      
      final tokens = await storage.read();
      expect(tokens, isNull);
    });

    test('Logout race: logout during refresh discards new tokens and throws', () async {
      await storage.write(const AuthTokens(accessToken: 'old', refreshToken: 'old'));
      
      adapter.delay = const Duration(milliseconds: 100);
      adapter.nextResponseStatus = 200;
      adapter.nextResponseJson = jsonEncode({
        'status': 'SUCCESS', 
        'data': {'accessToken': 'new_acc', 'refreshToken': 'new_ref'}
      });

      final refreshFuture = repo.refresh();
      await Future.delayed(const Duration(milliseconds: 10));
      await repo.logout();

      await expectLater(() => refreshFuture, throwsA(isA<SessionExpired>()));
      final tokens = await storage.read();
      expect(tokens, isNull);
    });

    test('200 text/html on login -> ServerError', () async {
      adapter.nextResponseStatus = 200;
      adapter.nextResponseJson = '<html><body>Captive Portal</body></html>';
      
      try {
        await repo.login('test@test.com', 'password');
        fail('Should throw');
      } on ServerError catch (e) {
        expect(e.status, 200);
      }
    });

    test('200 text/html on register -> ServerError', () async {
      adapter.nextResponseStatus = 200;
      adapter.nextResponseJson = '<html><body>Captive Portal</body></html>';
      
      try {
        await repo.register('test@test.com', 'password');
        fail('Should throw');
      } on ServerError catch (e) {
        expect(e.status, 200);
      }
    });

    test('200 text/html on refresh -> ServerError', () async {
      await storage.write(const AuthTokens(accessToken: 'old', refreshToken: 'old'));
      adapter.nextResponseStatus = 200;
      adapter.nextResponseJson = '<html><body>Captive Portal</body></html>';
      
      try {
        await repo.refresh();
        fail('Should throw');
      } on ServerError catch (e) {
        expect(e.status, 200);
      }
    });
    test('Logout race: early logout during keychain read discards new tokens and throws', () async {
      final localSecure = const FlutterSecureStorage();
      final localPrefs = await SharedPreferences.getInstance();
      
      final storage1 = TokenStorage(localSecure, localPrefs);
      await storage1.write(const AuthTokens(accessToken: 'old', refreshToken: 'old'));
      
      // Use a new TokenStorage so the in-memory cache is empty, forcing an async keychain read.
      final storage2 = TokenStorage(localSecure, localPrefs);
      final repo2 = AuthRepository(dio, storage2);
      
      adapter.delay = const Duration(milliseconds: 100);
      adapter.nextResponseStatus = 200;
      adapter.nextResponseJson = jsonEncode({
        'status': 'SUCCESS', 
        'data': {'accessToken': 'new_acc', 'refreshToken': 'new_ref'}
      });

      final refreshFuture = repo2.refresh();
      // Call logout immediately without delaying, hitting the 'await _storage.read()' gap
      await repo2.logout();

      await expectLater(() => refreshFuture, throwsA(isA<SessionExpired>()));
      final tokens = await storage2.read();
      expect(tokens?.accessToken, isNot('new_acc'));
    });

  });
}
