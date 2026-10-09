import 'package:cortex/core/database/tables.dart';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:uuid/uuid.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Notes])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 1;
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
