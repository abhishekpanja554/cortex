import 'package:cortex/core/constants/string_constants.dart';
import 'package:cortex/core/constants/text_styles.dart';
import 'package:cortex/features/notes/presentation/providers/providers.dart';
import 'package:cortex/features/notes/presentation/screens/edit_note_screen.dart';
import 'package:cortex/features/notes/presentation/widgets/note_list_card.dart';
import 'package:cortex/features/notes/presentation/widgets/profile_header.dart';
import 'package:cortex/features/notes/presentation/widgets/quick_action_grid.dart';
import 'package:cortex/features/notes/presentation/widgets/search_bar_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NotesListScreen extends ConsumerStatefulWidget {
  const NotesListScreen({super.key});

  @override
  ConsumerState<NotesListScreen> createState() => _NotesListScreenState();
}

class _NotesListScreenState extends ConsumerState<NotesListScreen> {
  String _searchQuery = '';

  void _navigateToCreateNote() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const EditNoteScreen()));
  }

  void _navigateToEditNote(String noteId) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => EditNoteScreen(noteId: noteId)));
  }

  @override
  Widget build(BuildContext context) {
    final notesState = ref.watch(noteNotifierProvider);

    final filteredNotes = notesState.notes.where((note) {
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      if (note.title.toLowerCase().contains(query)) return true;
      if (note.content.toLowerCase().contains(query)) return true;
      if (note.blocks.any((b) => b.data.toLowerCase().contains(query)))
        return true;
      return false;
    }).toList();

    // Sort notes: most recently updated or created first
    final sortedNotes = List.of(filteredNotes)
      ..sort((a, b) {
        final aDate = a.updatedAt ?? a.createdAt;
        final bDate = b.updatedAt ?? b.createdAt;
        return bDate.compareTo(aDate);
      });

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: ProfileHeader()),

          SliverToBoxAdapter(
            child: SearchBarWidget(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),

          SliverToBoxAdapter(
            child: QuickActionGrid(onTextNoteTap: _navigateToCreateNote),
          ),

          // "Recent Notes" section title
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                AppStrings.recentNotes,
                style: TextStyles.sectionHeaderStyle,
              ),
            ),
          ),

          SliverList.builder(
            itemCount: sortedNotes.length,
            itemBuilder: (context, index) {
              final note = sortedNotes[index];
              return Dismissible(
                key: ValueKey(note.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Icon(
                    Icons.delete_outline,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                onDismissed: (_) {
                  ref.read(noteNotifierProvider.notifier).deleteNote(note.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Note deleted'),
                      behavior: SnackBarBehavior.floating,
                      action: SnackBarAction(
                        label: 'Undo',
                        onPressed: () {
                          ref.read(noteNotifierProvider.notifier).addNote(note);
                        },
                      ),
                    ),
                  );
                },
                child: NoteListCard(
                  note: note,
                  searchQuery: _searchQuery,
                  onTap: () => _navigateToEditNote(note.id),
                ),
              );
            },
          ),

          const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
        ],
      ),
    );
  }
}
