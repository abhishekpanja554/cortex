import 'package:cortex/core/constants/string_constants.dart';
import 'package:cortex/features/notes/domain/entities/note_entity.dart';
import 'package:cortex/features/notes/domain/repositories/note_repository.dart';
import 'package:cortex/features/notes/presentation/note_actions.dart';
import 'package:cortex/features/notes/presentation/providers/providers.dart';
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
    when(() => mockRepository.watchAllNotes(limit: any(named: 'limit'))).thenAnswer((_) => Stream.value([]));
    when(() => mockRepository.watchNoteCount()).thenAnswer((_) => Stream.value(0));
    when(() => mockRepository.deleteNote(any())).thenAnswer((_) async {});
    when(() => mockRepository.restoreNote(any())).thenAnswer((_) async {});
  });

  final testNote = NoteEntity(
    id: 'note-1',
    title: 'Test Note',
    body: 'Test Body',
    createdAt: DateTime.utc(2026, 10, 24),
    updatedAt: DateTime.utc(2026, 10, 24),
  );

  testWidgets('deleteWithUndo shows SnackBar with persist: false that auto-dismisses', (tester) async {
    final container = ProviderContainer(
      overrides: [
        noteRepositoryProvider.overrideWithValue(mockRepository),
        syncSchedulerProvider.overrideWithValue(mockSyncScheduler),
      ],
    );
    addTearDown(container.dispose);

    late ScaffoldMessengerState messenger;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                messenger = ScaffoldMessenger.of(context);
                return ElevatedButton(
                  onPressed: () {
                    NoteActions.deleteWithUndo(
                      container: container,
                      messenger: messenger,
                      note: testNote,
                    );
                  },
                  child: const Text('Delete'),
                );
              },
            ),
          ),
        ),
      ),
    );

    // Tap Delete button
    await tester.tap(find.text('Delete'));
    await tester.pump(); // Start SnackBar animation
    await tester.pump(const Duration(milliseconds: 300)); // Finish entrance animation

    // SnackBar is shown
    expect(find.text(AppStrings.noteDeleted), findsOneWidget);
    expect(find.text(AppStrings.undo), findsOneWidget);

    final snackBarWidget = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBarWidget.persist, isFalse);
    expect(snackBarWidget.duration, const Duration(seconds: 4));

    // Verify repository was called to delete
    verify(() => mockRepository.deleteNote(testNote.id)).called(1);

    // Advance time past the 4s duration
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    // SnackBar should have disappeared automatically
    expect(find.text(AppStrings.noteDeleted), findsNothing);
  });

  testWidgets('tapping Undo restores the note and hides the SnackBar immediately', (tester) async {
    final container = ProviderContainer(
      overrides: [
        noteRepositoryProvider.overrideWithValue(mockRepository),
        syncSchedulerProvider.overrideWithValue(mockSyncScheduler),
      ],
    );
    addTearDown(container.dispose);

    late ScaffoldMessengerState messenger;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                messenger = ScaffoldMessenger.of(context);
                return ElevatedButton(
                  onPressed: () {
                    NoteActions.deleteWithUndo(
                      container: container,
                      messenger: messenger,
                      note: testNote,
                    );
                  },
                  child: const Text('Delete'),
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.undo), findsOneWidget);

    // Tap Undo
    await tester.tap(find.text(AppStrings.undo));
    await tester.pumpAndSettle();

    // Verify restoreNote was called and SnackBar is gone
    verify(() => mockRepository.restoreNote(testNote.id)).called(1);
    expect(find.text(AppStrings.noteDeleted), findsNothing);
  });
}
