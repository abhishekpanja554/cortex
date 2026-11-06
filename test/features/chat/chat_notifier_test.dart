import 'dart:async';
import 'dart:io';
import 'package:clock/clock.dart';
import 'package:cortex/core/network/ai_event.dart';
import 'package:cortex/core/network/ai_failure.dart';
import 'package:cortex/core/network/sse_client.dart';
import 'package:cortex/core/providers/core_providers.dart';
import 'package:cortex/features/auth/domain/auth_state.dart';
import 'package:cortex/features/auth/presentation/auth_notifier.dart';
import 'package:cortex/features/chat/domain/chat_message.dart';
import 'package:cortex/features/chat/domain/chat_source.dart';
import 'package:cortex/features/chat/domain/chat_source_parser.dart';
import 'package:cortex/features/chat/presentation/providers/chat_providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSseClient extends Fake implements SseClient {
  final List<Map<String, dynamic>> recordedRequests = [];
  final List<CancelToken?> recordedCancelTokens = [];
  Stream<AiEvent> Function(String path, Map<String, dynamic> body, CancelToken? cancelToken)? onPostEvents;

  @override
  Stream<AiEvent> postEvents(
    String path,
    Map<String, dynamic> body, {
    CancelToken? cancelToken,
  }) {
    recordedRequests.add(Map<String, dynamic>.from(body));
    recordedCancelTokens.add(cancelToken);
    if (onPostEvents != null) {
      return onPostEvents!(path, body, cancelToken);
    }
    return const Stream.empty();
  }
}

class _FakeAuthNotifier extends AuthNotifier {
  AuthState _current;
  _FakeAuthNotifier([AuthState? initial])
      : _current = initial ?? Authenticated('user-1');

  @override
  AuthState build() => _current;

  void setAuthState(AuthState newState) {
    _current = newState;
    state = newState;
  }
}

