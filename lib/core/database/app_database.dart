import 'package:cortex/core/database/tables.dart';
import 'package:cortex/core/perf/perf.dart';
import 'package:cortex/features/attachments/domain/attachment_ref.dart';
import 'package:cortex/features/notes/domain/entities/note_preview_data.dart';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:uuid/uuid.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Notes, SyncState, PendingUploads])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(notes, notes.titleDirty);
        await m.addColumn(notes, notes.bodyDirty);
        await customStatement(
          'UPDATE notes SET title_dirty = is_dirty, body_dirty = is_dirty',
        );
        await m.createTable(syncState);
      }
      if (from < 3) {
        await m.addColumn(notes, notes.previewText);
        await m.addColumn(notes, notes.firstImagePath);
        await m.addColumn(notes, notes.previewTodos);
        await _backfillPreviewsV3();
      }
      if (from < 4) {
        await customStatement('DROP INDEX IF EXISTS notes_updated_at;');
        await customStatement(
          'CREATE INDEX IF NOT EXISTS notes_list_cover ON notes(updated_at DESC, deleted_at, id, title, preview_text, preview_todos, first_image_path, created_at, conflict_of, conflict_field);',
        );
      }
      if (from < 5) {
        await customStatement(
          'CREATE INDEX IF NOT EXISTS notes_conflict_of ON notes(conflict_of) WHERE conflict_of IS NOT NULL;',
        );
      }
      if (from < 6) {
        await m.createTable(pendingUploads);
        await _queueExistingAttachmentsV6();
      }
    },
    onCreate: (m) async {
      await m.createAll();
    },
  );

  Future<void> _backfillPreviewsV3() async {
    await Perf.measureAsync('migration.v2ToV3', () async {
      const batchSize = 500;
      var offset = 0;
      while (true) {
        final rows = await (select(notes)
              ..orderBy([(t) => OrderingTerm(expression: t.id)])
              ..limit(batchSize, offset: offset))
            .get();
        if (rows.isEmpty) break;

        await batch((b) {
          for (final row in rows) {
            final preview = computePreview(row.body);
            b.update(
              notes,
              NotesCompanion(
                previewText: Value(preview.previewText),
                firstImagePath: Value(preview.firstImagePath),
                previewTodos: Value(preview.previewTodos),
              ),
              where: (t) => t.id.equals(row.id),
            );
          }
        });

        if (rows.length < batchSize) break;
        offset += batchSize;
      }
    });
  }

  // Images added before attachments synced exist only on this device; queue
  // them so the next sync uploads them. Paths whose file is gone are dropped
  // by the uploader.
  Future<void> _queueExistingAttachmentsV6() async {
    final rows = await customSelect(
      "SELECT body FROM notes WHERE deleted_at IS NULL AND body LIKE '%attachments/%'",
    ).get();
    final paths = {
      for (final row in rows) ...AttachmentRef.pathsIn(row.read<String>('body')),
    };
    await batch((b) {
      b.insertAll(
        pendingUploads,
        [for (final path in paths) PendingUploadsCompanion.insert(path: path)],
        mode: InsertMode.insertOrIgnore,
      );
    });
  }
}

QueryExecutor openEncryptedConnection(String hexKey) {
  return driftDatabase(
    name: 'cortex',
    native: DriftNativeOptions(
      setup: (db) {
        db.execute("PRAGMA cipher = 'sqlcipher';");
        db.execute("PRAGMA key = \"x'$hexKey'\";");
        db.select('SELECT count(*) FROM sqlite_master;');
      },
    ),
  );
}
