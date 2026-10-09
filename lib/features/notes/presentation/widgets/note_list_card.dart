
import 'package:animations/animations.dart';
import 'package:cortex/core/constants/colors.dart';
import 'package:cortex/core/constants/text_styles.dart';
import 'package:cortex/features/notes/presentation/state/notes_state.dart';
import 'package:cortex/features/notes/domain/entities/note_entity.dart';
import 'package:cortex/features/notes/presentation/screens/edit_note_screen.dart';
import 'package:cortex/features/notes/presentation/widgets/attachment_image.dart';
import 'package:flutter/material.dart';

class NoteListCard extends StatelessWidget {
  final NotePreview preview;
  final String searchQuery;

  const NoteListCard({super.key, required this.preview, this.searchQuery = ''});

  @override
  Widget build(BuildContext context) {
    final note = preview.note;
    final todoBlocks = preview.topTodos;
    final coverImage = preview.firstImagePath;

    return OpenContainer(
      transitionType: ContainerTransitionType.fadeThrough,
      openBuilder: (context, _) => EditNoteScreen(noteId: note.id),
      closedElevation: 0,
      closedShape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      closedColor: Colors.transparent,
      openColor: AppColors.searchBarBackground,
      middleColor: AppColors.searchBarBackground,
      transitionDuration: const Duration(milliseconds: 500),
      closedBuilder: (context, openContainer) {
        return GestureDetector(
          onTap: openContainer,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.90),
                    Colors.white.withValues(alpha: 0.82),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.65),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 20,
                    spreadRadius: 1,
                    offset: const Offset(0, 6),
                  ),
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.50),
                    blurRadius: 1,
                    spreadRadius: 0,
                    offset: const Offset(-1, -1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _highlightSearchTerm(
                          note.title,
                          TextStyles.noteTitleStyle,
                          maxLines: 1,
                        ),
                      ),
                      const Icon(
                        Icons.more_vert_rounded,
                        color: AppColors.iconDefault,
                        size: 22,
                      ),
                    ],
                  ),

                  if (coverImage != null && coverImage.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: double.infinity,
                        height: 140,
                        child: AttachmentImage(
                          path: coverImage,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ],

                  if (todoBlocks.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ...todoBlocks.map((block) => _buildTodoItem(block)),
                  ],

                  if (todoBlocks.isEmpty && preview.plainText.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _highlightSearchTerm(
                      preview.plainText,
                      TextStyles.noteContentStyle,
                      maxLines: 2,
                    ),
                  ],

                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatRelativeDate(note.createdAt),
                        style: TextStyles.dateStyle,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTodoItem(CheckboxBlock block) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: AppColors.todoCheckbox, width: 1.8),
              color: block.isChecked
                  ? AppColors.todoCheckbox.withValues(alpha: 0.08)
                  : Colors.transparent,
            ),
            child: Icon(
              Icons.check_rounded,
              size: 14,
              color: block.isChecked
                  ? AppColors.todoCheckbox
                  : Colors.transparent,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _highlightSearchTerm(
              block.data,
              TextStyles.todoItemStyle,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  String _formatRelativeDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return '1 Day Ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} Days Ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks Week${weeks > 1 ? 's' : ''} Ago';
    } else {
      final months = (difference.inDays / 30).floor();
      return '$months Month${months > 1 ? 's' : ''} Ago';
    }
  }

  Widget _highlightSearchTerm(
    String text,
    TextStyle baseStyle, {
    required int maxLines,
  }) {
    if (searchQuery.isEmpty) {
      return Text(
        text,
        style: baseStyle,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
      );
    }

    final String lowerText = text.toLowerCase();
    final String lowerQuery = searchQuery.toLowerCase();
    final int startIndex = lowerText.indexOf(lowerQuery);

    if (startIndex == -1) {
      return Text(
        text,
        style: baseStyle,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
      );
    }

    return RichText(
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: baseStyle,
        children: [
          TextSpan(text: text.substring(0, startIndex)),
          TextSpan(
            text: text.substring(startIndex, startIndex + searchQuery.length),
            style: baseStyle.copyWith(
              backgroundColor: AppColors.primary.withValues(alpha: 0.3),
              color: AppColors.textPrimary,
            ),
          ),
          TextSpan(text: text.substring(startIndex + searchQuery.length)),
        ],
      ),
    );
  }
}
