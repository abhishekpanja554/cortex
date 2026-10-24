import 'package:flutter/foundation.dart';

/// Execution status of an agent tool step.
enum AgentStepStatus {
  running,
  done,
  error,
  interrupted,
}

/// A single tool call and its execution result in an agent turn.
class AgentToolStep {
  final String id;
  final String tool;
  final Map<String, dynamic> args;
  final dynamic result;
  final AgentStepStatus status;

  const AgentToolStep({
    required this.id,
    required this.tool,
    required this.args,
    this.result,
    this.status = AgentStepStatus.running,
  });

  AgentToolStep copyWith({
    String? id,
    String? tool,
    Map<String, dynamic>? args,
    dynamic result,
    AgentStepStatus? status,
  }) {
    return AgentToolStep(
      id: id ?? this.id,
      tool: tool ?? this.tool,
      args: args ?? this.args,
      result: result ?? this.result,
      status: status ?? this.status,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AgentToolStep &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          tool == other.tool &&
          mapEquals(args, other.args) &&
          result == other.result &&
          status == other.status;

  @override
  int get hashCode => Object.hash(
        id,
        tool,
        Object.hashAll(args.entries),
        result,
        status,
      );

  @override
  String toString() =>
      'AgentToolStep(tool: $tool, status: $status, args: $args, result: $result)';
}

/// Resolution state of a pending destructive confirmation action.
enum ConfirmationResolution {
  /// Awaiting user choice.
  pending,

  /// User tapped Approve or Reject; confirm request in-flight.
  /// Both buttons are disabled to prevent double confirmations.
  confirming,

  /// Action was approved and successfully executed on the server.
  executed,

  /// Action was rejected/discarded by the user.
  rejected,

  /// Action not found or no longer available (404).
  /// Displays "This action is no longer available".
  unavailable,

  /// Confirm request failed (e.g. AiUnavailable, in_progress). Buttons can be tapped again.
  error,
}

/// A pending destructive action proposing delete, update, or bulk_delete.
class AgentConfirmation {
  final String confirmationId;
  final String tool;
  final Map<String, dynamic> args;
  final ConfirmationResolution resolution;
  final String? errorText;

  const AgentConfirmation({
    required this.confirmationId,
    required this.tool,
    required this.args,
    this.resolution = ConfirmationResolution.pending,
    this.errorText,
  });

  AgentConfirmation copyWith({
    String? confirmationId,
    String? tool,
    Map<String, dynamic>? args,
    ConfirmationResolution? resolution,
    String? errorText,
  }) {
    return AgentConfirmation(
      confirmationId: confirmationId ?? this.confirmationId,
      tool: tool ?? this.tool,
      args: args ?? this.args,
      resolution: resolution ?? this.resolution,
      errorText: errorText ?? this.errorText,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AgentConfirmation &&
          runtimeType == other.runtimeType &&
          confirmationId == other.confirmationId &&
          tool == other.tool &&
          mapEquals(args, other.args) &&
          resolution == other.resolution &&
          errorText == other.errorText;

  @override
  int get hashCode => Object.hash(
        confirmationId,
        tool,
        Object.hashAll(args.entries),
        resolution,
        errorText,
      );

  @override
  String toString() =>
      'AgentConfirmation(id: $confirmationId, tool: $tool, resolution: $resolution)';
}

/// High-level lifecycle status of an agent turn.
enum AgentTurnStatus {
  streaming,
  awaitingConfirmation,
  done,
  error,
  aiUnavailable,
  stopped,
}

/// A standalone turn in an Agent chat session.
class AgentTurn {
  final String id;
  final String query;
  final List<AgentToolStep> steps;
  final AgentConfirmation? confirmation;
  final String? answer;
  final AgentTurnStatus status;
  final String? errorText;

  const AgentTurn({
    required this.id,
    required this.query,
    this.steps = const [],
    this.confirmation,
    this.answer,
    required this.status,
    this.errorText,
  });

  AgentTurn copyWith({
    String? id,
    String? query,
    List<AgentToolStep>? steps,
    AgentConfirmation? confirmation,
    String? answer,
    AgentTurnStatus? status,
    String? errorText,
  }) {
    return AgentTurn(
      id: id ?? this.id,
      query: query ?? this.query,
      steps: steps ?? this.steps,
      confirmation: confirmation ?? this.confirmation,
      answer: answer ?? this.answer,
      status: status ?? this.status,
      errorText: errorText ?? this.errorText,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AgentTurn &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          query == other.query &&
          listEquals(steps, other.steps) &&
          confirmation == other.confirmation &&
          answer == other.answer &&
          status == other.status &&
          errorText == other.errorText;

  @override
  int get hashCode => Object.hash(
        id,
        query,
        Object.hashAll(steps),
        confirmation,
        answer,
        status,
        errorText,
      );

  @override
  String toString() =>
      'AgentTurn(id: $id, query: $query, status: $status, steps: ${steps.length}, confirmation: $confirmation)';
}
