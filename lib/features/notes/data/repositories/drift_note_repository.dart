import 'dart:io';
import 'package:cortex/core/database/app_database.dart';
import 'package:cortex/features/notes/domain/entities/note_entity.dart';
import 'package:cortex/features/notes/domain/repositories/note_repository.dart';
import 'package:drift/drift.dart';

class DriftNoteRepository implements NoteRepository {
  DriftNoteRepository(this._db, this._docsDir);
  final AppDatabase _db;
  final Directory _docsDir;

  @override
  Future<void> saveNote(NoteEntity note) {
    return _db.transaction(() async {
      final res = await (_db.select(
        _db.notes,
      )..where((t) => t.id.equals(note.id))).getSingleOrNull();
      if (res == null) {
        await _db
            .into(_db.notes)
            .insert(
              Note(
                id: note.id,
                title: note.title,
                body: note.body,
                createdAt: note.createdAt.toUtc(),
                updatedAt: DateTime.now().toUtc(),
                titleDirty: true,
                bodyDirty: true,
                localRevision: 1,
                conflictField: note.conflictField,
              ),
            );
        return;
      }
      if (res.deletedAt != null) {
        return;
      }
      if (res.title == note.title && res.body == note.body) {
        return;
      }

      final isTitleChanged = res.title != note.title;
      final isBodyChanged = res.body != note.body;

      await (_db.update(_db.notes)..where((t) => t.id.equals(note.id))).write(
        NotesCompanion(
          title: Value(note.title),
          body: Value(note.body),
          updatedAt: Value(DateTime.now().toUtc()),
          titleDirty: Value(res.titleDirty || isTitleChanged),
          bodyDirty: Value(res.bodyDirty || isBodyChanged),
          localRevision: Value(res.localRevision + 1),
          conflictField: Value(note.conflictField),
        ),
      );
    });
  }

  @override
  Stream<List<NoteEntity>> watchAllNotes() {
    final query = _db.select(_db.notes)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([
        (t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc),
      ]);

    return query.watch().map((driftNotes) {
      return driftNotes
          .map(
            (note) => NoteEntity(
              id: note.id,
              title: note.title,
              body: note.body,
              createdAt: note.createdAt,
              updatedAt: note.updatedAt,
              conflictOf: note.conflictOf,
              conflictField: note.conflictField,
            ),
          )
          .toList();
    });
  }

  @override
  Future<void> deleteNote(String id) {
    return _db.transaction(() async {
      final res = await (_db.select(
        _db.notes,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (res == null || res.deletedAt != null) {
        return;
      }
      await (_db.update(_db.notes)..where((t) => t.id.equals(id))).write(
        NotesCompanion(
          deletedAt: Value(DateTime.now().toUtc()),
          updatedAt: Value(DateTime.now().toUtc()),
          titleDirty: const Value(true),
          bodyDirty: const Value(true),
          localRevision: Value(res.localRevision + 1),
        ),
      );
    });
  }

  @override
  Future<void> wipeAll() async {
    await _db.delete(_db.notes).go();
    await _db.delete(_db.syncState).go();
    final attachmentsDir = Directory('${_docsDir.path}/attachments');
    if (await attachmentsDir.exists()) {
      await attachmentsDir.delete(recursive: true);
    }
  }

  @override
  Future<int> unsyncedCount() async {
    final countExp = _db.notes.id.count();
    final query = _db.selectOnly(_db.notes)
      ..addColumns([countExp])
      ..where(
        _db.notes.titleDirty.equals(true) | _db.notes.bodyDirty.equals(true),
      );
    final result = await query.getSingle();
    return result.read(countExp) ?? 0;
  }
}
