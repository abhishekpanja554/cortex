import 'package:cortex/core/database/app_database.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Database migration v1 → v2', () {
    test('Upgrades a version-1 database and keeps its rows', () async {
      // Use NativeDatabase.memory with setup callback to prepare v1 schema
      // BEFORE Drift opens the database and runs migrations.
      final db = AppDatabase.forTesting(
        NativeDatabase.memory(
          setup: (rawDb) {
            // Create v1 schema manually.
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
            rawDb.execute(
              'CREATE INDEX IF NOT EXISTS notes_updated_at ON notes (updated_at)',
            );

            // Set user_version to 1 so Drift thinks this is a v1 database.
            rawDb.execute('PRAGMA user_version = 1');

            // Insert test rows in v1 format.
            rawDb.execute('''
              INSERT INTO notes (id, title, body, created_at, updated_at, is_dirty, local_revision)
              VALUES ('test-id-1', 'My Title', 'My Body', '2024-01-01T00:00:00.000Z', '2024-01-02T00:00:00.000Z', 1, 3)
            ''');
            rawDb.execute('''
              INSERT INTO notes (id, title, body, created_at, updated_at, is_dirty, local_revision)
              VALUES ('test-id-2', 'Other Title', 'Other Body', '2024-01-01T00:00:00.000Z', '2024-01-02T00:00:00.000Z', 0, 1)
            ''');
          },
        ),
      );

      // Verify the migrated data.
      final notes = await db.select(db.notes).get();
      expect(notes.length, 2);

      final note1 = notes.firstWhere((n) => n.id == 'test-id-1');
      expect(note1.title, 'My Title');
      expect(note1.body, 'My Body');
      expect(note1.localRevision, 3);
      // is_dirty was true → both titleDirty and bodyDirty should be true.
      expect(note1.titleDirty, isTrue);
      expect(note1.bodyDirty, isTrue);

      final note2 = notes.firstWhere((n) => n.id == 'test-id-2');
      expect(note2.title, 'Other Title');
      expect(note2.body, 'Other Body');
      expect(note2.localRevision, 1);
      // is_dirty was false → both titleDirty and bodyDirty should be false.
      expect(note2.titleDirty, isFalse);
      expect(note2.bodyDirty, isFalse);

      // Verify the SyncState table was created and is empty.
      final syncRows = await db.select(db.syncState).get();
      expect(syncRows, isEmpty);

      await db.close();
    });

    test('SyncState table stores and retrieves nextSince cursor', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());

      // Initially empty.
      final initial = await (db.select(db.syncState)
            ..where((t) => t.key.equals('singleton')))
          .getSingleOrNull();
      expect(initial, isNull);

      // Insert a cursor.
      await db.into(db.syncState).insertOnConflictUpdate(
            SyncStateCompanion(
              key: const Value('singleton'),
              nextSince: const Value('2024-06-15T12:00:00Z'),
            ),
          );

      final row = await (db.select(db.syncState)
            ..where((t) => t.key.equals('singleton')))
          .getSingle();
      expect(row.nextSince, '2024-06-15T12:00:00Z');

      // Update the cursor.
      await db.into(db.syncState).insertOnConflictUpdate(
            SyncStateCompanion(
              key: const Value('singleton'),
              nextSince: const Value('2024-06-16T00:00:00Z'),
            ),
          );

      final updated = await (db.select(db.syncState)
            ..where((t) => t.key.equals('singleton')))
          .getSingle();
      expect(updated.nextSince, '2024-06-16T00:00:00Z');

      // Wipe (simulating logout) clears it.
      await db.delete(db.syncState).go();
      final afterWipe = await (db.select(db.syncState)
            ..where((t) => t.key.equals('singleton')))
          .getSingleOrNull();
      expect(afterWipe, isNull);

      await db.close();
    });
  });

  group('Schema v2 dirty flags', () {
    test('Only the dirty flag for the changed field is set', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());

      // Insert a note with both dirty flags clean.
      await db.into(db.notes).insert(
            Note(
              id: 'note-1',
              title: 'Original Title',
              body: 'Original Body',
              previewText: 'Original Body',
              firstImagePath: null,
              previewTodos: '[]',
              createdAt: DateTime.utc(2024, 1, 1),
              updatedAt: DateTime.utc(2024, 1, 1),
              titleDirty: false,
              bodyDirty: false,
              localRevision: 0,
            ),
          );

      // Simulate saving with only title changed.
      final existing = await (db.select(db.notes)
            ..where((t) => t.id.equals('note-1')))
          .getSingle();

      final isTitleChanged = existing.title != 'New Title';
      final isBodyChanged = existing.body != 'Original Body';

      await (db.update(db.notes)..where((t) => t.id.equals('note-1'))).write(
        NotesCompanion(
          title: const Value('New Title'),
          body: const Value('Original Body'),
          titleDirty: Value(existing.titleDirty || isTitleChanged),
          bodyDirty: Value(existing.bodyDirty || isBodyChanged),
          localRevision: Value(existing.localRevision + 1),
        ),
      );

      final updated = await (db.select(db.notes)
            ..where((t) => t.id.equals('note-1')))
          .getSingle();
      expect(updated.titleDirty, isTrue);
      expect(updated.bodyDirty, isFalse);
      expect(updated.title, 'New Title');
      expect(updated.body, 'Original Body');

      await db.close();
    });
  });
}
