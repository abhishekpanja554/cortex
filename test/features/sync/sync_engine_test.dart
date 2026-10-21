import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cortex/core/database/app_database.dart';
import 'package:cortex/features/notes/data/repositories/drift_note_repository.dart';
import 'package:cortex/features/sync/data/sync_api.dart';
import 'package:cortex/features/sync/data/sync_engine.dart';
import 'package:cortex/features/sync/data/sync_local_store.dart';
import 'package:cortex/features/sync/domain/sync_failure.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> loadFixtureData(String filename) {
  final content = File('test/fixtures/$filename').readAsStringSync();
  final json = jsonDecode(content) as Map<String, dynamic>;
  return (json['data'] as Map<String, dynamic>?) ?? json;
}

List<PushNoteResult> parsePushFixture(String filename) {
  final data = loadFixtureData(filename);
  final list = data['results'] as List<dynamic>;
  return list
      .map((item) => PushNoteResult.fromJson(item as Map<String, dynamic>))
      .toList();
}

PullResponse parsePullFixture(String filename) {
  final data = loadFixtureData(filename);
  return PullResponse.fromJson(data);
}

class FakeSyncApi implements SyncApi {
  List<Map<String, dynamic>> lastPushedNotes = [];
  FutureOr<List<PushNoteResult>> Function(List<Map<String, dynamic>> notes)? onPush;
  FutureOr<PullResponse> Function(String? since)? onPull;

  @override
  Future<List<PushNoteResult>> push(List<Map<String, dynamic>> notes) async {
    lastPushedNotes = notes;
    if (onPush != null) {
      return await onPush!(notes);
    }
    return notes
        .map((n) => PushNoteResult(
              id: n['id'] as String,
              deleted: n['deleted'] as bool? ?? false,
              titleOutcome: PushOutcome.accepted,
              bodyOutcome: PushOutcome.accepted,
              titleUpdatedAt: '2026-10-21T09:11:34.362944Z',
              bodyUpdatedAt: '2026-10-21T09:11:34.362944Z',
            ))
        .toList();
  }

  @override
  Future<PullResponse> pull({String? since}) async {
    if (onPull != null) {
      return await onPull!(since);
    }
    return parsePullFixture('pull_response_empty.json');
  }
}

