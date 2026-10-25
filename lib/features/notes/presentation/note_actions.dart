import 'package:cortex/core/constants/string_constants.dart';
import 'package:cortex/features/notes/presentation/providers/providers.dart';
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
    required dynamic note,
  }) {
    final String id = note is String ? note : (note as dynamic).id as String;
    container.read(noteNotifierProvider.notifier).deleteNote(id);

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 4),
          persist: false,
          content: const Text(AppStrings.noteDeleted),
          action: SnackBarAction(
            label: AppStrings.undo,
            onPressed: () {
              container.read(noteNotifierProvider.notifier).restoreNote(note.id);
            },
          ),
        ),
      );
  }
}
