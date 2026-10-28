import 'package:cortex/core/database/app_database_provider.dart';
import 'package:cortex/core/providers/core_providers.dart';
import 'package:cortex/features/notes/data/repositories/drift_note_repository.dart';
import 'package:cortex/features/notes/domain/entities/note_entity.dart';
import 'package:cortex/features/notes/domain/entities/note_list_item.dart';
import 'package:cortex/features/notes/domain/repositories/note_repository.dart';
import 'package:cortex/features/notes/presentation/notifiers/note_notifier.dart';
import 'package:cortex/features/notes/presentation/notifiers/search_notifier.dart';
import 'package:cortex/features/notes/presentation/state/notes_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final noteRepositoryProvider = Provider<NoteRepository>((ref) {
  return DriftNoteRepository(ref.watch(appDatabaseProvider), ref.watch(documentsDirectoryProvider));
});

final noteNotifierProvider = NotifierProvider<NoteNotifier, NotesState>(
  NoteNotifier.new,
);

final noteStreamProvider = StreamProvider.family<NoteEntity?, String>((ref, id) {
  return ref.watch(noteRepositoryProvider).watchNote(id);
});

final conflictCopiesProvider = StreamProvider.family<List<NoteEntity>, String>((ref, noteId) {
  return ref.watch(noteRepositoryProvider).watchConflictCopies(noteId);
});

final noteByIdProvider = FutureProvider.family<NoteEntity?, String>((ref, id) {
  return ref.watch(noteNotifierProvider.notifier).getNote(id);
});

final searchNotifierProvider = NotifierProvider<SearchNotifier, SearchState>(
  SearchNotifier.new,
);

final searchResultsProvider = FutureProvider.family<List<NoteListItem>, String>((ref, query) {
  final q = query.trim();
  if (q.isEmpty) return Future.value(const <NoteListItem>[]);
  return ref.watch(noteRepositoryProvider).searchNotes(q);
});
