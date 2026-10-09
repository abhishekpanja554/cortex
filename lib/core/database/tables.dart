import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

@TableIndex(name: 'notes_updated_at', columns: {#updatedAt})
class Notes extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get body => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();
  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();
  TextColumn get serverTitleUpdatedAt => text().nullable()();
  TextColumn get serverBodyUpdatedAt => text().nullable()();
  BoolColumn get isDirty => boolean().withDefault(const Constant(false))();
  IntColumn get localRevision => integer().withDefault(const Constant(0))();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get conflictOf => text().nullable()();
  TextColumn get conflictField => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
