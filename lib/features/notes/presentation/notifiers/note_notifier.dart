import 'dart:async';

import 'package:cortex/features/notes/presentation/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/notes_state.dart';
import '../../../notes/domain/entities/note.dart';

class NoteNotifier extends Notifier<NotesState> {
  StreamSubscription<List<Note>>? _subscription;

  @override
  NotesState build() {
    _initSubscription();
    return const NotesState(notes: []);
  }

  void _initSubscription() {
    final repo = ref.watch(noteRepositoryProvider);
    _subscription?.cancel();
    _subscription = repo.watchAllNotes().listen((notes) {
      state = NotesState(notes: notes);
    });
  }

  void addNote(Note note) {
    ref.read(noteRepositoryProvider).saveNote(note);
  }

  void updateNote(Note updatedNote) {
    ref.read(noteRepositoryProvider).saveNote(updatedNote);
  }

  Note? getNoteById(String id) {
    try {
      return state.notes.firstWhere((n) => n.id == id);
    } catch (_) {
      return null;
    }
  }

  void deleteNote(String id) {
    ref.read(noteRepositoryProvider).deleteNote(id);
  }
}

