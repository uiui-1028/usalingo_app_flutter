import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme_provider.dart';
import '../theme/app_theme.dart';
import 'dart:math';

// カードの表示設定を管理するプロバイダー
final cardDisplaySettingsProvider =
    StateNotifierProvider<CardDisplaySettingsNotifier, CardDisplaySettings>((
      ref,
    ) {
      return CardDisplaySettingsNotifier();
    });

class CardDisplaySettings {
  final bool showIllustration;
  final bool showTerm;
  final bool showPronunciation;
  final bool showDefinition;
  final bool showExampleSentence;

  const CardDisplaySettings({
    this.showIllustration = true,
    this.showTerm = true,
    this.showPronunciation = true,
    this.showDefinition = true,
    this.showExampleSentence = true,
  });

  CardDisplaySettings copyWith({
    bool? showIllustration,
    bool? showTerm,
    bool? showPronunciation,
    bool? showDefinition,
    bool? showExampleSentence,
  }) {
    return CardDisplaySettings(
      showIllustration: showIllustration ?? this.showIllustration,
      showTerm: showTerm ?? this.showTerm,
      showPronunciation: showPronunciation ?? this.showPronunciation,
      showDefinition: showDefinition ?? this.showDefinition,
      showExampleSentence: showExampleSentence ?? this.showExampleSentence,
    );
  }
}

class CardDisplaySettingsNotifier extends StateNotifier<CardDisplaySettings> {
  CardDisplaySettingsNotifier() : super(const CardDisplaySettings());

  void toggleIllustration() {
    state = state.copyWith(showIllustration: !state.showIllustration);
  }

  void toggleTerm() {
    state = state.copyWith(showTerm: !state.showTerm);
  }

  void togglePronunciation() {
    state = state.copyWith(showPronunciation: !state.showPronunciation);
  }

  void toggleDefinition() {
    state = state.copyWith(showDefinition: !state.showDefinition);
  }

  void toggleExampleSentence() {
    state = state.copyWith(showExampleSentence: !state.showExampleSentence);
  }
}

class Test3DCardScreen extends ConsumerStatefulWidget {
  const Test3DCardScreen({super.key});

  @override
  ConsumerState<Test3DCardScreen> createState() => _Test3DCardScreenState();
}

