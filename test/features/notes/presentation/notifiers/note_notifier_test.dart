import 'dart:async';
import 'package:cortex/features/notes/domain/entities/note_entity.dart';
import 'package:cortex/features/notes/domain/repositories/note_repository.dart';
import 'package:cortex/features/notes/presentation/providers/providers.dart';
import 'package:cortex/features/sync/data/sync_scheduler.dart';
import 'package:cortex/features/sync/presentation/sync_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockNoteRepository extends Mock implements NoteRepository {}

class FakeNoteEntity extends Fake implements NoteEntity {}

class MockSyncScheduler extends Mock implements SyncScheduler {}

void main() {
  late MockNoteRepository mockRepository;
  late MockSyncScheduler mockScheduler;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValue(FakeNoteEntity());
    registerFallbackValue(SyncTrigger.manual);
  });

  setUp(() {
    mockRepository = MockNoteRepository();
    mockScheduler = MockSyncScheduler();
    when(
      () => mockRepository.watchAllNotes(),
    ).thenAnswer((_) => Stream.value([]));
    when(() => mockScheduler.requestSync(any())).thenReturn(null);

    container = ProviderContainer(
      overrides: [
        noteRepositoryProvider.overrideWithValue(mockRepository),
        syncSchedulerProvider.overrideWithValue(mockScheduler),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  test('initial state should be empty and watchAllNotes should be called', () {
    final state = container.read(noteNotifierProvider);
    expect(state.notes, isEmpty);
    verify(() => mockRepository.watchAllNotes()).called(1);
  });

  test('state updates when repository stream emits new notes', () async {
    final controller = StreamController<List<NoteEntity>>();

    when(
      () => mockRepository.watchAllNotes(),
    ).thenAnswer((_) => controller.stream);

    final note = NoteEntity(
      id: '1',
      title: 'Test Note',
      body: 'Test Content',
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
    );
    container.listen(noteNotifierProvider, (_, __) {});
    controller.add([note]);
    await Future.delayed(Duration.zero);

    final state = container.read(noteNotifierProvider);
    expect(state.notes.length, 1);
    expect(state.notes.first.note.title, 'Test Note');

    await controller.close();
  });

  test('addNote calls saveNote on repository', () {
    final note = NoteEntity(
      id: '2',
      title: 'New Note',
      body: 'New Content',
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
    );
    when(() => mockRepository.saveNote(any())).thenAnswer((_) async {});
    container.read(noteNotifierProvider.notifier).addNote(note);
    verify(() => mockRepository.saveNote(note)).called(1);
  });

  test('deleteNote awaits repository and triggers sync', () async {
    when(() => mockRepository.deleteNote(any())).thenAnswer((_) async {});
    await container.read(noteNotifierProvider.notifier).deleteNote('2');
    verify(() => mockRepository.deleteNote('2')).called(1);
    verify(() => mockScheduler.requestSync(SyncTrigger.noteDeleted)).called(1);
  });

  test('deleteNote propagates repository errors to caller without requesting sync', () async {
    when(() => mockRepository.deleteNote(any()))
        .thenThrow(Exception('disk failure'));
    expect(
      () => container.read(noteNotifierProvider.notifier).deleteNote('2'),
      throwsA(isA<Exception>()),
    );
    verifyNever(() => mockScheduler.requestSync(any()));
  });

  test('restoreNote awaits repository and triggers sync', () async {
    when(() => mockRepository.restoreNote(any())).thenAnswer((_) async {});
    await container.read(noteNotifierProvider.notifier).restoreNote('2');
    verify(() => mockRepository.restoreNote('2')).called(1);
    verify(() => mockScheduler.requestSync(SyncTrigger.noteRestored)).called(1);
  });

  test('restoreNote propagates repository errors to caller without requesting sync', () async {
    when(() => mockRepository.restoreNote(any()))
        .thenThrow(Exception('disk failure'));
    expect(
      () => container.read(noteNotifierProvider.notifier).restoreNote('2'),
      throwsA(isA<Exception>()),
    );
    verifyNever(() => mockScheduler.requestSync(any()));
  });
}
