import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

@TableIndex.sql(
  'CREATE INDEX notes_list_cover ON notes(updated_at DESC, deleted_at, id, title, preview_text, preview_todos, first_image_path, created_at, conflict_of, conflict_field);',
)
@TableIndex.sql(
  'CREATE INDEX notes_conflict_of ON notes(conflict_of) WHERE conflict_of IS NOT NULL;',
)
class Notes extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get body => text().withDefault(const Constant(''))();
  TextColumn get previewText => text().withDefault(const Constant(''))();
  TextColumn get firstImagePath => text().nullable()();
  TextColumn get previewTodos => text().withDefault(const Constant('[]'))();
  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();
  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();
  TextColumn get serverTitleUpdatedAt => text().nullable()();
  TextColumn get serverBodyUpdatedAt => text().nullable()();
  BoolColumn get titleDirty => boolean().withDefault(const Constant(false))();
  BoolColumn get bodyDirty => boolean().withDefault(const Constant(false))();
  IntColumn get localRevision => integer().withDefault(const Constant(0))();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get conflictOf => text().nullable()();
  TextColumn get conflictField => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class SyncState extends Table {
  TextColumn get key => text().withDefault(const Constant('singleton'))();
  TextColumn get nextSince => text().nullable()();

  @override
  Set<Column> get primaryKey => {key};
}
