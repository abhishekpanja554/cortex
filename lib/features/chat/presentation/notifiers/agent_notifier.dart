import 'package:clock/clock.dart';
import 'package:cortex/core/network/ai_event.dart';
import 'package:cortex/core/network/ai_failure.dart';
import 'package:cortex/core/providers/core_providers.dart';
import 'package:cortex/features/auth/domain/auth_state.dart';
import 'package:cortex/features/auth/presentation/auth_notifier.dart';
import 'package:cortex/features/chat/domain/agent_models.dart';
import 'package:cortex/features/chat/presentation/state/agent_state.dart';
import 'package:cortex/features/sync/presentation/sync_providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class AgentNotifier extends Notifier<AgentState> {
  CancelToken? _cancelToken;

  @override
  AgentState build() {
    // Reset state on user change or logout
    ref.watch(authProvider.select((s) => s is Authenticated ? s.userId : null));

    ref.onDispose(() {
      _cancelToken?.cancel();
    });

    return const AgentState();
  }

  /// Clears agent turns and cancels any in-flight streaming.
  void clear() {
    _cancelToken?.cancel();
    _cancelToken = null;
    state = const AgentState();
  }

  /// Cancels in-flight request, marking the current turn as stopped.
  void cancel() {
    _cancelToken?.cancel();
    _cancelToken = null;
    if (state.isStreaming) {
      state = state.copyWith(
        isStreaming: false,
        turns: state.turns.map((turn) {
          if (turn.status == AgentTurnStatus.streaming) {
            return turn.copyWith(status: AgentTurnStatus.stopped);
          }
          return turn;
        }).toList(),
      );
    }
  }

  /// Sends a standalone agent query to /agent-chat.
  Future<void> send(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) return;

    if (state.isStreaming) return;

    final rateLimitedUntil = state.rateLimitedUntil;
    if (rateLimitedUntil != null && clock.now().isBefore(rateLimitedUntil)) {
      return;
    }

    final turnId = _uuid.v4();
    final newTurn = AgentTurn(
      id: turnId,
      query: trimmedQuery,
      status: AgentTurnStatus.streaming,
    );

    state = state.copyWith(
      turns: [...state.turns, newTurn],
      isStreaming: true,
      clearRateLimitedUntil: true,
    );

    _cancelToken = CancelToken();
    final currentCancelToken = _cancelToken!;

    final sseClient = ref.read(sseClientProvider);

    try {
      final eventStream = sseClient.postEvents(
        '/agent-chat',
        {'query': trimmedQuery},
        cancelToken: currentCancelToken,
      );

      await for (final event in eventStream) {
        if (currentCancelToken.isCancelled) return;

        switch (event) {
          case ToolCall(:final tool, :final args):
            final step = AgentToolStep(
              id: _uuid.v4(),
              tool: tool,
              args: args,
              status: AgentStepStatus.running,
            );
            _updateTurn(turnId, (t) => t.copyWith(steps: [...t.steps, step]));

          case ToolResult(:final tool, :final result):
            if (tool == 'create_note' ||
                tool == 'update_note' ||
                tool == 'delete_note' ||
                tool == 'bulk_delete_notes') {
              ref.read(syncSchedulerProvider).requestSync();
            }
            _updateTurn(turnId, (t) {
              // Find the latest running step matching this tool
              final reversedIndex = t.steps.lastIndexWhere(
                (s) => s.tool == tool && s.status == AgentStepStatus.running,
              );
              final targetIndex = reversedIndex != -1
                  ? reversedIndex
                  : t.steps.lastIndexWhere(
                      (s) => s.status == AgentStepStatus.running,
                    );

              if (targetIndex != -1) {
                final updatedSteps = List<AgentToolStep>.from(t.steps);
                updatedSteps[targetIndex] = updatedSteps[targetIndex].copyWith(
                  result: result,
                  status: AgentStepStatus.done,
                );
                return t.copyWith(steps: updatedSteps);
              }
              return t;
            });

          case ConfirmationRequired(
              :final confirmationId,
              :final tool,
              :final args
            ):
            final confirmation = AgentConfirmation(
              confirmationId: confirmationId,
              tool: tool,
              args: args,
              resolution: ConfirmationResolution.pending,
            );
            _updateTurn(
              turnId,
              (t) => t.copyWith(
                confirmation: confirmation,
                status: AgentTurnStatus.awaitingConfirmation,
              ),
            );

          case Answer(:final text):
            _updateTurn(
              turnId,
              (t) => t.copyWith(
                answer: text,
                status: AgentTurnStatus.done,
              ),
            );

          case AiError(:final message):
            _updateTurn(
              turnId,
              (t) => t.copyWith(
                status: AgentTurnStatus.error,
                errorText: message,
                steps: t.steps.map((s) {
                  if (s.status == AgentStepStatus.running) {
                    return s.copyWith(status: AgentStepStatus.interrupted);
                  }
                  return s;
                }).toList(),
              ),
            );

          case Done():
            // If the turn ended in an error or is awaiting confirmation, do not overwrite it.
            _updateTurn(turnId, (t) {
              if (t.steps.any((s) =>
                  s.tool == 'create_note' ||
                  s.tool == 'update_note' ||
                  s.tool == 'delete_note' ||
                  s.tool == 'bulk_delete_notes')) {
                ref.read(syncSchedulerProvider).requestSync();
              }
              if (t.status == AgentTurnStatus.streaming) {
                return t.copyWith(status: AgentTurnStatus.done);
              }
              return t;
            });

          default:
            // Unhandled/ignored event types
            break;
        }
      }

      // If the stream ended cleanly without a Done event (e.g. dropped connection),
      // mark the turn as error with "Connection lost", and mark any still-running steps as interrupted.
      if (!currentCancelToken.isCancelled) {
        _updateTurn(
          turnId,
          (t) {
            if (t.status == AgentTurnStatus.streaming) {
              return t.copyWith(
                status: AgentTurnStatus.error,
                errorText: 'Connection lost',
                steps: t.steps.map((s) {
                  if (s.status == AgentStepStatus.running) {
                    return s.copyWith(status: AgentStepStatus.interrupted);
                  }
                  return s;
                }).toList(),
              );
            }
            return t;
          },
        );
      }
    } on AiUnavailable catch (e) {
      if (currentCancelToken.isCancelled) return;
      _updateTurn(
        turnId,
        (t) => t.copyWith(
          status: AgentTurnStatus.aiUnavailable,
          errorText: e.message ?? 'AI is offline. Your notes still work.',
          steps: t.steps.map((s) {
            if (s.status == AgentStepStatus.running) {
              return s.copyWith(status: AgentStepStatus.interrupted);
            }
            return s;
          }).toList(),
        ),
      );
    } on RateLimited catch (e) {
      if (currentCancelToken.isCancelled) return;
      final until = e.retryAfter != null
          ? clock.now().add(e.retryAfter!)
          : clock.now().add(const Duration(seconds: 60));
      state = state.copyWith(rateLimitedUntil: until);
      _updateTurn(
        turnId,
        (t) => t.copyWith(
          status: AgentTurnStatus.error,
          errorText: 'Rate limit exceeded. Please wait a moment.',
          steps: t.steps.map((s) {
            if (s.status == AgentStepStatus.running) {
              return s.copyWith(status: AgentStepStatus.interrupted);
            }
            return s;
          }).toList(),
        ),
      );
    } catch (e) {
      if (currentCancelToken.isCancelled) {
        _updateTurn(
          turnId,
          (t) => t.copyWith(
            status: AgentTurnStatus.stopped,
            steps: t.steps.map((s) {
              if (s.status == AgentStepStatus.running) {
                return s.copyWith(status: AgentStepStatus.interrupted);
              }
              return s;
            }).toList(),
          ),
        );
      } else {
        _updateTurn(
          turnId,
          (t) => t.copyWith(
            status: AgentTurnStatus.error,
            errorText: e is AiFailure
                ? (e.message ?? 'Server error')
                : e.toString(),
            steps: t.steps.map((s) {
              if (s.status == AgentStepStatus.running) {
                return s.copyWith(status: AgentStepStatus.interrupted);
              }
              return s;
            }).toList(),
          ),
        );
      }
    } finally {
      if (_cancelToken == currentCancelToken) {
        _cancelToken = null;
      }
      state = state.copyWith(isStreaming: false);
    }
  }

  /// Confirms or rejects a pending destructive action.
  /// Prevents double confirmation by disabling actions immediately upon initiation.
  Future<void> confirm({
    required String turnId,
    required bool approve,
  }) async {
    final turn = state.turns.where((t) => t.id == turnId).firstOrNull;
    if (turn == null || turn.confirmation == null) return;

    final currentResolution = turn.confirmation!.resolution;
    // Guard against double taps or already resolved actions
    if (currentResolution == ConfirmationResolution.confirming ||
        currentResolution == ConfirmationResolution.executed ||
        currentResolution == ConfirmationResolution.rejected ||
        currentResolution == ConfirmationResolution.unavailable) {
      return;
    }

    // Immediately disable buttons and enter confirming state
    _updateTurnConfirmation(
      turnId,
      (c) => c.copyWith(
        resolution: ConfirmationResolution.confirming,
        errorText: null,
      ),
    );

    final sseClient = ref.read(sseClientProvider);

    try {
      final res = await sseClient.confirmAction(
        confirmationId: turn.confirmation!.confirmationId,
        approve: approve,
      );

      final status = res['status'] as String?;
      if (status == 'executed' || status == 'already_executed') {
        _updateTurnConfirmation(
          turnId,
          (c) => c.copyWith(resolution: ConfirmationResolution.executed),
        );
        // After executed or already_executed, call requestSync() to pull updated notes
        ref.read(syncSchedulerProvider).requestSync();
      } else if (status == 'rejected' || status == 'already_rejected') {
        _updateTurnConfirmation(
          turnId,
          (c) => c.copyWith(resolution: ConfirmationResolution.rejected),
        );
        // On reject or already_rejected, discarded without syncing
      } else if (status == 'in_progress') {
        _updateTurnConfirmation(
          turnId,
          (c) => c.copyWith(
            resolution: ConfirmationResolution.error,
            errorText: 'Still being carried out — try again in a moment.',
          ),
        );
      } else if (status == 'not_found') {
        _updateTurnConfirmation(
          turnId,
          (c) => c.copyWith(
            resolution: ConfirmationResolution.unavailable,
            errorText: 'This action is no longer available.',
          ),
        );
      } else {
        _updateTurnConfirmation(
          turnId,
          (c) => c.copyWith(
            resolution: ConfirmationResolution.error,
            errorText: res['message'] as String? ?? 'Confirmation failed',
          ),
        );
      }
    } on AiUnavailable catch (e) {
      // Network drop: can be tapped again
      _updateTurnConfirmation(
        turnId,
        (c) => c.copyWith(
          resolution: ConfirmationResolution.error,
          errorText: e.message ?? 'cortex-ai is unavailable',
        ),
      );
    } catch (e) {
      _updateTurnConfirmation(
        turnId,
        (c) => c.copyWith(
          resolution: ConfirmationResolution.error,
          errorText: e is AiFailure
              ? (e.message ?? 'Server error')
              : e.toString(),
        ),
      );
    }
  }

  void _updateTurn(String turnId, AgentTurn Function(AgentTurn) updater) {
    state = state.copyWith(
      turns: state.turns.map((t) => t.id == turnId ? updater(t) : t).toList(),
    );
  }

  void _updateTurnConfirmation(
    String turnId,
    AgentConfirmation Function(AgentConfirmation) updater,
  ) {
    _updateTurn(turnId, (t) {
      if (t.confirmation == null) return t;
      return t.copyWith(confirmation: updater(t.confirmation!));
    });
  }
}
