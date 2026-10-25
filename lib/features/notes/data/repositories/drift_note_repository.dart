import 'dart:io';
import 'package:clock/clock.dart';
import 'package:cortex/core/database/app_database.dart';
import 'package:cortex/core/perf/perf.dart';
import 'package:cortex/features/notes/domain/entities/note_entity.dart';
import 'package:cortex/features/notes/domain/entities/note_list_item.dart';
import 'package:cortex/features/notes/domain/entities/note_preview_data.dart';
import 'package:cortex/features/notes/domain/repositories/note_repository.dart';
import 'package:drift/drift.dart';

class DriftNoteRepository implements NoteRepository {
  DriftNoteRepository(this._db, this._docsDir);
  final AppDatabase _db;
  final Directory _docsDir;

  @override
  Future<void> saveNote(NoteEntity note) {
    return Perf.measureAsync('notes.saveNote', () {
      return _db.transaction(() async {
        final res = await (_db.select(
          _db.notes,
        )..where((t) => t.id.equals(note.id))).getSingleOrNull();

        final preview = computePreview(note.body);

        if (res == null) {
          await _db.into(_db.notes).insert(
                NotesCompanion.insert(
                  id: Value(note.id),
                  title: Value(note.title),
                  body: Value(note.body),
                  previewText: Value(preview.previewText),
                  firstImagePath: Value(preview.firstImagePath),
                  previewTodos: Value(preview.previewTodos),
                  createdAt: Value(note.createdAt.toUtc()),
                  updatedAt: Value(clock.now().toUtc()),
                  titleDirty: const Value(true),
                  bodyDirty: const Value(true),
                  localRevision: const Value(1),
                  conflictOf: Value(note.conflictOf),
                  conflictField: Value(note.conflictField),
                ),
              );
          return;
        }
        if (res.deletedAt != null) {
          return;
        }
        if (res.title == note.title &&
            res.body == note.body &&
            res.conflictOf == note.conflictOf &&
            res.conflictField == note.conflictField) {
          return;
        }

        final isTitleChanged = res.title != note.title;
        final isBodyChanged = res.body != note.body;

        await (_db.update(_db.notes)..where((t) => t.id.equals(note.id))).write(
          NotesCompanion(
            title: Value(note.title),
            body: Value(note.body),
            previewText: Value(preview.previewText),
            firstImagePath: Value(preview.firstImagePath),
            previewTodos: Value(preview.previewTodos),
            updatedAt: Value(clock.now().toUtc()),
            titleDirty: Value(res.titleDirty || isTitleChanged),
            bodyDirty: Value(res.bodyDirty || isBodyChanged),
            localRevision: Value(res.localRevision + 1),
            conflictOf: Value(note.conflictOf),
            conflictField: Value(note.conflictField),
          ),
        );
      });
    });
  }

  @override
  Stream<List<NoteListItem>> watchAllNotes() {
    final query = _db.selectOnly(_db.notes)
      ..addColumns([
        _db.notes.id,
        _db.notes.title,
        _db.notes.previewText,
        _db.notes.firstImagePath,
        _db.notes.previewTodos,
        _db.notes.createdAt,
        _db.notes.updatedAt,
        _db.notes.conflictOf,
        _db.notes.conflictField,
      ])
      ..where(_db.notes.deletedAt.isNull())
      ..orderBy([
        OrderingTerm(expression: _db.notes.updatedAt, mode: OrderingMode.desc),
      ]);

    return query.watch().map((rows) {
      return Perf.measure(
        'notes.mapRows',
        () => rows.map((row) {
          final data = row.rawData.data;
          return NoteListItem(
            id: row.read(_db.notes.id)!,
            title: row.read(_db.notes.title)!,
            previewText: row.read(_db.notes.previewText)!,
            firstImagePath: row.read(_db.notes.firstImagePath),
            previewTodos: row.read(_db.notes.previewTodos)!,
            rawCreatedAt: (data['notes.created_at'] ?? data['created_at'])?.toString() ?? '',
            rawUpdatedAt: (data['notes.updated_at'] ?? data['updated_at'])?.toString() ?? '',
            conflictOf: row.read(_db.notes.conflictOf),
            conflictField: row.read(_db.notes.conflictField),
          );
        }).toList(),
        count: rows.length,
      );
    });
  }

  @override
  Future<NoteEntity?> getNote(String id) async {
    final row = await (_db.select(
      _db.notes,
    )..where((t) => t.id.equals(id))).getSingleOrNull();

    if (row == null) return null;
    return NoteEntity(
      id: row.id,
      title: row.title,
      body: row.body,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      conflictOf: row.conflictOf,
      conflictField: row.conflictField,
    );
  }

  @override
  Stream<NoteEntity?> watchNote(String id) {
    final query = _db.select(_db.notes)..where((t) => t.id.equals(id));
    return query.watchSingleOrNull().map((row) {
      if (row == null) return null;
      return NoteEntity(
        id: row.id,
        title: row.title,
        body: row.body,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
        conflictOf: row.conflictOf,
        conflictField: row.conflictField,
      );
    });
  }

