import 'package:cortex/core/network/sse_client.dart';
import 'package:cortex/core/providers/core_providers.dart';
import 'package:cortex/features/auth/data/auth_repository.dart';
import 'package:cortex/features/auth/data/token_storage.dart';
import 'package:cortex/features/auth/network/auth_interceptor.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockTokenStorage extends Mock implements TokenStorage {}

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  group('core_providers Dio configuration', () {
    late ProviderContainer container;

    setUp(() {
      final mockStorage = _MockTokenStorage();
      final mockAuthRepo = _MockAuthRepository();

      container = ProviderContainer(
        overrides: [
          tokenStorageProvider.overrideWithValue(mockStorage),
          authRepositoryProvider.overrideWithValue(mockAuthRepo),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('bareDioProvider defaults to localhost:8080 and 10s timeouts', () {
      final dio = container.read(bareDioProvider);
      expect(dio.options.baseUrl, 'http://localhost:8080');
      expect(dio.options.connectTimeout, const Duration(seconds: 10));
      expect(dio.options.receiveTimeout, const Duration(seconds: 10));
      expect(dio.interceptors.whereType<AuthInterceptor>(), isEmpty);
    });

    test('apiDioProvider defaults to localhost:8080, shares 10s connectTimeout, and has AuthInterceptor', () {
      final dio = container.read(apiDioProvider);
      expect(dio.options.baseUrl, 'http://localhost:8080');
      expect(dio.options.connectTimeout, const Duration(seconds: 10));
      expect(dio.options.receiveTimeout, const Duration(seconds: 10));
      expect(dio.interceptors.whereType<AuthInterceptor>(), hasLength(1));
    });

    test('aiDioProvider defaults to localhost:8000, shares 10s connectTimeout, has 60s receiveTimeout, and has AuthInterceptor', () {
      final dio = container.read(aiDioProvider);
      expect(dio.options.baseUrl, 'http://localhost:8000');
      // Connect timeout must match bareDio and apiDio so downtime detection stays consistent
      expect(dio.options.connectTimeout, const Duration(seconds: 10));
      // Receive timeout is 60s for long-running LLM generation
      expect(dio.options.receiveTimeout, const Duration(seconds: 60));
      expect(dio.interceptors.whereType<AuthInterceptor>(), hasLength(1));
    });

    test('sseClientProvider provides SseClient using aiDioProvider', () {
      final client = container.read(sseClientProvider);
      expect(client, isA<SseClient>());
    });
  });
}
