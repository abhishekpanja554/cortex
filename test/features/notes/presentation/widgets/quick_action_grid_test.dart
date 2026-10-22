import 'package:cortex/features/notes/domain/note_template.dart';
import 'package:cortex/features/notes/presentation/widgets/quick_action_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('QuickActionGrid shows the three create actions', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: QuickActionGrid(onSelected: (_) {}))),
    );

    expect(find.text('Note'), findsOneWidget);
    expect(find.text('Checklist'), findsOneWidget);
    expect(find.text('Image'), findsOneWidget);
  });

  testWidgets('each tile reports its template', (tester) async {
    final selected = <NoteTemplate>[];
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: QuickActionGrid(onSelected: selected.add))),
    );

    await tester.tap(find.text('Note'));
    await tester.tap(find.text('Checklist'));
    await tester.tap(find.text('Image'));
    await tester.pump();

    expect(selected, [NoteTemplate.text, NoteTemplate.checklist, NoteTemplate.image]);
  });
}
