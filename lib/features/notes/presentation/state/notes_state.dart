import 'package:cortex/features/notes/domain/entities/note_entity.dart';

class NotePreview {
  final NoteEntity note;
  final List<Block> blocks;
  final String plainText;
  final String? firstImagePath;
  final List<CheckboxBlock> topTodos;

  const NotePreview({
    required this.note,
    required this.blocks,
    required this.plainText,
    this.firstImagePath,
    required this.topTodos,
  });
}

class NotesState {
  final List<NotePreview> notes;
  const NotesState({required this.notes});
}
