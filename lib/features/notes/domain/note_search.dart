import 'package:cortex/features/notes/domain/entities/note_entity.dart';
import 'package:cortex/features/notes/presentation/state/notes_state.dart';

/// Case-insensitive match on title, text and checklist items, newest first.
List<NotePreview> searchNotes(List<NotePreview> notes, String query) {
  final q = query.trim().toLowerCase();
  final matches = q.isEmpty
      ? List<NotePreview>.of(notes)
      : notes.where((preview) {
          if (preview.note.title.toLowerCase().contains(q)) return true;
          if (preview.plainText.toLowerCase().contains(q)) return true;
          return preview.blocks.any(
            (b) => b is! ImageBlock && b.data.toLowerCase().contains(q),
          );
        }).toList();
  matches.sort((a, b) => b.note.updatedAt.compareTo(a.note.updatedAt));
  return matches;
}
