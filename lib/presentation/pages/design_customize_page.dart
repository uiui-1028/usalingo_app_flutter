import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme_provider.dart';
import '../theme/app_theme.dart';

class DesignCustomizePage extends ConsumerWidget {
  const DesignCustomizePage({super.key});

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
                'デザインカスタマイズ',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: theme.textColor,
                ),
              ),
              const SizedBox(height: 24),

              // 設定項目
              Expanded(
                child: ListView(
                  children: [
                    _buildSettingModule(
                      context,
                      theme,
                      'UIテーマ設定',
                      Icons.palette,
                      'アプリ全体のテーマを変更',
                      () => _showThemeSettings(context, ref),
                    ),
                    const SizedBox(height: 16),
                    _buildSettingModule(
                      context,
                      theme,
                      'カードUI設定',
                      Icons.style,
                      'フラッシュカードのデザインを調整',
                      () => _showCardUISettings(context, ref),
                    ),
                    const SizedBox(height: 16),
                    _buildSettingModule(
                      context,
                      theme,
                      'アプリ挙動設定',
                      Icons.settings,
                      'フォントやTTSなどを変更',
                      () => _showBehaviorSettings(context, ref),
                    ),
                    const SizedBox(height: 16),
                    _buildSettingModule(
                      context,
                      theme,
                      'アルゴリズム設定',
                      Icons.apps,
                      '学習アルゴリズムの調整',
                      () => _showAlgorithmSettings(context, ref),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingModule(
    BuildContext context,
    AppTheme theme,
    String title,
    IconData icon,
    String description,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 32, color: theme.primaryColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: theme.textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: theme.textSecondaryColor,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showThemeSettings(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('UIテーマ設定', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _buildThemeOption(context, ref, 'フラット', Icons.crop_square),
                  _buildThemeOption(context, ref, 'マテリアル', Icons.layers),
                  _buildThemeOption(context, ref, 'ニューモーフ', Icons.blur_on),
                  _buildThemeOption(context, ref, 'ガラス', Icons.blur_circular),
                  _buildThemeOption(context, ref, 'ピクセル', Icons.grid_on),
                  _buildThemeOption(context, ref, 'ワイヤー', Icons.grain),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption(
    BuildContext context,
    WidgetRef ref,
    String name,
    IconData icon,
  ) {
    return GestureDetector(
      onTap: () {
        // テーマを変更
        Navigator.pop(context);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32),
            const SizedBox(height: 8),
            Text(name),
          ],
        ),
      ),
    );
  }

  void _showCardUISettings(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('カードUI設定', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            const Text('カードのデザイン設定がここに表示されます'),
          ],
        ),
      ),
    );
  }

  void _showBehaviorSettings(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('アプリ挙動設定', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            const Text('アニメーションや動作の設定がここに表示されます'),
          ],
        ),
      ),
    );
  }

  void _showAlgorithmSettings(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('アルゴリズム設定', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            const Text('学習アルゴリズムの調整がここに表示されます'),
          ],
        ),
      ),
    );
  }
}
