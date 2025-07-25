import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../presentation/pages/flashcard_page.dart';

class UsalingoApp extends StatelessWidget {
  const UsalingoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Usalingo',
      // theme: ThemeData(...), // 今後MaterialTheme拡張時に利用
      home: const FlashcardPage(),
    );
  }
}
