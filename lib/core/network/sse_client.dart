import 'dart:convert';
import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import 'ai_event.dart';
import 'ai_failure.dart';

/// Server-Sent Events (SSE) client for streaming from cortex-ai.
class SseClient {
  final Dio _dio;

  SseClient(this._dio);

  /// Streams raw JSON event maps from an SSE POST endpoint.
  Stream<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    CancelToken? cancelToken,
  }) async* {
    Response<ResponseBody> response;
    try {
      response = await _dio.post<ResponseBody>(
        path,
        data: body,
        cancelToken: cancelToken,
        options: Options(
          responseType: ResponseType.stream,
          headers: {'Accept': 'text/event-stream'},
        ),
      );
    } on DioException catch (e) {
      throw mapDioExceptionToAiFailure(e);
    } catch (e) {
      if (e is AiFailure) rethrow;
      throw AiServerError(e.toString());
    }

    final responseBody = response.data;
    if (responseBody == null) {
      throw const AiServerError('Response body is null');
    }

    yield* parseStream(responseBody.stream);
  }

  /// Streams strongly typed [AiEvent]s from an SSE POST endpoint.
  /// Unknown event types from newer server versions are skipped.
  Stream<AiEvent> postEvents(
    String path,
    Map<String, dynamic> body, {
    CancelToken? cancelToken,
  }) async* {
    await for (final map in post(path, body, cancelToken: cancelToken)) {
      final event = AiEvent.fromMap(map);
      if (event != null) {
        yield event;
      }
    }
  }

  /// Confirms or rejects a pending destructive agent action.
  /// Returns a map containing the status: 'executed' | 'rejected' | 'already_executed' | 'already_rejected' | 'in_progress' | 'not_found' | 'error'.
  Future<Map<String, dynamic>> confirmAction({
    required String confirmationId,
    required bool approve,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        '/agent-chat/confirm',
        data: {
          'confirmation_id': confirmationId,
          'approve': approve,
        },
        cancelToken: cancelToken,
      );
      final data = response.data;
      if (data is Map && data.containsKey('status')) {
        return Map<String, dynamic>.from(data);
      }
      throw const AiServerError('Unexpected response from approval server');
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return {
          'status': 'not_found',
          'message': (e.response?.data is Map)
              ? (e.response?.data['detail'] ??
                  'Pending action not found or already resolved')
              : 'Pending action not found or already resolved',
        };
      }
      if (e.response?.statusCode == 409) {
        final data = e.response?.data;
        final detail = (data is Map) ? data['detail'] : null;
        if (detail is Map) {
          return {
            'status': detail['status']?.toString() ?? 'conflict',
            'message': detail['message']?.toString() ?? 'Action conflict',
          };
        }
        return {
          'status': 'conflict',
          'message': 'Action conflict',
        };
      }
      throw mapDioExceptionToAiFailure(e);
    } catch (e) {
      if (e is AiFailure) rethrow;
      throw AiServerError(e.toString());
    }
  }

  /// Parses raw byte stream chunks conforming to the SSE specification.
  ///
  /// Uses [utf8.decoder] as a [StreamTransformer] to safely handle multi-byte
  /// code points split across chunk boundaries.
  static Stream<Map<String, dynamic>> parseStream(
    Stream<List<int>> byteStream,
  ) async* {
    final List<String> dataBuffer = [];

    final lines = byteStream
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    try {
      await for (final line in lines) {
        // Starts with : → a comment or keep-alive, so ignore it
        if (line.startsWith(':')) {
          continue;
        }

        // Starts with data: → remove the prefix plus at most one space
        if (line.startsWith('data:')) {
          var value = line.substring(5);
          if (value.startsWith(' ')) {
            value = value.substring(1);
          }
          dataBuffer.add(value);
        } else if (line.isEmpty) {
          // Empty line → join buffer with \n, JSON-decode, emit, and clear buffer
          if (dataBuffer.isNotEmpty) {
            final payload = dataBuffer.join('\n');
            dataBuffer.clear();
            try {
              final decoded = jsonDecode(payload);
              if (decoded is Map<String, dynamic>) {
                yield decoded;
              } else {
                developer.log(
                  'Malformed SSE JSON payload (not a Map): $payload',
                  name: 'cortex.sse',
                );
              }
            } catch (e, st) {
              developer.log(
                'Malformed SSE JSON payload: $payload',
                name: 'cortex.sse',
                error: e,
                stackTrace: st,
              );
            }
          }
        }
      }
    } on DioException catch (e) {
      throw mapDioExceptionToAiFailure(e);
    } catch (e) {
      if (e is AiFailure) rethrow;
      throw AiServerError('Broken stream: $e');
    } finally {
      // When the stream ends, throw away an unfinished event instead of emitting half of one.
      // That's what the SSE standard specifies.
      dataBuffer.clear();
    }
  }

  /// Parses raw byte stream chunks into strongly-typed [AiEvent]s, skipping unknown types.
  static Stream<AiEvent> parseEvents(Stream<List<int>> byteStream) async* {
    await for (final map in parseStream(byteStream)) {
      final event = AiEvent.fromMap(map);
      if (event != null) {
        yield event;
      }
    }
  }
}
