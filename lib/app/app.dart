import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../presentation/pages/splash_page.dart';
import '../presentation/theme/app_theme_provider.dart';

class UsalingoApp extends ConsumerWidget {
  const UsalingoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeData = ref.watch(themeDataProvider);

    return MaterialApp(
      title: 'Usalingo',
      theme: themeData,
      home: const SplashPage(),
    );
  }
}
