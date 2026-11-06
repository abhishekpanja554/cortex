import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/chat_message.dart';
import '../notifiers/chat_notifier.dart';
import '../state/chat_state.dart';

/// Main ChatNotifier provider managing conversation state.
///
/// ARCHITECTURAL DECISION (Background Chat Streaming):
/// Leaving the chat screen mid-stream does NOT cancel the in-flight SSE request.
/// [chatNotifierProvider] lives with the application/auth session lifecycle rather
/// than the widget/route lifecycle (`autoDispose` is deliberately omitted).
///
/// - Advantage: Answers continue streaming into state in the background, ensuring
///   the full response is ready when the user returns to the chat.
/// - Tradeoff: If the user leaves and never reads the answer, the server continues
///   generating tokens and consuming Gemini LLM quota.
final chatNotifierProvider =
    NotifierProvider<ChatNotifier, ChatState>(ChatNotifier.new);

/// Selects only the message list so header/input changes don't trigger list rebuilds.
final chatMessagesProvider = Provider<List<ChatMessage>>((ref) {
  return ref.watch(chatNotifierProvider.select((s) => s.messages));
});

/// Selects only the list of message IDs.
/// Uses a comma-joined ID string comparison so streaming token updates to an existing
/// message do NOT trigger rebuilds of the message list widget.
final chatMessageIdsProvider = Provider<List<String>>((ref) {
  final joined = ref.watch(chatNotifierProvider.select(
    (s) => s.messages.map((m) => m.id).join(','),
  ));
  if (joined.isEmpty) return const [];
  return joined.split(',');
});

/// Selects a specific message by its unique ID.
/// High performance selector: ensures only the single message receiving streamed tokens
/// is rebuilt in the UI, rather than the entire message list.
final chatMessageFamilyProvider =
    Provider.family<ChatMessage?, String>((ref, id) {
  return ref.watch(chatNotifierProvider.select((state) {
    for (final message in state.messages) {
      if (message.id == id) return message;
    }
    return null;
  }));
});

/// Selects streaming flag (e.g. to disable input or show spinner).
final chatIsStreamingProvider = Provider<bool>((ref) {
  return ref.watch(chatNotifierProvider.select((s) => s.isStreaming));
});

/// Selects rate limit timestamp (e.g. to drive UI countdown timer).
final chatRateLimitedUntilProvider = Provider<DateTime?>((ref) {
  return ref.watch(chatNotifierProvider.select((s) => s.rateLimitedUntil));
});

/// Selects conversation ID for the current thread.
final chatConversationIdProvider = Provider<String?>((ref) {
  return ref.watch(chatNotifierProvider.select((s) => s.conversationId));
});