  @override
  Future<List<NoteListItem>> searchNotes(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      final rows = await (_db.selectOnly(_db.notes)
            ..addColumns([
              _db.notes.id,
              _db.notes.title,
              _db.notes.previewText,
              _db.notes.firstImagePath,
              _db.notes.previewTodos,
              _db.notes.createdAt,
              _db.notes.updatedAt,
              _db.notes.conflictOf,
              _db.notes.conflictField,
            ])
            ..where(_db.notes.deletedAt.isNull())
            ..orderBy([
              OrderingTerm(
                expression: _db.notes.updatedAt,
                mode: OrderingMode.desc,
              ),
            ]))
          .get();

      return rows.map((row) {
        final data = row.rawData.data;
        return NoteListItem(
          id: row.read(_db.notes.id)!,
          title: row.read(_db.notes.title)!,
          previewText: row.read(_db.notes.previewText)!,
          firstImagePath: row.read(_db.notes.firstImagePath),
          previewTodos: row.read(_db.notes.previewTodos)!,
          rawCreatedAt: (data['notes.created_at'] ?? data['created_at'])?.toString() ?? '',
          rawUpdatedAt: (data['notes.updated_at'] ?? data['updated_at'])?.toString() ?? '',
          conflictOf: row.read(_db.notes.conflictOf),
          conflictField: row.read(_db.notes.conflictField),
        );
      }).toList();
    }

    return Perf.measureAsync('search.sqlLike', () async {
      final escaped = trimmed
          .replaceAll(r'\', r'\\')
          .replaceAll('%', r'\%')
          .replaceAll('_', r'\_');
      final likePattern = '%$escaped%';

      final q = _db.selectOnly(_db.notes)
        ..addColumns([
          _db.notes.id,
          _db.notes.title,
          _db.notes.previewText,
          _db.notes.firstImagePath,
          _db.notes.previewTodos,
          _db.notes.createdAt,
          _db.notes.updatedAt,
          _db.notes.conflictOf,
          _db.notes.conflictField,
        ])
        ..where(
          _db.notes.deletedAt.isNull() &
              (_db.notes.title.like(likePattern, escapeChar: r'\') |
                  _db.notes.body.like(likePattern, escapeChar: r'\')),
        )
        ..orderBy([
          OrderingTerm(
            expression: _db.notes.updatedAt,
            mode: OrderingMode.desc,
          ),
        ]);

      final rows = await q.get();
      return rows.map((row) {
        final data = row.rawData.data;
        return NoteListItem(
          id: row.read(_db.notes.id)!,
          title: row.read(_db.notes.title)!,
          previewText: row.read(_db.notes.previewText)!,
          firstImagePath: row.read(_db.notes.firstImagePath),
          previewTodos: row.read(_db.notes.previewTodos)!,
          rawCreatedAt: (data['notes.created_at'] ?? data['created_at'])?.toString() ?? '',
          rawUpdatedAt: (data['notes.updated_at'] ?? data['updated_at'])?.toString() ?? '',
          conflictOf: row.read(_db.notes.conflictOf),
          conflictField: row.read(_db.notes.conflictField),
        );
      }).toList();
    });
  }

  @override
  Future<void> deleteNote(String id) {
    return Perf.measureAsync('notes.softDelete', () {
      return _db.transaction(() async {
        final res = await (_db.select(
          _db.notes,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        if (res == null || res.deletedAt != null) {
          return;
        }
        await (_db.update(_db.notes)..where((t) => t.id.equals(id))).write(
          NotesCompanion(
            deletedAt: Value(clock.now().toUtc()),
            updatedAt: Value(clock.now().toUtc()),
            titleDirty: const Value(true),
            bodyDirty: const Value(true),
            localRevision: Value(res.localRevision + 1),
          ),
        );
      });
    });
  }

  @override
  Future<void> restoreNote(String id) {
    return Perf.measureAsync('notes.restore', () {
      return _db.transaction(() async {
        final res = await (_db.select(
          _db.notes,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        if (res == null || res.deletedAt == null) {
          return;
        }
        await (_db.update(_db.notes)..where((t) => t.id.equals(id))).write(
          NotesCompanion(
            deletedAt: const Value(null),
            updatedAt: Value(clock.now().toUtc()),
            titleDirty: const Value(true),
            bodyDirty: const Value(true),
            localRevision: Value(res.localRevision + 1),
          ),
        );
      });
    });
  }

  @override
  Future<void> wipeAll() {
    return Perf.measureAsync('notes.wipeAll', () async {
      await _db.delete(_db.notes).go();
      await _db.delete(_db.syncState).go();
      final attachmentsDir = Directory('${_docsDir.path}/attachments');
      if (await attachmentsDir.exists()) {
        await attachmentsDir.delete(recursive: true);
      }
    });
  }

  @override
  Future<int> unsyncedCount() {
    return Perf.measureAsync('notes.unsyncedCount', () async {
      final countExp = _db.notes.id.count();
      final query = _db.selectOnly(_db.notes)
        ..addColumns([countExp])
        ..where(
          _db.notes.titleDirty.equals(true) | _db.notes.bodyDirty.equals(true),
        );
      final result = await query.getSingle();
      return result.read(countExp) ?? 0;
    });
  }

  @override
  Future<List<NoteEntity>> getAllNotesForExport() async {
    final rows = await (_db.select(_db.notes)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([
            (t) => OrderingTerm(
                  expression: t.updatedAt,
                  mode: OrderingMode.desc,
                ),
          ]))
        .get();

    return rows
        .map((row) => NoteEntity(
              id: row.id,
              title: row.title,
              body: row.body,
              createdAt: row.createdAt,
              updatedAt: row.updatedAt,
              conflictOf: row.conflictOf,
              conflictField: row.conflictField,
            ))
        .toList();
  }
}