import 'package:cortex/core/database/app_database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Covering index guard for notes list query', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('list query uses COVERING INDEX notes_list_cover', () async {
      // Replicate the exact list query used by DriftNoteRepository.watchAllNotes()
      final query = db.selectOnly(db.notes)
        ..addColumns([
          db.notes.id,
          db.notes.title,
          db.notes.previewText,
          db.notes.firstImagePath,
          db.notes.previewTodos,
          db.notes.createdAt,
          db.notes.updatedAt,
          db.notes.conflictOf,
          db.notes.conflictField,
        ])
        ..where(db.notes.deletedAt.isNull())
        ..orderBy([
          OrderingTerm(expression: db.notes.updatedAt, mode: OrderingMode.desc),
        ])
        ..limit(100);

      final statement = query.constructQuery();
      final explainRows = await db.customSelect(
        'EXPLAIN QUERY PLAN ${statement.sql}',
        variables: statement.boundVariables.map((v) => Variable(v)).toList(),
      ).get();

      final details =
          explainRows.map((r) => r.read<String>('detail')).join(' ');

      // Guard: must use COVERING INDEX notes_list_cover
      expect(
        details,
        contains('COVERING INDEX'),
        reason:
            'List query must be covered by index so SQLite never touches table B-tree.',
      );
      expect(
        details,
        contains('notes_list_cover'),
        reason: 'List query must use the notes_list_cover index.',
      );
    });

    test('conflict copies query uses INDEX notes_conflict_of', () async {
      // Replicate the exact conflict copies query used by DriftNoteRepository.watchConflictCopies()
      final query = db.select(db.notes)
        ..where((t) => t.conflictOf.equals('some-note-id') & t.deletedAt.isNull());

      final statement = query.constructQuery();
      final explainRows = await db.customSelect(
        'EXPLAIN QUERY PLAN ${statement.sql}',
        variables: statement.boundVariables.map((v) => Variable(v)).toList(),
      ).get();

      final details =
          explainRows.map((r) => r.read<String>('detail')).join(' ');

      expect(
        details,
        contains('notes_conflict_of'),
        reason:
            'Conflict copies query must use notes_conflict_of partial index to avoid full table scans.',
      );
      expect(
        details,
        contains('INDEX'),
        reason: 'Query must use index search rather than scanning whole table.',
      );
    });

    test('adding an unindexed column to list query fails the covering index requirement', () async {
      // Adding body (which is 10MB across notes and not in the covering index)
      final badQuery = db.selectOnly(db.notes)
        ..addColumns([
          db.notes.id,
          db.notes.body, // Unindexed column!
        ])
        ..where(db.notes.deletedAt.isNull())
        ..orderBy([
          OrderingTerm(expression: db.notes.updatedAt, mode: OrderingMode.desc),
        ]);

      final statement = badQuery.constructQuery();
      final explainRows = await db.customSelect(
        'EXPLAIN QUERY PLAN ${statement.sql}',
        variables: statement.boundVariables.map((v) => Variable(v)).toList(),
      ).get();

      final details =
          explainRows.map((r) => r.read<String>('detail')).join(' ');

      expect(
        details,
        isNot(contains('COVERING INDEX')),
        reason:
            'Query including unindexed column should not be a COVERING INDEX.',
      );
    });
  });

  group('Database migration v3 → v4', () {
    test('Upgrades a version-3 database, drops notes_updated_at, and creates notes_list_cover', () async {
      final db = AppDatabase.forTesting(
        NativeDatabase.memory(
          setup: (rawDb) {
            // Create v3 schema
            rawDb.execute('''
              CREATE TABLE IF NOT EXISTS notes (
                id TEXT NOT NULL PRIMARY KEY,
                title TEXT NOT NULL DEFAULT '',
                body TEXT NOT NULL DEFAULT '',
                preview_text TEXT NOT NULL DEFAULT '',
                first_image_path TEXT,
                preview_todos TEXT NOT NULL DEFAULT '[]',
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                server_title_updated_at TEXT,
                server_body_updated_at TEXT,
                title_dirty INTEGER NOT NULL DEFAULT 0,
                body_dirty INTEGER NOT NULL DEFAULT 0,
                local_revision INTEGER NOT NULL DEFAULT 0,
                deleted_at INTEGER,
                conflict_of TEXT,
                conflict_field TEXT
              )
            ''');
            // Old index
            rawDb.execute(
              'CREATE INDEX IF NOT EXISTS notes_updated_at ON notes (updated_at)',
            );
            rawDb.execute('''
              CREATE TABLE IF NOT EXISTS sync_state (
                key TEXT NOT NULL PRIMARY KEY DEFAULT 'singleton',
                next_since TEXT
              )
            ''');
            // Set user_version to 3
            rawDb.execute('PRAGMA user_version = 3');

            final now = DateTime.now().toUtc().toIso8601String();
            rawDb.execute('''
              INSERT INTO notes (id, title, body, preview_text, preview_todos, created_at, updated_at)
              VALUES ('note-migrated-1', 'Migrated Title', 'Body text', 'Body preview', '[]', '$now', '$now')
            ''');
          },
        ),
      );

      // Verify schema version is now 5
      expect(db.schemaVersion, 5);

      // Verify old index notes_updated_at is dropped and notes_list_cover and notes_conflict_of exist
      final indexRows = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'index' AND tbl_name = 'notes';",
          )
          .get();
      final indexNames = indexRows.map((r) => r.read<String>('name')).toList();

      expect(indexNames, contains('notes_list_cover'));
      expect(indexNames, contains('notes_conflict_of'));
      expect(indexNames, isNot(contains('notes_updated_at')));

      // Verify existing note was preserved
      final note = await (db.select(db.notes)..where((t) => t.id.equals('note-migrated-1'))).getSingle();
      expect(note.title, 'Migrated Title');
      expect(note.previewText, 'Body preview');

      // Verify EXPLAIN QUERY PLAN on migrated db uses COVERING INDEX
      final query = db.selectOnly(db.notes)
        ..addColumns([
          db.notes.id,
          db.notes.title,
          db.notes.previewText,
          db.notes.firstImagePath,
          db.notes.previewTodos,
          db.notes.createdAt,
          db.notes.updatedAt,
          db.notes.conflictOf,
          db.notes.conflictField,
        ])
        ..where(db.notes.deletedAt.isNull())
        ..orderBy([
          OrderingTerm(expression: db.notes.updatedAt, mode: OrderingMode.desc),
        ])
        ..limit(100);

      final statement = query.constructQuery();
      final explainRows = await db.customSelect(
        'EXPLAIN QUERY PLAN ${statement.sql}',
        variables: statement.boundVariables.map((v) => Variable(v)).toList(),
      ).get();

      final details =
          explainRows.map((r) => r.read<String>('detail')).join(' ');

      expect(details, contains('COVERING INDEX'));
      expect(details, contains('notes_list_cover'));

      await db.close();
    });
  });

  group('Database migration v4 → v5', () {
    test('Upgrades a version-4 database and creates notes_conflict_of partial index', () async {
      final db = AppDatabase.forTesting(
        NativeDatabase.memory(
          setup: (rawDb) {
            // Create v4 schema
            rawDb.execute('''
              CREATE TABLE IF NOT EXISTS notes (
                id TEXT NOT NULL PRIMARY KEY,
                title TEXT NOT NULL DEFAULT '',
                body TEXT NOT NULL DEFAULT '',
                preview_text TEXT NOT NULL DEFAULT '',
                first_image_path TEXT,
                preview_todos TEXT NOT NULL DEFAULT '[]',
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                server_title_updated_at TEXT,
                server_body_updated_at TEXT,
                title_dirty INTEGER NOT NULL DEFAULT 0,
                body_dirty INTEGER NOT NULL DEFAULT 0,
                local_revision INTEGER NOT NULL DEFAULT 0,
                deleted_at INTEGER,
                conflict_of TEXT,
                conflict_field TEXT
              )
            ''');
            rawDb.execute(
              'CREATE INDEX IF NOT EXISTS notes_list_cover ON notes(updated_at DESC, deleted_at, id, title, preview_text, preview_todos, first_image_path, created_at, conflict_of, conflict_field);',
            );
            rawDb.execute('''
              CREATE TABLE IF NOT EXISTS sync_state (
                key TEXT NOT NULL PRIMARY KEY DEFAULT 'singleton',
                next_since TEXT
              )
            ''');
            rawDb.execute('PRAGMA user_version = 4');

            final now = DateTime.now().toUtc().toIso8601String();
            rawDb.execute('''
              INSERT INTO notes (id, title, body, preview_text, preview_todos, created_at, updated_at, conflict_of)
              VALUES ('conflict-copy-migrated', 'Copy Title', 'Copy body', 'Copy preview', '[]', '$now', '$now', 'original-note-1')
            ''');
          },
        ),
      );

      // Verify schema version is now 5
      expect(db.schemaVersion, 5);

      // Verify notes_conflict_of index exists
      final indexRows = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'index' AND tbl_name = 'notes';",
          )
          .get();
      final indexNames = indexRows.map((r) => r.read<String>('name')).toList();
      expect(indexNames, contains('notes_conflict_of'));

      // Verify existing conflict copy was preserved
      final copy = await (db.select(db.notes)..where((t) => t.id.equals('conflict-copy-migrated'))).getSingle();
      expect(copy.conflictOf, 'original-note-1');

      // Verify EXPLAIN QUERY PLAN on migrated db uses notes_conflict_of index
      final query = db.select(db.notes)
        ..where((t) => t.conflictOf.equals('original-note-1') & t.deletedAt.isNull());

      final statement = query.constructQuery();
      final explainRows = await db.customSelect(
        'EXPLAIN QUERY PLAN ${statement.sql}',
        variables: statement.boundVariables.map((v) => Variable(v)).toList(),
      ).get();

      final details =
          explainRows.map((r) => r.read<String>('detail')).join(' ');

      expect(details, contains('notes_conflict_of'));
      expect(details, contains('INDEX'));

      await db.close();
    });
  });
}
