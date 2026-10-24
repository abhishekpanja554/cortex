import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/agent_models.dart';
import '../notifiers/agent_notifier.dart';
import '../state/agent_state.dart';

/// Provider managing standalone Agent turns and approval workflows.
final agentNotifierProvider =
    NotifierProvider<AgentNotifier, AgentState>(AgentNotifier.new);

/// Selects all agent turns.
final agentTurnsProvider = Provider<List<AgentTurn>>((ref) {
  return ref.watch(agentNotifierProvider.select((s) => s.turns));
});

/// Selects list of turn IDs to avoid unnecessary list rebuilds.
final agentTurnIdsProvider = Provider<List<String>>((ref) {
  final ids = ref.watch(agentNotifierProvider.select(
    (s) => s.turns.map((t) => t.id).join(','),
  ));
  if (ids.isEmpty) return const [];
  return ids.split(',');
});

/// Selects a specific turn by its unique ID for optimized subtree rebuilds.
final agentTurnFamilyProvider =
    Provider.family<AgentTurn?, String>((ref, id) {
  return ref.watch(agentNotifierProvider.select((state) {
    for (final turn in state.turns) {
      if (turn.id == id) return turn;
    }
    return null;
  }));
});

/// Selects agent streaming state.
final agentIsStreamingProvider = Provider<bool>((ref) {
  return ref.watch(agentNotifierProvider.select((s) => s.isStreaming));
});

/// Selects rate limit timestamp for the agent endpoint.
final agentRateLimitedUntilProvider = Provider<DateTime?>((ref) {
  return ref.watch(agentNotifierProvider.select((s) => s.rateLimitedUntil));
});
