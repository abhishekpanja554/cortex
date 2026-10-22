import 'package:cortex/core/constants/string_constants.dart';
import 'package:cortex/features/notes/domain/entities/note_entity.dart';
import 'package:cortex/features/notes/presentation/providers/providers.dart';
import 'package:cortex/features/sync/presentation/sync_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shared note actions so delete/undo behaves the same from the list,
/// search results and the editor.
class NoteActions {
  NoteActions._();

  /// Uses the [ProviderContainer] rather than a widget `ref`, because the
  /// Undo tap can arrive after the calling widget (e.g. the editor) is gone.
  static void deleteWithUndo({
    required ProviderContainer container,
    required ScaffoldMessengerState messenger,
    required NoteEntity note,
  }) {
    container.read(noteNotifierProvider.notifier).deleteNote(note.id);

    // Promptly push tombstone once the undo grace period (6s) expires,
    // if the user does not tap Undo.
    Future.delayed(const Duration(milliseconds: 6500), () {
      container.read(syncSchedulerProvider).requestSync();
    });

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 4),
          content: const Text(AppStrings.noteDeleted),
          action: SnackBarAction(
            label: AppStrings.undo,
            onPressed: () {
              container.read(noteNotifierProvider.notifier).restoreNote(note.id);
              container.read(syncSchedulerProvider).requestSync();
            },
          ),
        ),
      );
  }
}
