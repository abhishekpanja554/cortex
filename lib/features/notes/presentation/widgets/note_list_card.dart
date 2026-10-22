import 'package:cortex/core/constants/colors.dart';
import 'package:cortex/core/constants/dimens.dart';
import 'package:cortex/core/constants/string_constants.dart';
import 'package:cortex/core/constants/text_styles.dart';
import 'package:cortex/core/theme/liquid_glass.dart';
import 'package:cortex/core/utils/date_format.dart';
import 'package:cortex/features/notes/domain/entities/note_entity.dart';
import 'package:cortex/features/notes/presentation/state/notes_state.dart';
import 'package:cortex/features/notes/presentation/widgets/attachment_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Preview card shown on the Notes and Search tabs.
///
/// Pure presentation: navigation and deletion are passed in as callbacks so
/// the same card works everywhere (and in widget tests without a router).
class NoteListCard extends StatelessWidget {
  final NotePreview preview;
  final String searchQuery;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const NoteListCard({
    super.key,
    required this.preview,
    this.searchQuery = '',
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final note = preview.note;
    final allTodos = preview.blocks.whereType<CheckboxBlock>().toList();
    final todos = preview.topTodos;
    final doneCount = allTodos.where((t) => t.isChecked).length;
    final coverImage = preview.firstImagePath;
    final hasTitle = note.title.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.page,
        vertical: AppSpacing.xs + 1,
      ),
      // No backdrop blur per card: long lists stay smooth, and the rim and
      // sheen still read as glass over the ambient background.
      child: LiquidGlass.rounded(
        radius: AppRadius.xl,
        tint: AppColors.glassFillStrong,
        blur: 0,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg + 2,
                AppSpacing.md + 2,
                AppSpacing.xs,
                AppSpacing.md + 2,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (note.conflictOf != null) _ConflictBadge(field: note.conflictField),
                  Row(
                    children: [
                      Expanded(
                        child: hasTitle
                            ? _highlight(note.title, TextStyles.cardTitle, maxLines: 1)
                            : Text(
                                AppStrings.untitled,
                                style: TextStyles.cardTitle.copyWith(
                                  color: AppColors.textTertiary,
                                ),
                              ),
                      ),
                      if (onDelete != null)
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                          minimumSize: const Size(40, 32),
                          onPressed: () => _showActions(context),
                          child: const Icon(
                            CupertinoIcons.ellipsis,
                            size: 20,
                            color: AppColors.textSecondary,
                          ),
                        )
                      else
                        const SizedBox(height: 32, width: AppSpacing.md),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.md + 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (coverImage != null && coverImage.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(
                              top: AppSpacing.sm,
                              bottom: AppSpacing.sm,
                            ),
                            child: AttachmentImage(
                              path: coverImage,
                              height: 150,
                              borderRadius: AppRadius.lg - 4,
                              hideWhenMissing: true,
                            ),
                          ),
                        if (preview.plainText.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          _highlight(
                            preview.plainText,
                            TextStyles.bodySecondary,
                            maxLines: todos.isEmpty ? 3 : 2,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                        ],
                        ...todos.map(_buildTodoItem),
                        if (allTodos.length > todos.length)
                          Padding(
                            padding: const EdgeInsets.only(left: 30, bottom: 4),
                            child: Text(
                              '+${allTodos.length - todos.length} more',
                              style: TextStyles.caption,
                            ),
                          ),
                        const SizedBox(height: AppSpacing.xs),
                        Row(
                          children: [
                            Text(
                              AppDateFormat.relative(note.updatedAt),
                              style: TextStyles.caption,
                            ),
                            const Spacer(),
                            if (allTodos.isNotEmpty)
                              Text(
                                '$doneCount of ${allTodos.length} done',
                                style: TextStyles.caption,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showActions(BuildContext context) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: Text(
          preview.note.title.trim().isEmpty ? AppStrings.untitled : preview.note.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.of(sheetContext).pop();
              onDelete?.call();
            },
            child: const Text(AppStrings.deleteNote),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  Widget _buildTodoItem(CheckboxBlock block) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(
            block.isChecked
                ? CupertinoIcons.checkmark_circle_fill
                : CupertinoIcons.circle,
            size: 20,
            color: block.isChecked ? AppColors.primary : AppColors.textTertiary,
          ),
          const SizedBox(width: AppSpacing.sm + 2),
          Expanded(
            child: _highlight(
              block.data,
              TextStyles.bodySecondary.copyWith(
                color: block.isChecked ? AppColors.textSecondary : AppColors.textPrimary,
                decoration: block.isChecked ? TextDecoration.lineThrough : null,
              ),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _highlight(String text, TextStyle style, {required int maxLines}) {
    final query = searchQuery.trim();
    final start = query.isEmpty ? -1 : text.toLowerCase().indexOf(query.toLowerCase());
    if (start == -1) {
      return Text(text, style: style, maxLines: maxLines, overflow: TextOverflow.ellipsis);
    }
    final end = start + query.length;
    return RichText(
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: style,
        children: [
          TextSpan(text: text.substring(0, start)),
          TextSpan(
            text: text.substring(start, end),
            style: style.copyWith(
              backgroundColor: const Color(0x66FFD60A), // iOS find highlight
              color: AppColors.textPrimary,
            ),
          ),
          TextSpan(text: text.substring(end)),
        ],
      ),
    );
  }
}

class _ConflictBadge extends StatelessWidget {
  final String? field;
  const _ConflictBadge({required this.field});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: const ShapeDecoration(
        color: AppColors.warningSoft,
        shape: StadiumBorder(side: BorderSide(color: Color(0xFFFFB74D))),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.call_split_rounded, size: 13, color: AppColors.warning),
          const SizedBox(width: 4),
          Text(
            'Conflict: ${field ?? 'copy'}',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.warning,
            ),
          ),
        ],
      ),
    );
  }
}
