import 'dart:async';
import 'package:cortex/core/perf/perf.dart';
import 'package:cortex/features/notes/domain/entities/note_entity.dart';
import 'package:cortex/features/notes/domain/entities/note_list_item.dart';
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

NoteListItem _testItem(String id, {String title = 'Title', String preview = 'Preview'}) {
  final now = DateTime.utc(2026, 1, 1);
  return NoteListItem(
    id: id,
    title: title,
    previewText: preview,
    previewTodos: '[]',
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  late MockNoteRepository mockRepository;
  late MockSyncScheduler mockScheduler;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValue(FakeNoteEntity());
    registerFallbackValue(SyncTrigger.manual);
  });

  setUp(() {
    Perf.reset();
    mockRepository = MockNoteRepository();
    mockScheduler = MockSyncScheduler();
    when(
      () => mockRepository.watchAllNotes(limit: any(named: 'limit')),
    ).thenAnswer((_) => Stream.value([]));
    when(
      () => mockRepository.watchNoteCount(),
    ).thenAnswer((_) => Stream.value(0));
    when(() => mockScheduler.requestSync(any())).thenReturn(null);

    container = ProviderContainer(
      overrides: [
        noteRepositoryProvider.overrideWithValue(mockRepository),
        syncSchedulerProvider.overrideWithValue(mockScheduler),
      ],
    );
  });

  tearDown(() {
    Perf.reset();
    container.dispose();
  });

  test('initial state should be empty and watchAllNotes should be called with limit 100', () {
    final state = container.read(noteNotifierProvider);
    expect(state.notes, isEmpty);
    expect(state.limit, 100);
    expect(state.totalCount, 0);
    verify(() => mockRepository.watchAllNotes(limit: 100)).called(1);
    verify(() => mockRepository.watchNoteCount()).called(1);
  });

  test('state updates when repository stream emits new items', () async {
    final controller = StreamController<List<NoteListItem>>();

    when(
      () => mockRepository.watchAllNotes(limit: any(named: 'limit')),
    ).thenAnswer((_) => controller.stream);

    final item = _testItem('1', title: 'Test Note', preview: 'Test Content');
    container.listen(noteNotifierProvider, (_, __) {});
    controller.add([item]);
    await Future.delayed(Duration.zero);

    final state = container.read(noteNotifierProvider);
    expect(state.notes.length, 1);
    expect(state.notes.first.title, 'Test Note');
    expect(state.notes.first.previewText, 'Test Content');

    await controller.close();
  });

  test('watchNoteCount updates totalCount in state', () async {
    final countController = StreamController<int>();
    when(
      () => mockRepository.watchNoteCount(),
    ).thenAnswer((_) => countController.stream);

    container = ProviderContainer(
      overrides: [
        noteRepositoryProvider.overrideWithValue(mockRepository),
        syncSchedulerProvider.overrideWithValue(mockScheduler),
      ],
    );
    container.listen(noteNotifierProvider, (_, __) {});

    countController.add(250);
    await Future.delayed(Duration.zero);

    final state = container.read(noteNotifierProvider);
    expect(state.totalCount, 250);
    expect(state.hasMore, isTrue);

    await countController.close();
  });

  test('loadMore increases limit by 100 and restarts watch with new limit', () async {
    final countController = StreamController<int>.broadcast();
    final notesController1 = StreamController<List<NoteListItem>>.broadcast();
    final notesController2 = StreamController<List<NoteListItem>>.broadcast();

    when(
      () => mockRepository.watchNoteCount(),
    ).thenAnswer((_) => countController.stream);

    when(
      () => mockRepository.watchAllNotes(limit: 100),
    ).thenAnswer((_) => notesController1.stream);

    when(
      () => mockRepository.watchAllNotes(limit: 200),
    ).thenAnswer((_) => notesController2.stream);

    container = ProviderContainer(
      overrides: [
        noteRepositoryProvider.overrideWithValue(mockRepository),
        syncSchedulerProvider.overrideWithValue(mockScheduler),
      ],
    );
    container.listen(noteNotifierProvider, (_, __) {});

    countController.add(250);
    await Future.delayed(Duration.zero);

    final notifier = container.read(noteNotifierProvider.notifier);
    expect(container.read(noteNotifierProvider).limit, 100);

    notifier.loadMore();

    expect(container.read(noteNotifierProvider).limit, 200);
    verify(() => mockRepository.watchAllNotes(limit: 200)).called(1);

    await countController.close();
    await notesController1.close();
    await notesController2.close();
  });

  test('getNote delegates to repository getNote', () async {
    final expectedNote = NoteEntity(
      id: 'repo-note-1',
      title: 'Repo Note',
      body: 'Full Note Body',
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
    );
    when(() => mockRepository.getNote('repo-note-1')).thenAnswer((_) async => expectedNote);

    final result = await container.read(noteNotifierProvider.notifier).getNote('repo-note-1');
    expect(result, equals(expectedNote));
    verify(() => mockRepository.getNote('repo-note-1')).called(1);
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

  test('updateNote calls saveNote on repository', () {
    final note = NoteEntity(
      id: '2',
      title: 'Updated Note',
      body: 'Updated Content',
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
    );
    when(() => mockRepository.saveNote(any())).thenAnswer((_) async {});
    container.read(noteNotifierProvider.notifier).updateNote(note);
    verify(() => mockRepository.saveNote(note)).called(1);
  });

  test('deleteNote awaits repository and triggers sync', () async {
    when(() => mockRepository.deleteNote(any())).thenAnswer((_) async {});
    await container.read(noteNotifierProvider.notifier).deleteNote('2');
    verify(() => mockRepository.deleteNote('2')).called(1);
  });

  test('deleteNote starts saveToEmission stopwatch', () async {
    when(() => mockRepository.deleteNote(any())).thenAnswer((_) async {});

    final controller = StreamController<List<NoteListItem>>();
    when(() => mockRepository.watchAllNotes(limit: any(named: 'limit'))).thenAnswer((_) => controller.stream);

    container.listen(noteNotifierProvider, (_, __) {});

    await container.read(noteNotifierProvider.notifier).deleteNote('2');

    // Emit updated notes to trigger emission handler and stop timer
    controller.add([]);
    await Future.delayed(Duration.zero);

    final summary = Perf.summary();
    expect(summary.containsKey('notes.saveToEmission'), isTrue);

    await controller.close();
  });

  test('restoreNote calls restoreNote on repository', () async {
    when(() => mockRepository.restoreNote(any())).thenAnswer((_) async {});
    await container.read(noteNotifierProvider.notifier).restoreNote('2');
    verify(() => mockRepository.restoreNote('2')).called(1);
  });

  test('getNoteById returns matching note from state', () async {
    final controller = StreamController<List<NoteListItem>>();
    when(() => mockRepository.watchAllNotes(limit: any(named: 'limit'))).thenAnswer((_) => controller.stream);

    final item = _testItem('target-id', title: 'Target Title');
    container.listen(noteNotifierProvider, (_, __) {});
    controller.add([item]);
    await Future.delayed(Duration.zero);

    final notifier = container.read(noteNotifierProvider.notifier);
    final found = notifier.getNoteById('target-id');
    expect(found, isNotNull);
    expect(found!.id, 'target-id');
    expect(found.title, 'Target Title');

    expect(notifier.getNoteById('missing-id'), isNull);

    await controller.close();
  });

  test('saveToEmission stopwatch records notes.saveToEmission on update', () async {
    when(() => mockRepository.saveNote(any())).thenAnswer((_) async {});

    final controller = StreamController<List<NoteListItem>>();
    when(() => mockRepository.watchAllNotes(limit: any(named: 'limit'))).thenAnswer((_) => controller.stream);

    container.listen(noteNotifierProvider, (_, __) {});

    final note = NoteEntity(
      id: 'save-timer-note',
      title: 'Timer Note',
      body: 'Timer Content',
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
    );

    container.read(noteNotifierProvider.notifier).addNote(note);

    controller.add([_testItem('save-timer-note')]);
    await Future.delayed(Duration.zero);

    final summary = Perf.summary();
    expect(summary.containsKey('notes.saveToEmission'), isTrue);
    expect(summary['notes.saveToEmission']!.samples, 1);

    await controller.close();
  });

  test('startup stopwatch records startup.toFirstList on first notes update handled', () async {
    Perf.reset();
    Perf.startStartupWatch();

    final controller = StreamController<List<NoteListItem>>();
    when(() => mockRepository.watchAllNotes(limit: any(named: 'limit'))).thenAnswer((_) => controller.stream);

    container.listen(noteNotifierProvider, (_, __) {});
    controller.add([_testItem('startup-note')]);
    await Future.delayed(Duration.zero);

    final summary = Perf.summary();
    expect(summary.containsKey('startup.toFirstList'), isTrue);
    expect(summary['startup.toFirstList']!.samples, 1);

    // Subsequent update should NOT add another sample
    controller.add([_testItem('startup-note'), _testItem('startup-note-2')]);
    await Future.delayed(Duration.zero);

    final summaryAfterSecond = Perf.summary();
    expect(summaryAfterSecond['startup.toFirstList']!.samples, 1);

    await controller.close();
  });
}
