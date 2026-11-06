import 'package:cortex/core/perf/perf.dart';
import 'package:cortex/features/notes/domain/entities/note_list_item.dart';

/// Case-insensitive match on title, text and checklist items, newest first.
List<NoteListItem> searchNotes(List<NoteListItem> notes, String query) {
  final q = query.trim().toLowerCase();

  return Perf.measure('search.filterSort', () {
    final matches = q.isEmpty
        ? List<NoteListItem>.of(notes)
        : notes.where((note) {
            if (note.title.toLowerCase().contains(q)) return true;
            if (note.previewText.toLowerCase().contains(q)) return true;
            return note.topTodos.any(
              (t) => t.text.toLowerCase().contains(q),
            );
          }).toList();

    matches.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return matches;
  }, count: notes.length);
}
