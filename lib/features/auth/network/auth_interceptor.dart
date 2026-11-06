import 'package:dio/dio.dart';
import 'package:cortex/features/auth/data/token_storage.dart';
import 'package:cortex/features/auth/data/auth_repository.dart';
import 'package:cortex/features/auth/domain/auth_failure.dart';

class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this.dio,
    required this.storage,
    required this.authRepo,
    required this.onSessionExpired,
  });

  final Dio dio;
  final TokenStorage storage;
  final AuthRepository authRepo;
  final Future<void> Function() onSessionExpired;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final tokens = await storage.read();
    if (tokens != null) {
      options.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
      options.extra['token'] = tokens.accessToken;
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final response = err.response;
    if (response?.statusCode != 401 || err.requestOptions.path.startsWith('/auth/')) {
      return handler.next(err);
    }
    
    if (err.requestOptions.extra['retried'] == true) {
      return handler.next(err);
    }

    final sentToken = err.requestOptions.extra['token'];
    final currentTokens = await storage.read();
    
    // If the token in storage has changed since we sent the request,
    // another request already refreshed it. Retry immediately.
    if (currentTokens != null && sentToken != null && currentTokens.accessToken != sentToken) {
      _retry(err.requestOptions, currentTokens.accessToken, handler);
      return;
    }

    try {
      final newTokens = await authRepo.refresh();
      _retry(err.requestOptions, newTokens.accessToken, handler);
    } on SessionExpired {
      await onSessionExpired();
      handler.reject(err);
    } on NetworkUnavailable {
      handler.reject(err);
    } on ServerError {
      handler.reject(err);
    } on AuthFailure {
      handler.reject(err);
    }
  }

  void _retry(RequestOptions options, String newToken, ErrorInterceptorHandler handler) async {
    options.extra['retried'] = true;
    options.headers['Authorization'] = 'Bearer $newToken';
    try {
      final response = await dio.fetch(options);
      handler.resolve(response);
    } on DioException catch (e) {
      handler.reject(e);
    }
  }
}
