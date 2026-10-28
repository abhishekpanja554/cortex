import '../entities/note_entity.dart';
import '../entities/note_list_item.dart';

abstract interface class NoteRepository {
  Future<void> saveNote(NoteEntity note);
  Stream<List<NoteListItem>> watchAllNotes({required int limit});
  Stream<int> watchNoteCount();
  Future<NoteEntity?> getNote(String id);
  Stream<NoteEntity?> watchNote(String id);
  Stream<List<NoteEntity>> watchConflictCopies(String noteId);
  Future<List<NoteListItem>> searchNotes(String query);
  Future<void> deleteNote(String id);
  Future<void> restoreNote(String id);
  Future<void> wipeAll();
  Future<int> unsyncedCount();
  Future<List<NoteEntity>> getAllNotesForExport();
}
