import 'package:cortex/core/constants/colors.dart';
import 'package:cortex/core/constants/dimens.dart';
import 'package:cortex/core/constants/text_styles.dart';
import 'package:cortex/features/chat/domain/agent_models.dart';
import 'package:cortex/features/notes/presentation/providers/providers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Interactive approval card for destructive actions proposed by Cortex Agent.
/// Humanizes note IDs to titles using local Drift note storage.
class AgentApprovalCard extends ConsumerWidget {
  final AgentConfirmation confirmation;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const AgentApprovalCard({
    super.key,
    required this.confirmation,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final noteNotifier = ref.watch(noteNotifierProvider.notifier);

    return Container(
      key: const ValueKey('agent_approval_card'),
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: _getBorderColor(),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          const SizedBox(height: AppSpacing.sm),
          _buildContent(noteNotifier),
          const SizedBox(height: AppSpacing.md),
          _buildFooter(),
        ],
      ),
    );
  }

  Color _getBorderColor() {
    switch (confirmation.resolution) {
      case ConfirmationResolution.executed:
        return AppColors.success.withValues(alpha: 0.5);
      case ConfirmationResolution.rejected:
        return AppColors.textTertiary.withValues(alpha: 0.3);
      case ConfirmationResolution.error:
        return AppColors.danger.withValues(alpha: 0.4);
      case ConfirmationResolution.unavailable:
        return AppColors.textTertiary.withValues(alpha: 0.3);
      case ConfirmationResolution.confirming:
      case ConfirmationResolution.pending:
        return AppColors.warning.withValues(alpha: 0.4);
    }
  }

  Widget _buildHeader() {
    String titleText;
    IconData icon;
    Color iconColor;

    switch (confirmation.tool) {
      case 'delete_note':
        titleText = 'Delete Note';
        icon = CupertinoIcons.trash;
        iconColor = AppColors.danger;
        break;
      case 'bulk_delete_notes':
        titleText = 'Delete Notes';
        icon = CupertinoIcons.trash_fill;
        iconColor = AppColors.danger;
        break;
      case 'update_note':
        titleText = 'Update Note';
        icon = CupertinoIcons.pencil_ellipsis_rectangle;
        iconColor = AppColors.warning;
        break;
      default:
        titleText = 'Action Approval Required';
        icon = CupertinoIcons.exclamationmark_shield;
        iconColor = AppColors.primary;
    }

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 14, color: iconColor),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          titleText,
          style: TextStyles.cardTitle.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        _buildStatusBadge(),
      ],
    );
  }

  Widget _buildStatusBadge() {
    switch (confirmation.resolution) {
      case ConfirmationResolution.executed:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: AppColors.success.withValues(alpha: 0.3),
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(CupertinoIcons.checkmark_alt,
                  size: 11, color: AppColors.success),
              const SizedBox(width: 3),
              Text(
                'Done',
                style: TextStyles.caption.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
        );
      case ConfirmationResolution.rejected:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: Text(
            'Discarded',
            style: TextStyles.caption.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        );
      case ConfirmationResolution.unavailable:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: Text(
            'Unavailable',
            style: TextStyles.caption.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        );
      case ConfirmationResolution.confirming:
        return const CupertinoActivityIndicator(radius: 6);
      case ConfirmationResolution.pending:
      case ConfirmationResolution.error:
        return const SizedBox.shrink();
    }
  }

  Widget _buildContent(dynamic noteNotifier) {
    final tool = confirmation.tool;
    final args = confirmation.args;

    if (tool == 'bulk_delete_notes') {
      final rawIds = args['note_ids'];
      final List<String> noteIds = rawIds is List
          ? rawIds.map((e) => e.toString()).toList()
          : const [];

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'The following ${noteIds.length} notes will be deleted:',
            style: TextStyles.bodySecondary.copyWith(fontSize: 13),
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final id in noteIds) ...[
            Builder(builder: (context) {
              final note = noteNotifier.getNoteById(id);
              final hasLocalNote = note != null;
              final title = hasLocalNote
                  ? (note.title.isNotEmpty ? note.title : 'Untitled note')
                  : 'not on this device';

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Icon(
                      hasLocalNote
                          ? CupertinoIcons.doc_text
                          : CupertinoIcons.question_circle,
                      size: 13,
                      color: hasLocalNote
                          ? AppColors.textSecondary
                          : AppColors.warning,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyles.body.copyWith(
                          fontSize: 13,
                          fontWeight:
                              hasLocalNote ? FontWeight.w600 : FontWeight.w400,
                          color: hasLocalNote
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                          fontStyle: hasLocalNote
                              ? FontStyle.normal
                              : FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      );
    } else if (tool == 'delete_note') {
      final noteId = args['note_id']?.toString() ?? '';
      final note = noteNotifier.getNoteById(noteId);
      final hasLocalNote = note != null;
      final title = hasLocalNote
          ? (note.title.isNotEmpty ? note.title : 'Untitled note')
          : 'not on this device';

      return Row(
        children: [
          Icon(
            hasLocalNote
                ? CupertinoIcons.doc_text
                : CupertinoIcons.question_circle,
            size: 14,
            color: hasLocalNote ? AppColors.textSecondary : AppColors.warning,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              title,
              style: TextStyles.body.copyWith(
                fontSize: 13,
                fontWeight: hasLocalNote ? FontWeight.w600 : FontWeight.w400,
                color: hasLocalNote
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                fontStyle:
                    hasLocalNote ? FontStyle.normal : FontStyle.italic,
              ),
            ),
          ),
        ],
      );
    } else if (tool == 'update_note') {
      final noteId = args['note_id']?.toString() ?? '';
      final proposedBody = args['body']?.toString() ?? '';
      final note = noteNotifier.getNoteById(noteId);

      if (note == null) {
        return Text(
          'Note is not on this device.',
          style: TextStyles.bodySecondary.copyWith(
            fontStyle: FontStyle.italic,
            fontSize: 13,
          ),
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            note.title.isNotEmpty ? note.title : 'Untitled Note',
            style: TextStyles.body.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current content:',
                  style: TextStyles.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  note.body.isNotEmpty ? note.body : '(empty)',
                  style: TextStyles.caption.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
                const Divider(height: 12, thickness: 0.5),
                Text(
                  'Proposed content:',
                  style: TextStyles.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  proposedBody.isNotEmpty ? proposedBody : '(empty)',
                  style: TextStyles.caption.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildFooter() {
    // If resolved as unavailable (not_found 404):
    if (confirmation.resolution == ConfirmationResolution.unavailable) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Row(
          children: [
            const Icon(CupertinoIcons.info, size: 14, color: AppColors.textSecondary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                confirmation.errorText ??
                    'This action is no longer available.',
                style: TextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // If resolved as executed, rejected, or unavailable:
    if (confirmation.resolution == ConfirmationResolution.executed ||
        confirmation.resolution == ConfirmationResolution.rejected ||
        confirmation.resolution == ConfirmationResolution.unavailable) {
      return const SizedBox.shrink();
    }

    final isConfirming =
        confirmation.resolution == ConfirmationResolution.confirming;
    final hasError = confirmation.resolution == ConfirmationResolution.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasError && confirmation.errorText != null) ...[
          Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.dangerSoft,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(
              children: [
                const Icon(CupertinoIcons.exclamationmark_triangle_fill,
                    size: 13, color: AppColors.danger),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    confirmation.errorText!,
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
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Semantics(
              button: true,
              label: 'Discard proposal',
              child: OutlinedButton(
                key: const ValueKey('agent_reject_button'),
                onPressed: isConfirming ? null : onReject,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  side: const BorderSide(color: AppColors.border, width: 0.5),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  minimumSize: const Size(80, 36),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
                child: const Text('Discard', style: TextStyle(fontSize: 13)),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Semantics(
              button: true,
              label: 'Approve proposal',
              child: FilledButton(
                key: const ValueKey('agent_approve_button'),
                onPressed: isConfirming ? null : onApprove,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  minimumSize: const Size(88, 36),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
                child: isConfirming
                    ? const CupertinoActivityIndicator(
                        radius: 7,
                        color: AppColors.onPrimary,
                      )
                    : const Text(
                        'Approve',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onPrimary,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
