// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:usalingo_app/presentation/widgets/flashcard_widget.dart';

void main() {
  testWidgets('FlashcardWidget shows word and taps to show answer', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: FlashcardWidget())),
      ),
    );
    expect(find.text('presence'), findsOneWidget);
    expect(find.text('存在'), findsNothing);
    await tester.tap(find.text('presence'));
    await tester.pumpAndSettle();
    expect(find.text('存在'), findsOneWidget);
  });
}
