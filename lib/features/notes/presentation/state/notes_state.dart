import 'package:cortex/features/notes/domain/entities/note_entity.dart';
import 'package:cortex/features/notes/domain/entities/note_list_item.dart';
import 'package:cortex/features/notes/domain/entities/note_preview_data.dart';

class NotePreview extends NoteListItem {
  final List<Block> blocks;

  NotePreview({
    NoteEntity? note,
    String? id,
    String? title,
    String? previewText,
    String? plainText,
    String? firstImagePath,
    String? previewTodos,
    List<dynamic>? topTodos,
    super.rawCreatedAt,
    super.rawUpdatedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? conflictOf,
    String? conflictField,
    this.blocks = const [],
  }) : super(
          id: id ?? note?.id ?? '',
          title: title ?? note?.title ?? '',
          previewText: previewText ??
              plainText ??
              (blocks.isNotEmpty
                  ? blocks.whereType<TextBlock>().map((b) => b.data).join('\n')
                  : note?.title ?? ''),
          firstImagePath: firstImagePath ??
              (blocks.isNotEmpty
                  ? blocks.whereType<ImageBlock>().firstOrNull?.data
                  : null),
          previewTodos: previewTodos ?? '[]',
          topTodos: topTodos != null
              ? topTodos.map((t) {
                  if (t is PreviewTodoItem) return t;
                  if (t is CheckboxBlock) {
                    return PreviewTodoItem(text: t.data, isChecked: t.isChecked);
                  }
                  return PreviewTodoItem(text: t.toString(), isChecked: false);
                }).toList()
              : (blocks.isNotEmpty
                  ? blocks
                      .whereType<CheckboxBlock>()
                      .take(3)
                      .map((b) =>
                          PreviewTodoItem(text: b.data, isChecked: b.isChecked))
                      .toList()
                  : null),
          createdAt: createdAt ?? note?.createdAt,
          updatedAt: updatedAt ?? note?.updatedAt,
          conflictOf: conflictOf ?? note?.conflictOf,
          conflictField: conflictField ?? note?.conflictField,
        );
}

class NotesState {
  final List<NoteListItem> notes;
  const NotesState({required this.notes});
}
