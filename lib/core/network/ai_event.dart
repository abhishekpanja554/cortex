import 'package:flutter/foundation.dart';

/// Sealed class representing typed SSE events streamed from cortex-ai.
sealed class AiEvent {
  const AiEvent();

  /// Converts a parsed JSON event map into a strongly-typed [AiEvent].
  /// Returns `null` if the event type is unknown, ensuring future server
  /// events do not break older client builds.
  static AiEvent? fromMap(Map<String, dynamic> map) {
    final type = map['type'] as String?;
    switch (type) {
      case 'conversation_id':
        return ConversationId(map['conversation_id'] as String? ?? '');
      case 'cache_hit':
        return CacheHit(map['cache_hit'] as bool? ?? true);
      case 'sources':
        final list = map['sources'] as List<dynamic>? ?? const [];
        return Sources(list);
      case 'token':
        return Token(map['text'] as String? ?? '');
      case 'answer':
        return Answer(map['text'] as String? ?? '');
      case 'tool_call':
        return ToolCall(
          tool: map['tool'] as String? ?? '',
          args: (map['args'] as Map<String, dynamic>?) ?? const {},
        );
      case 'tool_result':
        return ToolResult(
          tool: map['tool'] as String? ?? '',
          result: map['result'],
        );
      case 'confirmation_required':
        return ConfirmationRequired(
          confirmationId: map['confirmation_id'] as String? ?? '',
          tool: map['tool'] as String? ?? '',
          args: (map['args'] as Map<String, dynamic>?) ?? const {},
        );
      case 'error':
        return AiError(map['message'] as String? ?? '');
      case 'done':
        return const Done();
      default:
        // Unknown type is ignored so server changes don't break the client
        return null;
    }
  }
}

class ConversationId extends AiEvent {
  final String conversationId;
  const ConversationId(this.conversationId);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConversationId &&
          runtimeType == other.runtimeType &&
          conversationId == other.conversationId;

  @override
  int get hashCode => conversationId.hashCode;

  @override
  String toString() => 'ConversationId($conversationId)';
}

class CacheHit extends AiEvent {
  final bool cacheHit;
  const CacheHit([this.cacheHit = true]);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CacheHit &&
          runtimeType == other.runtimeType &&
          cacheHit == other.cacheHit;

  @override
  int get hashCode => cacheHit.hashCode;

  @override
  String toString() => 'CacheHit($cacheHit)';
}

class Sources extends AiEvent {
  final List<dynamic> sources;
  const Sources(this.sources);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Sources || runtimeType != other.runtimeType) return false;
    return listEquals(sources, other.sources);
  }

  @override
  int get hashCode => Object.hashAll(sources);

  @override
  String toString() => 'Sources($sources)';
}

class Token extends AiEvent {
  final String text;
  const Token(this.text);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Token &&
          runtimeType == other.runtimeType &&
          text == other.text;

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => 'Token($text)';
}

class Answer extends AiEvent {
  final String text;
  const Answer(this.text);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Answer &&
          runtimeType == other.runtimeType &&
          text == other.text;

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => 'Answer($text)';
}

class ToolCall extends AiEvent {
  final String tool;
  final Map<String, dynamic> args;
  const ToolCall({required this.tool, required this.args});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ToolCall &&
          runtimeType == other.runtimeType &&
          tool == other.tool &&
          mapEquals(args, other.args);

  @override
  int get hashCode => Object.hash(tool, Object.hashAll(args.entries));

  @override
  String toString() => 'ToolCall(tool: $tool, args: $args)';
}

class ToolResult extends AiEvent {
  final String tool;
  final dynamic result;
  const ToolResult({required this.tool, required this.result});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ToolResult &&
          runtimeType == other.runtimeType &&
          tool == other.tool &&
          result == other.result;

  @override
  int get hashCode => Object.hash(tool, result);

  @override
  String toString() => 'ToolResult(tool: $tool, result: $result)';
}

class ConfirmationRequired extends AiEvent {
  final String confirmationId;
  final String tool;
  final Map<String, dynamic> args;
  const ConfirmationRequired({
    required this.confirmationId,
    required this.tool,
    required this.args,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConfirmationRequired &&
          runtimeType == other.runtimeType &&
          confirmationId == other.confirmationId &&
          tool == other.tool &&
          mapEquals(args, other.args);

  @override
  int get hashCode =>
      Object.hash(confirmationId, tool, Object.hashAll(args.entries));

  @override
  String toString() =>
      'ConfirmationRequired(id: $confirmationId, tool: $tool, args: $args)';
}

class AiError extends AiEvent {
  final String message;
  const AiError(this.message);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AiError &&
          runtimeType == other.runtimeType &&
          message == other.message;

  @override
  int get hashCode => message.hashCode;

  @override
  String toString() => 'AiError($message)';
}

class Done extends AiEvent {
  const Done();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Done && runtimeType == other.runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'Done()';
}
