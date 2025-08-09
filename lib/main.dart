import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Supabaseの初期化
  await SupabaseInitializer.initialize();

  runApp(const ProviderScope(child: UsalingoApp()));
}
