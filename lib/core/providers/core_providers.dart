import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cortex/features/auth/data/auth_repository.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cortex/features/security/services/security_service.dart';
import 'package:cortex/features/auth/data/token_storage.dart';
import '../network/network_client.dart';
import '../network/dio_network_client.dart';

import 'package:cortex/features/auth/network/auth_interceptor.dart';
import 'package:cortex/features/auth/presentation/auth_notifier.dart';

Dio _createBaseDio() {
  final dio = Dio();
  dio.options.connectTimeout = const Duration(seconds: 10);
  dio.options.receiveTimeout = const Duration(seconds: 10);
  const String baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:8080');
  dio.options.baseUrl = baseUrl;
  return dio;
}

final bareDioProvider = Provider<Dio>((ref) {
  return _createBaseDio();
});

final apiDioProvider = Provider<Dio>((ref) {
  final dio = _createBaseDio();
  
  dio.interceptors.add(AuthInterceptor(
    dio: dio,
    storage: ref.watch(tokenStorageProvider),
    authRepo: ref.watch(authRepositoryProvider),
    onSessionExpired: () => ref.read(authProvider.notifier).onSessionExpired(),
  ));
  
  return dio;
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
  return AuthRepository(ref.watch(bareDioProvider), ref.watch(tokenStorageProvider));
});