void main() {
  late AppDatabase db;
  late SyncLocalStore store;
  late FakeSyncApi api;
  late int session;
  late SyncEngine engine;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    store = SyncLocalStore(db);
    api = FakeSyncApi();
    session = 1;
    engine = SyncEngine(
      api: api,
      store: store,
      getSession: () => session,
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('SyncEngine specifications', () {
    // 1. Pushing a fresh note with null bases saves returned stamps and clears dirty flags
    test('1. A new note is pushed with both fields and null bases -> after ACCEPTED, clean and stores both stamps',
        () async {
      final now = DateTime.now().toUtc();
      await db.into(db.notes).insert(
            Note(
              id: '00000000-0000-0000-0000-000000000001',
              title: 'Fixture Title',
              body: 'Fixture Body',
              createdAt: now,
              updatedAt: now,
              titleDirty: true,
              bodyDirty: true,
              localRevision: 1,
            ),
          );

      api.onPush = (notes) => parsePushFixture('push_response_accepted.json');

      await engine.syncOnce();

      expect(api.lastPushedNotes.length, 1);
      final pushed = api.lastPushedNotes.first;
      expect(pushed['id'], '00000000-0000-0000-0000-000000000001');
      expect(pushed['title'], 'Fixture Title');
      expect(pushed['titleBaseUpdatedAt'], isNull);
      expect(pushed['body'], 'Fixture Body');
      expect(pushed['bodyBaseUpdatedAt'], isNull);

      final row = await (db.select(db.notes)
            ..where((t) => t.id.equals('00000000-0000-0000-0000-000000000001')))
          .getSingle();
      expect(row.titleDirty, isFalse);
      expect(row.bodyDirty, isFalse);
      expect(row.serverTitleUpdatedAt, '2026-10-21T09:11:34.362944Z');
      expect(row.serverBodyUpdatedAt, '2026-10-21T09:11:34.362944Z');
    });

    // 2. Editing only one field pushes only that field, omitting untouched fields
    test('2. Edit only the title -> the push contains no body', () async {
      final now = DateTime.now().toUtc();
      await db.into(db.notes).insert(
            Note(
              id: '00000000-0000-0000-0000-000000000002',
              title: 'Partial Title Only',
              body: 'Unchanged Body',
              createdAt: now,
              updatedAt: now,
              serverTitleUpdatedAt: 'base-title-stamp',
              serverBodyUpdatedAt: 'base-body-stamp',
              titleDirty: true,
              bodyDirty: false,
              localRevision: 2,
            ),
          );

      api.onPush = (notes) => parsePushFixture('push_response_partial.json');

      await engine.syncOnce();

      expect(api.lastPushedNotes.length, 1);
      final pushed = api.lastPushedNotes.first;
      expect(pushed['id'], '00000000-0000-0000-0000-000000000002');
      expect(pushed['title'], 'Partial Title Only');
      expect(pushed['titleBaseUpdatedAt'], 'base-title-stamp');
      expect(pushed.containsKey('body'), isFalse);
      expect(pushed.containsKey('bodyBaseUpdatedAt'), isFalse);

      final row = await (db.select(db.notes)
            ..where((t) => t.id.equals('00000000-0000-0000-0000-000000000002')))
          .getSingle();
      expect(row.titleDirty, isFalse);
      expect(row.bodyDirty, isFalse);
      expect(row.serverTitleUpdatedAt, '2026-10-21T09:11:34.407330Z');
    });

    // 3. If content changes while push is in flight, stamp updates but field remains dirty
    test('3. The content changes while push is in flight -> stamp is stored, but note stays dirty',
        () async {
      final now = DateTime.now().toUtc();
      await db.into(db.notes).insert(
            Note(
              id: '00000000-0000-0000-0000-000000000001',
              title: 'Fixture Title',
              body: 'Fixture Body',
              createdAt: now,
              updatedAt: now,
              titleDirty: true,
              bodyDirty: false,
              localRevision: 1,
            ),
          );

      api.onPush = (notes) async {
        // User typed a new title locally while the push request was in flight!
        await (db.update(db.notes)
              ..where((t) => t.id.equals('00000000-0000-0000-0000-000000000001')))
            .write(
          const NotesCompanion(
            title: Value('New Title Typed During Flight'),
            titleDirty: Value(true),
          ),
        );

        return parsePushFixture('push_response_accepted.json');
      };

      await engine.syncOnce();

      final row = await (db.select(db.notes)
            ..where((t) => t.id.equals('00000000-0000-0000-0000-000000000001')))
          .getSingle();
      expect(row.title, 'New Title Typed During Flight');
      expect(row.serverTitleUpdatedAt, '2026-10-21T09:11:34.362944Z');
      expect(row.titleDirty, isTrue);
    });

    // 4. Server conflict rejects change; subsequent pull replaces local content
    test('4. CONFLICT -> stamp is not stored; pull afterwards overwrites local content',
        () async {
      final now = DateTime.now().toUtc();
      await db.into(db.notes).insert(
            Note(
              id: '00000000-0000-0000-0000-000000000001',
              title: 'My Conflicting Title',
              body: 'Fixture Body',
              createdAt: now,
              updatedAt: now,
              serverTitleUpdatedAt: 'original-stamp',
              titleDirty: true,
              bodyDirty: false,
              localRevision: 1,
            ),
          );

      api.onPush = (notes) => parsePushFixture('push_response_conflict.json');
      api.onPull = (since) => parsePullFixture('pull_response_notes.json');

      await engine.syncOnce();

      final row = await (db.select(db.notes)
            ..where((t) => t.id.equals('00000000-0000-0000-0000-000000000001')))
          .getSingle();
      expect(row.title, 'Fixture Title');
      expect(row.serverTitleUpdatedAt, '2026-10-21T09:11:34.362944Z');
      expect(row.titleDirty, isFalse);
    });

    // 5. Pulling changes must never overwrite locally dirty fields or touch their stamps
    test('5. A pull does not overwrite a dirty field, and does not touch its stamp',
        () async {
      final now = DateTime.now().toUtc();
      await db.into(db.notes).insert(
            Note(
              id: '00000000-0000-0000-0000-000000000001',
              title: 'Local Dirty Title',
              body: 'Local Clean Body',
              createdAt: now,
              updatedAt: now,
              serverTitleUpdatedAt: 'local-old-title-stamp',
              serverBodyUpdatedAt: 'local-old-body-stamp',
              titleDirty: true,
              bodyDirty: false,
              localRevision: 1,
            ),
          );

      api.onPull = (since) => parsePullFixture('pull_response_notes.json');
      // Disable push to simulate incoming pull while local edit is pending
      api.onPush = (notes) => [];

      await engine.syncOnce();

      final row = await (db.select(db.notes)
            ..where((t) => t.id.equals('00000000-0000-0000-0000-000000000001')))
          .getSingle();
      // Dirty field keeps local edits and existing base stamp
      expect(row.title, 'Local Dirty Title');
      expect(row.serverTitleUpdatedAt, 'local-old-title-stamp');
      expect(row.titleDirty, isTrue);

      // Clean field accepts incoming remote updates
      expect(row.body, 'Fixture Body');
      expect(row.serverBodyUpdatedAt, '2026-10-21T09:11:34.362944Z');
      expect(row.bodyDirty, isFalse);
    });

    // 6. Deleted rows (pushed or pulled) are purged from the local database
    test('6. A pulled tombstone removes local row; pushed delete removes it too',
        () async {
      final now = DateTime.now().toUtc();

      // Case A: locally deleted row pushed to server
      await db.into(db.notes).insert(
            Note(
              id: '00000000-0000-0000-0000-000000000001',
              title: 'To Delete',
              body: 'Body',
              createdAt: now,
              updatedAt: now,
              deletedAt: now,
              titleDirty: true,
              bodyDirty: true,
              localRevision: 1,
            ),
          );

      api.onPush = (notes) {
        expect(notes.first['deleted'], isTrue);
        return parsePushFixture('push_response_deleted.json');
      };

      await engine.syncOnce();

      final row1 = await (db.select(db.notes)
            ..where((t) => t.id.equals('00000000-0000-0000-0000-000000000001')))
          .getSingleOrNull();
      expect(row1, isNull);

      // Case B: clean local row that gets deleted remotely via pulled tombstone
      await db.into(db.notes).insert(
            Note(
              id: '00000000-0000-0000-0000-000000000001',
              title: 'Clean Note',
              body: 'Body',
              createdAt: now,
              updatedAt: now,
              titleDirty: false,
              bodyDirty: false,
              localRevision: 0,
            ),
          );

      api.onPush = (notes) => [];
      api.onPull = (since) => parsePullFixture('pull_response_tombstone.json');

      await engine.syncOnce();

      final row2 = await (db.select(db.notes)
            ..where((t) => t.id.equals('00000000-0000-0000-0000-000000000001')))
          .getSingleOrNull();
      expect(row2, isNull);
    });

    // 7. Pulling identical changes twice produces identical state (idempotence)
    test('7. Applying the same pull response twice gives an identical database',
        () async {
      api.onPull = (_) => parsePullFixture('pull_response_notes.json');

      // First sync
      await engine.syncOnce();
      final snapshot1 = await db.select(db.notes).get();
      final cursor1 = await store.getCursor();

      // Second sync with identical pull response
      await engine.syncOnce();
      final snapshot2 = await db.select(db.notes).get();
      final cursor2 = await store.getCursor();

      expect(snapshot2.length, snapshot1.length);
      for (var i = 0; i < snapshot1.length; i++) {
        expect(snapshot2[i].id, snapshot1[i].id);
        expect(snapshot2[i].title, snapshot1[i].title);
        expect(snapshot2[i].body, snapshot1[i].body);
        expect(snapshot2[i].serverTitleUpdatedAt, snapshot1[i].serverTitleUpdatedAt);
        expect(snapshot2[i].serverBodyUpdatedAt, snapshot1[i].serverBodyUpdatedAt);
        expect(snapshot2[i].titleDirty, snapshot1[i].titleDirty);
        expect(snapshot2[i].bodyDirty, snapshot1[i].bodyDirty);
      }
      expect(cursor2, cursor1);
    });

    // 8. Session mismatch (logout during push) throws and aborts before writing to db
    test('8. Logout during a sync -> nothing is written after the wipe', () async {
      final now = DateTime.now().toUtc();
      await db.into(db.notes).insert(
            Note(
              id: '00000000-0000-0000-0000-000000000001',
              title: 'Fixture Title',
              body: 'Fixture Body',
              createdAt: now,
              updatedAt: now,
              titleDirty: true,
              bodyDirty: true,
              localRevision: 1,
            ),
          );

      api.onPush = (notes) async {
        // User logs out while push request is in flight!
        session++; // session increments on logout
        await db.delete(db.notes).go();
        await db.delete(db.syncState).go();

        return parsePushFixture('push_response_accepted.json');
      };

      // Sync must throw SessionExpiredSyncFailure and write nothing
      await expectLater(
        () => engine.syncOnce(),
        throwsA(isA<SessionExpiredSyncFailure>()),
      );

      // Verify database remains completely empty
      final notesInDb = await db.select(db.notes).get();
      expect(notesInDb, isEmpty);
      expect(await store.getCursor(), isNull);
    });

    // 9. Sync cursor is saved after pulls and wiped when user logs out
    test('9. The cursor is saved after a pull and cleared by wipeAll()',
        () async {
      api.onPull = (since) => parsePullFixture('pull_response_empty.json');

      await engine.syncOnce();
      expect(await store.getCursor(), '2026-10-21T09:11:01.727652Z');

      // Now call wipeAll() on repository
      final repo = DriftNoteRepository(db, Directory.systemTemp);
      await repo.wipeAll();

      expect(await store.getCursor(), isNull);
    });

    // 10. Upgrading v1 database to v2 preserves existing notes and maps dirty flags
    test('10. Migration: a version-1 database with rows upgrades to version 2 without losing them',
        () async {
      final migrationDb = AppDatabase.forTesting(
        NativeDatabase.memory(
          setup: (rawDb) {
            rawDb.execute('''
              CREATE TABLE IF NOT EXISTS notes (
                id TEXT NOT NULL PRIMARY KEY,
                title TEXT NOT NULL DEFAULT '',
                body TEXT NOT NULL DEFAULT '',
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                server_title_updated_at TEXT,
                server_body_updated_at TEXT,
                is_dirty INTEGER NOT NULL DEFAULT 0,
                local_revision INTEGER NOT NULL DEFAULT 0,
                deleted_at TEXT,
                conflict_of TEXT,
                conflict_field TEXT
              )
            ''');
            rawDb.execute('PRAGMA user_version = 1');
            rawDb.execute('''
              INSERT INTO notes (id, title, body, created_at, updated_at, is_dirty, local_revision)
              VALUES ('v1-note', 'V1 Title', 'V1 Body', '2024-01-01T00:00:00.000Z', '2024-01-02T00:00:00.000Z', 1, 4)
            ''');
          },
        ),
      );

      // Open and trigger migration to v2
      final rows = await migrationDb.select(migrationDb.notes).get();
      expect(rows.length, 1);
      final migratedNote = rows.first;
      expect(migratedNote.id, 'v1-note');
      expect(migratedNote.title, 'V1 Title');
      expect(migratedNote.body, 'V1 Body');
      expect(migratedNote.titleDirty, isTrue);
      expect(migratedNote.bodyDirty, isTrue);
      expect(migratedNote.localRevision, 4);

      // SyncState table should exist and work
      final storeV2 = SyncLocalStore(migrationDb);
      expect(await storeV2.getCursor(), isNull);
      await storeV2.saveCursor('cursor-v2');
      expect(await storeV2.getCursor(), 'cursor-v2');

      await migrationDb.close();
    });

    // 11. Push result with mixed outcomes: title ACCEPTED and body CONFLICT
    test('11. Mixed per-field push outcomes: title ACCEPTED and body CONFLICT applied independently',
        () async {
      final now = DateTime.now().toUtc();
      await db.into(db.notes).insert(
            Note(
              id: '00000000-0000-0000-0000-000000000099',
              title: 'Device New Title',
              body: 'Device Conflicting Body',
              createdAt: now,
              updatedAt: now,
              serverTitleUpdatedAt: 'base-title',
              serverBodyUpdatedAt: 'base-body',
              titleDirty: true,
              bodyDirty: true,
              localRevision: 3,
            ),
          );

      api.onPush = (notes) => parsePushFixture('push_response_mixed_outcomes.json');

      await engine.syncOnce();

      final row = await (db.select(db.notes)
            ..where((t) => t.id.equals('00000000-0000-0000-0000-000000000099')))
          .getSingle();

      // Title was ACCEPTED: updated to new server title stamp, titleDirty cleared
      expect(row.title, 'Device New Title');
      expect(row.serverTitleUpdatedAt, '2026-10-21T09:16:18.433857Z');
      expect(row.titleDirty, isFalse);

      // Body was CONFLICT: stamp remains base stamp, bodyDirty cleared so upcoming pull can overwrite
      expect(row.body, 'Device Conflicting Body');
      expect(row.serverBodyUpdatedAt, 'base-body');
      expect(row.bodyDirty, isFalse);
    });
  });
}
