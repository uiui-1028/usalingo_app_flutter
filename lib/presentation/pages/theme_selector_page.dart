import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme_provider.dart';
import '../theme/app_theme.dart';

/// テーマ選択ページ
/// ユーザーが異なるテーマを選択できるUIを提供します
class ThemeSelectorPage extends ConsumerWidget {
  const ThemeSelectorPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTheme = ref.watch(appThemeProvider);
    final currentThemeType = ref.watch(appThemeTypeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('テーマ選択'),
        backgroundColor: currentTheme.backgroundColor,
        foregroundColor: currentTheme.textColor,
      ),
      backgroundColor: currentTheme.backgroundColor,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 現在のテーマプレビュー
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: currentTheme.cardColor,
                borderRadius: BorderRadius.circular(currentTheme.borderRadius),
                boxShadow: currentTheme.cardShadows,
                border: Border.all(
                  color: currentTheme.borderSide.color,
                  width: currentTheme.borderSide.width,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    '現在のテーマ: ${_getThemeName(currentThemeType)}',
                    style: currentTheme.headingTextStyle,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'このテーマの特徴を確認できます',
                    style: currentTheme.secondaryTextStyle,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // テーマ選択ボタン
            Expanded(
              child: ListView(
                children: AppThemeType.values.map((themeType) {
                  return _buildThemeOption(
                    context,
                    ref,
                    themeType,
                    currentThemeType,
                    currentTheme,
                  );
                }).toList(),
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
    AppThemeType themeType,
    AppThemeType currentThemeType,
    AppTheme currentTheme,
  ) {
    final isSelected = themeType == currentThemeType;

    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(currentTheme.borderRadius),
          onTap: () {
            ref.read(appThemeTypeProvider.notifier).state = themeType;
          },
          child: Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: isSelected
                  ? currentTheme.accentColor.withValues(alpha: 0.1)
                  : currentTheme.cardColor,
              borderRadius: BorderRadius.circular(currentTheme.borderRadius),
              boxShadow: currentTheme.cardShadows,
              border: Border.all(
                color: isSelected
                    ? currentTheme.accentColor
                    : currentTheme.borderSide.color,
                width: isSelected ? 2.0 : currentTheme.borderSide.width,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getThemeName(themeType),
                        style: currentTheme.headingTextStyle.copyWith(
                          fontSize: 18,
                          color: isSelected
                              ? currentTheme.accentColor
                              : currentTheme.textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getThemeDescription(themeType),
                        style: currentTheme.secondaryTextStyle,
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle,
                    color: currentTheme.accentColor,
                    size: 24,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getThemeName(AppThemeType themeType) {
    switch (themeType) {
      case AppThemeType.wireframe:
        return 'ワイヤーフレーム';
      case AppThemeType.mockup:
        return 'モックアップ';
      case AppThemeType.flat:
        return 'フラット';
      case AppThemeType.material:
        return 'マテリアル';
      case AppThemeType.neumorphism:
        return 'ニューモーフィズム';
      case AppThemeType.pixelArt:
        return 'ピクセルアート';
    }
  }

  String _getThemeDescription(AppThemeType themeType) {
    switch (themeType) {
      case AppThemeType.wireframe:
        return '開発基盤用のシンプルなテーマ';
      case AppThemeType.mockup:
        return 'プロトタイピング用のダークテーマ';
      case AppThemeType.flat:
        return 'ミニマルなフラットデザイン';
      case AppThemeType.material:
        return 'Google Material Design準拠';
      case AppThemeType.neumorphism:
        return 'ソフトな影効果のニューモーフィズム';
      case AppThemeType.pixelArt:
        return 'レトロゲーム風のピクセルアート';
    }
  }
}
