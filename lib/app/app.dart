import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../presentation/pages/splash_page.dart';
import '../presentation/theme/app_theme_provider.dart';
import '../secrets.dart';

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

// Supabase初期化用のクラス
class SupabaseInitializer {
  static Future<void> initialize() async {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  }

  static SupabaseClient get client => Supabase.instance.client;
}
