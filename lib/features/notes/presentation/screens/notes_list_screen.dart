import 'package:cortex/core/constants/string_constants.dart';
import 'package:cortex/core/constants/text_styles.dart';
import 'package:cortex/features/notes/presentation/providers/providers.dart';
import 'package:cortex/features/notes/presentation/widgets/note_list_card.dart';
import 'package:cortex/features/notes/presentation/widgets/profile_header.dart';
import 'package:cortex/features/notes/presentation/widgets/quick_action_grid.dart';
import 'package:cortex/features/notes/presentation/widgets/search_bar_widget.dart';
import 'package:cortex/features/sync/presentation/sync_orchestrator.dart';
import 'package:cortex/features/sync/presentation/sync_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NotesListScreen extends ConsumerStatefulWidget {
  const NotesListScreen({super.key});

  @override
  ConsumerState<NotesListScreen> createState() => _NotesListScreenState();
}

class _NotesListScreenState extends ConsumerState<NotesListScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final notesState = ref.watch(noteNotifierProvider);

    final filteredNotes = notesState.notes.where((preview) {
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      if (preview.note.title.toLowerCase().contains(query)) return true;
      if (preview.plainText.toLowerCase().contains(query)) return true;
      if (preview.blocks.any((b) => b.data.toLowerCase().contains(query))) {
        return true;
      }
      return false;
    }).toList();

    final sortedNotes = List.of(filteredNotes)
      ..sort((a, b) {
        return b.note.updatedAt.compareTo(a.note.updatedAt);
      });

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          final orchestrator = SyncOrchestrator.of(context);
          if (orchestrator != null) {
            await orchestrator.onPullToRefresh();
          } else {
            ref.read(syncSchedulerProvider).requestSync();
          }
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            const SliverToBoxAdapter(child: ProfileHeader()),

            SliverAppBar(
              pinned: true,
              primary: false,
              elevation: 0,
              scrolledUnderElevation: 4,
              shadowColor: Colors.black.withValues(alpha: 0.2),
              backgroundColor: const Color(0xFFF6FAFE),
              surfaceTintColor: Colors.transparent,
              automaticallyImplyLeading: false,
              titleSpacing: 0,
              toolbarHeight: 64,
              title: SearchBarWidget(
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ),

            const SliverToBoxAdapter(child: QuickActionGrid()),

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
                final preview = sortedNotes[index];
                final note = preview.note;
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
                    ref.read(syncSchedulerProvider).requestSync();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Note deleted'),
                        behavior: SnackBarBehavior.floating,
                        action: SnackBarAction(
                          label: 'Undo',
                          onPressed: () {
                            ref.read(noteNotifierProvider.notifier).addNote(note);
                            ref.read(syncSchedulerProvider).requestSync();
                          },
                        ),
                      ),
                    );
                  },
                  child: NoteListCard(
                    preview: preview,
                    searchQuery: _searchQuery,
                  ),
                );
              },
            ),

            const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
          ],
        ),
      ),
    );
  }
}
