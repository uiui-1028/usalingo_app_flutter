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
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
          borderRadius: BorderRadius.circular(theme.cornerRadius),
          border: Border.all(
            color: theme.borderColor,
            width: theme.borderWidth,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(theme.cornerRadius),
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
    final theme = ref.read(currentThemeProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width),
      builder: (context) => Container(
        width: MediaQuery.of(context).size.width,
        padding: const EdgeInsets.all(20),
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'UIテーマ設定',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // デザインスタイル選択
            _buildThemeSection(
              context,
              title: '🎨 デザインスタイル',
              description: 'アプリのUIデザインの基本スタイルを選択します',
              children: [
                _buildThemeOption(
                  context,
                  ref,
                  theme,
                  'フラット',
                  Icons.crop_square,
                  'ミニマルでシンプル',
                ),
                _buildThemeOption(
                  context,
                  ref,
                  theme,
                  'マテリアル',
                  Icons.layers,
                  'Google Material Design準拠',
                ),
                _buildThemeOption(
                  context,
                  ref,
                  theme,
                  'ニューモーフ',
                  Icons.blur_on,
                  'ソフトな影効果',
                ),
                _buildThemeOption(
                  context,
                  ref,
                  theme,
                  'ガラス',
                  Icons.blur_circular,
                  '透明感のあるガラス風',
                ),
                _buildThemeOption(
                  context,
                  ref,
                  theme,
                  'ピクセル',
                  Icons.grid_on,
                  'レトロゲーム風',
                ),
                _buildThemeOption(
                  context,
                  ref,
                  theme,
                  'ワイヤー',
                  Icons.grain,
                  '開発基盤用',
                ),
              ],
            ),
            const SizedBox(height: 24),

            // カラーモード選択
            _buildThemeSection(
              context,
              title: '🌓 カラーモード',
              description: '表示モードを切り替えます',
              children: [
                _buildColorModeOption(
                  context,
                  'ライトモード',
                  Icons.light_mode,
                  true,
                ),
                _buildColorModeOption(
                  context,
                  'ダークモード',
                  Icons.dark_mode,
                  false,
                ),
                _buildColorModeOption(
                  context,
                  'システム設定に追従',
                  Icons.settings_system_daydream,
                  null,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // アクセントカラー選択
            _buildThemeSection(
              context,
              title: '🎨 アクセントカラー',
              description: 'ボタンやアクティブな要素の差し色',
              children: [
                _buildAccentColorOption(context, 'ピンク', '#FF5D97', true),
                _buildAccentColorOption(context, 'ブルー', '#2196F3', false),
                _buildAccentColorOption(context, 'グリーン', '#4CAF50', false),
                _buildAccentColorOption(context, 'オレンジ', '#FF9800', false),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption(
    BuildContext context,
    WidgetRef ref,
    AppTheme theme,
    String name,
    IconData icon,
    String description,
  ) {
    return GestureDetector(
      onTap: () {
        // テーマを変更
        Navigator.pop(context);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(theme.cornerRadius),
          border: Border.all(
            color: theme.borderColor,
            width: theme.borderWidth,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32),
            const SizedBox(height: 8),
            Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeSection(
    BuildContext context, {
    required String title,
    required String description,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: children,
        ),
      ],
    );
  }

  Widget _buildColorModeOption(
    BuildContext context,
    String name,
    IconData icon,
    bool? isLight,
  ) {
    return GestureDetector(
      onTap: () {
        // カラーモードを変更
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.grey.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24),
            const SizedBox(height: 8),
            Text(
              name,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccentColorOption(
    BuildContext context,
    String name,
    String colorCode,
    bool isSelected,
  ) {
    return GestureDetector(
      onTap: () {
        // アクセントカラーを変更
      },
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.blue.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? Colors.blue
                : Colors.grey.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Color(int.parse(colorCode.replaceAll('#', '0xFF'))),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.blue : null,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardUISection(
    BuildContext context, {
    required String title,
    required String description,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildCardUISwitch(
    BuildContext context,
    String title,
    String subtitle,
    bool value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                ),
                Text(
                  subtitle,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: (newValue) {
              // 設定を変更
            },
            activeColor: Theme.of(context).primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildCardUIRadio(
    BuildContext context,
    String title,
    String subtitle,
    String value,
    String groupValue,
    ValueChanged<String?> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Radio<String>(
            value: value,
            groupValue: groupValue,
            onChanged: onChanged,
            activeColor: Theme.of(context).primaryColor,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                ),
                Text(
                  subtitle,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBehaviorSection(
    BuildContext context, {
    required String title,
    required String description,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildBehaviorDropdown(
    BuildContext context,
    String title,
    String subtitle,
    String value,
    List<String> items,
    ValueChanged<String?> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                ),
                Text(
                  subtitle,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          DropdownButton<String>(
            value: value,
            onChanged: onChanged,
            items: items.map((String item) {
              return DropdownMenuItem<String>(value: item, child: Text(item));
            }).toList(),
            underline: Container(
              height: 2,
              color: Theme.of(context).primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBehaviorSlider(
    BuildContext context,
    String title,
    String subtitle,
    double value,
    double min,
    double max,
    int divisions,
    ValueChanged<double> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
              ),
              Text(
                subtitle,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
              ),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
            activeColor: Theme.of(context).primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildBehaviorSwitch(
    BuildContext context,
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                ),
                Text(
                  subtitle,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Theme.of(context).primaryColor,
          ),
        ],
      ),
    );
  }

  void _showCardUISettings(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width,
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      builder: (context) => Container(
        width: MediaQuery.of(context).size.width,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'カードUI設定',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),

            // 情報表示設定
            _buildCardUISection(
              context,
              title: '📱 情報表示設定',
              description: 'カード上に表示するデータ項目をON/OFFで切り替えます',
              children: [
                _buildCardUISwitch(context, '単語訳', '単語の日本語訳を表示', true),
                _buildCardUISwitch(context, '単語音声', '単語の読み上げ音声を再生', true),
                _buildCardUISwitch(context, '発音記号', '国際音声記号（IPA）を表示', false),
                _buildCardUISwitch(context, '例文', '英語の例文を表示', true),
                _buildCardUISwitch(context, '例文訳', '例文の日本語訳を表示', false),
                _buildCardUISwitch(context, '例文音声', '例文の読み上げ音声を再生', true),
                _buildCardUISwitch(context, '品詞', '単語の品詞を表示', true),
                _buildCardUISwitch(context, '語源', '単語の語源情報を表示', false),
                _buildCardUISwitch(context, '類義語', '類義語のリストを表示', false),
                _buildCardUISwitch(context, '対義語', '対義語のリストを表示', false),
                _buildCardUISwitch(context, 'イラスト', '例文のイラストを表示', true),
              ],
            ),
            const SizedBox(height: 24),

            // 多義語の表示設定
            _buildCardUISection(
              context,
              title: '🔤 多義語の表示',
              description: '多義語の場合の表示方法を選択します',
              children: [
                _buildCardUIRadio(
                  context,
                  '全ての意味を表示',
                  '単語が持つ全ての意味を一覧表示',
                  'all',
                  'all',
                  (value) {},
                ),
                _buildCardUIRadio(
                  context,
                  '主要な意味のみ表示',
                  '最も重要な意味のみを表示',
                  'main',
                  'all',
                  (value) {},
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 解答インタラクション設定
            _buildCardUISection(
              context,
              title: '👆 解答インタラクション',
              description: '解答を表示する際の操作方法を選択します',
              children: [
                _buildCardUIRadio(
                  context,
                  'パンチアクション',
                  'タップで解答を表示（推奨）',
                  'punch',
                  'punch',
                  (value) {},
                ),
                _buildCardUIRadio(
                  context,
                  'カード裏返し',
                  'スワイプまたはタップで反転',
                  'flip',
                  'punch',
                  (value) {},
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showBehaviorSettings(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width,
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      builder: (context) => Container(
        width: MediaQuery.of(context).size.width,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'アプリ挙動設定',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),

            // フォント設定
            _buildBehaviorSection(
              context,
              title: '🔤 フォント設定',
              description: 'アプリ全体の表示フォントを選択します',
              children: [
                _buildBehaviorDropdown(
                  context,
                  'フォントファミリー',
                  'システム標準フォント',
                  'システム標準フォント',
                  [
                    'システム標準フォント',
                    'Google Fonts - Roboto',
                    'Google Fonts - Open Sans',
                    'Google Fonts - Lato',
                    'カスタムフォント',
                  ],
                  (value) {},
                ),
                _buildBehaviorSlider(
                  context,
                  'フォントサイズ',
                  '標準サイズ',
                  1.0,
                  0.8,
                  1.4,
                  6,
                  (value) {},
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 読み上げ音声（TTS）設定
            _buildBehaviorSection(
              context,
              title: '🔊 読み上げ音声（TTS）',
              description: '単語や例文を読み上げる音声の種類を選択します',
              children: [
                _buildBehaviorDropdown(context, '音声の種類', '英語（女性）', '英語（女性）', [
                  '英語（女性）',
                  '英語（男性）',
                  '英語（子供）',
                  '英語（高齢者）',
                ], (value) {}),
                _buildBehaviorSlider(
                  context,
                  '話速',
                  '標準速度',
                  1.0,
                  0.5,
                  2.0,
                  15,
                  (value) {},
                ),
                _buildBehaviorSlider(
                  context,
                  '音調',
                  '標準音調',
                  1.0,
                  0.8,
                  1.2,
                  4,
                  (value) {},
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 効果音と振動設定
            _buildBehaviorSection(
              context,
              title: '🎵 効果音と振動',
              description: '操作時のサウンドエフェクトや触覚フィードバック',
              children: [
                _buildBehaviorSwitch(
                  context,
                  '効果音',
                  '操作時のサウンドエフェクトを再生',
                  true,
                  (value) {},
                ),
                _buildBehaviorSwitch(
                  context,
                  '振動フィードバック',
                  '操作時の触覚フィードバック（Haptics）',
                  true,
                  (value) {},
                ),
                _buildBehaviorSlider(
                  context,
                  '効果音の音量',
                  '標準音量',
                  0.7,
                  0.0,
                  1.0,
                  10,
                  (value) {},
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAlgorithmSettings(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width,
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      builder: (context) => Container(
        width: MediaQuery.of(context).size.width,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'アルゴリズム設定',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),

              // 学習アルゴリズム設定
              _buildAlgorithmSection(
                context,
                title: '🧠 学習アルゴリズム',
                description: '単語の学習効率を最適化するアルゴリズムを調整します',
                children: [
                  _buildAlgorithmDropdown(
                    context,
                    'アルゴリズムタイプ',
                    'Spaced Repetition（間隔反復）',
                    'Spaced Repetition（間隔反復）',
                    [
                      'Spaced Repetition（間隔反復）',
                      'Leitner System（ライトナーシステム）',
                      'SuperMemo（スーパーメモ）',
                      'Custom Algorithm（カスタム）',
                    ],
                    (value) {},
                  ),
                  _buildAlgorithmSlider(
                    context,
                    '難易度調整',
                    '標準レベル',
                    0.5,
                    0.0,
                    1.0,
                    10,
                    (value) {},
                  ),
                  _buildAlgorithmSlider(
                    context,
                    '復習頻度',
                    '標準頻度',
                    0.5,
                    0.0,
                    1.0,
                    10,
                    (value) {},
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // パーソナライゼーション設定
              _buildAlgorithmSection(
                context,
                title: '👤 パーソナライゼーション',
                description: '学習者の習熟度に応じた個別調整',
                children: [
                  _buildAlgorithmSwitch(
                    context,
                    '適応学習',
                    '学習者の理解度に応じて自動調整',
                    true,
                    (value) {},
                  ),
                  _buildAlgorithmSwitch(
                    context,
                    '難易度記憶',
                    '単語ごとの難易度を記憶・適用',
                    true,
                    (value) {},
                  ),
                  _buildAlgorithmSwitch(
                    context,
                    '学習パターン分析',
                    '学習時間帯や頻度を分析',
                    false,
                    (value) {},
                  ),
                ],
              ),
              // 下部に余白を追加してオーバーフローを防ぐ
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlgorithmSection(
    BuildContext context, {
    required String title,
    required String description,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
        ),
        const SizedBox(height: 8),
        ...children,
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildAlgorithmDropdown(
    BuildContext context,
    String title,
    String subtitle,
    String value,
    List<String> items,
    ValueChanged<String?> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                ),
                Text(
                  subtitle,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          DropdownButton<String>(
            value: value,
            onChanged: onChanged,
            items: items.map((String item) {
              return DropdownMenuItem<String>(value: item, child: Text(item));
            }).toList(),
            underline: Container(
              height: 2,
              color: Theme.of(context).primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlgorithmSlider(
    BuildContext context,
    String title,
    String subtitle,
    double value,
    double min,
    double max,
    int divisions,
    ValueChanged<double> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
              ),
              Text(
                subtitle,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
              ),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
            activeColor: Theme.of(context).primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildAlgorithmSwitch(
    BuildContext context,
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                ),
                Text(
                  subtitle,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Theme.of(context).primaryColor,
          ),
        ],
      ),
    );
  }
}
