import 'package:flutter/foundation.dart';
import '../../domain/agent_models.dart';

/// State of the agent chat session.
class AgentState {
  final List<AgentTurn> turns;
  final bool isStreaming;
  final DateTime? rateLimitedUntil;

  const AgentState({
    this.turns = const [],
    this.isStreaming = false,
    this.rateLimitedUntil,
  });

  AgentState copyWith({
    List<AgentTurn>? turns,
    bool? isStreaming,
    DateTime? rateLimitedUntil,
    bool clearRateLimitedUntil = false,
  }) {
    return AgentState(
      turns: turns ?? this.turns,
      isStreaming: isStreaming ?? this.isStreaming,
      rateLimitedUntil: clearRateLimitedUntil
          ? null
          : (rateLimitedUntil ?? this.rateLimitedUntil),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AgentState &&
          runtimeType == other.runtimeType &&
          listEquals(turns, other.turns) &&
          isStreaming == other.isStreaming &&
          rateLimitedUntil == other.rateLimitedUntil;

  @override
  int get hashCode => Object.hash(
        Object.hashAll(turns),
        isStreaming,
        rateLimitedUntil,
      );

  @override
  String toString() =>
      'AgentState(turns: ${turns.length}, isStreaming: $isStreaming, rateLimited: $rateLimitedUntil)';
}
