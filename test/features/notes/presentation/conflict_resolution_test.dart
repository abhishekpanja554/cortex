import 'dart:async';
import 'dart:io';
import 'package:cortex/core/database/app_database.dart';
import 'package:cortex/features/notes/data/repositories/drift_note_repository.dart';
import 'package:cortex/features/notes/domain/entities/note_entity.dart';
import 'package:cortex/features/notes/domain/entities/note_list_item.dart';
import 'package:cortex/features/notes/domain/repositories/note_repository.dart';
import 'package:cortex/features/notes/presentation/providers/providers.dart';
import 'package:cortex/features/notes/presentation/screens/edit_note_screen.dart';
import 'package:cortex/features/notes/presentation/state/notes_state.dart';
import 'package:cortex/features/notes/presentation/widgets/note_list_card.dart';
import 'package:cortex/features/sync/data/sync_scheduler.dart';
import 'package:cortex/features/sync/presentation/sync_providers.dart';
import 'package:drift/drift.dart' hide Column, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockNoteRepository extends Mock implements NoteRepository {}

class MockSyncScheduler extends Mock implements SyncScheduler {}

class FakeNoteEntity extends Fake implements NoteEntity {}

void main() {
  late MockNoteRepository mockRepository;
  late MockSyncScheduler mockSyncScheduler;

  setUpAll(() {
    registerFallbackValue(FakeNoteEntity());
  });

  setUp(() {
    mockRepository = MockNoteRepository();
    mockSyncScheduler = MockSyncScheduler();
    when(() => mockSyncScheduler.requestSync()).thenReturn(null);
  });

  group('NoteListCard conflict badge', () {
    testWidgets('displays conflict badge when note is a conflict copy',
        (tester) async {
      final now = DateTime.utc(2026, 10, 21, 10, 0, 0);
      final conflictNote = NoteEntity(
        id: 'copy-1',
        title: 'Conflicted Title',
        body: 'Conflicted Body',
        createdAt: now,
        updatedAt: now,
        conflictOf: 'orig-1',
        conflictField: 'body',
      );

      final preview = NotePreview(
        note: conflictNote,
        blocks: const [],
        previewText: 'Conflicted Body',
        firstImagePath: null,
        topTodos: const [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteListCard(preview: preview),
          ),
        ),
      );

      expect(find.text('Conflict: body'), findsOneWidget);
      expect(find.byIcon(Icons.call_split_rounded), findsOneWidget);
    });

    testWidgets('does not display conflict badge for normal notes',
        (tester) async {
      final now = DateTime.utc(2026, 10, 21, 10, 0, 0);
      final normalNote = NoteEntity(
        id: 'norm-1',
        title: 'Normal Title',
        body: 'Normal Body',
        createdAt: now,
        updatedAt: now,
      );

      final preview = NotePreview(
        note: normalNote,
        blocks: const [],
        previewText: 'Normal Body',
        firstImagePath: null,
        topTodos: const [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteListCard(preview: preview),
          ),
        ),
      );

      expect(find.textContaining('Conflict'), findsNothing);
    });
  });

  group('EditNoteScreen conflict resolution', () {
    late StreamController<List<NoteListItem>> notesStream;
    late NoteEntity origNote;
    late NoteEntity copyNote;

    setUp(() {
      final now = DateTime.utc(2026, 10, 21, 10, 0, 0);
      origNote = NoteEntity(
        id: 'orig-123',
        title: 'Original Title',
        body: 'Original content from server',
        createdAt: now,
        updatedAt: now,
      );

      copyNote = NoteEntity(
        id: 'copy-456',
        title: 'Copy Title',
        body: 'Local conflicting edits made offline',
        createdAt: now,
        updatedAt: now.add(const Duration(minutes: 1)),
        conflictOf: 'orig-123',
        conflictField: 'body',
      );

      notesStream = StreamController<List<NoteListItem>>.broadcast();
      when(() => mockRepository.watchAllNotes(limit: any(named: 'limit'))).thenAnswer((_) =>
          Stream.value([NotePreview(note: origNote), NotePreview(note: copyNote)]));
      when(() => mockRepository.watchNoteCount()).thenAnswer((_) => Stream.value(2));
      when(() => mockRepository.getNote('copy-456')).thenAnswer((_) async => copyNote);
      when(() => mockRepository.getNote('orig-123')).thenAnswer((_) async => origNote);
      when(() => mockRepository.watchNote('copy-456')).thenAnswer((_) => Stream.value(copyNote));
      when(() => mockRepository.watchNote('orig-123')).thenAnswer((_) => Stream.value(origNote));
      when(() => mockRepository.saveNote(any())).thenAnswer((_) async {});
      when(() => mockRepository.deleteNote(any())).thenAnswer((_) async {});
      when(() => mockRepository.watchConflictCopies(any())).thenAnswer((_) => Stream.value([]));
    });

    tearDown(() {
      notesStream.close();
    });

    testWidgets('shows conflict banner with Compare, Keep Original, and Keep Copy',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            noteRepositoryProvider.overrideWithValue(mockRepository),
            syncSchedulerProvider.overrideWithValue(mockSyncScheduler),
          ],
          child: const MaterialApp(
            home: EditNoteScreen(noteId: 'copy-456'),
          ),
        ),
      );

      notesStream.add([NotePreview(note: origNote), NotePreview(note: copyNote)]);
      await tester.pumpAndSettle();

      expect(find.text('Conflict Copy'), findsWidgets);
      expect(find.text('BODY'), findsOneWidget);
      expect(find.text('Compare'), findsOneWidget);
      expect(find.text('Keep Original'), findsOneWidget);
      expect(find.text('Keep Copy'), findsOneWidget);
    });

    testWidgets('tapping Compare opens comparison sheet showing both notes',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            noteRepositoryProvider.overrideWithValue(mockRepository),
            syncSchedulerProvider.overrideWithValue(mockSyncScheduler),
          ],
          child: const MaterialApp(
            home: EditNoteScreen(noteId: 'copy-456'),
          ),
        ),
      );

      notesStream.add([NotePreview(note: origNote), NotePreview(note: copyNote)]);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Compare'));
      await tester.pumpAndSettle();

      expect(find.text('Compare Notes'), findsOneWidget);
      expect(find.text('Conflict detected on: BODY'), findsOneWidget);
      expect(find.text('Original Note'), findsOneWidget);
      expect(find.text('Original Title'), findsWidgets);
      expect(find.text('Conflict Copy'), findsWidgets);
      expect(find.text('Copy Title'), findsWidgets);
    });

    testWidgets('Keep Original deletes the copy note and requests sync',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            noteRepositoryProvider.overrideWithValue(mockRepository),
            syncSchedulerProvider.overrideWithValue(mockSyncScheduler),
          ],
          child: const MaterialApp(
            home: EditNoteScreen(noteId: 'copy-456'),
          ),
        ),
      );

      notesStream.add([NotePreview(note: origNote), NotePreview(note: copyNote)]);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Keep Original'));
      await tester.pumpAndSettle();

      verify(() => mockRepository.deleteNote('copy-456')).called(1);
      verify(() => mockSyncScheduler.requestSync()).called(1);
      verifyNever(() => mockRepository.saveNote(any()));
    });

    testWidgets('Keep Copy writes copy content to original, deletes copy, and syncs',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            noteRepositoryProvider.overrideWithValue(mockRepository),
            syncSchedulerProvider.overrideWithValue(mockSyncScheduler),
          ],
          child: const MaterialApp(
            home: EditNoteScreen(noteId: 'copy-456'),
          ),
        ),
      );

      notesStream.add([NotePreview(note: origNote), NotePreview(note: copyNote)]);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Keep Copy'));
      await tester.pumpAndSettle();

      final captured = verify(() => mockRepository.saveNote(captureAny())).captured;
      expect(captured.isNotEmpty, isTrue);
      final savedNote = captured.last as NoteEntity;

      expect(savedNote.id, 'orig-123');
      expect(savedNote.title, 'Copy Title');
      expect(savedNote.body, 'Local conflicting edits made offline');
      expect(savedNote.conflictOf, isNull);
      expect(savedNote.conflictField, isNull);

      verify(() => mockRepository.deleteNote('copy-456')).called(1);
      verify(() => mockSyncScheduler.requestSync()).called(1);
    });

    testWidgets(
        'Keep Copy when original is missing saves copy content as a new note, deletes copy, and syncs',
        (tester) async {
      when(() => mockRepository.watchAllNotes(limit: any(named: 'limit')))
          .thenAnswer((_) => Stream.value([NotePreview(note: copyNote)])); // origNote is missing!
      when(() => mockRepository.watchNoteCount()).thenAnswer((_) => Stream.value(1));
      when(() => mockRepository.getNote('orig-123')).thenAnswer((_) async => null);
      when(() => mockRepository.watchNote('orig-123')).thenAnswer((_) => Stream.value(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            noteRepositoryProvider.overrideWithValue(mockRepository),
            syncSchedulerProvider.overrideWithValue(mockSyncScheduler),
          ],
          child: const MaterialApp(
            home: EditNoteScreen(noteId: 'copy-456'),
          ),
        ),
      );

      notesStream.add([NotePreview(note: copyNote)]);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Keep Copy'));
      await tester.pumpAndSettle();

      final captured = verify(() => mockRepository.saveNote(captureAny())).captured;
      expect(captured.isNotEmpty, isTrue);
      final savedNote = captured.last as NoteEntity;

      // Brand new note created with its own ID (not orig-123 and not copy-456)
      expect(savedNote.id, isNot('orig-123'));
      expect(savedNote.id, isNot('copy-456'));
      expect(savedNote.title, 'Copy Title');
      expect(savedNote.body, 'Local conflicting edits made offline');
      expect(savedNote.conflictOf, isNull);
      expect(savedNote.conflictField, isNull);

      verify(() => mockRepository.deleteNote('copy-456')).called(1);
      verify(() => mockSyncScheduler.requestSync()).called(1);
    });
  });

  group('Conflict banner with 150 notes (conflict copy older than newest 100)', () {
    late AppDatabase db;
    late Directory tempDir;
    late DriftNoteRepository driftRepo;
    late MockSyncScheduler scheduler;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      tempDir = Directory.systemTemp.createTempSync('conflict_150_');
      driftRepo = DriftNoteRepository(db, tempDir);
      scheduler = MockSyncScheduler();
      when(() => scheduler.requestSync()).thenReturn(null);
    });

    tearDown(() async {
      await db.close();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    testWidgets(
        'original note screen displays conflict banner when conflict copy is outside top 100 notes',
        (tester) async {
      await tester.runAsync(() async {
        final baseTime = DateTime.utc(2026, 1, 1, 10, 0, 0);

        // 1. Original note (active and updated recently)
        await db.into(db.notes).insert(
          NotesCompanion.insert(
            id: const Value('original-123'),
            title: const Value('Original Project Plan'),
            body: const Value('Original content'),
            previewText: const Value('Original content'),
            previewTodos: const Value('[]'),
            createdAt: Value(baseTime),
            updatedAt: Value(baseTime.add(const Duration(minutes: 500))),
          ),
        );

        // 2. Conflict copy created at baseTime + 1 minute (older than filler notes)
        final copyTime = baseTime.add(const Duration(minutes: 1));
        await db.into(db.notes).insert(
          NotesCompanion.insert(
            id: const Value('conflict-copy-456'),
            title: const Value('Conflicted Project Plan'),
            body: const Value('Conflicting offline edits'),
            previewText: const Value('Conflicting offline edits'),
            previewTodos: const Value('[]'),
            createdAt: Value(copyTime),
            updatedAt: Value(copyTime),
            conflictOf: const Value('original-123'),
            conflictField: const Value('body'),
          ),
        );

        // 3. Add 148 other notes updated AFTER the conflict copy (total = 150 notes)
        await db.batch((batch) {
          for (var i = 0; i < 148; i++) {
            final t = copyTime.add(Duration(minutes: i + 2));
            batch.insert(
              db.notes,
              NotesCompanion.insert(
                id: Value('filler-note-$i'),
                title: Value('Filler Note $i'),
                body: Value('Content for note $i'),
                previewText: const Value('Content'),
                previewTodos: const Value('[]'),
                createdAt: Value(t),
                updatedAt: Value(t),
              ),
            );
          }
        });

        // Verify that the conflict copy is NOT in the top 100 notes
        final top100Rows = await (db.selectOnly(db.notes)
              ..addColumns([db.notes.id])
              ..where(db.notes.deletedAt.isNull())
              ..orderBy([OrderingTerm(expression: db.notes.updatedAt, mode: OrderingMode.desc)])
              ..limit(100))
            .get();
        expect(top100Rows.length, equals(100));
        expect(top100Rows.any((row) => row.read(db.notes.id) == 'conflict-copy-456'), isFalse,
            reason: 'Conflict copy must have dropped out of the newest 100 notes');
      });

      // 4. Pump EditNoteScreen for original note
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            noteRepositoryProvider.overrideWithValue(driftRepo),
            syncSchedulerProvider.overrideWithValue(scheduler),
          ],
          child: const MaterialApp(
            home: EditNoteScreen(noteId: 'original-123'),
          ),
        ),
      );
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 5. The original's screen still finds it via watchConflictCopies
      expect(find.text('Conflict Detected'), findsOneWidget);
      expect(find.text('BODY'), findsOneWidget);
      expect(find.text('Compare'), findsOneWidget);
      expect(find.text('Keep Original'), findsOneWidget);
      expect(find.text('Keep Copy'), findsOneWidget);

      // Clean unmount so providers close stream listeners and flush timer
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
