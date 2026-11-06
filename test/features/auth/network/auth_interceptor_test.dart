import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cortex/features/auth/data/auth_repository.dart';
import 'package:cortex/features/auth/data/token_storage.dart';
import 'package:cortex/features/auth/domain/auth_failure.dart';
import 'package:cortex/features/auth/network/auth_interceptor.dart';
import 'dart:async';

class MockAuthRepository extends Mock implements AuthRepository {}
class MockOnSessionExpired extends Mock {
  Future<void> call();
}

class FakeAdapter implements HttpClientAdapter {
  int callCount = 0;
  final List<String?> receivedHeaders = [];
  
  /// (path) -> ResponseBody or throws DioException
  Future<ResponseBody> Function(RequestOptions)? handler;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    callCount++;
    receivedHeaders.add(options.headers['Authorization'] as String?);
    if (handler != null) {
      return handler!(options);
    }
    return ResponseBody.fromString('', 200);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('AuthInterceptor', () {
    late Dio apiDio;
    late FakeAdapter adapter;
    late TokenStorage storage;
    late MockAuthRepository authRepo;
    late MockOnSessionExpired onSessionExpired;

    setUp(() async {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});
      final secure = const FlutterSecureStorage();
      final prefs = await SharedPreferences.getInstance();
      storage = TokenStorage(secure, prefs);

      authRepo = MockAuthRepository();
      onSessionExpired = MockOnSessionExpired();
      when(() => onSessionExpired.call()).thenAnswer((_) async {});

      adapter = FakeAdapter();
      apiDio = Dio()..httpClientAdapter = adapter;
      apiDio.interceptors.add(AuthInterceptor(
        dio: apiDio,
        storage: storage,
        authRepo: authRepo,
        onSessionExpired: onSessionExpired.call,
      ));
    });

    test('1 200 -> the header has the stored access token', () async {
      await storage.write(AuthTokens(accessToken: 'T1', refreshToken: 'R1'));
      
      await apiDio.get('/test');
      
      expect(adapter.callCount, 1);
      expect(adapter.receivedHeaders[0], 'Bearer T1');
      verifyNever(() => authRepo.refresh());
    });

    test('2 401, then the refresh succeeds -> retried with the new token, the caller gets 200, refresh called once', () async {
      await storage.write(AuthTokens(accessToken: 'T1', refreshToken: 'R1'));
      
      when(() => authRepo.refresh()).thenAnswer((_) async {
        final t2 = AuthTokens(accessToken: 'T2', refreshToken: 'R2');
        await storage.write(t2);
        return t2;
      });

      adapter.handler = (options) async {
        if (options.headers['Authorization'] == 'Bearer T1') {
          return ResponseBody.fromString('', 401);
        }
        return ResponseBody.fromString('{"ok":true}', 200, headers: {
          Headers.contentTypeHeader: ['application/json']
        });
      };

      final response = await apiDio.get('/test');
      
      expect(response.statusCode, 200);
      expect(adapter.callCount, 2);
      expect(adapter.receivedHeaders[0], 'Bearer T1');
      expect(adapter.receivedHeaders[1], 'Bearer T2');
      verify(() => authRepo.refresh()).called(1);
    });

    test('3 3 concurrent requests all get 401 -> refresh called once, all 3 retried with the new token and succeed', () async {
      await storage.write(AuthTokens(accessToken: 'T1', refreshToken: 'R1'));

      final refreshCompleter = Completer<AuthTokens>();
      when(() => authRepo.refresh()).thenAnswer((_) => refreshCompleter.future);

      adapter.handler = (options) async {
        if (options.headers['Authorization'] == 'Bearer T1') {
          return ResponseBody.fromString('', 401);
        }
        return ResponseBody.fromString('', 200);
      };

      final futures = [
        apiDio.get('/1'),
        apiDio.get('/2'),
        apiDio.get('/3'),
      ];

      // Delay to ensure all reach 401 and at least one enters refresh
      await Future.delayed(const Duration(milliseconds: 100));

      // Resolve refresh
      final t2 = AuthTokens(accessToken: 'T2', refreshToken: 'R2');
      await storage.write(t2);
      refreshCompleter.complete(t2);

      final responses = await Future.wait(futures);

      for (final res in responses) {
        expect(res.statusCode, 200);
      }
      verify(() => authRepo.refresh()).called(3);
      
      // 3 original requests + 3 retries
      expect(adapter.callCount, 6);
      expect(adapter.receivedHeaders.where((h) => h == 'Bearer T2').length, 3);
    });

