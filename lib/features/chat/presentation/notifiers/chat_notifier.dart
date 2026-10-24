import 'package:clock/clock.dart';
import 'package:cortex/core/network/ai_event.dart';
import 'package:cortex/core/network/ai_failure.dart';
import 'package:cortex/core/providers/core_providers.dart';
import 'package:cortex/features/auth/domain/auth_state.dart';
import 'package:cortex/features/auth/presentation/auth_notifier.dart';
import 'package:cortex/features/chat/domain/chat_message.dart';
import 'package:cortex/features/chat/domain/chat_source.dart';
import 'package:cortex/features/chat/presentation/state/chat_state.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class ChatNotifier extends Notifier<ChatState> {
  CancelToken? _cancelToken;

  @override
  ChatState build() {
    // Watch signed-in user ID: when the user logs out or changes,
    // Riverpod disposes and rebuilds the notifier with an empty state.
    ref.watch(authProvider.select((s) => s is Authenticated ? s.userId : null));

    ref.onDispose(() {
      _cancelToken?.cancel();
    });
    return const ChatState();
  }

  /// Clears the current conversation, resetting messages and conversationId.
  void newConversation() {
    _cancelToken?.cancel();
    _cancelToken = null;
    state = const ChatState();
  }

  /// Cancels an in-flight streaming request, keeping any partial text received.
  void cancel() {
    _cancelToken?.cancel();
    _cancelToken = null;
    if (state.isStreaming) {
      state = state.copyWith(
        isStreaming: false,
        messages: state.messages.map((m) {
          if (m.status == ChatMessageStatus.streaming) {
            return m.copyWith(status: ChatMessageStatus.stopped);
          }
          return m;
        }).toList(),
      );
    }
  }

  /// Retries a failed message turn by re-sending the preceding user question.
  Future<void> retry(String failedMessageId) async {
    final errorIndex = state.messages.indexWhere((m) => m.id == failedMessageId);
    if (errorIndex == -1) return;
    String? query;
    for (int i = errorIndex - 1; i >= 0; i--) {
      if (state.messages[i].sender == MessageSender.user) {
        query = state.messages[i].text;
        break;
      }
    }
    if (query == null) return;
    // Remove the failed assistant message and re-send the question
    state = state.copyWith(
      messages: state.messages.where((m) => m.id != failedMessageId).toList(),
    );
    await send(query);
  }

  /// Sends a user question and handles streaming responses from cortex-ai.
  Future<void> send(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) return;

    // Do not allow overlapping requests while one is already streaming
    if (state.isStreaming) return;

    // Disable sending while rate limited
    final rateLimitedUntil = state.rateLimitedUntil;
    if (rateLimitedUntil != null && clock.now().isBefore(rateLimitedUntil)) {
      return;
    }

    final userMessage = ChatMessage(
      id: _uuid.v4(),
      sender: MessageSender.user,
      text: trimmedQuery,
      status: ChatMessageStatus.done,
    );

    final assistantMessageId = _uuid.v4();
    final assistantMessage = ChatMessage(
      id: assistantMessageId,
      sender: MessageSender.assistant,
      text: '',
      status: ChatMessageStatus.streaming,
    );

    state = state.copyWith(
      messages: [...state.messages, userMessage, assistantMessage],
      isStreaming: true,
      clearRateLimitedUntil: true,
    );

    _cancelToken = CancelToken();
    final currentCancelToken = _cancelToken!;

    final sseClient = ref.read(sseClientProvider);

    try {
      final requestBody = <String, dynamic>{
        'query': trimmedQuery,
        'top_k': 5,
        if (state.conversationId != null) 'conversation_id': state.conversationId,
      };

      final eventStream = sseClient.postEvents(
        '/chat',
        requestBody,
        cancelToken: currentCancelToken,
      );

      await for (final event in eventStream) {
        if (currentCancelToken.isCancelled) return;

        switch (event) {
          case ConversationId(:final conversationId):
            state = state.copyWith(conversationId: conversationId);

          case CacheHit(:final cacheHit):
            _updateAssistantMessage(
              assistantMessageId,
              (msg) => msg.copyWith(fromCache: cacheHit),
            );

          case Sources(:final sources):
            final parsedSources = sources
                .whereType<Map<String, dynamic>>()
                .map(ChatSource.fromMap)
                .toList();
            _updateAssistantMessage(
              assistantMessageId,
              (msg) => msg.copyWith(sources: parsedSources),
            );

          case Token(:final text):
            // Ignore empty tokens; append non-empty text
            if (text.isNotEmpty) {
              _updateAssistantMessage(
                assistantMessageId,
                (msg) => msg.copyWith(text: msg.text + text),
              );
            }

          case Answer(:final text):
            // Cache hits or whole answer responses set the entire text
            _updateAssistantMessage(
              assistantMessageId,
              (msg) => msg.copyWith(text: text),
            );

          case AiError(:final message):
            // Status error, preserving any partial text already received
            _updateAssistantMessage(
              assistantMessageId,
              (msg) => msg.copyWith(
                status: ChatMessageStatus.error,
                errorText: message,
              ),
            );

          case Done():
            _updateAssistantMessage(
              assistantMessageId,
              (msg) {
                // Done only moves a message from streaming to done, and never changes error
                if (msg.status == ChatMessageStatus.streaming) {
                  return msg.copyWith(status: ChatMessageStatus.done);
                }
                return msg;
              },
            );

          default:
            break;
        }
      }

      // If the stream ended without a Done event (e.g. dropped connection),
      // mark any message still streaming as error with "Connection lost", keeping partial text.
      if (!currentCancelToken.isCancelled) {
        _updateAssistantMessage(
          assistantMessageId,
          (msg) {
            if (msg.status == ChatMessageStatus.streaming) {
              return msg.copyWith(
                status: ChatMessageStatus.error,
                errorText: 'Connection lost',
              );
            }
            return msg;
          },
        );
      }
    } on AiUnavailable {
      if (currentCancelToken.isCancelled) return;
      _updateAssistantMessage(
        assistantMessageId,
        (msg) => msg.copyWith(
          status: ChatMessageStatus.aiUnavailable,
          errorText: 'AI is offline. Your notes still work.',
        ),
      );
    } on RateLimited catch (e) {
      if (currentCancelToken.isCancelled) return;
      final retryAfter = e.retryAfter ?? const Duration(seconds: 60);
      final until = clock.now().add(retryAfter);

      // Remove the empty assistant message and set rateLimitedUntil
      state = state.copyWith(
        messages: state.messages
            .where((msg) => msg.id != assistantMessageId)
            .toList(),
        rateLimitedUntil: until,
      );
    } on AiServerError catch (e) {
      if (currentCancelToken.isCancelled) return;
      _updateAssistantMessage(
        assistantMessageId,
        (msg) => msg.copyWith(
          status: ChatMessageStatus.error,
          errorText: e.message ?? 'Server error',
        ),
      );
    } catch (e) {
      if (currentCancelToken.isCancelled) return;
      _updateAssistantMessage(
        assistantMessageId,
        (msg) => msg.copyWith(
          status: ChatMessageStatus.error,
          errorText: e.toString(),
        ),
      );
    } finally {
      if (!currentCancelToken.isCancelled) {
        state = state.copyWith(isStreaming: false);
      }
    }
  }

  void _updateAssistantMessage(
    String id,
    ChatMessage Function(ChatMessage) updater,
  ) {
    state = state.copyWith(
      messages: state.messages.map((m) {
        if (m.id == id) {
          return updater(m);
        }
        return m;
      }).toList(),
    );
  }
}
