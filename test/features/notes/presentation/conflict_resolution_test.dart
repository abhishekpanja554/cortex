import 'dart:async';
import 'package:cortex/features/notes/domain/entities/note_entity.dart';
import 'package:cortex/features/notes/domain/repositories/note_repository.dart';
import 'package:cortex/features/notes/presentation/providers/providers.dart';
import 'package:cortex/features/notes/presentation/screens/edit_note_screen.dart';
import 'package:cortex/features/notes/presentation/state/notes_state.dart';
import 'package:cortex/features/notes/presentation/widgets/note_list_card.dart';
import 'package:cortex/features/sync/data/sync_scheduler.dart';
import 'package:cortex/features/sync/presentation/sync_providers.dart';
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
        plainText: 'Conflicted Body',
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
        plainText: 'Normal Body',
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
    late StreamController<List<NoteEntity>> notesStream;
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

      notesStream = StreamController<List<NoteEntity>>.broadcast();
      when(() => mockRepository.watchAllNotes())
          .thenAnswer((_) => Stream.value([origNote, copyNote]));
      when(() => mockRepository.saveNote(any())).thenAnswer((_) async {});
      when(() => mockRepository.deleteNote(any())).thenAnswer((_) async {});
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

      notesStream.add([origNote, copyNote]);
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

      notesStream.add([origNote, copyNote]);
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

      notesStream.add([origNote, copyNote]);
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

      notesStream.add([origNote, copyNote]);
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
      when(() => mockRepository.watchAllNotes())
          .thenAnswer((_) => Stream.value([copyNote])); // origNote is missing!

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

      notesStream.add([copyNote]);
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
}
