import 'dart:io';
import 'package:cortex/core/database/app_database.dart';
import 'package:cortex/features/notes/data/repositories/drift_note_repository.dart';
import 'package:cortex/features/notes/domain/entities/note_entity.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DriftNoteRepository.restoreNote', () {
    late AppDatabase db;
    late Directory tempDir;
    late DriftNoteRepository repository;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      tempDir = Directory.systemTemp.createTempSync('cortex_restore_test');
      repository = DriftNoteRepository(db, tempDir);
    });

    tearDown(() async {
      await db.close();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('deleting a note marks deletedAt and titleDirty/bodyDirty', () async {
      final now = DateTime.now().toUtc();
      final note = NoteEntity(
        id: 'test-note-1',
        title: 'Original Title',
        body: 'Original Body',
        createdAt: now,
        updatedAt: now,
      );

      await repository.saveNote(note);
      await repository.deleteNote('test-note-1');

      final row = await (db.select(db.notes)..where((t) => t.id.equals('test-note-1')))
          .getSingle();
      expect(row.deletedAt, isNotNull);
      expect(row.titleDirty, isTrue);
      expect(row.bodyDirty, isTrue);

      final visible = await repository.watchAllNotes().first;
      expect(visible.any((n) => n.id == 'test-note-1'), isFalse);
    });

    test('restoreNote clears deletedAt, keeps dirty flags, and makes note visible again',
        () async {
      final now = DateTime.now().toUtc();
      final note = NoteEntity(
        id: 'test-note-2',
        title: 'Will Restore',
        body: 'Body to restore',
        createdAt: now,
        updatedAt: now,
      );

      await repository.saveNote(note);
      await repository.deleteNote('test-note-2');

      // Now restore it
      await repository.restoreNote('test-note-2');

      final row = await (db.select(db.notes)..where((t) => t.id.equals('test-note-2')))
          .getSingle();
      expect(row.deletedAt, isNull);
      expect(row.titleDirty, isTrue);
      expect(row.bodyDirty, isTrue);

      final visible = await repository.watchAllNotes().first;
      expect(visible.any((n) => n.id == 'test-note-2'), isTrue);
      expect(visible.firstWhere((n) => n.id == 'test-note-2').title, 'Will Restore');
    });

    test('restoreNote does nothing if note does not exist or is not deleted', () async {
      await repository.restoreNote('non-existent');

      final now = DateTime.now().toUtc();
      final note = NoteEntity(
        id: 'active-note',
        title: 'Active',
        body: 'Active Body',
        createdAt: now,
        updatedAt: now,
      );
      await repository.saveNote(note);
      await repository.restoreNote('active-note');

      final row = await (db.select(db.notes)..where((t) => t.id.equals('active-note')))
          .getSingle();
      expect(row.deletedAt, isNull);
    });
  });
}
