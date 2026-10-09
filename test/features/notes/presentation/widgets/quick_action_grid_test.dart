import 'package:cortex/features/notes/presentation/widgets/quick_action_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('QuickActionGrid renders properly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: QuickActionGrid())),
    );

    expect(find.text('Text Note'), findsOneWidget);
    expect(find.text('Voice Note'), findsOneWidget);
    expect(find.text('Image Note'), findsOneWidget);
    expect(find.text('AI Note'), findsOneWidget);

    final textNoteCard = find.text('Text Note');
    await tester.tap(textNoteCard);

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  });
}
