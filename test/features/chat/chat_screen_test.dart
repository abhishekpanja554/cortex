import 'dart:async';
import 'package:clock/clock.dart';
import 'package:cortex/core/network/ai_event.dart';
import 'package:cortex/core/network/sse_client.dart';
import 'package:cortex/core/providers/core_providers.dart';
import 'package:cortex/features/auth/domain/auth_state.dart';
import 'package:cortex/features/auth/presentation/auth_notifier.dart';
import 'package:cortex/features/chat/domain/chat_message.dart';
import 'package:cortex/features/chat/domain/chat_source.dart';
import 'package:cortex/features/chat/presentation/providers/chat_providers.dart';
import 'package:cortex/features/chat/presentation/screens/chat_screen.dart';
import 'package:cortex/features/chat/presentation/state/chat_state.dart';
import 'package:cortex/features/sync/data/sync_scheduler.dart';
import 'package:cortex/features/sync/presentation/sync_providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSseClient extends Fake implements SseClient {
  Stream<AiEvent> Function(String path, Map<String, dynamic> body, CancelToken? cancelToken)? onPostEvents;

  @override
  Stream<AiEvent> postEvents(
    String path,
    Map<String, dynamic> body, {
    CancelToken? cancelToken,
  }) {
    if (onPostEvents != null) {
      return onPostEvents!(path, body, cancelToken);
    }
    return const Stream.empty();
  }
}

class _FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => Authenticated('test-user');
}

class _FakeSyncScheduler extends Fake implements SyncScheduler {
  bool requestSyncCalled = false;
  @override
  void requestSync([SyncTrigger trigger = SyncTrigger.manual]) {
    requestSyncCalled = true;
  }
}

