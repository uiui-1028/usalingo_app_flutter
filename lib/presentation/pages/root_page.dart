import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'word_list_page.dart';
import '../widgets/flashcard_widget.dart';
import 'supabase_test_page.dart';
import '../../presentation/theme/app_theme_provider.dart';
import '../../data/repositories/word_repository_selector.dart';

class RootPage extends ConsumerStatefulWidget {
  const RootPage({super.key});
  @override
  ConsumerState<RootPage> createState() => _RootPageState();
}

class _RootPageState extends ConsumerState<RootPage> {
  int _selectedIndex = 0;

  static const _pages = [WordListPage(), FlashcardWidget(), SupabaseTestPage()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Usalingo'),
        actions: [
          PopupMenuButton<int>(
            icon: const Icon(Icons.color_lens),
            onSelected: (index) {
              ref.read(appThemeTypeProvider.notifier).state =
                  AppThemeType.values[index];
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 0, child: Text('Flat')),
              const PopupMenuItem(value: 1, child: Text('Material')),
              const PopupMenuItem(value: 2, child: Text('Neumorph')),
              const PopupMenuItem(value: 3, child: Text('Mockup')),
            ],
          ),
          PopupMenuButton<DbType>(
            icon: const Icon(Icons.storage),
            onSelected: (dbType) {
              ref.read(dbTypeProvider.notifier).state = dbType;
              ref.invalidate(wordRepositoryProvider);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: DbType.sqlite, child: Text('SQLite')),
              const PopupMenuItem(
                value: DbType.supabase,
                child: Text('Supabase'),
              ),
            ],
          ),
        ],
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.list), label: '単語リスト'),
          BottomNavigationBarItem(icon: Icon(Icons.style), label: 'フラッシュカード'),
          BottomNavigationBarItem(
            icon: Icon(Icons.cloud),
            label: 'Supabaseテスト',
          ),
        ],
      ),
    );
  }
}
