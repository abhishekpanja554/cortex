import 'package:dio/dio.dart';
import 'network_client.dart';
import 'network_exception.dart';

class DioNetworkClient implements NetworkClient {
  final Dio _dio;

  DioNetworkClient(this._dio);

  @override
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
  }) async {
    try {
      final response = await _dio.get(
        path,
        queryParameters: queryParameters,
        options: Options(headers: headers),
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<dynamic> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
  }) async {
    try {
      final response = await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: Options(headers: headers),
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<dynamic> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
  }) async {
    try {
      final response = await _dio.put(
        path,
        data: data,
        queryParameters: queryParameters,
        options: Options(headers: headers),
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<dynamic> patch(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
  }) async {
    try {
      final response = await _dio.patch(
        path,
        data: data,
        queryParameters: queryParameters,
        options: Options(headers: headers),
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<dynamic> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
  }) async {
    try {
      final response = await _dio.delete(
        path,
        data: data,
        queryParameters: queryParameters,
        options: Options(headers: headers),
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  NetworkException _handleError(DioException error) {
    if (error.response != null) {
      // The server responded with a status code that falls out of the range of 2xx
      return NetworkException(
        error.message ?? 'Unknown error occurred',
        statusCode: error.response?.statusCode,
      );
    } else {
      // Something happened in setting up or sending the request that triggered an Error
      return NetworkException(error.message ?? 'Connection error');
    }
  }
}