void main() {
  group('ChatNotifier', () {
    late _FakeSseClient fakeSseClient;
    late _FakeAuthNotifier fakeAuthNotifier;
    late ProviderContainer container;

    setUp(() {
      fakeSseClient = _FakeSseClient();
      fakeAuthNotifier = _FakeAuthNotifier();
      container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(() => fakeAuthNotifier),
          sseClientProvider.overrideWithValue(fakeSseClient),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    // Test 1: Normal stream → tokens joined in order, sources attached, status done, conversationId saved
    test('1: Normal stream -> tokens joined in order, sources attached, status done, conversationId saved', () async {
      fakeSseClient.onPostEvents = (path, body, cancelToken) {
        return Stream.fromIterable([
          const ConversationId('conv-123'),
          const Sources([
            {
              'note_id': 'note-1',
              'title': 'Flutter Architecture',
              'chunk_text': 'State management with Riverpod is declarative.',
              'score': 0.95,
            }
          ]),
          const Token('State '),
          const Token(''), // Empty token must be ignored
          const Token('management is '),
          const Token('declarative.'),
          const Done(),
        ]);
      };

      final notifier = container.read(chatNotifierProvider.notifier);
      await notifier.send('How does state management work?');

      final state = container.read(chatNotifierProvider);
      expect(state.conversationId, 'conv-123');
      expect(state.isStreaming, isFalse);
      expect(state.messages.length, 2);

      final userMsg = state.messages[0];
      expect(userMsg.sender, MessageSender.user);
      expect(userMsg.text, 'How does state management work?');
      expect(userMsg.status, ChatMessageStatus.done);

      final assistantMsg = state.messages[1];
      expect(assistantMsg.sender, MessageSender.assistant);
      expect(assistantMsg.text, 'State management is declarative.');
      expect(assistantMsg.status, ChatMessageStatus.done);
      expect(assistantMsg.fromCache, isFalse);
      expect(assistantMsg.sources.length, 1);
      expect(assistantMsg.sources.first.noteId, 'note-1');
      expect(assistantMsg.sources.first.title, 'Flutter Architecture');
      expect(assistantMsg.sources.first.score, 0.95);
    });

    // Test 2: The next send includes that conversationId in the request body
    test('2: The next send includes that conversationId in the request body', () async {
      fakeSseClient.onPostEvents = (path, body, cancelToken) {
        return Stream.fromIterable([
          const ConversationId('conv-persistent-456'),
          const Token('First reply'),
          const Done(),
        ]);
      };

      final notifier = container.read(chatNotifierProvider.notifier);
      await notifier.send('First question');

      expect(container.read(chatNotifierProvider).conversationId, 'conv-persistent-456');
      expect(fakeSseClient.recordedRequests.length, 1);
      expect(fakeSseClient.recordedRequests.first['conversation_id'], isNull);

      // Second send
      fakeSseClient.onPostEvents = (path, body, cancelToken) {
        return Stream.fromIterable([
          const Token('Second reply'),
          const Done(),
        ]);
      };

      await notifier.send('Follow-up question');

      expect(fakeSseClient.recordedRequests.length, 2);
      expect(fakeSseClient.recordedRequests[1]['query'], 'Follow-up question');
      expect(fakeSseClient.recordedRequests[1]['conversation_id'], 'conv-persistent-456');
      expect(container.read(chatNotifierProvider).messages.length, 4);
    });

    // Test 3: Cache hit (CacheHit + Answer, no tokens) → full text and fromCache = true
    test('3: Cache hit (CacheHit + Answer, no tokens) -> full text and fromCache = true', () async {
      fakeSseClient.onPostEvents = (path, body, cancelToken) {
        return Stream.fromIterable([
          const ConversationId('conv-cache-789'),
          const CacheHit(true),
          const Answer('Instant cached response without LLM tokens.'),
          const Done(),
        ]);
      };

      final notifier = container.read(chatNotifierProvider.notifier);
      await notifier.send('Repeat query');

      final state = container.read(chatNotifierProvider);
      expect(state.conversationId, 'conv-cache-789');
      expect(state.isStreaming, isFalse);
      expect(state.messages.length, 2);

      final assistantMsg = state.messages[1];
      expect(assistantMsg.fromCache, isTrue);
      expect(assistantMsg.text, 'Instant cached response without LLM tokens.');
      expect(assistantMsg.status, ChatMessageStatus.done);
    });

    // Test 4 (fix): Use the real error fixture, […, error, done] → the final status is error
    test('4 (fix): Use the real error fixture, [..., error, done] -> the final status is error', () async {
      final file = File('test/fixtures/chat_stream_error.txt');
      expect(file.existsSync(), isTrue);
      final bytes = file.readAsBytesSync();
      final fixtureEvents = await SseClient.parseEvents(Stream.value(bytes)).toList();

      // Real server sends error followed by done in finally
      expect(fixtureEvents.any((e) => e is AiError), isTrue);
      expect(fixtureEvents.last, isA<Done>());

      fakeSseClient.onPostEvents = (path, body, cancelToken) {
        return Stream.fromIterable([
          const Token('Partial thoughts before error. '),
          ...fixtureEvents,
        ]);
      };

      final notifier = container.read(chatNotifierProvider.notifier);
      await notifier.send('Complex query with server error');

      final state = container.read(chatNotifierProvider);
      expect(state.isStreaming, isFalse);
      expect(state.messages.length, 2);

      final assistantMsg = state.messages[1];
      expect(assistantMsg.text, 'Partial thoughts before error. ');
      expect(assistantMsg.status, ChatMessageStatus.error);
      expect(assistantMsg.errorText, 'Conversation not found or not yours.');
    });

    // Test 5: AiUnavailable thrown → the assistant message is aiUnavailable, and the user's message stays
    test('5: AiUnavailable thrown -> the assistant message is aiUnavailable, and the user message stays', () async {
      fakeSseClient.onPostEvents = (path, body, cancelToken) {
        return Stream.error(const AiUnavailable('Connection refused'));
      };

      final notifier = container.read(chatNotifierProvider.notifier);
      await notifier.send('Question when server down');

      final state = container.read(chatNotifierProvider);
      expect(state.isStreaming, isFalse);
      expect(state.messages.length, 2);

      final userMsg = state.messages[0];
      expect(userMsg.sender, MessageSender.user);
      expect(userMsg.text, 'Question when server down');

      final assistantMsg = state.messages[1];
      expect(assistantMsg.status, ChatMessageStatus.aiUnavailable);
      expect(assistantMsg.errorText, 'AI is offline. Your notes still work.');
    });

    // Test 6: RateLimited(60s) → rateLimitedUntil is set and the empty assistant message is removed. Use clock package
    test('6: RateLimited(60s) -> rateLimitedUntil is set and the empty assistant message is removed', () async {
      final fixedTime = DateTime.utc(2026, 10, 24, 12, 0, 0);

      await withClock(Clock.fixed(fixedTime), () async {
        fakeSseClient.onPostEvents = (path, body, cancelToken) {
          return Stream.error(const RateLimited(Duration(seconds: 60)));
        };

        final notifier = container.read(chatNotifierProvider.notifier);
        await notifier.send('Fast query');

        final state = container.read(chatNotifierProvider);
        expect(state.isStreaming, isFalse);

        // rateLimitedUntil is set to now + 60s
        expect(state.rateLimitedUntil, DateTime.utc(2026, 10, 24, 12, 1, 0));

        // The empty assistant message was removed, so only the user message remains
        expect(state.messages.length, 1);
        expect(state.messages.first.sender, MessageSender.user);
        expect(state.messages.first.text, 'Fast query');

        // Sending while rate-limited is ignored
        await notifier.send('Another query while rate limited');
        expect(fakeSseClient.recordedRequests.length, 1); // No new request was sent
      });
    });

    // Test 7: send while already streaming does nothing
    test('7: send while already streaming does nothing', () async {
      final streamController = StreamController<AiEvent>();

      fakeSseClient.onPostEvents = (path, body, cancelToken) {
        return streamController.stream;
      };

      final notifier = container.read(chatNotifierProvider.notifier);
      final firstSendFuture = notifier.send('First query');

      expect(container.read(chatNotifierProvider).isStreaming, isTrue);

      // Attempt second send while first is in progress
      await notifier.send('Second query while active');

      expect(fakeSseClient.recordedRequests.length, 1);
      expect(container.read(chatNotifierProvider).messages.length, 2);

      // Complete first stream
      streamController.add(const Token('Done'));
      streamController.add(const Done());
      await streamController.close();
      await firstSendFuture;

      expect(container.read(chatNotifierProvider).isStreaming, isFalse);
    });

    // Test 8: Disposing the provider mid-stream cancels the token, and later events change nothing
    test('8: Disposing the provider mid-stream cancels the token, and later events change nothing', () async {
      final streamController = StreamController<AiEvent>();

      fakeSseClient.onPostEvents = (path, body, cancelToken) {
        return streamController.stream;
      };

      final notifier = container.read(chatNotifierProvider.notifier);
      unawaited(notifier.send('Query before dispose'));

      streamController.add(const Token('Initial chunk. '));
      await Future<void>.delayed(Duration.zero);

      final stateBefore = container.read(chatNotifierProvider);
      expect(stateBefore.messages[1].text, 'Initial chunk. ');

      // Dispose container mid-stream
      container.dispose();

      // CancelToken should have been cancelled by onDispose
      expect(fakeSseClient.recordedCancelTokens.last?.isCancelled, isTrue);

      // Emitting more events on the closed stream should not crash or modify state
      streamController.add(const Token('Should be ignored.'));
      streamController.add(const Done());
      await streamController.close();
    });

    // Test 10: Stream ends without Done → status error, partial text kept, isStreaming false
    test('10: Stream ends without Done -> status error, partial text kept, isStreaming false', () async {
      fakeSseClient.onPostEvents = (path, body, cancelToken) {
        return Stream.fromIterable([
          const Token('Partial content before stream dropped unexpectedly.'),
        ]);
      };

      final notifier = container.read(chatNotifierProvider.notifier);
      await notifier.send('Query during network glitch');

      final state = container.read(chatNotifierProvider);
      expect(state.isStreaming, isFalse);
      expect(state.messages.length, 2);

      final assistantMsg = state.messages[1];
      expect(assistantMsg.text, 'Partial content before stream dropped unexpectedly.');
      expect(assistantMsg.status, ChatMessageStatus.error);
      expect(assistantMsg.errorText, 'Connection lost');
    });

    // Test 11: Log out and log in as a different user → messages empty, conversationId null; a stream still running is cancelled and writes nothing afterwards
    test('11: Log out and log in as a different user -> messages empty, conversationId null; running stream cancelled', () async {
      final streamController = StreamController<AiEvent>();

      fakeSseClient.onPostEvents = (path, body, cancelToken) {
        return streamController.stream;
      };

      // User A is logged in
      (container.read(authProvider.notifier) as _FakeAuthNotifier).setAuthState(Authenticated('user-A'));
      final notifierA = container.read(chatNotifierProvider.notifier);
      unawaited(notifierA.send('User A question'));

      streamController.add(const ConversationId('conv-user-A'));
      streamController.add(const Token('User A answer part 1. '));
      await Future<void>.delayed(Duration.zero);

      final stateA = container.read(chatNotifierProvider);
      expect(stateA.conversationId, 'conv-user-A');
      expect(stateA.messages.length, 2);
      expect(stateA.messages[1].text, 'User A answer part 1. ');

      // User A logs out and User B logs in
      (container.read(authProvider.notifier) as _FakeAuthNotifier).setAuthState(Authenticated('user-B'));
      await Future<void>.delayed(Duration.zero);

      // ChatNotifier has rebuilt with empty state for User B
      final stateB = container.read(chatNotifierProvider);
      expect(stateB.messages, isEmpty);
      expect(stateB.conversationId, isNull);
      expect(stateB.isStreaming, isFalse);

      // Old stream emits further events
      expect(fakeSseClient.recordedCancelTokens.last?.isCancelled, isTrue);
      streamController.add(const Token('User A answer part 2. '));
      streamController.add(const Done());
      await streamController.close();
      await Future<void>.delayed(Duration.zero);

      // User B's state remains empty and unpolluted
      final stateBAfter = container.read(chatNotifierProvider);
      expect(stateBAfter.messages, isEmpty);
      expect(stateBAfter.conversationId, isNull);
    });

    // Test 12: newConversation() clears messages and conversationId
    test('12: newConversation() clears messages and conversationId', () async {
      fakeSseClient.onPostEvents = (path, body, cancelToken) {
        return Stream.fromIterable([
          const ConversationId('conv-reset-test'),
          const Token('Some answer'),
          const Done(),
        ]);
      };

      final notifier = container.read(chatNotifierProvider.notifier);
      await notifier.send('Test message');

      expect(container.read(chatNotifierProvider).messages.length, 2);
      expect(container.read(chatNotifierProvider).conversationId, 'conv-reset-test');

      notifier.newConversation();

      final stateAfter = container.read(chatNotifierProvider);
      expect(stateAfter.messages, isEmpty);
      expect(stateAfter.conversationId, isNull);
      expect(stateAfter.isStreaming, isFalse);
    });

    // Test 9: [Source 2] in the text maps to sources[1]. Pure function tested on its own
    group('9: Source citation pure function parseSourceCitations', () {
      final sources = [
        const ChatSource(
          noteId: 'note-0',
          title: 'First Note',
          chunkText: 'Text 0',
        ),
        const ChatSource(
          noteId: 'note-1',
          title: 'Second Note',
          chunkText: 'Text 1',
        ),
        const ChatSource(
          noteId: 'note-2',
          title: 'Third Note',
          chunkText: 'Text 2',
        ),
      ];

      test('[Source 2] maps to sources[1]', () {
        const text = 'According to [Source 2], the system is stable.';
        final segments = parseSourceCitations(text, sources);

        expect(segments, [
          const PlainTextSegment('According to '),
          SourceCitationSegment(
            sourceIndex: 1,
            sourceNumber: 2,
            source: sources[1],
          ),
          const PlainTextSegment(', the system is stable.'),
        ]);
      });

      test('[Source 9] when there are only 3 sources stays plain text without crashing', () {
        const text = 'Valid [Source 1], but invalid [Source 9] is out of bounds.';
        final segments = parseSourceCitations(text, sources);

        expect(segments, [
          const PlainTextSegment('Valid '),
          SourceCitationSegment(
            sourceIndex: 0,
            sourceNumber: 1,
            source: sources[0],
          ),
          const PlainTextSegment(', but invalid [Source 9] is out of bounds.'),
        ]);
      });

      test('Multiple valid and invalid citations with adjacent text merging', () {
        const text = '[Source 1][Source 2] and [Source 0] plus [Source 3]';
        final segments = parseSourceCitations(text, sources);

        expect(segments, [
          SourceCitationSegment(
            sourceIndex: 0,
            sourceNumber: 1,
            source: sources[0],
          ),
          SourceCitationSegment(
            sourceIndex: 1,
            sourceNumber: 2,
            source: sources[1],
          ),
          const PlainTextSegment(' and [Source 0] plus '),
          SourceCitationSegment(
            sourceIndex: 2,
            sourceNumber: 3,
            source: sources[2],
          ),
        ]);
      });

      test('Empty text and text without citations', () {
        expect(parseSourceCitations('', sources), isEmpty);
        expect(
          parseSourceCitations('Just plain text here.', sources),
          [const PlainTextSegment('Just plain text here.')],
        );
      });
    });
  });
}
