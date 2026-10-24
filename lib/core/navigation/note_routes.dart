import 'package:cortex/features/notes/domain/note_template.dart';
import 'package:cortex/features/notes/presentation/providers/providers.dart';
import 'package:cortex/features/sync/presentation/sync_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// One place that knows how to open the editor, so every entry point
/// (home, search, quick actions) uses the same route and transition.
class NoteRoutes {
  NoteRoutes._();

  static void open(BuildContext context, String noteId) {
    context.push(Uri(path: '/edit-note', queryParameters: {'id': noteId}).toString());
  }

  /// Checks if the note exists locally before opening the editor.
  /// If the note is not found on this device (e.g. created on another device or deleted),
  /// triggers a sync and alerts the user rather than opening an empty editor that
  /// causes duplicate conflicts.
  static void openOrSync(BuildContext context, WidgetRef ref, String noteId) {
    final note = ref.read(noteNotifierProvider.notifier).getNoteById(noteId);
    if (note == null) {
      ref.read(syncSchedulerProvider).requestSync();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("This note isn't on this device yet. Syncing…"),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }
    open(context, noteId);
  }

  static void create(BuildContext context, NoteTemplate template) {
    context.push(
      Uri(path: '/edit-note', queryParameters: {'type': template.name}).toString(),
    );
  }

  static void openChat(BuildContext context) {
    context.push('/chat');
  }

  static void openAgentChat(BuildContext context) {
    context.push('/agent-chat');
  }
}
