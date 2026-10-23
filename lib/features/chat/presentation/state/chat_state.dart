import 'package:flutter/foundation.dart';
import '../../domain/chat_message.dart';

/// State of the chat conversation.
class ChatState {
  final List<ChatMessage> messages; // user + assistant turns
  final String? conversationId; // send it with the next question
  final bool isStreaming;
  final DateTime? rateLimitedUntil; // drives the countdown and disables send

  const ChatState({
    this.messages = const [],
    this.conversationId,
    this.isStreaming = false,
    this.rateLimitedUntil,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    String? conversationId,
    bool? isStreaming,
    DateTime? rateLimitedUntil,
    bool clearRateLimitedUntil = false,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      conversationId: conversationId ?? this.conversationId,
      isStreaming: isStreaming ?? this.isStreaming,
      rateLimitedUntil: clearRateLimitedUntil
          ? null
          : (rateLimitedUntil ?? this.rateLimitedUntil),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatState &&
          runtimeType == other.runtimeType &&
          listEquals(messages, other.messages) &&
          conversationId == other.conversationId &&
          isStreaming == other.isStreaming &&
          rateLimitedUntil == other.rateLimitedUntil;

  @override
  int get hashCode => Object.hash(
        Object.hashAll(messages),
        conversationId,
        isStreaming,
        rateLimitedUntil,
      );

  @override
  String toString() =>
      'ChatState(messagesCount: ${messages.length}, isStreaming: $isStreaming, convId: $conversationId, rateLimitedUntil: $rateLimitedUntil)';
}
