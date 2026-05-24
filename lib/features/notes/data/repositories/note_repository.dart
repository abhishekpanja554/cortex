import 'package:cortex/features/notes/data/models/note_isar_model.dart';
import 'package:cortex/features/notes/domain/entities/note.dart' as domain;
import 'package:cortex/features/security/services/security_service.dart';
import 'package:isar_community/isar.dart';

class IsarNoteRepository {
  final Isar _isar;
  final SecurityService _securityService;
  final Map<String, _DecryptedCacheEntry> _decryptedCache = {};

  IsarNoteRepository(this._isar, this._securityService);

  Future<void> saveNote(domain.Note note) async {
    try {
      _decryptedCache.remove(note.id); // Invalidate cache entry
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
        final results = await Future.wait(
          isarNotes.map((isarNote) async {
            final uuid = isarNote.uuid;
            if (uuid != null) {
              final cached = _decryptedCache[uuid];
              if (cached != null &&
                  cached.updatedAt == isarNote.updatedAt &&
                  cached.createdAt == isarNote.createdAt) {
                return cached.note;
              }
            }

            try {
              final domainNote = isarNote.toDomain();

              // Decrypt title and content concurrently
              final titleFuture = _securityService.decryptData(domainNote.title);
              final contentFuture = _securityService.decryptData(domainNote.content);

              // Decrypt blocks concurrently
              final blocksFuture = Future.wait(
                domainNote.blocks.map((b) async {
                  if (b is domain.TextBlock) {
                    final decryptedData = await _securityService.decryptData(b.data);
                    return b.copyWith(data: decryptedData);
                  } else if (b is domain.CheckboxBlock) {
                    final decryptedData = await _securityService.decryptData(b.data);
                    return b.copyWith(data: decryptedData);
                  } else {
                    return b;
                  }
                }),
              );

              final decryptedTitle = await titleFuture;
              final decryptedContent = await contentFuture;
              final decryptedBlocks = await blocksFuture;

              final decryptedNote = domainNote.copyWith(
                title: decryptedTitle,
                content: decryptedContent,
                blocks: decryptedBlocks,
              );

              if (uuid != null) {
                _decryptedCache[uuid] = _DecryptedCacheEntry(
                  note: decryptedNote,
                  updatedAt: isarNote.updatedAt,
                  createdAt: isarNote.createdAt,
                );
              }

              return decryptedNote;
            } catch (e) {
              // Skip corrupted or un-decryptable note gracefully
              return null;
            }
          }),
        );

        return results.whereType<domain.Note>().toList();
      });
    } catch (e) {
      throw Exception('Failed to watch notes: $e');
    }
  }

  Future<void> deleteNote(String id) async {
    try {
      _decryptedCache.remove(id); // Invalidate cache entry
      await _isar.writeTxn(() async {
        await _isar.isarNotes.deleteByUuid(id);
      });
    } catch (e) {
      throw Exception('Failed to delete note: $e');
    }
  }
}

class _DecryptedCacheEntry {
  final domain.Note note;
  final DateTime? updatedAt;
  final DateTime? createdAt;

  _DecryptedCacheEntry({
    required this.note,
    this.updatedAt,
    this.createdAt,
  });
}
