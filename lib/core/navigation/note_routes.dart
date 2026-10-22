import 'package:cortex/features/notes/domain/note_template.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// One place that knows how to open the editor, so every entry point
/// (home, search, quick actions) uses the same route and transition.
class NoteRoutes {
  NoteRoutes._();

  static void open(BuildContext context, String noteId) {
    context.push(Uri(path: '/edit-note', queryParameters: {'id': noteId}).toString());
  }

  static void create(BuildContext context, NoteTemplate template) {
    context.push(
      Uri(path: '/edit-note', queryParameters: {'type': template.name}).toString(),
    );
  }
}
