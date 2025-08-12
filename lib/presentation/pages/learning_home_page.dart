import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme_provider.dart';
import '../theme/app_theme.dart';
import 'flashcard_page.dart';

class LearningHomePage extends ConsumerWidget {
  const LearningHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(currentThemeProvider);

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ヘッダー
              Text(
                '学習',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: theme.textColor,
                ),
              ),
              const SizedBox(height: 24),

              // ウィジェットエリア
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  children: [
                    // 学習デッキウィジェット
                    _buildLearningDeckWidget(context, theme),

                    // プレースホルダー（空きスロット）
                    _buildPlaceholderWidget(context, theme),

                    // その他のウィジェット用スロット
                    _buildEmptySlot(context, theme),
                    _buildEmptySlot(context, theme),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLearningDeckWidget(BuildContext context, AppTheme theme) {
    return GestureDetector(
      onTap: () {
        // 学習画面に遷移
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const FlashcardPage()),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(theme.cornerRadius),
          border: Border.all(
            color: theme.borderColor,
            width: theme.borderWidth,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.style, size: 48, color: theme.primaryColor),
              const SizedBox(height: 12),
              Text(
                '学習デッキ',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: theme.textColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'フラッシュカードで学習',
                style: TextStyle(fontSize: 12, color: theme.textSecondaryColor),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderWidget(BuildContext context, AppTheme theme) {
    return GestureDetector(
      onTap: () {
        // ウィジェットギャラリーを表示
        _showWidgetGallery(context);
      },
      child: Container(
        decoration: BoxDecoration(
          color: theme.backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.borderColor ?? Colors.grey.withValues(alpha: 0.3),
            width: 2,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, size: 32, color: theme.textSecondaryColor),
            const SizedBox(height: 8),
            Text(
              'ウィジェット追加',
              style: TextStyle(fontSize: 14, color: theme.textSecondaryColor),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptySlot(BuildContext context, AppTheme theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.borderColor ?? Colors.grey.withValues(alpha: 0.1),
          width: 1,
          style: BorderStyle.solid,
        ),
      ),
      child: const Center(
        child: Icon(Icons.add_circle_outline, size: 32, color: Colors.grey),
      ),
    );
  }

  void _showWidgetGallery(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'ウィジェットギャラリー',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            // ここにウィジェット一覧を表示
            const Text('利用可能なウィジェットがここに表示されます'),
          ],
        ),
      ),
    );
  }
}
