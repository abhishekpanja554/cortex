import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cortex/features/auth/data/auth_repository.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cortex/features/security/services/security_service.dart';
import 'package:cortex/features/auth/data/token_storage.dart';
import '../network/network_client.dart';
import '../network/dio_network_client.dart';

import 'package:cortex/core/network/sse_client.dart';
import 'package:cortex/features/auth/network/auth_interceptor.dart';
import 'package:cortex/features/auth/presentation/auth_notifier.dart';

const Duration _sharedConnectTimeout = Duration(seconds: 10);
const Duration _defaultReceiveTimeout = Duration(seconds: 10);

/// Helper to construct Dio instances with shared base configuration,
/// preventing timeout values and options from drifting apart.
Dio _createConfiguredDio({
  required String baseUrl,
  Duration connectTimeout = _sharedConnectTimeout,
  Duration receiveTimeout = _defaultReceiveTimeout,
}) {
  final dio = Dio();
  dio.options.connectTimeout = connectTimeout;
  dio.options.receiveTimeout = receiveTimeout;
  dio.options.baseUrl = baseUrl;
  return dio;
}

void _attachAuthInterceptor(Dio dio, Ref ref) {
  dio.interceptors.add(
    AuthInterceptor(
      dio: dio,
      storage: ref.watch(tokenStorageProvider),
      authRepo: ref.watch(authRepositoryProvider),
      onSessionExpired: () =>
          ref.read(authProvider.notifier).onSessionExpired(),
    ),
  );
}

const String _apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8080',
);

const String _aiBaseUrl = String.fromEnvironment(
  'AI_BASE_URL',
  defaultValue: 'http://localhost:8000',
);

final bareDioProvider = Provider<Dio>((ref) {
  return _createConfiguredDio(baseUrl: _apiBaseUrl);
});

final apiDioProvider = Provider<Dio>((ref) {
  final dio = _createConfiguredDio(baseUrl: _apiBaseUrl);
  _attachAuthInterceptor(dio, ref);
  return dio;
});

final aiDioProvider = Provider<Dio>((ref) {
  final dio = _createConfiguredDio(
    baseUrl: _aiBaseUrl,
    // LLM responses stream tokens over an extended generation window, so receiveTimeout
    // is set to 60s to avoid prematurely aborting active responses. Connect timeout stays
    // at the shared 10s default so that a down cortex-ai service is detected immediately.
    receiveTimeout: const Duration(seconds: 60),
  );
  _attachAuthInterceptor(dio, ref);
  return dio;
});

final sseClientProvider = Provider<SseClient>((ref) {
  return SseClient(ref.watch(aiDioProvider));
});

final networkClientProvider = Provider<NetworkClient>((ref) {
  final dio = ref.watch(apiDioProvider);
  return DioNetworkClient(dio);
});

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  throw UnimplementedError();
});

final securityServiceProvider = Provider<SecurityService>((ref) {
  return SecurityService(ref.watch(secureStorageProvider));
});

final tokenStorageProvider = Provider<TokenStorage>((ref) {
  throw UnimplementedError();
});

final documentsDirectoryProvider = Provider<Directory>((ref) {
  throw UnimplementedError();
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(bareDioProvider),
    ref.watch(tokenStorageProvider),
  );
});
