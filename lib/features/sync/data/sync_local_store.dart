import 'package:cortex/core/database/app_database.dart';
import 'package:cortex/features/sync/data/sync_api.dart';
import 'package:drift/drift.dart';

/// Works directly on AppDatabase for per-note sync transactions.
class SyncLocalStore {
  final AppDatabase _db;

  SyncLocalStore(this._db);

  // Notes with local uncommitted edits
  Future<List<Note>> getDirtyNotes() async {
    final query = _db.select(_db.notes)
      ..where((t) => t.titleDirty.equals(true) | t.bodyDirty.equals(true));
    return query.get();
  }

  // Pagination cursor
  Future<String?> getCursor() async {
    final row = await (_db.select(
      _db.syncState,
    )..where((t) => t.key.equals('singleton'))).getSingleOrNull();
    return row?.nextSince;
  }

  Future<void> saveCursor(String nextSince) async {
    await _db
        .into(_db.syncState)
        .insertOnConflictUpdate(
          SyncStateCompanion(
            key: const Value('singleton'),
            nextSince: Value(nextSince),
          ),
        );
  }

  // Apply server push responses to local rows per field outcome
  Future<void> applyPushResult(
    PushNoteResult result, {
    required String? sentTitle,
    required String? sentBody,
  }) async {
    await _db.transaction(() async {
      // Tombstone confirmed by server: drop local row
      if (result.deleted) {
        await (_db.delete(
          _db.notes,
        )..where((t) => t.id.equals(result.id))).go();
        return;
      }

      final row = await (_db.select(
        _db.notes,
      )..where((t) => t.id.equals(result.id))).getSingleOrNull();
      if (row == null) return;

      // Handle title outcome
      String? newServerTitleStamp = row.serverTitleUpdatedAt;
      bool newTitleDirty = row.titleDirty;

      if (result.titleOutcome != null) {
        switch (result.titleOutcome!) {
          case PushOutcome.accepted:
          case PushOutcome.rejectedStale:
            // Device content matches server: adopt stamp, clear dirty unless user edited in-flight
            newServerTitleStamp =
                result.titleUpdatedAt ?? row.serverTitleUpdatedAt;
            newTitleDirty = (sentTitle != null && row.title != sentTitle);
          case PushOutcome.conflict:
            // Keep old stamp. Clear dirty if untouched so upcoming pull can overwrite
            newTitleDirty = (sentTitle != null && row.title != sentTitle);
          case PushOutcome.rejectedDeleted:
            await (_db.delete(_db.notes)..where((t) => t.id.equals(result.id))).go();
            return;
        }
      }

      // Handle body outcome
      String? newServerBodyStamp = row.serverBodyUpdatedAt;
      bool newBodyDirty = row.bodyDirty;

      if (result.bodyOutcome != null) {
        switch (result.bodyOutcome!) {
          case PushOutcome.accepted:
          case PushOutcome.rejectedStale:
            newServerBodyStamp =
                result.bodyUpdatedAt ?? row.serverBodyUpdatedAt;
            newBodyDirty = (sentBody != null && row.body != sentBody);
          case PushOutcome.conflict:
            newBodyDirty = (sentBody != null && row.body != sentBody);
          case PushOutcome.rejectedDeleted:
            await (_db.delete(_db.notes)..where((t) => t.id.equals(result.id))).go();
            return;
        }
      }

      await (_db.update(
        _db.notes,
      )..where((t) => t.id.equals(result.id))).write(
        NotesCompanion(
          serverTitleUpdatedAt: Value(newServerTitleStamp),
          titleDirty: Value(newTitleDirty),
          serverBodyUpdatedAt: Value(newServerBodyStamp),
          bodyDirty: Value(newBodyDirty),
        ),
      );
    });
  }

  // Apply incoming remote note from pull
  Future<void> applyPulledNote(PulledNote note) async {
    await _db.transaction(() async {
      // Tombstone: remove from local db
      if (note.deleted) {
        await (_db.delete(_db.notes)..where((t) => t.id.equals(note.id))).go();
        return;
      }

      final row = await (_db.select(
        _db.notes,
      )..where((t) => t.id.equals(note.id))).getSingleOrNull();

      // New note: insert clean
      if (row == null) {
        await _db
            .into(_db.notes)
            .insert(
              Note(
                id: note.id,
                title: note.title ?? '',
                body: note.body ?? '',
                createdAt: note.createdAt ?? DateTime.now().toUtc(),
                updatedAt: note.updatedAt ?? DateTime.now().toUtc(),
                serverTitleUpdatedAt: note.titleUpdatedAt,
                serverBodyUpdatedAt: note.bodyUpdatedAt,
                titleDirty: false,
                bodyDirty: false,
                localRevision: 0,
                conflictOf: note.conflictOf,
                conflictField: note.conflictField,
              ),
            );
        return;
      }

      // Existing note: overwrite clean fields. Dirty fields keep local
      // content and their original stamp so the server catches future conflicts.
      final newTitle = row.titleDirty ? row.title : (note.title ?? row.title);
      final newServerTitleStamp = row.titleDirty
          ? row.serverTitleUpdatedAt
          : (note.titleUpdatedAt ?? row.serverTitleUpdatedAt);

      final newBody = row.bodyDirty ? row.body : (note.body ?? row.body);
      final newServerBodyStamp = row.bodyDirty
          ? row.serverBodyUpdatedAt
          : (note.bodyUpdatedAt ?? row.serverBodyUpdatedAt);

      await (_db.update(_db.notes)..where((t) => t.id.equals(note.id))).write(
        NotesCompanion(
          title: Value(newTitle),
          serverTitleUpdatedAt: Value(newServerTitleStamp),
          body: Value(newBody),
          serverBodyUpdatedAt: Value(newServerBodyStamp),
          updatedAt: Value(note.updatedAt ?? row.updatedAt),
          conflictOf: Value(note.conflictOf ?? row.conflictOf),
          conflictField: Value(note.conflictField ?? row.conflictField),
        ),
      );
    });
  }
}
