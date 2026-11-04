import 'package:cortex/core/database/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('v5 → v6 creates pending_uploads and queues images already in notes', () async {
    const idA = '11111111-1111-4111-8111-111111111111';
    const idB = '22222222-2222-4222-8222-222222222222';
    const idDeleted = '33333333-3333-4333-8333-333333333333';
    final db = AppDatabase.forTesting(
      NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('''
            CREATE TABLE notes (
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
              deleted_at TEXT,
              conflict_of TEXT,
              conflict_field TEXT
            )
          ''');
          rawDb.execute('''
            CREATE TABLE sync_state (
              key TEXT NOT NULL PRIMARY KEY DEFAULT 'singleton',
              next_since TEXT
            )
          ''');
          rawDb.execute('PRAGMA user_version = 5');
          const now = '2026-11-03T00:00:00.000Z';
          rawDb.execute('''
            INSERT INTO notes (id, body, created_at, updated_at) VALUES
              ('n1', 'Trip\n\n![](<attachments/$idA.jpg>)\n\n![](<attachments/perf_sample.jpg>)', '$now', '$now'),
              ('n2', '![](<attachments/$idA.jpg>)\n\n![](</old/Documents/attachments/$idB.jpg>)', '$now', '$now'),
              ('n3', 'no images here', '$now', '$now')
          ''');
          rawDb.execute('''
            INSERT INTO notes (id, body, created_at, updated_at, deleted_at)
            VALUES ('n4', '![](<attachments/$idDeleted.jpg>)', '$now', '$now', '$now')
          ''');
        },
      ),
    );

    final queued = await db.select(db.pendingUploads).get();

    // Deduplicated, legacy absolute path normalised, perf sample and deleted
    // notes skipped.
    expect(
      queued.map((r) => r.path).toSet(),
      {'attachments/$idA.jpg', 'attachments/$idB.jpg'},
    );
    expect((await db.select(db.notes).get()).length, 4);
    await db.close();
  });
}
