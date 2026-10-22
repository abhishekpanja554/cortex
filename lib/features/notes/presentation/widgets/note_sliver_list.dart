import 'package:cortex/core/constants/colors.dart';
import 'package:cortex/core/constants/dimens.dart';
import 'package:cortex/core/navigation/note_routes.dart';
import 'package:cortex/core/theme/app_shapes.dart';
import 'package:cortex/features/notes/presentation/note_actions.dart';
import 'package:cortex/features/notes/presentation/state/notes_state.dart';
import 'package:cortex/features/notes/presentation/widgets/note_list_card.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Swipe-to-delete list of note cards, shared by the Notes and Search tabs.
class NoteSliverList extends StatelessWidget {
  final List<NotePreview> notes;
  final String searchQuery;

  const NoteSliverList({super.key, required this.notes, this.searchQuery = ''});

  @override
  Widget build(BuildContext context) {
    return SliverList.builder(
      itemCount: notes.length,
      itemBuilder: (context, index) {
        final preview = notes[index];
        final note = preview.note;
        void delete() => NoteActions.deleteWithUndo(
              container: ProviderScope.containerOf(context, listen: false),
              messenger: ScaffoldMessenger.of(context),
              note: note,
            );

        return Dismissible(
          key: ValueKey('note-${note.id}'),
          direction: DismissDirection.endToStart,
          background: Container(
            margin: const EdgeInsets.symmetric(
              horizontal: AppSpacing.page,
              vertical: AppSpacing.xs + 1,
            ),
            decoration: ShapeDecoration(
              color: AppColors.red,
              shape: AppShapes.continuous(AppRadius.xl),
            ),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: AppSpacing.xxl),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CupertinoIcons.trash_fill, color: Colors.white, size: 22),
                SizedBox(height: 4),
                Text(
                  'Delete',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          onDismissed: (_) => delete(),
          child: NoteListCard(
            preview: preview,
            searchQuery: searchQuery,
            onTap: () => NoteRoutes.open(context, note.id),
            onDelete: delete,
          ),
        );
      },
    );
  }
}
