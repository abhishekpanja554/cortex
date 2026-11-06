import 'dart:async';

import 'package:cortex/features/notes/domain/entities/note_list_item.dart';
import 'package:cortex/features/notes/domain/repositories/note_repository.dart';
import 'package:cortex/features/notes/presentation/providers/providers.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockNoteRepository extends Mock implements NoteRepository {}

NoteListItem _testItem(String id, {String title = 'Title'}) {
  final now = DateTime.utc(2026, 1, 1);
  return NoteListItem(
    id: id,
    title: title,
    previewText: 'Preview',
    previewTodos: '[]',
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  late MockNoteRepository mockRepository;
  late ProviderContainer container;

  setUp(() {
    mockRepository = MockNoteRepository();
    container = ProviderContainer(
      overrides: [
        noteRepositoryProvider.overrideWithValue(mockRepository),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('SearchNotifier pause-before-search (debounce)', () {
    test('typing "project" quickly runs exactly one query, for "project"', () {
      fakeAsync((async) {
        final queryHistory = <String>[];
        when(() => mockRepository.searchNotes(any())).thenAnswer((invocation) async {
          final q = invocation.positionalArguments.first as String;
          queryHistory.add(q);
          return [_testItem('1', title: 'Result for $q')];
        });

        final notifier = container.read(searchNotifierProvider.notifier);

        // Simulate typing "project" with 40ms between keystrokes
        const word = 'project';
        for (var i = 1; i <= word.length; i++) {
          final partial = word.substring(0, i);
          notifier.onQueryChanged(partial);
          async.elapse(const Duration(milliseconds: 40));
        }

        // Before 250ms have elapsed since the last keystroke ('t'), no queries have run
        expect(queryHistory, isEmpty, reason: 'Debounce should prevent premature queries');

        // Now elapse the remaining 210ms (40ms elapsed since 'project' + 210ms = 250ms)
        async.elapse(const Duration(milliseconds: 210));

        // Exactly one query should have run, specifically for "project"
        expect(queryHistory, equals(['project']));
        verify(() => mockRepository.searchNotes('project')).called(1);
        verifyNoMoreInteractions(mockRepository);

        final state = container.read(searchNotifierProvider);
        expect(state.results.length, 1);
        expect(state.results.first.title, 'Result for project');
        expect(state.isLoading, isFalse);
      });
    });

    test('latest-wins drops older, slower results so they cannot overwrite newer ones', () {
      fakeAsync((async) {
        final completer1 = Completer<List<NoteListItem>>();
        final completer2 = Completer<List<NoteListItem>>();

        when(() => mockRepository.searchNotes('first')).thenAnswer((_) => completer1.future);
        when(() => mockRepository.searchNotes('second')).thenAnswer((_) => completer2.future);

        final notifier = container.read(searchNotifierProvider.notifier);

        // Type 'first' and wait for debounce timer to fire
        notifier.onQueryChanged('first');
        async.elapse(const Duration(milliseconds: 250));
        // Search 1 is now in flight

        // Type 'second' and wait for debounce timer to fire
        notifier.onQueryChanged('second');
        async.elapse(const Duration(milliseconds: 250));
        // Search 2 is now in flight

        // Complete search 2 first (newer search wins)
        final results2 = [_testItem('2', title: 'Second Result')];
        completer2.complete(results2);
        async.elapse(Duration.zero);

        expect(container.read(searchNotifierProvider).results, equals(results2));
        expect(container.read(searchNotifierProvider).results.first.title, 'Second Result');

        // Now older search 1 completes late (should be dropped!)
        final results1 = [_testItem('1', title: 'First Result')];
        completer1.complete(results1);
        async.elapse(Duration.zero);

        // State must STILL show search 2's results, not overwritten by search 1
        expect(container.read(searchNotifierProvider).results, equals(results2));
        expect(container.read(searchNotifierProvider).results.first.title, 'Second Result');
      });
    });

    test('empty or whitespace query clears results immediately and cancels pending timer', () {
      fakeAsync((async) {
        when(() => mockRepository.searchNotes(any())).thenAnswer((_) async => []);

        final notifier = container.read(searchNotifierProvider.notifier);

        notifier.onQueryChanged('test');
        async.elapse(const Duration(milliseconds: 100));

        // User clears input before 250ms
        notifier.onQueryChanged('');
        expect(container.read(searchNotifierProvider).query, '');
        expect(container.read(searchNotifierProvider).results, isEmpty);
        expect(container.read(searchNotifierProvider).isLoading, isFalse);

        // Wait another 300ms
        async.elapse(const Duration(milliseconds: 300));

        // searchNotes was never called
        verifyNever(() => mockRepository.searchNotes(any()));
      });
    });

    test('clear() cancels debounce and resets state', () {
      fakeAsync((async) {
        when(() => mockRepository.searchNotes(any())).thenAnswer((_) async => []);

        final notifier = container.read(searchNotifierProvider.notifier);
        notifier.onQueryChanged('typing');
        async.elapse(const Duration(milliseconds: 100));

        notifier.clear();
        final state = container.read(searchNotifierProvider);
        expect(state.query, '');
        expect(state.results, isEmpty);
        expect(state.isLoading, isFalse);

        async.elapse(const Duration(milliseconds: 300));
        verifyNever(() => mockRepository.searchNotes(any()));
      });
    });

    test('slower "proj" in flight does not show results while query is already "project"', () {
      fakeAsync((async) {
        final projCompleter = Completer<List<NoteListItem>>();
        when(() => mockRepository.searchNotes('proj')).thenAnswer((_) => projCompleter.future);
        when(() => mockRepository.searchNotes('project')).thenAnswer((_) async => [_testItem('2', title: 'Project Note')]);

        final notifier = container.read(searchNotifierProvider.notifier);

        // User types 'proj' and debounce timer fires
        notifier.onQueryChanged('proj');
        async.elapse(const Duration(milliseconds: 250));
        // 'proj' search is now in-flight

        // User types 'project' before 'proj' finishes
        notifier.onQueryChanged('project');
        // 'proj' completes now (before 'project' debounce fires)
        projCompleter.complete([_testItem('1', title: 'Proj Note')]);
        async.elapse(Duration.zero);

        // 'proj' results must be dropped because _latestSearchId increased on onQueryChanged('project')
        expect(container.read(searchNotifierProvider).results, isEmpty);
        expect(container.read(searchNotifierProvider).query, 'project');

        // Now let 'project' debounce fire
        async.elapse(const Duration(milliseconds: 250));
        expect(container.read(searchNotifierProvider).results.length, 1);
        expect(container.read(searchNotifierProvider).results.first.title, 'Project Note');
      });
    });

    test('if searchNotes throws, isLoading resets to false', () {
      fakeAsync((async) {
        when(() => mockRepository.searchNotes('fail')).thenThrow(Exception('database error'));

        final notifier = container.read(searchNotifierProvider.notifier);
        notifier.onQueryChanged('fail');
        expect(container.read(searchNotifierProvider).isLoading, isTrue);

        async.elapse(const Duration(milliseconds: 250));

        final state = container.read(searchNotifierProvider);
        expect(state.isLoading, isFalse);
        expect(state.results, isEmpty);
      });
    });
  });
}
