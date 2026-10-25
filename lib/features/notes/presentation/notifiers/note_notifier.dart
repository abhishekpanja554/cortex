import 'dart:async';

import 'package:cortex/core/perf/perf.dart';
import 'package:cortex/features/notes/domain/entities/note_entity.dart';
import 'package:cortex/features/notes/domain/entities/note_list_item.dart';
import 'package:cortex/features/notes/presentation/providers/providers.dart';
import 'package:cortex/features/notes/presentation/state/notes_state.dart';
import 'package:cortex/features/sync/data/sync_scheduler.dart';
import 'package:cortex/features/sync/presentation/sync_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NoteNotifier extends Notifier<NotesState> {
  StreamSubscription<List<NoteListItem>>? _subscription;
  Stopwatch? _saveToEmissionTimer;

  bool _disposed = false;
  int _latestUpdateId = 0;
  Future<void> _updateChain = Future.value();

  @override
  NotesState build() {
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      _subscription?.cancel();
    });
    _initSubscription();
    return const NotesState(notes: []);
  }

  void _initSubscription() {
    final repo = ref.watch(noteRepositoryProvider);
    _subscription?.cancel();

    _subscription = repo.watchAllNotes().listen((items) {
      final updateId = ++_latestUpdateId;

      _updateChain = _updateChain.catchError((_) {}).then((_) async {
        if (_disposed) return;
        if (updateId < _latestUpdateId) return;

        await _handleEmission(items, updateId);
      });
    });
  }

  Future<void> _handleEmission(List<NoteListItem> items, int updateId) async {
    if (_saveToEmissionTimer != null && _saveToEmissionTimer!.isRunning) {
      _saveToEmissionTimer!.stop();
      Perf.record('notes.saveToEmission', _saveToEmissionTimer!.elapsed);
      _saveToEmissionTimer = null;
    }

    state = NotesState(notes: items);
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

  NoteEntity? getNoteById(String id) {
    try {
      final item = state.notes.firstWhere((n) => n.id == id);
      return NoteEntity(
        id: item.id,
        title: item.title,
        body: '',
        createdAt: item.createdAt,
        updatedAt: item.updatedAt,
        conflictOf: item.conflictOf,
        conflictField: item.conflictField,
      );
    } catch (_) {
      return null;
    }
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