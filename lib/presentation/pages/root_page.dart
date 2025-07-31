import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'word_list_page.dart';
import '../widgets/flashcard_widget.dart';
import '../../presentation/theme/app_theme_provider.dart';
import '../../data/repositories/word_repository_selector.dart';

class RootPage extends ConsumerStatefulWidget {
  const RootPage({super.key});
  @override
  ConsumerState<RootPage> createState() => _RootPageState();
}

class _RootPageState extends ConsumerState<RootPage> {
  int _selectedIndex = 0;

  static const _pages = [WordListPage(), FlashcardWidget()];

  static const _tabItems = [
    {'icon': Icons.style, 'label': 'フラッシュカード', 'color': Colors.orange},
    {'icon': Icons.color_lens, 'label': 'デザイン', 'color': Colors.purple},
  ];

  Future<void> _resetLearningProgress() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('学習状況のリセット'),
        content: const Text('すべてのカードの学習状況をリセットしますか？\nこの操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('リセット'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final repository = ref.read(wordRepositoryProvider);
        await repository.resetLearningProgress();

        // プロバイダーを無効化してデータを再読み込み
        ref.invalidate(wordListProvider);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('学習状況をリセットしました'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('リセットに失敗しました: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showThemeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('デザイン変更'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.flatware),
              title: const Text('Flat'),
              onTap: () {
                ref.read(appThemeTypeProvider.notifier).state =
                    AppThemeType.flat;
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.design_services),
              title: const Text('Material'),
              onTap: () {
                ref.read(appThemeTypeProvider.notifier).state =
                    AppThemeType.material;
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.blur_on),
              title: const Text('Neumorphism'),
              onTap: () {
                ref.read(appThemeTypeProvider.notifier).state =
                    AppThemeType.neumorphism;
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.phone_android),
              title: const Text('Mockup'),
              onTap: () {
                ref.read(appThemeTypeProvider.notifier).state =
                    AppThemeType.mockup;
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Usalingo'),
        actions: [
          // 単語リストボタン
          IconButton(
            icon: const Icon(Icons.list),
            tooltip: '単語リスト',
            onPressed: () {
              setState(() => _selectedIndex = 0);
            },
          ),
          // リセットボタン
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '学習状況をリセット',
            onPressed: _resetLearningProgress,
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
            child: _selectedIndex == 0
                ? _pages[0]
                : _selectedIndex == 1
                ? _pages[1]
                : Container(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.color_lens,
                            size: 64,
                            color: Colors.purple,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'デザイン設定',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '現在のデザインを変更できます',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                          const SizedBox(height: 32),
                          ElevatedButton.icon(
                            onPressed: _showThemeDialog,
                            icon: const Icon(Icons.color_lens),
                            label: const Text('デザインを変更'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
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
