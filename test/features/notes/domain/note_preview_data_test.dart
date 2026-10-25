import 'dart:convert';
import 'package:cortex/features/notes/domain/entities/note_entity.dart';
import 'package:cortex/features/notes/domain/entities/note_list_item.dart';
import 'package:cortex/features/notes/domain/entities/note_preview_data.dart';
import 'package:cortex/features/notes/domain/note_body_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const codec = NoteBodyCodec();

  group('computePreview', () {
    test('handles empty body', () {
      final preview = computePreview('');
      expect(preview.previewText, '');
      expect(preview.firstImagePath, isNull);
      expect(preview.previewTodos, '[]');
      expect(preview.topTodos, isEmpty);
    });

    test('truncates plain text at 160 characters', () {
      final longText = 'A' * 250;
      final body = codec.serialize([TextBlock(id: '1', data: longText)]);
      final preview = computePreview(body);

      expect(preview.previewText.length, 160);
      expect(preview.previewText, 'A' * 160);
      expect(preview.firstImagePath, isNull);
      expect(preview.previewTodos, '[]');
    });

    test('preserves plain text shorter than 160 characters', () {
      final shortText = 'Short note description.';
      final body = codec.serialize([TextBlock(id: '1', data: shortText)]);
      final preview = computePreview(body);

      expect(preview.previewText, shortText);
    });

    test('extracts only the first image path', () {
      final body = codec.serialize([
        TextBlock(id: '1', data: 'Intro text'),
        ImageBlock(id: '2', data: 'attachments/image_1.jpg'),
        ImageBlock(id: '3', data: 'attachments/image_2.jpg'),
      ]);
      final preview = computePreview(body);

      expect(preview.firstImagePath, 'attachments/image_1.jpg');
    });

    test('extracts up to 3 checkbox items and serializes to JSON', () {
      final body = codec.serialize([
        TextBlock(id: '1', data: 'Tasks for today'),
        CheckboxBlock(id: '2', data: 'First item', isChecked: true),
        CheckboxBlock(id: '3', data: 'Second item', isChecked: false),
        CheckboxBlock(id: '4', data: 'Third item', isChecked: true),
        CheckboxBlock(id: '5', data: 'Fourth item', isChecked: false),
      ]);
      final preview = computePreview(body);

      expect(preview.previewText, 'Tasks for today');
      expect(preview.topTodos.length, 3);
      expect(preview.topTodos[0].text, 'First item');
      expect(preview.topTodos[0].isChecked, isTrue);
      expect(preview.topTodos[1].text, 'Second item');
      expect(preview.topTodos[1].isChecked, isFalse);
      expect(preview.topTodos[2].text, 'Third item');
      expect(preview.topTodos[2].isChecked, isTrue);

      final decoded = jsonDecode(preview.previewTodos) as List<dynamic>;
      expect(decoded.length, 3);
      expect(decoded[0], {'text': 'First item', 'checked': true});
      expect(decoded[1], {'text': 'Second item', 'checked': false});
      expect(decoded[2], {'text': 'Third item', 'checked': true});
    });

    test('PreviewTodoItem JSON round trip', () {
      const item = PreviewTodoItem(text: 'Buy coffee', isChecked: true);
      final json = item.toJson();
      final fromJson = PreviewTodoItem.fromJson(json);
      expect(fromJson, item);
    });

    test('NoteListItem lazily evaluates topTodos', () {
      final item = NoteListItem(
        id: '1',
        title: 'Title',
        previewText: 'Preview',
        previewTodos: '[{"text":"Task A","checked":true}]',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Accessing topTodos parses correctly on demand
      expect(item.topTodos.length, 1);
      expect(item.topTodos.first.text, 'Task A');
      expect(item.topTodos.first.isChecked, isTrue);
    });

    test('NoteListItem stores rawCreatedAt and rawUpdatedAt as raw strings and parses lazily', () {
      const isoCreated = '2026-05-10T14:30:00.000Z';
      const isoUpdated = '2026-05-10T16:45:00.000Z';

      final item1 = NoteListItem(
        id: 'note-1',
        title: 'Title 1',
        previewText: 'Preview 1',
        previewTodos: '[]',
        rawCreatedAt: isoCreated,
        rawUpdatedAt: isoUpdated,
      );

      final item2 = NoteListItem(
        id: 'note-1',
        title: 'Title 1',
        previewText: 'Preview 1',
        previewTodos: '[]',
        rawCreatedAt: isoCreated,
        rawUpdatedAt: isoUpdated,
      );

      // Raw strings match directly
      expect(item1.rawCreatedAt, isoCreated);
      expect(item1.rawUpdatedAt, isoUpdated);

      // Equality compares raw strings directly without evaluating DateTime
      expect(item1 == item2, isTrue);
      expect(item1.hashCode, item2.hashCode);

      // Lazy getters accurately parse ISO string
      expect(item1.createdAt, DateTime.utc(2026, 5, 10, 14, 30));
      expect(item1.updatedAt, DateTime.utc(2026, 5, 10, 16, 45));
    });
  });
}
