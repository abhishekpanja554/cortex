import 'package:cortex/core/database/tables.dart';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:uuid/uuid.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Notes, SyncState])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 2;

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
    },
    onCreate: (m) async {
      await m.createAll();
    },
  );
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
