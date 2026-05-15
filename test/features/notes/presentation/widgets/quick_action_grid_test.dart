import 'package:cortex/features/notes/presentation/widgets/quick_action_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('QuickActionGrid renders properly and handles tap on Text Note', (WidgetTester tester) async {
    bool wasTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuickActionGrid(
            onTextNoteTap: () {
              wasTapped = true;
            },
          ),
        ),
      ),
    );

    // Verify all 4 action cards exist by title
    expect(find.text('Text Note'), findsOneWidget);
    expect(find.text('Voice Note'), findsOneWidget);
    expect(find.text('Image Note'), findsOneWidget);
    expect(find.text('AI Note'), findsOneWidget);

    // Tap the Text Note card
    // The "Text Note" card is the first item in the grid
    final textNoteCard = find.text('Text Note');
    await tester.tap(textNoteCard);
    
    // Pump animation frames
    await tester.pumpAndSettle();

    // Verify callback was triggered
    expect(wasTapped, isTrue);
  });
}
