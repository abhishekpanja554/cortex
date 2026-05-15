import 'package:cortex/core/database/isar_provider.dart';
import 'package:cortex/features/notes/data/repositories/note_repository.dart';
import 'package:cortex/features/notes/presentation/notifiers/note_notifier.dart';
import 'package:cortex/features/notes/presentation/state/notes_state.dart';
import 'package:cortex/features/security/services/security_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final securityServiceProvider = Provider<SecurityService>((ref) {
  return SecurityService();
});

final noteRepositoryProvider = Provider<IsarNoteRepository>((ref) {
  final isar = ref.watch(isarProvider);
  final securityService = ref.watch(securityServiceProvider);
  return IsarNoteRepository(isar, securityService);
});

final noteNotifierProvider = NotifierProvider<NoteNotifier, NotesState>(
  NoteNotifier.new,
);
