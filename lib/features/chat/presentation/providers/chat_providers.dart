import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/chat_message.dart';
import '../notifiers/chat_notifier.dart';
import '../state/chat_state.dart';

/// Main ChatNotifier provider managing conversation state.
final chatNotifierProvider =
    NotifierProvider<ChatNotifier, ChatState>(ChatNotifier.new);

/// Selects only the message list so header/input changes don't trigger list rebuilds.
final chatMessagesProvider = Provider<List<ChatMessage>>((ref) {
  return ref.watch(chatNotifierProvider.select((s) => s.messages));
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
