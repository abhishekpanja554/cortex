import 'package:dio/dio.dart';
import 'package:cortex/features/auth/data/token_storage.dart';
import 'package:cortex/features/auth/domain/auth_failure.dart';

class AuthRepository {
  final Dio _dio;
  final TokenStorage _storage;
  int _session = 0;
  int get currentSession => _session;

  AuthRepository(this._dio, this._storage);

  AuthTokens _parseTokens(Response response) {
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw ServerError(response.statusCode, null);
    }

    final innerData = data['data'];
    if (innerData is! Map<String, dynamic>) {
      throw ServerError(response.statusCode, null);
    }

    final accessToken = innerData['accessToken'];
    final refreshToken = innerData['refreshToken'];

    if (accessToken is! String || refreshToken is! String) {
      throw ServerError(response.statusCode, null);
    }

    return AuthTokens(accessToken: accessToken, refreshToken: refreshToken);
  }

  Future<AuthTokens> login(String email, String password) async {
    try {
      final response = await _dio.post(
        '/auth/login',
        data: {'email': email, 'password': password},
      );
      final tokens = _parseTokens(response);
      await _storage.write(tokens);
      return tokens;
    } on DioException catch (e) {
      throw _mapException(e);
    }
  }

  Future<AuthTokens> register(String email, String password) async {
    try {
      final response = await _dio.post(
        '/auth/register',
        data: {'email': email, 'password': password},
      );
      final tokens = _parseTokens(response);
      await _storage.write(tokens);
      return tokens;
    } on DioException catch (e) {
      throw _mapException(e);
    }
  }

  Future<AuthTokens>? _inFlight;

  Future<AuthTokens> refresh() =>
      _inFlight ??= _doRefresh().whenComplete(() => _inFlight = null);

  Future<AuthTokens> _doRefresh() async {
    final currentSession = _session;

    final tokens = await _storage.read();
    if (tokens == null) {
      throw SessionExpired();
    }

    try {
      final response = await _dio.post(
        '/auth/refresh',
        data: {'refreshToken': tokens.refreshToken},
      );

      final newTokens = _parseTokens(response);

      if (_session != currentSession) {
        throw SessionExpired();
      }

      await _storage.write(newTokens);
      return newTokens;
    } on DioException catch (e) {
      throw _mapException(e);
    }
  }

  Future<void> logout() async {
    _session++;
    await _storage.clear();
  }

  AuthFailure _mapException(DioException e) {
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.response == null) {
      return NetworkUnavailable();
    }

    final response = e.response!;
    final data = response.data;

    if (data is Map<String, dynamic>) {
      final errorDetails = data['errorDetails'];
      if (errorDetails is Map<String, dynamic>) {
        final code = errorDetails['code'];
        final message = errorDetails['message'] as String?;
        final requestId = errorDetails['requestId'] as String?;

        if (code == 'INVALID_CREDENTIALS') return InvalidCredentials();
        if (code == 'EMAIL_ALREADY_IN_USE') return EmailAlreadyInUse();
        if (code == 'METHOD_ARG_NOT_VALID') {
          return ValidationFailed(message ?? 'Validation failed');
        }
        if (code == 'INVALID_REFRESH_TOKEN') return SessionExpired();

        return ServerError(response.statusCode, requestId);
      }
    }

    return ServerError(response.statusCode, null);
  }
}