class _Test3DCardScreenState extends ConsumerState<Test3DCardScreen>
    with SingleTickerProviderStateMixin {
  double _rotationX = 0.0;
  double _rotationY = 0.0;
  Offset _dragStart = Offset.zero;
  bool _isDragging = false;

  late AnimationController _controller;
  late Animation<double> _animationX;
  late Animation<double> _animationY;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _controller.addListener(() {
      setState(() {
        _rotationX = _animationX.value;
        _rotationY = _animationY.value;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(appThemeProvider);

    return Scaffold(
      backgroundColor: Colors.grey[900], // 暗めの背景色
      body: Stack(
        children: [
          // 3Dカード
          Center(
            child: GestureDetector(
              onPanStart: (details) {
                _dragStart = details.localPosition;
                _isDragging = true;
                if (_controller.isAnimating) {
                  _controller.stop();
                }
              },
              onPanUpdate: (details) {
                if (_isDragging) {
                  final delta = details.localPosition - _dragStart;
                  setState(() {
                    _rotationY += delta.dx * 0.01;
                    _rotationX -= delta.dy * 0.01;

                    // 回転角度を制限
                    _rotationX = _rotationX.clamp(-0.5, 0.5);
                    _rotationY = _rotationY.clamp(-1.0, 1.0);
                  });
                  _dragStart = details.localPosition;
                }
              },
              onPanEnd: (details) {
                _isDragging = false;
                // アニメーションで元の位置に戻す
                _animationX = Tween<double>(begin: _rotationX, end: 0.0)
                    .animate(
                      CurvedAnimation(
                        parent: _controller,
                        curve: Curves.easeOutCubic,
                      ),
                    );
                _animationY = Tween<double>(begin: _rotationY, end: 0.0)
                    .animate(
                      CurvedAnimation(
                        parent: _controller,
                        curve: Curves.easeOutCubic,
                      ),
                    );
                _controller.forward(from: 0);
              },
              child: Transform(
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001) // パースペクティブ
                  ..rotateX(_rotationX)
                  ..rotateY(_rotationY),
                alignment: Alignment.center,
                child: _build3DCard(theme),
              ),
            ),
          ),

          // 設定ボタン
          Positioned(
            bottom: 100,
            right: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  onPressed: _showSettingsPanel,
                  backgroundColor: theme.accent,
                  child: const Icon(Icons.settings, color: Colors.white),
                ),
                const SizedBox(height: 16),
                FloatingActionButton(
                  onPressed: _showThemeDialog,
                  backgroundColor: Colors.purple,
                  child: const Icon(Icons.color_lens, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _build3DCard(AppTheme theme) {
    final settings = ref.watch(cardDisplaySettingsProvider);

    return Container(
      width: 300,
      height: 400,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          // カードの厚みを表現する影
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
          // カードの縁の影（厚み表現）
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 5,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          // カードの本体
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.yellow[100]!, Colors.yellow[200]!],
              ),
              border: Border.all(color: Colors.amber[400]!, width: 3),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: Column(
                children: [
                  // イラストエリア
                  if (settings.showIllustration)
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.green[100]!, Colors.green[200]!],
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.auto_awesome,
                          size: 80,
                          color: Colors.amber[600],
                        ),
                      ),
                    ),

                  // コンテンツエリア
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Term
                          if (settings.showTerm)
                            Text(
                              'ピチュー',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),

                          const SizedBox(height: 8),

                          // Pronunciation
                          if (settings.showPronunciation)
                            Text(
                              'ピチュー (Pichu)',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                                fontStyle: FontStyle.italic,
                              ),
                            ),

                          const SizedBox(height: 12),

                          // Definition
                          if (settings.showDefinition)
                            Text(
                              '電気を溜めこむのが下手。なんらかのショックを受けるとすぐに放電してしまう。',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                              ),
                            ),

                          const SizedBox(height: 12),

                          // Example Sentence
                          if (settings.showExampleSentence)
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.amber[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.amber[200]!,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                'ピチューは小さな電気ポケモンです。',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[700],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // カードの厚みを表現する縁
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.amber[300]!, width: 1),
              ),
            ),
          ),
        ],
      ),
    );
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

  void _showSettingsPanel() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildSettingsPanel(),
    );
  }

  Widget _buildSettingsPanel() {
    final settings = ref.watch(cardDisplaySettingsProvider);
    final notifier = ref.read(cardDisplaySettingsProvider.notifier);
    final theme = ref.watch(appThemeProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // ハンドル
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          const SizedBox(height: 20),

          // タイトル
          Text(
            'カード表示設定',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: theme.primaryText,
            ),
          ),

          const SizedBox(height: 20),

          // 設定項目
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                SwitchListTile(
                  title: const Text('イラスト'),
                  subtitle: const Text('カード上部のイラストを表示'),
                  value: settings.showIllustration,
                  onChanged: (value) => notifier.toggleIllustration(),
                  activeColor: theme.accent,
                ),

                SwitchListTile(
                  title: const Text('単語名'),
                  subtitle: const Text('ピチューなどの単語名を表示'),
                  value: settings.showTerm,
                  onChanged: (value) => notifier.toggleTerm(),
                  activeColor: theme.accent,
                ),

                SwitchListTile(
                  title: const Text('発音記号'),
                  subtitle: const Text('発音記号や読み方を表示'),
                  value: settings.showPronunciation,
                  onChanged: (value) => notifier.togglePronunciation(),
                  activeColor: theme.accent,
                ),

                SwitchListTile(
                  title: const Text('定義'),
                  subtitle: const Text('単語の定義や説明を表示'),
                  value: settings.showDefinition,
                  onChanged: (value) => notifier.toggleDefinition(),
                  activeColor: theme.accent,
                ),

                SwitchListTile(
                  title: const Text('例文'),
                  subtitle: const Text('使用例や例文を表示'),
                  value: settings.showExampleSentence,
                  onChanged: (value) => notifier.toggleExampleSentence(),
                  activeColor: theme.accent,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
