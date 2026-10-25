import 'dart:convert';
import 'package:cortex/core/database/app_database.dart';
import 'package:cortex/core/perf/perf.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Database migration v2 → v3', () {
    test('Upgrades a version-2 database and backfills previews for existing rows', () async {
      Perf.reset();

      final longText = 'A' * 200;
      final bodyWithImageAndChecklist =
          'Intro text\n![](<attachments/pic.jpg>)\n- [x] Item 1\n- [ ] Item 2\n- [x] Item 3\n- [ ] Item 4';

      final db = AppDatabase.forTesting(
        NativeDatabase.memory(
          setup: (rawDb) {
            // Create v2 schema
            rawDb.execute('''
              CREATE TABLE IF NOT EXISTS notes (
                id TEXT NOT NULL PRIMARY KEY,
                title TEXT NOT NULL DEFAULT '',
                body TEXT NOT NULL DEFAULT '',
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
              'CREATE INDEX IF NOT EXISTS notes_updated_at ON notes (updated_at)',
            );
            rawDb.execute('''
              CREATE TABLE IF NOT EXISTS sync_state (
                key TEXT NOT NULL PRIMARY KEY DEFAULT 'singleton',
                next_since TEXT
              )
            ''');

            // Set user_version to 2 so Drift treats this as a v2 database.
            rawDb.execute('PRAGMA user_version = 2');

            final now = DateTime.now().toUtc().toIso8601String();

            // Insert test rows in v2 format without preview columns.
            rawDb.execute('''
              INSERT INTO notes (id, title, body, created_at, updated_at, title_dirty, body_dirty, local_revision)
              VALUES ('note-1', 'Long Note', '$longText', '$now', '$now', 0, 0, 1)
            ''');

            rawDb.execute('''
              INSERT INTO notes (id, title, body, created_at, updated_at, title_dirty, body_dirty, local_revision)
              VALUES ('note-2', 'Complex Note', '$bodyWithImageAndChecklist', '$now', '$now', 0, 0, 1)
            ''');
          },
        ),
      );

      final notes = await db.select(db.notes).get();
      expect(notes.length, 2);

      final note1 = notes.firstWhere((n) => n.id == 'note-1');
      expect(note1.previewText.length, 160);
      expect(note1.previewText, 'A' * 160);
      expect(note1.firstImagePath, isNull);
      expect(note1.previewTodos, '[]');

      final note2 = notes.firstWhere((n) => n.id == 'note-2');
      expect(note2.previewText, 'Intro text');
      expect(note2.firstImagePath, 'attachments/pic.jpg');

      final todos = jsonDecode(note2.previewTodos) as List<dynamic>;
      expect(todos.length, 3);
      expect(todos[0], {'text': 'Item 1', 'checked': true});
      expect(todos[1], {'text': 'Item 2', 'checked': false});
      expect(todos[2], {'text': 'Item 3', 'checked': true});

      // Verify migration metric was recorded
      final summary = Perf.summary();
      expect(summary.containsKey('migration.v2ToV3'), isTrue);

      await db.close();
    });
  });
}
