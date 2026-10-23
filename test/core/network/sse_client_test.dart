import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:cortex/core/network/ai_event.dart';
import 'package:cortex/core/network/ai_failure.dart';
import 'package:cortex/core/network/sse_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) onFetch;
  _FakeAdapter(this.onFetch);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return onFetch(options);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('SseClient SSE parsing tests', () {
    // 1. One event in one chunk
    test('1: One event in one chunk', () async {
      final raw = utf8.encode('data: {"type": "token", "text": "hello"}\n\n');
      final stream = Stream.value(raw);
      final events = await SseClient.parseStream(stream).toList();

      expect(events, [
        {'type': 'token', 'text': 'hello'},
      ]);
    });

    // 2. One event split across 3 chunks at arbitrary byte positions
    test('2: One event split across 3 chunks at arbitrary byte positions', () async {
      final raw = utf8.encode('data: {"type": "token", "text": "hello"}\n\n');
      // Split into 3 chunks: [0..7], [7..18], [18..end]
      final chunk1 = raw.sublist(0, 7);
      final chunk2 = raw.sublist(7, 18);
      final chunk3 = raw.sublist(18);

      final stream = Stream.fromIterable([chunk1, chunk2, chunk3]);
      final events = await SseClient.parseStream(stream).toList();

      expect(events, [
        {'type': 'token', 'text': 'hello'},
      ]);
    });

    // 3. Two events in one chunk
    test('3: Two events in one chunk', () async {
      final raw = utf8.encode(
        'data: {"type": "token", "text": "first"}\n\n'
        'data: {"type": "token", "text": "second"}\n\n',
      );
      final stream = Stream.value(raw);
      final events = await SseClient.parseStream(stream).toList();

      expect(events, [
        {'type': 'token', 'text': 'first'},
        {'type': 'token', 'text': 'second'},
      ]);
    });

    // 4. A multi-byte character split between chunks (e.g. "नमस्ते 🙂") decodes correctly
    test('4: A multi-byte character split between chunks (e.g. "नमस्ते 🙂") decodes correctly', () async {
      const text = 'नमस्ते 🙂';
      final raw = utf8.encode('data: {"type": "token", "text": "$text"}\n\n');

      // Find byte indices that fall inside multi-byte characters
      // In UTF-8, continuation bytes have binary prefix 10xxxxxx (0x80 to 0xBF).
      // Let's deliberately split right at an internal continuation byte of "🙂"
      final emojiBytes = utf8.encode('🙂'); // 4 bytes: [240, 159, 153, 130]
      expect(emojiBytes.length, 4);

      // Find where emoji starts in raw
      int splitPos = -1;
      for (int i = 0; i <= raw.length - 4; i++) {
        if (raw[i] == emojiBytes[0] &&
            raw[i + 1] == emojiBytes[1] &&
            raw[i + 2] == emojiBytes[2] &&
            raw[i + 3] == emojiBytes[3]) {
          splitPos = i + 2; // Split right in the middle of the 4-byte emoji!
          break;
        }
      }
      expect(splitPos, greaterThan(0));

      final chunk1 = raw.sublist(0, splitPos);
      final chunk2 = raw.sublist(splitPos);

      final stream = Stream.fromIterable([chunk1, chunk2]);
      final events = await SseClient.parseStream(stream).toList();

      expect(events.length, 1);
      expect(events.first['text'], text);
    });

    // 5. \r\n line endings work, and : comment lines are ignored
    test('5: \\r\\n line endings work, and : comment lines are ignored', () async {
      final raw = utf8.encode(
        ': keepalive ping\r\n'
        'data: {"type": "conversation_id", "conversation_id": "abc-123"}\r\n\r\n'
        ': another comment line\r\n'
        ': yet another comment\r\n'
        'data: {"type": "done"}\r\n\r\n',
      );
      final stream = Stream.value(raw);
      final events = await SseClient.parseStream(stream).toList();

      expect(events, [
        {'type': 'conversation_id', 'conversation_id': 'abc-123'},
        {'type': 'done'},
      ]);
    });

    // 6. An unfinished event at the end of the stream isn't emitted
    test('6: An unfinished event at the end of the stream is not emitted', () async {
      final raw = utf8.encode(
        'data: {"type": "token", "text": "first"}\n\n'
        'data: {"type": "token", "text": "incomplete partial',
      );
      final stream = Stream.value(raw);
      final events = await SseClient.parseStream(stream).toList();

      // Only the first complete event (terminated by empty line) is emitted.
      expect(events, [
        {'type': 'token', 'text': 'first'},
      ]);
    });

    // 7. A real stream captured with curl -N into test/fixtures/chat_stream.txt,
    // split at every possible byte position, always gives the same events.
    test('7: Real stream captured into test/fixtures/chat_stream.txt split at every possible byte position yields identical events', () async {
      final file = File('test/fixtures/chat_stream.txt');
      expect(file.existsSync(), isTrue, reason: 'test/fixtures/chat_stream.txt must exist');
      final bytes = file.readAsBytesSync();

      // Baseline reference parse on unfragmented stream
      final baselineEvents = await SseClient.parseStream(Stream.value(bytes)).toList();
      expect(baselineEvents, isNotEmpty);

      // Fuzz test every possible single split index
      for (int i = 1; i < bytes.length; i++) {
        final chunk1 = bytes.sublist(0, i);
        final chunk2 = bytes.sublist(i);

        final events = await SseClient.parseStream(
          Stream.fromIterable([chunk1, chunk2]),
        ).toList();

        expect(
          events,
          equals(baselineEvents),
          reason: 'Failed to match baseline when split at byte offset $i',
        );
      }

      // Also verify cache-hit fixture if present
      final cacheHitFile = File('test/fixtures/chat_stream_cache_hit.txt');
      if (cacheHitFile.existsSync()) {
        final cacheBytes = cacheHitFile.readAsBytesSync();
        final cacheBaseline = await SseClient.parseStream(Stream.value(cacheBytes)).toList();
        for (int i = 1; i < cacheBytes.length; i++) {
          final chunk1 = cacheBytes.sublist(0, i);
          final chunk2 = cacheBytes.sublist(i);

          final events = await SseClient.parseStream(
            Stream.fromIterable([chunk1, chunk2]),
          ).toList();

          expect(
            events,
            equals(cacheBaseline),
            reason: 'Cache hit fixture failed when split at byte offset $i',
          );
        }
      }
    });

    // 8. An unknown type is skipped; a 429 becomes RateLimited(60s)
    test('8: An unknown type is skipped in typed events; a 429 becomes RateLimited(60s)', () async {
      // A) Unknown types are skipped when converting to AiEvent
      final raw = utf8.encode(
        'data: {"type": "future_unknown_server_type", "version": 2}\n\n'
        'data: {"type": "token", "text": "valid_token"}\n\n'
        'data: {"type": "unrecognized_experimental_event", "foo": "bar"}\n\n'
        'data: {"type": "done"}\n\n',
      );
      final typedEvents = await SseClient.parseEvents(Stream.value(raw)).toList();
      expect(typedEvents, [
        const Token('valid_token'),
        const Done(),
      ]);

      // B) 429 becomes RateLimited(60s) from Retry-After header
      final dio429 = Dio();
      dio429.httpClientAdapter = _FakeAdapter((options) async {
        throw DioException(
          requestOptions: options,
          response: Response(
            requestOptions: options,
            statusCode: 429,
            headers: Headers.fromMap({
              'retry-after': ['60'],
            }),
          ),
          type: DioExceptionType.badResponse,
        );
      });
      final sse429 = SseClient(dio429);

      expect(
        () => sse429.post('/chat', {}).toList(),
        throwsA(
          isA<RateLimited>().having(
            (e) => e.retryAfter,
            'retryAfter',
            equals(const Duration(seconds: 60)),
          ),
        ),
      );

      // C) Connection refused / timeout becomes AiUnavailable (Spec §9)
      final dioDown = Dio();
      dioDown.httpClientAdapter = _FakeAdapter((options) async {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          error: const SocketException('Connection refused'),
        );
      });
      final sseDown = SseClient(dioDown);

      expect(
        () => sseDown.post('/chat', {}).toList(),
        throwsA(isA<AiUnavailable>()),
      );

      // D) 5xx becomes AiServerError
      final dio500 = Dio();
      dio500.httpClientAdapter = _FakeAdapter((options) async {
        throw DioException(
          requestOptions: options,
          response: Response(
            requestOptions: options,
            statusCode: 502,
            statusMessage: 'Bad Gateway',
          ),
          type: DioExceptionType.badResponse,
        );
      });
      final sse500 = SseClient(dio500);

      expect(
        () => sse500.post('/chat', {}).toList(),
        throwsA(
          isA<AiServerError>().having(
            (e) => e.statusCode,
            'statusCode',
            equals(502),
          ),
        ),
      );

      // E) Error event inside the stream is NOT an exception; it yields an AiError event
      final errorStreamRaw = utf8.encode(
        'data: {"type": "error", "message": "High server load"}\n\n'
        'data: {"type": "done"}\n\n',
      );
      final inStreamEvents = await SseClient.parseEvents(Stream.value(errorStreamRaw)).toList();
      expect(inStreamEvents, [
        const AiError('High server load'),
        const Done(),
      ]);
    });

    test('malformed JSON payload is logged and does not interrupt following events', () async {
      final raw = utf8.encode(
        'data: {"type": "token", "text": "start"}\n\n'
        'data: {malformed json here\n\n'
        'data: "not a map JSON"\n\n'
        'data: {"type": "token", "text": "end"}\n\n',
      );
      final events = await SseClient.parseStream(Stream.value(raw)).toList();
      expect(events, [
        {'type': 'token', 'text': 'start'},
        {'type': 'token', 'text': 'end'},
      ]);
    });
  });
}
