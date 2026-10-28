import 'dart:async';

import 'package:cortex/core/perf/perf.dart';
import 'package:cortex/features/notes/domain/entities/note_entity.dart';
import 'package:cortex/features/notes/domain/entities/note_list_item.dart';
import 'package:cortex/features/notes/domain/repositories/note_repository.dart';
import 'package:cortex/features/notes/presentation/providers/providers.dart';
import 'package:cortex/features/notes/presentation/state/notes_state.dart';
import 'package:cortex/features/sync/data/sync_scheduler.dart';
import 'package:cortex/features/sync/presentation/sync_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NoteNotifier extends Notifier<NotesState> {
  StreamSubscription<List<NoteListItem>>? _notesSubscription;
  StreamSubscription<int>? _countSubscription;
  Stopwatch? _saveToEmissionTimer;

  bool _disposed = false;
  int _latestUpdateId = 0;
  Future<void> _updateChain = Future.value();
  int _limit = 100;
  int _totalCount = 0;

  @override
  NotesState build() {
    _disposed = false;
    _limit = 100;
    _totalCount = 0;
    ref.onDispose(() {
      _disposed = true;
      _notesSubscription?.cancel();
      _countSubscription?.cancel();
    });
    _initSubscriptions();
    return NotesState(notes: const [], totalCount: 0, limit: _limit);
  }

  void _initSubscriptions() {
    final repo = ref.watch(noteRepositoryProvider);
    _countSubscription?.cancel();
    _countSubscription = repo.watchNoteCount().listen((count) {
      if (_disposed) return;
      _totalCount = count;
      state = state.copyWith(totalCount: count);
    });

    _restartNotesWatch(repo);
  }

  void _restartNotesWatch([NoteRepository? repo]) {
    final NoteRepository r = repo ?? ref.read(noteRepositoryProvider);
    _notesSubscription?.cancel();
    _notesSubscription = r.watchAllNotes(limit: _limit).listen((items) {
      final updateId = ++_latestUpdateId;

      _updateChain = _updateChain.catchError((_) {}).then((_) async {
        if (_disposed) return;
        if (updateId < _latestUpdateId) return;

        await _handleEmission(items, updateId);
      });
    });
  }

  void loadMore() {
    if (state.notes.length >= _totalCount && _totalCount > 0) return;
    _limit += 100;
    state = state.copyWith(limit: _limit);
    _restartNotesWatch();
  }

  Future<void> _handleEmission(List<NoteListItem> items, int updateId) async {
    if (_saveToEmissionTimer != null && _saveToEmissionTimer!.isRunning) {
      _saveToEmissionTimer!.stop();
      Perf.record('notes.saveToEmission', _saveToEmissionTimer!.elapsed);
      _saveToEmissionTimer = null;
    }

    state = state.copyWith(notes: items, totalCount: _totalCount, limit: _limit);
    Perf.markFirstListHandled();
  }

  void addNote(NoteEntity note) {
    _saveToEmissionTimer = Stopwatch()..start();
    ref.read(noteRepositoryProvider).saveNote(note);
  }

  void updateNote(NoteEntity updatedNote) {
    _saveToEmissionTimer = Stopwatch()..start();
    ref.read(noteRepositoryProvider).saveNote(updatedNote);
  }

  Future<NoteEntity?> getNote(String id) {
    return ref.read(noteRepositoryProvider).getNote(id);
  }

  NoteListItem? getNoteById(String id) {
    return state.notes.where((n) => n.id == id).firstOrNull;
  }

  Future<void> deleteNote(String id) async {
    _saveToEmissionTimer = Stopwatch()..start();
    await ref.read(noteRepositoryProvider).deleteNote(id);
    ref.read(syncSchedulerProvider).requestSync(SyncTrigger.noteDeleted);
  }

  Future<void> restoreNote(String id) async {
    _saveToEmissionTimer = Stopwatch()..start();
    await ref.read(noteRepositoryProvider).restoreNote(id);
    ref.read(syncSchedulerProvider).requestSync(SyncTrigger.noteRestored);
  }
}