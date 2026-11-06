import 'package:cortex/core/constants/colors.dart';
import 'package:cortex/core/constants/dimens.dart';
import 'package:cortex/core/constants/text_styles.dart';
import 'package:cortex/features/chat/domain/agent_models.dart';
import 'package:cortex/features/chat/presentation/providers/agent_providers.dart';
import 'package:cortex/features/chat/presentation/widgets/agent_approval_card.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Keyed widget rendering a standalone Agent turn (user query, tool steps, approval card, answer).
class AgentTurnBubble extends ConsumerWidget {
  final String turnId;

  const AgentTurnBubble({
    super.key,
    required this.turnId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final turn = ref.watch(agentTurnFamilyProvider(turnId));
    if (turn == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildUserQuery(turn.query),
        _buildAgentResponse(context, ref, turn),
      ],
    );
  }

  Widget _buildUserQuery(String query) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(48, 6, AppSpacing.page, 6),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(AppRadius.lg),
              topRight: Radius.circular(AppRadius.lg),
              bottomLeft: Radius.circular(AppRadius.lg),
              bottomRight: Radius.circular(AppRadius.sm),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1F007AFF),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            query,
            style: TextStyles.body.copyWith(
              color: AppColors.onPrimary,
              height: 1.35,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAgentResponse(BuildContext context, WidgetRef ref, AgentTurn turn) {
    if (turn.status == AgentTurnStatus.aiUnavailable) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.page, 6, 48, 6),
        child: Container(
          key: const ValueKey('agent_ai_unavailable_bubble'),
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border, width: 0.8),
          ),
          child: Row(
            children: [
              const Icon(CupertinoIcons.wifi_slash,
                  size: 18, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  turn.errorText ?? 'AI is offline. Your notes still work.',
                  style: TextStyles.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, 6, 48, 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(AppRadius.lg),
              topRight: Radius.circular(AppRadius.lg),
              bottomLeft: Radius.circular(AppRadius.sm),
              bottomRight: Radius.circular(AppRadius.lg),
            ),
            border: Border.all(
              color: turn.status == AgentTurnStatus.error
                  ? AppColors.danger.withValues(alpha: 0.3)
                  : AppColors.border.withValues(alpha: 0.6),
              width: 0.8,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              if (turn.steps.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                _buildStepsList(turn.steps),
              ],
              if (turn.confirmation != null) ...[
                const SizedBox(height: AppSpacing.sm),
                AgentApprovalCard(
                  confirmation: turn.confirmation!,
                  onApprove: () {
                    ref.read(agentNotifierProvider.notifier).confirm(
                          turnId: turn.id,
                          approve: true,
                        );
                  },
                  onReject: () {
                    ref.read(agentNotifierProvider.notifier).confirm(
                          turnId: turn.id,
                          approve: false,
                        );
                  },
                ),
              ],
              if (turn.answer != null && turn.answer!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  turn.answer!,
                  style: TextStyles.body.copyWith(
                    color: AppColors.textPrimary,
                    height: 1.4,
                  ),
                ),
              ],
              if (turn.status == AgentTurnStatus.streaming &&
                  turn.steps.isEmpty &&
                  turn.confirmation == null &&
                  turn.answer == null) ...[
                const SizedBox(height: AppSpacing.sm),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CupertinoActivityIndicator(radius: 7),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Thinking…',
                      style: TextStyles.bodySecondary.copyWith(
                        fontStyle: FontStyle.italic,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
              if (turn.status == AgentTurnStatus.error && turn.errorText != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.dangerSoft,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(
                      color: AppColors.danger.withValues(alpha: 0.3),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(CupertinoIcons.exclamationmark_circle_fill,
                          size: 14, color: AppColors.danger),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          turn.errorText!,
                          style: TextStyles.caption.copyWith(
                            color: AppColors.danger,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.3),
              width: 0.5,
            ),
          ),
          child: const Icon(
            CupertinoIcons.cube_box,
            size: 12,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          'Cortex Agent',
          style: TextStyles.caption.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildStepsList(List<AgentToolStep> steps) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final step in steps) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                if (step.status == AgentStepStatus.running)
                  const CupertinoActivityIndicator(radius: 6)
                else if (step.status == AgentStepStatus.interrupted)
                  const Icon(
                    CupertinoIcons.xmark_circle_fill,
                    size: 13,
                    color: AppColors.warning,
                  )
                else if (step.status == AgentStepStatus.error)
                  const Icon(
                    CupertinoIcons.exclamationmark_circle_fill,
                    size: 13,
                    color: AppColors.danger,
                  )
                else
                  const Icon(
                    CupertinoIcons.checkmark_circle_fill,
                    size: 13,
                    color: AppColors.success,
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _formatStepLabel(step),
                    style: TextStyles.caption.copyWith(
                      color: step.status == AgentStepStatus.running
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontWeight: step.status == AgentStepStatus.running
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  String _formatStepLabel(AgentToolStep step) {
    final suffix =
        step.status == AgentStepStatus.interrupted ? ' (interrupted)' : '';
    switch (step.tool) {
      case 'search_notes':
        final q = step.args['query'] ?? '';
        return step.status == AgentStepStatus.running
            ? 'Searching notes for "$q"…'
            : 'Searched notes for "$q"$suffix';
      case 'get_note':
        return step.status == AgentStepStatus.running
            ? 'Reading note…'
            : 'Read note$suffix';
      case 'create_note':
        final title = step.args['title'] ?? '';
        return step.status == AgentStepStatus.running
            ? 'Creating note "$title"…'
            : 'Created note "$title"$suffix';
      default:
        return '${step.tool}$suffix…';
    }
  }
}
