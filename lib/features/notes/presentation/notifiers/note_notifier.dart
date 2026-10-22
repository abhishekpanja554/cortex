import 'dart:async';

import 'package:cortex/features/notes/domain/note_body_codec.dart';
import 'package:cortex/features/notes/presentation/providers/providers.dart';
import 'package:cortex/features/sync/data/sync_scheduler.dart';
import 'package:cortex/features/sync/presentation/sync_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/notes_state.dart';
import '../../domain/entities/note_entity.dart';

class NoteNotifier extends Notifier<NotesState> {
  StreamSubscription<List<NoteEntity>>? _subscription;
  static const _codec = NoteBodyCodec();

  @override
  NotesState build() {
    ref.onDispose(() {
      _subscription?.cancel();
    });
    _initSubscription();
    return const NotesState(notes: []);
  }

  void _initSubscription() {
    final repo = ref.watch(noteRepositoryProvider);
    _subscription?.cancel();
    _subscription = repo.watchAllNotes().listen((entities) {
      final previews = entities.map((e) {
        final blocks = _codec.parse(e.body);
        final plainText = blocks
            .whereType<TextBlock>()
            .map((b) => b.data)
            .join('\n')
            .trim();
        final firstImage = blocks.whereType<ImageBlock>().firstOrNull?.data;
        final topTodos = blocks.whereType<CheckboxBlock>().take(3).toList();

        return NotePreview(
          note: e,
          blocks: blocks,
          plainText: plainText,
          firstImagePath: firstImage,
          topTodos: topTodos,
        );
      }).toList();
      state = NotesState(notes: previews);
    });
  }

  void addNote(NoteEntity note) {
    ref.read(noteRepositoryProvider).saveNote(note);
  }

  void updateNote(NoteEntity updatedNote) {
    ref.read(noteRepositoryProvider).saveNote(updatedNote);
  }

  NoteEntity? getNoteById(String id) {
    try {
      return state.notes.firstWhere((n) => n.note.id == id).note;
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteNote(String id) async {
    await ref.read(noteRepositoryProvider).deleteNote(id);
    ref.read(syncSchedulerProvider).requestSync(SyncTrigger.noteDeleted);
  }

  Future<void> restoreNote(String id) async {
    await ref.read(noteRepositoryProvider).restoreNote(id);
    ref.read(syncSchedulerProvider).requestSync(SyncTrigger.noteRestored);
  }
}
