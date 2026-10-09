import '../entities/note_entity.dart';

abstract interface class NoteRepository {
  Future<void> saveNote(NoteEntity note);
  Stream<List<NoteEntity>> watchAllNotes();
  Future<void> deleteNote(String id);
  Future<void> wipeAll();
  Future<int> unsyncedCount();
}
