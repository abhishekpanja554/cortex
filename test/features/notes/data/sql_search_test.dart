import 'dart:io';
import 'package:cortex/core/database/app_database.dart';
import 'package:cortex/core/perf/perf.dart';
import 'package:cortex/features/notes/data/repositories/drift_note_repository.dart';
import 'package:cortex/features/notes/domain/entities/note_entity.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DriftNoteRepository SQL search & note loading by ID', () {
    late AppDatabase db;
    late DriftNoteRepository repo;
    late Directory tempDir;

    setUp(() async {
      Perf.reset();
      db = AppDatabase.forTesting(NativeDatabase.memory());
      tempDir = await Directory.systemTemp.createTemp('sql_search_test');
      repo = DriftNoteRepository(db, tempDir);
    });

    tearDown(() async {
      await db.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('searchNotes matches by title and body, case-insensitively, records search.sqlLike', () async {
      final now = DateTime.utc(2026, 1, 1);
      final note1 = NoteEntity(
        id: 'note-1',
        title: 'Grocery List',
        body: 'Buy oat milk and bread',
        createdAt: now,
        updatedAt: now.add(const Duration(minutes: 1)),
      );
      final note2 = NoteEntity(
        id: 'note-2',
        title: 'Ideas for app',
        body: 'Improve startup performance and memory',
        createdAt: now,
        updatedAt: now.add(const Duration(minutes: 2)),
      );
      final note3 = NoteEntity(
        id: 'note-3',
        title: 'Archived recipe',
        body: 'Secret cookie recipe',
        createdAt: now,
        updatedAt: now.add(const Duration(minutes: 3)),
      );

      await repo.saveNote(note1);
      await repo.saveNote(note2);
      await repo.saveNote(note3);

      // 1. Search by title
      final titleResults = await repo.searchNotes('grocery');
      expect(titleResults.length, 1);
      expect(titleResults.first.id, 'note-1');
      expect(titleResults.first.title, 'Grocery List');

      // 2. Search by body text (which is not loaded in NoteListItem)
      final bodyResults = await repo.searchNotes('oat milk');
      expect(bodyResults.length, 1);
      expect(bodyResults.first.id, 'note-1');

      // 3. Search matching multiple
      final performanceResults = await repo.searchNotes('performance');
      expect(performanceResults.length, 1);
      expect(performanceResults.first.id, 'note-2');

      // 4. Exclude soft-deleted note
      await repo.deleteNote('note-1');
      final afterDeleteResults = await repo.searchNotes('grocery');
      expect(afterDeleteResults, isEmpty);

      // 5. Verify search.sqlLike metric recorded
      final summary = Perf.summary();
      expect(summary.containsKey('search.sqlLike'), isTrue);
      expect(summary['search.sqlLike']!.samples, greaterThanOrEqualTo(3));
    });

    test('getNote and watchNote load full bodies by ID', () async {
      final now = DateTime.utc(2026, 1, 1);
      const fullBody = 'Full note body with lots of text:\n- [x] Done\n![](<attachments/img.jpg>)';
      final note = NoteEntity(
        id: 'id-load-test',
        title: 'Target Title',
        body: fullBody,
        createdAt: now,
        updatedAt: now,
      );

      await repo.saveNote(note);

      // getNote loads full NoteEntity including body
      final loaded = await repo.getNote('id-load-test');
      expect(loaded, isNotNull);
      expect(loaded!.id, 'id-load-test');
      expect(loaded.title, 'Target Title');
      expect(loaded.body, fullBody);

      // watchNote emits full NoteEntity including body
      final streamFuture = repo.watchNote('id-load-test').first;
      final streamed = await streamFuture;
      expect(streamed, isNotNull);
      expect(streamed!.body, fullBody);
    });

    test('searchNotes correctly finds text containing %, _, and literal backslash', () async {
      final now = DateTime.utc(2026, 1, 1);
      final noteA = NoteEntity(
        id: 'note-sale',
        title: 'Shoe Discount',
        body: 'Sale: 50% off shoes',
        createdAt: now,
        updatedAt: now.add(const Duration(minutes: 1)),
      );
      final noteB = NoteEntity(
        id: 'note-report',
        title: 'Project Files',
        body: 'file my_report.pdf',
        createdAt: now,
        updatedAt: now.add(const Duration(minutes: 2)),
      );
      final noteC = NoteEntity(
        id: 'note-report-other',
        title: 'Other Files',
        body: 'file myXreport.pdf',
        createdAt: now,
        updatedAt: now.add(const Duration(minutes: 3)),
      );
      final noteD = NoteEntity(
        id: 'note-backslash',
        title: 'Windows path',
        body: r'path\to\file',
        createdAt: now,
        updatedAt: now.add(const Duration(minutes: 4)),
      );

      await repo.saveNote(noteA);
      await repo.saveNote(noteB);
      await repo.saveNote(noteC);
      await repo.saveNote(noteD);

      // SEARCH "50%" -> [noteA]
      final results50 = await repo.searchNotes('50%');
      expect(results50.map((n) => n.id), ['note-sale']);

      // SEARCH "my_report" -> [noteB] (_ must not match 'X' in noteC)
      final resultsReport = await repo.searchNotes('my_report');
      expect(resultsReport.map((n) => n.id), ['note-report']);

      // SEARCH "Sale" -> [noteA]
      final resultsSale = await repo.searchNotes('Sale');
      expect(resultsSale.map((n) => n.id), ['note-sale']);

      // SEARCH containing literal backslash -> [noteD]
      final resultsBackslash = await repo.searchNotes(r'path\to\file');
      expect(resultsBackslash.map((n) => n.id), ['note-backslash']);

      // Search just the backslash query
      final singleBackslashResults = await repo.searchNotes(r'\');
      expect(singleBackslashResults.map((n) => n.id), ['note-backslash']);
    });

    test('getAllNotesForExport returns full notes including bodies, excluding deleted', () async {
      final now = DateTime.utc(2026, 1, 1);
      final note1 = NoteEntity(
        id: 'exp-1',
        title: 'Title 1',
        body: 'Full body 1',
        createdAt: now,
        updatedAt: now.add(const Duration(minutes: 1)),
      );
      final note2 = NoteEntity(
        id: 'exp-2',
        title: 'Title 2',
        body: 'Full body 2',
        createdAt: now,
        updatedAt: now.add(const Duration(minutes: 2)),
      );

      await repo.saveNote(note1);
      await repo.saveNote(note2);
      await repo.deleteNote('exp-1');

      final exportNotes = await repo.getAllNotesForExport();
      expect(exportNotes.length, 1);
      expect(exportNotes.first.id, 'exp-2');
      expect(exportNotes.first.body, 'Full body 2');
    });
  });
}
