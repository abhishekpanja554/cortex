import 'dart:typed_data';

import 'package:cortex/features/sync/domain/sync_failure.dart';
import 'package:dio/dio.dart';

abstract class AttachmentApi {
  /// Idempotent: uploading an id the server already has is a no-op.
  Future<void> upload(String id, Uint8List bytes);

  /// Null when the server has no such attachment (never uploaded, or not ours).
  Future<Uint8List?> download(String id);
}

class HttpAttachmentApi implements AttachmentApi {
  final Dio _dio;

  // Images are much bigger than note JSON; the shared 10 s would cut off a
  // camera photo on a slow connection.
  static const _transferTimeout = Duration(seconds: 60);

  HttpAttachmentApi(this._dio);

  @override
  Future<void> upload(String id, Uint8List bytes) async {
    try {
      // Bytes, not a file stream: the auth interceptor may replay the request
      // after a token refresh, and a stream can only be read once.
      await _dio.put(
        '/attachments/$id',
        data: bytes,
        options: Options(
          contentType: 'application/octet-stream',
          sendTimeout: _transferTimeout,
          receiveTimeout: _transferTimeout,
        ),
      );
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  @override
  Future<Uint8List?> download(String id) async {
    try {
      final response = await _dio.get<List<int>>(
        '/attachments/$id',
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: _transferTimeout,
        ),
      );
      final data = response.data;
      return data == null ? null : Uint8List.fromList(data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw _mapDioException(e);
    }
  }

  SyncFailure _mapDioException(DioException e) {
    if (e.response == null) return const NetworkUnavailableSyncFailure();
    return ServerSyncFailure(
      statusCode: e.response?.statusCode,
      message: e.message,
    );
  }
}
