import 'package:cortex/core/database/app_database_provider.dart';
import 'package:cortex/features/notes/data/repositories/drift_note_repository.dart';
import 'package:cortex/features/notes/domain/repositories/note_repository.dart';
import 'package:cortex/features/notes/presentation/notifiers/note_notifier.dart';
import 'package:cortex/features/notes/presentation/state/notes_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final noteRepositoryProvider = Provider<NoteRepository>((ref) {
  return DriftNoteRepository(ref.watch(appDatabaseProvider));
});

final noteNotifierProvider = NotifierProvider<NoteNotifier, NotesState>(
  NoteNotifier.new,
);
