import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../presentation/pages/root_page.dart';
import '../presentation/theme/app_theme_provider.dart';

class UsalingoApp extends ConsumerWidget {
  const UsalingoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(appThemeProvider);
    
    return MaterialApp(
      title: 'Usalingo',
      theme: ThemeData(
        scaffoldBackgroundColor: theme.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: theme.accent,
          brightness: Brightness.dark,
          surface: theme.surface,
        ),
        textTheme: TextTheme(
          bodyLarge: TextStyle(color: theme.primaryText),
          bodyMedium: TextStyle(color: theme.primaryText),
          bodySmall: TextStyle(color: theme.secondaryText),
        ),
      ),
      home: const RootPage(),
    );
  }
}
