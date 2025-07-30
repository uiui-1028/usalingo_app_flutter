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

  static const _tabItems = [
    {'icon': Icons.list, 'label': '単語リスト', 'color': Colors.purple},
    {'icon': Icons.style, 'label': 'フラッシュカード', 'color': Colors.orange},
    {'icon': Icons.cloud, 'label': 'Supabase', 'color': Colors.teal},
  ];

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
      body: Stack(
        children: [
          // メインコンテンツ（下部にパディングを追加）
          Padding(
            padding: EdgeInsets.only(
              bottom: 80 + MediaQuery.of(context).padding.bottom,
            ),
            child: _pages[_selectedIndex],
          ),
          // 独立したタブバー（画面下部に固定）
          Positioned(
            left: 0,
            right: 0,
            bottom: 20 + MediaQuery.of(context).padding.bottom,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: ref.watch(appThemeProvider).surface,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(_tabItems.length, (index) {
                    final isActive = _selectedIndex == index;
                    final item = _tabItems[index];
                    final color = item['color'] as Color;

                    return GestureDetector(
                      onTap: () => setState(() => _selectedIndex = index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: EdgeInsets.symmetric(
                          horizontal: isActive ? 16 : 8,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isActive
                              ? color.withOpacity(0.2)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              item['icon'] as IconData,
                              color: isActive
                                  ? color
                                  : ref.watch(appThemeProvider).secondaryText,
                              size: 24,
                            ),
                            if (isActive) ...[
                              const SizedBox(width: 8),
                              Text(
                                item['label'] as String,
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
