import 'package:cortex/features/notes/domain/entities/note_entity.dart';
import 'package:cortex/features/notes/domain/repositories/note_repository.dart';
import 'package:cortex/features/notes/presentation/providers/providers.dart';
import 'package:cortex/features/notes/presentation/screens/edit_note_screen.dart';
import 'package:cortex/features/notes/presentation/state/notes_state.dart';
import 'package:cortex/features/sync/data/sync_scheduler.dart';
import 'package:cortex/features/sync/presentation/sync_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockNoteRepository extends Mock implements NoteRepository {}

class _MockSyncScheduler extends Mock implements SyncScheduler {}

void main() {
  // On a phone, real font metrics with the body line height can leave a
  // field's own scroll view a fraction of a pixel taller than the field; it
  // then takes the vertical drag and the page stops scrolling. The test font
  // doesn't reproduce that, so guard the setting instead of the gesture.
  testWidgets('editor text fields never scroll on their own', (tester) async {
    final now = DateTime.utc(2026, 11, 3);
    final note = NoteEntity(
      id: 'n1',
      title: 'Packing list',
      body: 'A paragraph that wraps.\n\n- [ ] Passport\n- [x] Charger',
      createdAt: now,
      updatedAt: now,
    );
    final repo = _MockNoteRepository();
    final scheduler = _MockSyncScheduler();
    when(() => scheduler.requestSync()).thenReturn(null);
    when(() => repo.watchAllNotes(limit: any(named: 'limit')))
        .thenAnswer((_) => Stream.value([NotePreview(note: note)]));
    when(() => repo.watchNoteCount()).thenAnswer((_) => Stream.value(1));
    when(() => repo.getNote('n1')).thenAnswer((_) async => note);
    when(() => repo.watchNote('n1')).thenAnswer((_) => Stream.value(note));
    when(() => repo.watchConflictCopies(any()))
        .thenAnswer((_) => Stream.value([]));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          noteRepositoryProvider.overrideWithValue(repo),
          syncSchedulerProvider.overrideWithValue(scheduler),
        ],
        child: const MaterialApp(home: EditNoteScreen(noteId: 'n1')),
      ),
    );
    await tester.pumpAndSettle();

    final fields = tester.widgetList<TextField>(find.byType(TextField)).toList();
    // Title + paragraph + two checklist items.
    expect(fields.length, greaterThanOrEqualTo(4));
    for (final field in fields) {
      expect(field.scrollPhysics, isA<NeverScrollableScrollPhysics>());
    }
  });
}
