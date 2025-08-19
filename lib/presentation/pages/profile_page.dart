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
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
    return GestureDetector(
      onTap: () {
        _showStreakDetails(context);
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
      ),
    );
  }

  Widget _buildHeatmapWidget(BuildContext context, AppTheme theme) {
    return GestureDetector(
      onTap: () {
        _showHeatmapDetails(context);
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
      ),
    );
  }

  Widget _buildAchievementWidget(BuildContext context, AppTheme theme) {
    return GestureDetector(
      onTap: () {
        _showAchievementDetails(context);
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
      isScrollControlled: true,
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width),
      builder: (context) => Container(
        width: MediaQuery.of(context).size.width,
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
      isScrollControlled: true,
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width),
      builder: (context) => Container(
        width: MediaQuery.of(context).size.width,
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
      isScrollControlled: true,
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width),
      builder: (context) => Container(
        width: MediaQuery.of(context).size.width,
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

  void _showStreakDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width),
      builder: (context) => Container(
        width: MediaQuery.of(context).size.width,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '学習ストリーク',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(
                  Icons.local_fire_department,
                  size: 32,
                  color: Colors.orange,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 現在のストリーク
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.orange, width: 2),
              ),
              child: Column(
                children: [
                  Text(
                    '7',
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '日連続学習中！',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.orange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ストリーク情報
            Row(
              children: [
                Expanded(child: _buildStreakInfoItem(context, '自己最長記録', '12日')),
                Expanded(child: _buildStreakInfoItem(context, '今月の学習日', '18日')),
                Expanded(child: _buildStreakInfoItem(context, '総学習日数', '45日')),
              ],
            ),
            const SizedBox(height: 24),

            // 継続のコツ
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '💡 継続のコツ',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '1日1単語でも学習すればストリークは継続されます。毎日少しずつでも続けることが大切です。',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreakInfoItem(
    BuildContext context,
    String label,
    String value,
  ) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  void _showHeatmapDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width),
      builder: (context) => Container(
        width: MediaQuery.of(context).size.width,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '学習ヒートマップ',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(
                  Icons.calendar_today,
                  size: 32,
                  color: Theme.of(context).primaryColor,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ヒートマップの説明
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📊 ヒートマップの見方',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildHeatmapLegendItem(
                        '0単語',
                        Colors.grey.withValues(alpha: 0.3),
                      ),
                      const SizedBox(width: 16),
                      _buildHeatmapLegendItem(
                        '1-10単語',
                        Colors.green.withValues(alpha: 0.3),
                      ),
                      const SizedBox(width: 16),
                      _buildHeatmapLegendItem('11-30単語', Colors.green),
                      const SizedBox(width: 16),
                      _buildHeatmapLegendItem('31単語以上', Colors.green.shade700),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 今月のサマリー
            Row(
              children: [
                Expanded(
                  child: _buildHeatmapInfoItem(context, '今月の学習日', '18日'),
                ),
                Expanded(
                  child: _buildHeatmapInfoItem(context, '今月の総単語数', '156単語'),
                ),
                Expanded(
                  child: _buildHeatmapInfoItem(context, '平均/日', '8.7単語'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // タップで詳細確認の説明
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue, width: 1),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'ヒートマップ上の各マスをタップすると、その日の学習詳細を確認できます',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeatmapLegendItem(String label, Color color) {
    return Column(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildHeatmapInfoItem(
    BuildContext context,
    String label,
    String value,
  ) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  void _showAchievementDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width),
      builder: (context) => Container(
        width: MediaQuery.of(context).size.width,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '実績サマリー',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(Icons.emoji_events, size: 32, color: Colors.amber),
              ],
            ),
            const SizedBox(height: 24),

            // 総合統計
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.amber, width: 2),
              ),
              child: Column(
                children: [
                  Text(
                    '🎯 学習の軌跡',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.amber.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildAchievementInfoItem(
                          context,
                          '総学習単語数',
                          '1,247',
                        ),
                      ),
                      Expanded(
                        child: _buildAchievementInfoItem(
                          context,
                          'マスター済み',
                          '892',
                        ),
                      ),
                      Expanded(
                        child: _buildAchievementInfoItem(context, '学習中', '355'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 詳細統計
            Row(
              children: [
                Expanded(
                  child: _buildAchievementInfoItem(context, '総学習時間', '約32時間'),
                ),
                Expanded(
                  child: _buildAchievementInfoItem(context, '生涯正解率', '87.3%'),
                ),
                Expanded(
                  child: _buildAchievementInfoItem(context, '獲得バッジ', '3個'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 最近の実績
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🏆 最近の実績',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildRecentAchievement(context, '7日連続学習', '3日前'),
                  _buildRecentAchievement(context, '100単語マスター', '1週間前'),
                  _buildRecentAchievement(context, '月間目標達成', '2週間前'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAchievementInfoItem(
    BuildContext context,
    String label,
    String value,
  ) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildRecentAchievement(
    BuildContext context,
    String title,
    String date,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: Theme.of(context).textTheme.bodyMedium),
          Text(
            date,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}
