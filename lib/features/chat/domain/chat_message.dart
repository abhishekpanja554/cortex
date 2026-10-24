import 'package:flutter/foundation.dart';
import 'chat_source.dart';

enum MessageSender { user, assistant }

enum ChatMessageStatus { streaming, done, error, aiUnavailable, stopped }

/// A single message turn within the chat conversation.
class ChatMessage {
  final String id;
  final MessageSender sender;
  final String text; // built up from Token events, or one Answer
  final List<ChatSource> sources;
  final bool fromCache;
  final ChatMessageStatus status; // streaming | done | error | aiUnavailable | stopped
  final String? errorText;

  const ChatMessage({
    required this.id,
    required this.sender,
    required this.text,
    this.sources = const [],
    this.fromCache = false,
    required this.status,
    this.errorText,
  });

  ChatMessage copyWith({
    String? id,
    MessageSender? sender,
    String? text,
    List<ChatSource>? sources,
    bool? fromCache,
    ChatMessageStatus? status,
    String? errorText,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      sender: sender ?? this.sender,
      text: text ?? this.text,
      sources: sources ?? this.sources,
      fromCache: fromCache ?? this.fromCache,
      status: status ?? this.status,
      errorText: errorText ?? this.errorText,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatMessage &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          sender == other.sender &&
          text == other.text &&
          listEquals(sources, other.sources) &&
          fromCache == other.fromCache &&
          status == other.status &&
          errorText == other.errorText;

  @override
  int get hashCode => Object.hash(
        id,
        sender,
        text,
        Object.hashAll(sources),
        fromCache,
        status,
        errorText,
      );

  @override
  String toString() =>
      'ChatMessage(id: $id, sender: $sender, status: $status, textLen: ${text.length})';
}
