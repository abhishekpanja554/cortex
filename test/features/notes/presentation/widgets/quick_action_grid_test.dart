import 'package:cortex/features/notes/presentation/widgets/quick_action_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('QuickActionGrid renders properly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: QuickActionGrid(),
        ),
      ),
    );

    // Verify all 4 action cards exist by title
    expect(find.text('Text Note'), findsOneWidget);
    expect(find.text('Voice Note'), findsOneWidget);
    expect(find.text('Image Note'), findsOneWidget);
    expect(find.text('AI Note'), findsOneWidget);

    /// Tap the Text Note card to ensure it doesn't crash
    /// Since it uses OpenContainer, it will trigger an internal transition
    final textNoteCard = find.text('Text Note');
    await tester.tap(textNoteCard);
    
    /// Pump frames to ensure no exceptions during transition start
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  });
}
