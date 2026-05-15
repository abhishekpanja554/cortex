import 'package:cortex/features/notes/data/models/note_isar_model.dart';
import 'package:cortex/features/notes/domain/entities/note.dart' as domain;
import 'package:cortex/features/security/services/security_service.dart';
import 'package:isar_community/isar.dart';

class IsarNoteRepository {
  final Isar _isar;
  final SecurityService _securityService;

  IsarNoteRepository(this._isar, this._securityService);

  Future<void> saveNote(domain.Note note) async {
    try {
      final title = await _securityService.encryptData(note.title);
      final content = await _securityService.encryptData(note.content);

      final encryptedBlocks = <domain.Block>[];
      for (final b in note.blocks) {
        if (b is domain.TextBlock) {
          encryptedBlocks.add(
            b.copyWith(data: await _securityService.encryptData(b.data)),
          );
        } else if (b is domain.CheckboxBlock) {
          encryptedBlocks.add(
            b.copyWith(data: await _securityService.encryptData(b.data)),
          );
        } else {
          encryptedBlocks.add(b);
        }
      }

      final encryptedNote = note.copyWith(
        title: title,
        content: content,
        blocks: encryptedBlocks,
      );

      final isarNote = encryptedNote.toIsar();

      await _isar.writeTxn(() async {
        await _isar.isarNotes.putByUuid(isarNote);
      });
    } catch (e) {
      throw Exception('Failed to save note: $e');
    }
  }

  Stream<List<domain.Note>> watchAllNotes() {
    try {
      return _isar.isarNotes.where().watch(fireImmediately: true).asyncMap((
        isarNotes,
      ) async {
        final decryptedNotes = <domain.Note>[];

        for (final isarNote in isarNotes) {
          try {
            final domainNote = isarNote.toDomain();

            final title = await _securityService.decryptData(domainNote.title);
            final content = await _securityService.decryptData(
              domainNote.content,
            );

            final decryptedBlocks = <domain.Block>[];
            for (final b in domainNote.blocks) {
              if (b is domain.TextBlock) {
                decryptedBlocks.add(
                  b.copyWith(data: await _securityService.decryptData(b.data)),
                );
              } else if (b is domain.CheckboxBlock) {
                decryptedBlocks.add(
                  b.copyWith(data: await _securityService.decryptData(b.data)),
                );
              } else {
                decryptedBlocks.add(b);
              }
            }

            decryptedNotes.add(
              domainNote.copyWith(
                title: title,
                content: content,
                blocks: decryptedBlocks,
              ),
            );
          } catch (e) {
            // Skip corrupted or un-decryptable note gracefully
            continue;
          }
        }

        return decryptedNotes;
      });
    } catch (e) {
      throw Exception('Failed to watch notes: $e');
    }
  }

  Future<void> deleteNote(String id) async {
    try {
      await _isar.writeTxn(() async {
        await _isar.isarNotes.deleteByUuid(id);
      });
    } catch (e) {
      throw Exception('Failed to delete note: $e');
    }
  }
}
