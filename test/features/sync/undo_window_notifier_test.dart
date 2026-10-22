import 'dart:io';
import 'package:cortex/core/database/app_database.dart';
import 'package:cortex/features/notes/data/repositories/drift_note_repository.dart';
import 'package:cortex/features/notes/domain/entities/note_entity.dart';
import 'package:cortex/features/notes/presentation/providers/providers.dart';
import 'package:cortex/features/sync/data/sync_api.dart';
import 'package:cortex/features/sync/data/sync_engine.dart';
import 'package:cortex/features/sync/data/sync_local_store.dart';
import 'package:cortex/features/sync/data/sync_scheduler.dart';
import 'package:cortex/features/sync/presentation/sync_providers.dart';
import 'package:drift/native.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeApi implements SyncApi {
  final List<List<Map<String, dynamic>>> pushCalls = [];

  @override
  Future<List<PushNoteResult>> push(List<Map<String, dynamic>> notes) async {
    pushCalls.add(List.from(notes));
    return notes.map((n) {
      final isDel = n['deleted'] as bool? ?? false;
      return PushNoteResult(
        id: n['id'] as String,
        deleted: isDel,
        titleOutcome: isDel ? null : PushOutcome.accepted,
        bodyOutcome: isDel ? null : PushOutcome.accepted,
      );
    }).toList();
  }

  @override
  Future<PullResponse> pull({String? since}) async {
    return const PullResponse(notes: []);
  }
}

void main() {
  test('a delete through the notifier is pushed with no other trigger', () {
    fakeAsync((async) {
      final db = AppDatabase(NativeDatabase.memory());
      final tempDir = Directory.systemTemp.createTempSync('undo_window_test');
      final repo = DriftNoteRepository(db, tempDir);
      final store = SyncLocalStore(db);
      final api = _FakeApi();

      const undoGrace = Duration(seconds: 6);
      final engine = SyncEngine(
        api: api,
        store: store,
        getSession: () => 1,
        undoGracePeriod: undoGrace,
      );
      final scheduler = SyncScheduler(syncEngine: engine);

      final container = ProviderContainer(
        overrides: [
          noteRepositoryProvider.overrideWithValue(repo),
          syncSchedulerProvider.overrideWithValue(scheduler),
        ],
      );

      // Start scheduler and flush initial sync
      scheduler.start();
      async.flushMicrotasks();
      expect(api.pushCalls.isEmpty, isTrue);

      // 1. Create a note and push it cleanly
      const noteId = 'test-note-to-delete';
      final now = DateTime.now().toUtc();
      repo.saveNote(NoteEntity(
        id: noteId,
        title: 'Initial Note',
        body: 'Initial content',
        createdAt: now,
        updatedAt: now,
      ));
      async.flushMicrotasks();

      scheduler.requestSync();
      async.flushMicrotasks();
      expect(api.pushCalls.length, 1);
      expect(api.pushCalls.first.first['title'], 'Initial Note');

      // 2. Delete the note through the notifier.
      // NO OTHER TRIGGER is called.
      container.read(noteNotifierProvider.notifier).deleteNote(noteId);
      async.flushMicrotasks();

      // Immediately after deletion, sync ran via noteDeleted trigger,
      // but tombstone was skipped because it's within the 6-second undo window.
      expect(api.pushCalls.length, 1); // No new push call yet
      final firstDeleteLog = scheduler.recentLogs.last;
      expect(firstDeleteLog.trigger, SyncTrigger.noteDeleted);
      expect(firstDeleteLog.skippedTombstones, 1);

      // Advance clock by 3 seconds (still within the 6-second undo window)
      async.elapse(const Duration(seconds: 3));
      async.flushMicrotasks();
      expect(api.pushCalls.length, 1); // Still not pushed

      // 3. Advance clock past the remaining 3 seconds (total >= 6s).
      // The scheduler's internal tombstone timer fires automatically!
      async.elapse(const Duration(seconds: 3, milliseconds: 100));
      async.flushMicrotasks();

      // Now the tombstone has been pushed to the server with NO other trigger!
      expect(api.pushCalls.length, 2);
      final pushedTombstone = api.pushCalls.last.first;
      expect(pushedTombstone['id'], noteId);
      expect(pushedTombstone['deleted'], isTrue);

      final secondLog = scheduler.recentLogs.last;
      expect(secondLog.trigger, SyncTrigger.undoWindowExpired);
      expect(secondLog.skippedTombstones, 0);
      expect(secondLog.pushedCount, 1);
      expect(secondLog.success, isTrue);

      // Cleanup
      container.dispose();
      scheduler.dispose();
      db.close();
      tempDir.deleteSync(recursive: true);
    });
  });

  test('restoring note before undo window expires prevents tombstone push', () {
    fakeAsync((async) {
      final db = AppDatabase(NativeDatabase.memory());
      final tempDir = Directory.systemTemp.createTempSync('undo_restore_test');
      final repo = DriftNoteRepository(db, tempDir);
      final store = SyncLocalStore(db);
      final api = _FakeApi();

      const undoGrace = Duration(seconds: 6);
      final engine = SyncEngine(
        api: api,
        store: store,
        getSession: () => 1,
        undoGracePeriod: undoGrace,
      );
      final scheduler = SyncScheduler(syncEngine: engine);

      final container = ProviderContainer(
        overrides: [
          noteRepositoryProvider.overrideWithValue(repo),
          syncSchedulerProvider.overrideWithValue(scheduler),
        ],
      );

      scheduler.start();
      async.flushMicrotasks();

      const noteId = 'test-note-undo';
      final now = DateTime.now().toUtc();
      repo.saveNote(NoteEntity(
        id: noteId,
        title: 'Will Be Undone',
        body: 'Content',
        createdAt: now,
        updatedAt: now,
      ));
      async.flushMicrotasks();

      scheduler.requestSync();
      async.flushMicrotasks();
      expect(api.pushCalls.length, 1);

      // Delete note
      container.read(noteNotifierProvider.notifier).deleteNote(noteId);
      async.flushMicrotasks();

      // Advance by 2 seconds
      async.elapse(const Duration(seconds: 2));
      async.flushMicrotasks();

      // User taps Undo
      container.read(noteNotifierProvider.notifier).restoreNote(noteId);
      async.flushMicrotasks();

      // Advance past the 6 seconds window
      async.elapse(const Duration(seconds: 6));
      async.flushMicrotasks();

      // Verify NO delete push was ever sent
      for (final call in api.pushCalls) {
        for (final note in call) {
          expect(note['deleted'], isNot(isTrue));
        }
      }

      container.dispose();
      scheduler.dispose();
      db.close();
      tempDir.deleteSync(recursive: true);
    });
  });
}
