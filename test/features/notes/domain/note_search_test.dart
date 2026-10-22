import 'package:cortex/features/notes/domain/entities/note_entity.dart';
import 'package:cortex/features/notes/domain/note_search.dart';
import 'package:cortex/features/notes/presentation/state/notes_state.dart';
import 'package:flutter_test/flutter_test.dart';

NotePreview _preview(String id, {String title = '', List<Block> blocks = const [], int minute = 0}) {
  final time = DateTime.utc(2026, 10, 22, 10, minute);
  return NotePreview(
    note: NoteEntity(id: id, title: title, body: '', createdAt: time, updatedAt: time),
    blocks: blocks,
    plainText: blocks.whereType<TextBlock>().map((b) => b.data).join('\n'),
    topTodos: blocks.whereType<CheckboxBlock>().take(3).toList(),
  );
}

void main() {
  final notes = [
    _preview('a', title: 'Groceries', blocks: [const Block.checkbox(id: '1', data: 'Buy milk')], minute: 1),
    _preview('b', title: 'Ideas', blocks: [const Block.text(id: '2', data: 'Improve the UI')], minute: 3),
    _preview('c', title: 'Photo', blocks: [const Block.image(id: '3', data: 'attachments/milk.jpg')], minute: 2),
  ];

  test('empty query returns everything, newest first', () {
    expect(searchNotes(notes, '  ').map((n) => n.note.id), ['b', 'c', 'a']);
  });

  test('matches titles case-insensitively', () {
    expect(searchNotes(notes, 'groc').map((n) => n.note.id), ['a']);
  });

  test('matches checklist items and text, but not image paths', () {
    expect(searchNotes(notes, 'milk').map((n) => n.note.id), ['a']);
    expect(searchNotes(notes, 'ui').map((n) => n.note.id), ['b']);
  });
}