    test('4 Refresh throws SessionExpired -> onSessionExpired called, every caller gets an error', () async {
      await storage.write(AuthTokens(accessToken: 'T1', refreshToken: 'R1'));

      final refreshCompleter = Completer<AuthTokens>();
      when(() => authRepo.refresh()).thenAnswer((_) => refreshCompleter.future);

      adapter.handler = (options) async {
        return ResponseBody.fromString('', 401);
      };

      final futures = [
        apiDio.get('/1'),
        apiDio.get('/2'),
        apiDio.get('/3'),
      ];

      await Future.delayed(const Duration(milliseconds: 100));
      refreshCompleter.completeError(SessionExpired());

      final results = await Future.wait(futures.map((f) async {
        try {
          return await f;
        } catch (e) {
          return e;
        }
      }));
      for (final res in results) {
        expect(res, isA<DioException>());
      }
      
      verify(() => authRepo.refresh()).called(3);
      verify(() => onSessionExpired.call()).called(3); // Called for each waiting interceptor
      expect(adapter.callCount, 3);
    });

    test('5 Refresh throws NetworkUnavailable -> onSessionExpired never called', () async {
      await storage.write(AuthTokens(accessToken: 'T1', refreshToken: 'R1'));

      when(() => authRepo.refresh()).thenThrow(NetworkUnavailable());

      adapter.handler = (options) async {
        return ResponseBody.fromString('', 401);
      };

      await expectLater(() => apiDio.get('/test'), throwsA(isA<DioException>()));
      verify(() => authRepo.refresh()).called(1);
      verifyNever(() => onSessionExpired.call());
    });

    test('6 The retried request gets 401 again -> no second refresh, the error reaches the caller', () async {
      await storage.write(AuthTokens(accessToken: 'T1', refreshToken: 'R1'));

      when(() => authRepo.refresh()).thenAnswer((_) async {
        final t2 = AuthTokens(accessToken: 'T2', refreshToken: 'R2');
        await storage.write(t2);
        return t2;
      });

      adapter.handler = (options) async {
        return ResponseBody.fromString('', 401);
      };

      await expectLater(() => apiDio.get('/test'), throwsA(isA<DioException>().having((e) => e.response?.statusCode, 'status', 401)));
      
      verify(() => authRepo.refresh()).called(1);
      expect(adapter.callCount, 2); // 1 original + 1 retry
    });

    test('7 Stale token: storage already holds T2 when a 401 arrives for a request sent with T1 -> retried with T2, refresh never called', () async {
      await storage.write(AuthTokens(accessToken: 'T1', refreshToken: 'R1'));

      adapter.handler = (options) async {
        if (options.headers['Authorization'] == 'Bearer T1') {
          // While the 401 is inflight, another process updates storage
          await storage.write(AuthTokens(accessToken: 'T2', refreshToken: 'R2'));
          return ResponseBody.fromString('', 401);
        }
        return ResponseBody.fromString('', 200);
      };

      final response = await apiDio.get('/test');

      expect(response.statusCode, 200);
      verifyNever(() => authRepo.refresh());
      expect(adapter.callCount, 2);
      expect(adapter.receivedHeaders[0], 'Bearer T1');
      expect(adapter.receivedHeaders[1], 'Bearer T2');
    });
    test('8 Real AuthRepository with second adapter proves 3 concurrent 401s = 1 network refresh', () async {
      final realAuthAdapter = FakeAdapter();
      final realDio = Dio()..httpClientAdapter = realAuthAdapter;
      final realAuthRepo = AuthRepository(realDio, storage);

      final realApiAdapter = FakeAdapter();
      final realApiDio = Dio()..httpClientAdapter = realApiAdapter;
      realApiDio.interceptors.add(AuthInterceptor(
        dio: realApiDio,
        storage: storage,
        authRepo: realAuthRepo,
        onSessionExpired: onSessionExpired.call,
      ));

      await storage.write(AuthTokens(accessToken: 'T1', refreshToken: 'R1'));

      // Real auth repo will hit this for refresh
      realAuthAdapter.handler = (options) async {
        await Future.delayed(const Duration(milliseconds: 100)); // Simulate network latency
        return ResponseBody.fromString(
          '{"status":"SUCCESS","data":{"accessToken":"T2","refreshToken":"R2"}}',
          200,
          headers: {Headers.contentTypeHeader: ['application/json']},
        );
      };

      // API adapter hits 401 for T1, 200 for T2
      realApiAdapter.handler = (options) async {
        if (options.headers['Authorization'] == 'Bearer T1') {
          return ResponseBody.fromString('', 401);
        }
        return ResponseBody.fromString('', 200);
      };

      final futures = [
        realApiDio.get('/1'),
        realApiDio.get('/2'),
        realApiDio.get('/3'),
      ];

      final responses = await Future.wait(futures);

      for (final res in responses) {
        expect(res.statusCode, 200);
      }

      // 3 API calls (T1) + 3 Retries (T2)
      expect(realApiAdapter.callCount, 6);
      
      // Proves single flight!
      expect(realAuthAdapter.callCount, 1);
    });
  });
}
