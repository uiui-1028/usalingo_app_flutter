import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme_provider.dart';
import '../theme/app_theme.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

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
                'プロフィール',
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
                    // ストリークウィジェット
                    _buildStreakWidget(context, theme),

                    // 学習ヒートマップウィジェット
                    _buildHeatmapWidget(context, theme),

                    // 実績サマリーウィジェット
                    _buildAchievementWidget(context, theme),

                    // 簡易プロフィールウィジェット
                    _buildProfileWidget(context, theme),

                    // アプリロゴウィジェット
                    _buildLogoWidget(context, theme),

                    // プレースホルダー（空きスロット）
                    _buildPlaceholderWidget(context, theme),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStreakWidget(BuildContext context, AppTheme theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(theme.cornerRadius),
        border: Border.all(color: theme.borderColor, width: theme.borderWidth),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_fire_department, size: 32, color: Colors.orange),
            const SizedBox(height: 8),
            Text(
              '7',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: theme.textColor,
              ),
            ),
            Text(
              '日連続学習',
              style: TextStyle(fontSize: 12, color: theme.textSecondaryColor),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeatmapWidget(BuildContext context, AppTheme theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(theme.cornerRadius),
        border: Border.all(color: theme.borderColor, width: theme.borderWidth),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today, size: 32, color: theme.primaryColor),
            const SizedBox(height: 8),
            Text(
              '学習ヒートマップ',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.textColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            // 簡易的なヒートマップ表示
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                7,
                (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: index < 5
                        ? Colors.green
                        : Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAchievementWidget(BuildContext context, AppTheme theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(theme.cornerRadius),
        border: Border.all(color: theme.borderColor, width: theme.borderWidth),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.emoji_events, size: 32, color: Colors.amber),
            const SizedBox(height: 8),
            Text(
              '実績サマリー',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.textColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '3個獲得',
              style: TextStyle(fontSize: 14, color: theme.textSecondaryColor),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileWidget(BuildContext context, AppTheme theme) {
    return GestureDetector(
      onTap: () {
        // アカウント設定画面に遷移
        _showAccountSettings(context);
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
              CircleAvatar(
                radius: 20,
                backgroundColor: theme.primaryColor,
                child: Icon(Icons.person, color: Colors.white, size: 24),
              ),
              const SizedBox(height: 8),
              Text(
                'ユーザー名',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.textColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'タップで設定',
                style: TextStyle(fontSize: 10, color: theme.textSecondaryColor),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoWidget(BuildContext context, AppTheme theme) {
    return GestureDetector(
      onTap: () {
        // 補助機能画面に遷移
        _showSupportFeatures(context);
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
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.primaryColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.language,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Usalingo',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: theme.textColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'タップで詳細',
                style: TextStyle(fontSize: 10, color: theme.textSecondaryColor),
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
          borderRadius: BorderRadius.circular(theme.cornerRadius),
          border: Border.all(
            color: theme.borderColor,
            width: theme.borderWidth,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, size: 32, color: theme.textSecondaryColor),
            const SizedBox(height: 8),
            Text(
              'ウィジェット追加',
              style: TextStyle(fontSize: 12, color: theme.textSecondaryColor),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showAccountSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('アカウント設定', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            const Text('メールアドレス、パスワード、プラン変更の設定がここに表示されます'),
          ],
        ),
      ),
    );
  }

  void _showSupportFeatures(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('補助機能', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            const Text('規約、ヘルプ、プラン詳細がここに表示されます'),
          ],
        ),
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
              'プロフィールウィジェットギャラリー',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            const Text('利用可能なプロフィールウィジェットがここに表示されます'),
          ],
        ),
      ),
    );
  }
}
