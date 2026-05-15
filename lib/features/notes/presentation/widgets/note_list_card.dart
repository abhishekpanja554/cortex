import 'dart:io';
import 'dart:ui';

import 'package:cortex/core/constants/colors.dart';
import 'package:cortex/core/constants/text_styles.dart';
import 'package:cortex/features/notes/domain/entities/note.dart';
import 'package:flutter/material.dart';

class NoteListCard extends StatelessWidget {
  final Note note;
  final VoidCallback? onTap;
  final String searchQuery;

  const NoteListCard({super.key, required this.note, this.onTap, this.searchQuery = ''});

  @override
  Widget build(BuildContext context) {
    final todoBlocks = note.blocks
        .whereType<CheckboxBlock>()
        .take(3)
        .toList();

    return GestureDetector(
      onTap: onTap,
      child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.45),
                  Colors.white.withValues(alpha: 0.25),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.60),
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
                // Title row with more-options
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

                // Cover Image Thumbnail
                if (note.coverImage != null && note.coverImage!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      File(note.coverImage!),
                      width: double.infinity,
                      height: 140,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],

                // Todo items
                if (todoBlocks.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ...todoBlocks.map((block) => _buildTodoItem(block)),
                ],

                // Content text for non-todo notes
                if (todoBlocks.isEmpty && note.content.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _highlightSearchTerm(
                    note.content,
                    TextStyles.noteContentStyle,
                    maxLines: 2,
                  ),
                ],

                // Tags row + date
                if (note.tags.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      // Tags
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: note.tags
                              .map((tag) => _buildTag(tag))
                              .toList(),
                        ),
                      ),
                      // Date
                      Row(
                        mainAxisSize: MainAxisSize.min,
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
                ],
              ],
            ),
          ),
        ),
      ),
    ),
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
              color: block.isChecked ? AppColors.todoCheckbox.withValues(alpha: 0.08) : Colors.transparent,
            ),
            child: Icon(
              Icons.check_rounded,
              size: 14,
              color: block.isChecked ? AppColors.todoCheckbox : Colors.transparent,
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

  Widget _buildTag(String tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.tagBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.tagBorder, width: 0.8),
      ),
      child: Text(tag, style: TextStyles.tagStyle),
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

  Widget _highlightSearchTerm(String text, TextStyle baseStyle, {required int maxLines}) {
    if (searchQuery.isEmpty) {
      return Text(text, style: baseStyle, maxLines: maxLines, overflow: TextOverflow.ellipsis);
    }

    final String lowerText = text.toLowerCase();
    final String lowerQuery = searchQuery.toLowerCase();
    final int startIndex = lowerText.indexOf(lowerQuery);

    if (startIndex == -1) {
      return Text(text, style: baseStyle, maxLines: maxLines, overflow: TextOverflow.ellipsis);
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
