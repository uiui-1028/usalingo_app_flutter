import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../presentation/pages/flashcard_page.dart';

class UsalingoApp extends StatelessWidget {
  const UsalingoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(title: 'Usalingo', home: const FlashcardPage()),
    );
  }
}
