import 'package:cortex/core/database/app_database.dart';
import 'package:cortex/features/notes/domain/entities/note_entity.dart';
import 'package:cortex/features/notes/domain/repositories/note_repository.dart';
import 'package:drift/drift.dart';

class DriftNoteRepository implements NoteRepository {
  DriftNoteRepository(this._db);
  final AppDatabase _db;

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
                isDirty: true,
                localRevision: 1,
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
      await (_db.update(_db.notes)..where((t) => t.id.equals(note.id))).write(
        NotesCompanion(
          title: Value(note.title),
          body: Value(note.body),
          updatedAt: Value(DateTime.now().toUtc()),
          isDirty: const Value(true),
          localRevision: Value(res.localRevision + 1),
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
          isDirty: const Value(true),
          localRevision: Value(res.localRevision + 1),
        ),
      );
    });
  }
}
