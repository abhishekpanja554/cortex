import 'dart:convert';
import 'package:cortex/core/database/app_database.dart';
import 'package:cortex/features/sync/data/sync_api.dart';
import 'package:cortex/features/sync/data/sync_local_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SyncLocalStore preview population', () {
    late AppDatabase db;
    late SyncLocalStore store;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      store = SyncLocalStore(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('pulled new note computes and populates preview columns on insert', () async {
      final now = DateTime.utc(2026, 1, 1);
      final pulled = PulledNote(
        id: 'remote-1',
        title: 'Remote Note',
        body: 'Remote body text\n![](<attachments/pic.png>)\n- [x] Item A\n- [ ] Item B',
        createdAt: now,
        updatedAt: now,
        titleUpdatedAt: 'stamp-1',
        bodyUpdatedAt: 'stamp-1',
      );

      await store.applyPulledNote(pulled);

      final row = await (db.select(db.notes)..where((t) => t.id.equals('remote-1'))).getSingle();
      expect(row.title, 'Remote Note');
      expect(row.body, pulled.body);
      expect(row.previewText, 'Remote body text');
      expect(row.firstImagePath, 'attachments/pic.png');

      final todos = jsonDecode(row.previewTodos) as List<dynamic>;
      expect(todos.length, 2);
      expect(todos[0], {'text': 'Item A', 'checked': true});
      expect(todos[1], {'text': 'Item B', 'checked': false});
    });

    test('pulled updated note updates preview columns on update', () async {
      final now = DateTime.utc(2026, 1, 1);
      final initial = PulledNote(
        id: 'remote-2',
        title: 'Initial Title',
        body: 'Initial short text',
        createdAt: now,
        updatedAt: now,
        titleUpdatedAt: 'stamp-1',
        bodyUpdatedAt: 'stamp-1',
      );

      await store.applyPulledNote(initial);

      // Verify initial preview
      var row = await (db.select(db.notes)..where((t) => t.id.equals('remote-2'))).getSingle();
      expect(row.previewText, 'Initial short text');
      expect(row.firstImagePath, isNull);
      expect(row.previewTodos, '[]');

      // Update with new body containing image and todo
      final updated = PulledNote(
        id: 'remote-2',
        title: 'Updated Title',
        body: 'Updated body text\n![](<attachments/new_pic.jpg>)\n- [x] Done item',
        createdAt: now,
        updatedAt: now.add(const Duration(hours: 1)),
        titleUpdatedAt: 'stamp-2',
        bodyUpdatedAt: 'stamp-2',
      );

      await store.applyPulledNote(updated);

      row = await (db.select(db.notes)..where((t) => t.id.equals('remote-2'))).getSingle();
      expect(row.previewText, 'Updated body text');
      expect(row.firstImagePath, 'attachments/new_pic.jpg');

      final todos = jsonDecode(row.previewTodos) as List<dynamic>;
      expect(todos.length, 1);
      expect(todos[0], {'text': 'Done item', 'checked': true});
    });
  });
}