void main() {
  late _FakeSseClient fakeSseClient;

  setUp(() {
    fakeSseClient = _FakeSseClient();
  });

  Widget buildChatScreen() {
    return ProviderScope(
      overrides: [
        authProvider.overrideWith(() => _FakeAuthNotifier()),
        sseClientProvider.overrideWithValue(fakeSseClient),
      ],
      child: const MaterialApp(
        home: ChatScreen(),
      ),
    );
  }

  group('ChatScreen UI', () {
    testWidgets('Header has New chat button and title', (tester) async {
      await tester.pumpWidget(buildChatScreen());
      await tester.pump();

      expect(find.text('Ask Cortex'), findsOneWidget);
      expect(find.byKey(const ValueKey('new_chat_button')), findsOneWidget);
      expect(find.text('New chat'), findsOneWidget);
    });

    testWidgets('Empty state shows guidance and prompt suggestion chips', (tester) async {
      await tester.pumpWidget(buildChatScreen());
      await tester.pump();

      expect(find.text('Ask anything in your notes'), findsOneWidget);
      expect(find.text('Summarize my recent notes'), findsOneWidget);
      expect(find.text('What are my key action items?'), findsOneWidget);
    });

    testWidgets('Items in message list are keyed by message ID and render user & assistant bubbles', (tester) async {
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(() => _FakeAuthNotifier()),
          sseClientProvider.overrideWithValue(fakeSseClient),
        ],
      );

      final notifier = container.read(chatNotifierProvider.notifier);
      // Populate state with a user message and assistant message
      final userMsg = const ChatMessage(
        id: 'msg-user-1',
        sender: MessageSender.user,
        text: 'What is Cortex?',
        status: ChatMessageStatus.done,
      );
      final assistantMsg = const ChatMessage(
        id: 'msg-assistant-1',
        sender: MessageSender.assistant,
        text: 'Cortex is a local-first note-taking app.',
        status: ChatMessageStatus.done,
      );

      container.read(chatNotifierProvider.notifier);
      // Direct state setting
      container.read(chatNotifierProvider);
      notifier.state = ChatState(messages: [userMsg, assistantMsg]);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ChatScreen()),
        ),
      );
      await tester.pump();

      // Keyed message widgets
      expect(find.byKey(const ValueKey('msg-user-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('msg-assistant-1')), findsOneWidget);

      expect(find.text('What is Cortex?'), findsOneWidget);
      expect(find.text('Cortex is a local-first note-taking app.'), findsOneWidget);
    });

    testWidgets('Assistant bubble renders citations as tappable chips, sources list, and cached badge', (tester) async {
      const source0 = ChatSource(
        noteId: 'note-123',
        title: 'Project Architecture',
        chunkText: 'Local SQLite with Drift and periodic sync.',
      );

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(() => _FakeAuthNotifier()),
          sseClientProvider.overrideWithValue(fakeSseClient),
        ],
      );

      final notifier = container.read(chatNotifierProvider.notifier);
      notifier.state = const ChatState(
        messages: [
          ChatMessage(
            id: 'asst-1',
            sender: MessageSender.assistant,
            text: 'See [Source 1] for details.',
            sources: [source0],
            fromCache: true,
            status: ChatMessageStatus.done,
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ChatScreen()),
        ),
      );
      await tester.pump();

      // Tappable chip
      expect(find.text('Source 1'), findsNWidgets(2)); // Once in inline chip, once in source card badge
      // Cached badge
      expect(find.byKey(const ValueKey('chat_cached_badge')), findsOneWidget);
      expect(find.text('cached'), findsOneWidget);
      // Source card with title & snippet
      expect(find.text('Project Architecture'), findsOneWidget);
      expect(find.text('Local SQLite with Drift and periodic sync.'), findsOneWidget);
    });

    testWidgets('Input bar is disabled while streaming and shows Stop button', (tester) async {
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(() => _FakeAuthNotifier()),
          sseClientProvider.overrideWithValue(fakeSseClient),
        ],
      );

      final notifier = container.read(chatNotifierProvider.notifier);
      notifier.state = const ChatState(
        isStreaming: true,
        messages: [
          ChatMessage(
            id: 'asst-streaming',
            sender: MessageSender.assistant,
            text: 'Streaming in progress…',
            status: ChatMessageStatus.streaming,
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ChatScreen()),
        ),
      );
      await tester.pump();

      // Stop button visible
      expect(find.byKey(const ValueKey('chat_stop_button')), findsOneWidget);
      // Textfield disabled
      final textField = tester.widget<TextField>(find.byKey(const ValueKey('chat_input_textfield')));
      expect(textField.enabled, isFalse);

      // Tap stop button calls cancel
      await tester.tap(find.byKey(const ValueKey('chat_stop_button')));
      await tester.pump();

      final state = container.read(chatNotifierProvider);
      expect(state.isStreaming, isFalse);
      expect(state.messages.first.status, ChatMessageStatus.stopped);
      expect(find.text('Stopped'), findsAtLeastNWidgets(1));
    });

    testWidgets('Tapping source for note not on device triggers requestSync and shows snackbar', (tester) async {
      final fakeScheduler = _FakeSyncScheduler();
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(() => _FakeAuthNotifier()),
          sseClientProvider.overrideWithValue(fakeSseClient),
          syncSchedulerProvider.overrideWithValue(fakeScheduler),
        ],
      );

      final notifier = container.read(chatNotifierProvider.notifier);
      notifier.state = const ChatState(
        messages: [
          ChatMessage(
            id: 'asst-1',
            sender: MessageSender.assistant,
            text: 'See [Source 1] for details.',
            sources: [
              ChatSource(
                noteId: 'remote-only-note-id',
                title: 'Laptop Note',
                chunkText: 'Written on another device.',
              ),
            ],
            status: ChatMessageStatus.done,
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: ChatScreen()),
          ),
        ),
      );
      await tester.pump();

      // Tap the source card
      await tester.tap(find.text('Laptop Note'));
      await tester.pump();

      // Verify sync requested and alert shown
      expect(fakeScheduler.requestSyncCalled, isTrue);
      expect(find.text("This note isn't on this device yet. Syncing…"), findsOneWidget);
    });

    testWidgets('Input bar is disabled during rate limit showing live countdown', (tester) async {
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(() => _FakeAuthNotifier()),
          sseClientProvider.overrideWithValue(fakeSseClient),
        ],
      );

      final notifier = container.read(chatNotifierProvider.notifier);
      final fakeNow = DateTime(2026, 10, 24, 12, 0, 0);

      withClock(Clock.fixed(fakeNow), () {
        notifier.state = ChatState(
          rateLimitedUntil: fakeNow.add(const Duration(seconds: 42)),
        );
      });

      await withClock(Clock.fixed(fakeNow), () async {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: ChatScreen()),
          ),
        );
        await tester.pump();

        expect(find.text('Try again in 42s'), findsOneWidget);
        expect(find.byKey(const ValueKey('chat_send_button')), findsOneWidget);
      });
    });

    testWidgets('aiUnavailable message renders distinct offline card style', (tester) async {
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(() => _FakeAuthNotifier()),
          sseClientProvider.overrideWithValue(fakeSseClient),
        ],
      );

      final notifier = container.read(chatNotifierProvider.notifier);
      notifier.state = const ChatState(
        messages: [
          ChatMessage(
            id: 'offline-msg',
            sender: MessageSender.assistant,
            text: '',
            status: ChatMessageStatus.aiUnavailable,
            errorText: 'AI is offline. Your notes still work.',
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ChatScreen()),
        ),
      );
      await tester.pump();

      expect(find.byKey(const ValueKey('chat_ai_unavailable_bubble')), findsOneWidget);
      expect(find.text('AI is offline. Your notes still work.'), findsOneWidget);
      expect(find.text('Your local notes, search, and editing remain fully functional.'), findsOneWidget);
    });

    testWidgets('error message renders retry button that re-sends user previous question', (tester) async {
      final streamController = StreamController<AiEvent>();
      fakeSseClient.onPostEvents = (path, body, cancelToken) {
        return streamController.stream;
      };

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(() => _FakeAuthNotifier()),
          sseClientProvider.overrideWithValue(fakeSseClient),
        ],
      );

      final notifier = container.read(chatNotifierProvider.notifier);
      notifier.state = const ChatState(
        messages: [
          ChatMessage(
            id: 'user-prev',
            sender: MessageSender.user,
            text: 'How to build with Flutter?',
            status: ChatMessageStatus.done,
          ),
          ChatMessage(
            id: 'asst-err',
            sender: MessageSender.assistant,
            text: 'Partial notes before error.',
            status: ChatMessageStatus.error,
            errorText: 'Connection lost',
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ChatScreen()),
        ),
      );
      await tester.pump();

      expect(find.byKey(const ValueKey('chat_error_banner')), findsOneWidget);
      expect(find.byKey(const ValueKey('chat_retry_button')), findsOneWidget);
      expect(find.text('Connection lost'), findsOneWidget);

      // Tap Retry
      await tester.tap(find.byKey(const ValueKey('chat_retry_button')));
      await tester.pump();

      // Check that a new request was triggered with 'How to build with Flutter?'
      final state = container.read(chatNotifierProvider);
      expect(state.isStreaming, isTrue);
      expect(state.messages.any((m) => m.text == 'How to build with Flutter?'), isTrue);

      await streamController.close();
    });

    testWidgets('New chat button clears messages and conversationId', (tester) async {
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(() => _FakeAuthNotifier()),
          sseClientProvider.overrideWithValue(fakeSseClient),
        ],
      );

      final notifier = container.read(chatNotifierProvider.notifier);
      notifier.state = const ChatState(
        conversationId: 'active-conv-id',
        messages: [
          ChatMessage(
            id: 'user-1',
            sender: MessageSender.user,
            text: 'Existing question',
            status: ChatMessageStatus.done,
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ChatScreen()),
        ),
      );
      await tester.pump();

      expect(find.text('Existing question'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('new_chat_button')));
      await tester.pump();

      expect(find.text('Existing question'), findsNothing);
      expect(container.read(chatNotifierProvider).messages, isEmpty);
      expect(container.read(chatNotifierProvider).conversationId, isNull);
    });

    testWidgets('Automatic scrolling: scrolls down when already at bottom, stays put when scrolled up', (tester) async {
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(() => _FakeAuthNotifier()),
          sseClientProvider.overrideWithValue(fakeSseClient),
        ],
      );

      final notifier = container.read(chatNotifierProvider.notifier);
      // Create a list with multiple long messages so the list scrolls
      final messages = List.generate(
        15,
        (i) => ChatMessage(
          id: 'msg-$i',
          sender: i.isEven ? MessageSender.user : MessageSender.assistant,
          text: 'Message number $i: This is a sufficiently long message block to fill the screen and test scrolling mechanics.',
          status: ChatMessageStatus.done,
        ),
      );

      notifier.state = ChatState(messages: messages);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ChatScreen()),
        ),
      );
      await tester.pumpAndSettle();

      final scrollFinder = find.byKey(const ValueKey('chat_messages_list'));
      expect(scrollFinder, findsOneWidget);

      // Scroll to top
      await tester.drag(scrollFinder, const Offset(0, 500));
      await tester.pumpAndSettle();

      final scrollState = tester.state<ScrollableState>(find.byType(Scrollable).first);
      final offsetBefore = scrollState.position.pixels;

      // Add a token/message while user is scrolled up
      notifier.state = notifier.state.copyWith(
        messages: [
          ...notifier.state.messages,
          const ChatMessage(
            id: 'msg-stream',
            sender: MessageSender.assistant,
            text: 'New token while scrolled up',
            status: ChatMessageStatus.streaming,
          ),
        ],
      );
      await tester.pump();

      // User was scrolled up, so they should NOT have been pulled down
      final offsetAfter = scrollState.position.pixels;
      expect(offsetAfter, equals(offsetBefore));
    });

    testWidgets('Automatic scrolling: moves down as new tokens generate when at bottom', (tester) async {
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(() => _FakeAuthNotifier()),
          sseClientProvider.overrideWithValue(fakeSseClient),
        ],
      );

      final notifier = container.read(chatNotifierProvider.notifier);
      final messages = List.generate(
        15,
        (i) => ChatMessage(
          id: 'msg-$i',
          sender: i.isEven ? MessageSender.user : MessageSender.assistant,
          text: 'Message number $i: This is a sufficiently long message block to fill the screen.',
          status: ChatMessageStatus.done,
        ),
      );

      notifier.state = ChatState(messages: messages);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ChatScreen()),
        ),
      );
      await tester.pumpAndSettle();

      final scrollState = tester.state<ScrollableState>(find.byType(Scrollable).first);
      final offsetAtOpen = scrollState.position.pixels;
      expect(offsetAtOpen, equals(scrollState.position.maxScrollExtent));

      // Append assistant message that starts streaming
      const assistantMsg = ChatMessage(
        id: 'msg-stream',
        sender: MessageSender.assistant,
        text: 'Initial text',
        status: ChatMessageStatus.streaming,
      );
      notifier.state = notifier.state.copyWith(
        messages: [...notifier.state.messages, assistantMsg],
      );
      await tester.pump();
      await tester.pump();

      // Now add 10 long tokens
      for (int i = 0; i < 10; i++) {
        final currentText = notifier.state.messages.last.text;
        final updatedMsg = notifier.state.messages.last.copyWith(
          text: '$currentText\nToken $i: Additional generated sentence that makes the bubble taller and forces scrolling down.',
        );
        notifier.state = notifier.state.copyWith(
          messages: [...notifier.state.messages.sublist(0, notifier.state.messages.length - 1), updatedMsg],
        );
        await tester.pump();
      }

      // Check that pixels is at maxScrollExtent
      expect(scrollState.position.pixels, equals(scrollState.position.maxScrollExtent));
      expect(scrollState.position.pixels, greaterThan(offsetAtOpen));
    });

    testWidgets('Opening chat screen with existing messages shows the bottom-most message', (tester) async {
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(() => _FakeAuthNotifier()),
          sseClientProvider.overrideWithValue(fakeSseClient),
        ],
      );

      final notifier = container.read(chatNotifierProvider.notifier);
      final messages = List.generate(
        60,
        (i) => ChatMessage(
          id: 'msg-$i',
          sender: i.isEven ? MessageSender.user : MessageSender.assistant,
          text: 'Message $i content: A longer paragraph with some details so each item is 80px tall.',
          status: ChatMessageStatus.done,
        ),
      );
      notifier.state = ChatState(messages: messages);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ChatScreen()),
        ),
      );
      await tester.pump();
      await tester.pump();

      // Check if the bottom-most message is visible
      expect(find.text('Message 59 content: A longer paragraph with some details so each item is 80px tall.'), findsOneWidget);
    });

    testWidgets('Sending a new question while scrolled up re-enables auto-scroll and follows tokens down', (tester) async {
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(() => _FakeAuthNotifier()),
          sseClientProvider.overrideWithValue(fakeSseClient),
        ],
      );

      final notifier = container.read(chatNotifierProvider.notifier);
      final messages = List.generate(
        15,
        (i) => ChatMessage(
          id: 'msg-$i',
          sender: i.isEven ? MessageSender.user : MessageSender.assistant,
          text: 'Message number $i: This is a sufficiently long message block to fill the screen.',
          status: ChatMessageStatus.done,
        ),
      );

      notifier.state = ChatState(messages: messages);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ChatScreen()),
        ),
      );
      await tester.pumpAndSettle();

      final scrollFinder = find.byKey(const ValueKey('chat_messages_list'));
      // User scrolls up to read earlier messages
      await tester.drag(scrollFinder, const Offset(0, 600));
      await tester.pumpAndSettle();

      final scrollState = tester.state<ScrollableState>(find.byType(Scrollable).first);
      final offsetScrolledUp = scrollState.position.pixels;
      expect(offsetScrolledUp, lessThan(scrollState.position.maxScrollExtent));

      // User asks a new question
      const newUserMsg = ChatMessage(
        id: 'msg-user-new',
        sender: MessageSender.user,
        text: 'What about this new topic?',
        status: ChatMessageStatus.done,
      );
      const newAsstMsg = ChatMessage(
        id: 'msg-asst-new',
        sender: MessageSender.assistant,
        text: 'Initial response',
        status: ChatMessageStatus.streaming,
      );

      notifier.state = notifier.state.copyWith(
        messages: [...notifier.state.messages, newUserMsg, newAsstMsg],
      );
      await tester.pump();
      await tester.pump();

      // View should have jumped back to the bottom for the new question
      expect(scrollState.position.pixels, equals(scrollState.position.maxScrollExtent));

      final offsetBeforeTokens = scrollState.position.pixels;

      // Stream tokens into the assistant response
      for (int i = 0; i < 5; i++) {
        final currentText = notifier.state.messages.last.text;
        final updatedMsg = notifier.state.messages.last.copyWith(
          text: '$currentText\nLine $i of answer that adds more vertical height to test scroll following.',
        );
        notifier.state = notifier.state.copyWith(
          messages: [...notifier.state.messages.sublist(0, notifier.state.messages.length - 1), updatedMsg],
        );
        await tester.pump();
      }

      // View should have continued moving down with the generated tokens
      expect(scrollState.position.pixels, equals(scrollState.position.maxScrollExtent));
      expect(scrollState.position.pixels, greaterThan(offsetBeforeTokens));
    });

    testWidgets('Animated tab switch between Ask and Agent modes', (tester) async {
      await tester.pumpWidget(buildChatScreen());
      await tester.pump();

      // Initial state: Ask mode
      expect(find.text('Ask Cortex'), findsOneWidget);
      expect(find.text('Grounded in your notes'), findsOneWidget);
      expect(find.text('New chat'), findsOneWidget);
      expect(find.text('Ask anything in your notes'), findsOneWidget);

      // Tap Agent tab
      await tester.tap(find.byKey(const ValueKey('chat_mode_agent_tab')));
      await tester.pumpAndSettle();

      // Agent mode state
      expect(find.text('Cortex Agent'), findsOneWidget);
      expect(find.text('Can search, edit, and organize notes'), findsOneWidget);
      expect(find.text('Reset'), findsOneWidget);
      expect(find.text('Search my notes for database architecture'), findsOneWidget);

      // Tap Ask tab to return
      await tester.tap(find.byKey(const ValueKey('chat_mode_ask_tab')));
      await tester.pumpAndSettle();

      // Returned to Ask mode
      expect(find.text('Ask Cortex'), findsOneWidget);
      expect(find.text('Grounded in your notes'), findsOneWidget);
      expect(find.text('New chat'), findsOneWidget);
      expect(find.text('Ask anything in your notes'), findsOneWidget);
    });

    testWidgets('Horizontal swipe transitions between Ask and Agent modes', (tester) async {
      await tester.pumpWidget(buildChatScreen());
      await tester.pump();

      expect(find.text('Ask Cortex'), findsOneWidget);

      // Swipe left to switch to Agent
      await tester.fling(
        find.byKey(const ValueKey('chat_screen_body_area')),
        const Offset(-400, 0),
        1000,
      );
      await tester.pumpAndSettle();

      expect(find.text('Cortex Agent'), findsOneWidget);

      // Swipe right to switch back to Ask
      await tester.fling(
        find.byKey(const ValueKey('chat_screen_body_area')),
        const Offset(400, 0),
        1000,
      );
      await tester.pumpAndSettle();

      expect(find.text('Ask Cortex'), findsOneWidget);
    });
  });
}
