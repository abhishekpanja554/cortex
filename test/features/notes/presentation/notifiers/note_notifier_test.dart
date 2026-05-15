import 'dart:async';
import 'package:cortex/features/notes/data/repositories/note_repository.dart';
import 'package:cortex/features/notes/domain/entities/note.dart';
import 'package:cortex/features/notes/presentation/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockNoteRepository extends Mock implements IsarNoteRepository {}

class FakeNote extends Fake implements Note {}

void main() {
  late MockNoteRepository mockRepository;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValue(FakeNote());
  });

  setUp(() {
    mockRepository = MockNoteRepository();

    // Set up the default stream behavior for the mock
    when(
      () => mockRepository.watchAllNotes(),
    ).thenAnswer((_) => Stream.value([]));

    container = ProviderContainer(
      overrides: [noteRepositoryProvider.overrideWithValue(mockRepository)],
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
    final controller = StreamController<List<Note>>();

    when(
      () => mockRepository.watchAllNotes(),
    ).thenAnswer((_) => controller.stream);

    final note = Note(
      id: '1',
      title: 'Test Note',
      content: 'Test Content',
      createdAt: DateTime.now(),
    );

    // Watch the provider to trigger build()
    container.listen(noteNotifierProvider, (_, __) {});

    // Emitting notes
    controller.add([note]);

    // Wait for stream to process
    await Future.delayed(Duration.zero);

    final state = container.read(noteNotifierProvider);
    expect(state.notes.length, 1);
    expect(state.notes.first.title, 'Test Note');

    await controller.close();
  });

  test('addNote calls saveNote on repository', () {
    final note = Note(
      id: '2',
      title: 'New Note',
      content: 'New Content',
      createdAt: DateTime.now(),
    );

    when(() => mockRepository.saveNote(any())).thenAnswer((_) async {});

    container.read(noteNotifierProvider.notifier).addNote(note);

    verify(() => mockRepository.saveNote(note)).called(1);
  });

  test('deleteNote calls deleteNote on repository', () {
    when(() => mockRepository.deleteNote(any())).thenAnswer((_) async {});

    container.read(noteNotifierProvider.notifier).deleteNote('2');

    verify(() => mockRepository.deleteNote('2')).called(1);
  });
}
