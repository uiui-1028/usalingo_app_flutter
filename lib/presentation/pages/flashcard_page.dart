import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/flashcard_widget.dart';
import '../theme/app_theme_provider.dart';
import '../theme/app_theme.dart';

class FlashcardPage extends ConsumerWidget {
  const FlashcardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(currentThemeProvider);

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        title: const Text('フラッシュカード学習'),
        backgroundColor: theme.backgroundColor,
        foregroundColor: theme.textColor,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // 学習進捗表示
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '進捗: 3/10',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: theme.textColor,
                      ),
                    ),
                    Text(
                      '残り: 7枚',
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // フラッシュカード（中央配置）
              Expanded(
                child: Center(
                  child: FlashcardWidget(word: 'Hello', definition: 'こんにちは'),
                ),
              ),

              const SizedBox(height: 24),

              // 操作ボタン
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildActionButton(
                    context,
                    theme,
                    Icons.close,
                    '間違えた',
                    Colors.red,
                    () => _handleWrongAnswer(context),
                  ),
                  _buildActionButton(
                    context,
                    theme,
                    Icons.check,
                    '正解',
                    Colors.green,
                    () => _handleCorrectAnswer(context),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    AppTheme theme,
    IconData icon,
    String label,
    Color color,
    VoidCallback onPressed,
  ) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: color, width: 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleWrongAnswer(BuildContext context) {
    // 間違えた場合の処理
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('間違えました。もう一度学習しましょう。'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _handleCorrectAnswer(BuildContext context) {
    // 正解の場合の処理
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('正解です！よくできました。'),
        backgroundColor: Colors.green,
      ),
    );
  }
}
