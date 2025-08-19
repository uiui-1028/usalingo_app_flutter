// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:usalingo_app/app/app.dart';
import 'package:usalingo_app/presentation/widgets/flashcard_widget.dart';

void main() {
  testWidgets('UsalingoApp smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: UsalingoApp()));

    // Verify that the app title is displayed
    expect(find.text('Usalingo'), findsOneWidget);
  });

  testWidgets('FlashcardWidget test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: FlashcardWidget())),
      ),
    );

    // Verify that the widget is displayed
    expect(find.byType(FlashcardWidget), findsOneWidget);
  });
}
