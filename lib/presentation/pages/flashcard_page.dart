import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/flashcard_widget.dart';
import '../theme/app_theme_provider.dart';
import '../theme/app_theme.dart';
import '../../app/providers.dart';
import '../../domain/entities/learning_progress.dart';

class FlashcardPage extends ConsumerStatefulWidget {
  const FlashcardPage({super.key});

  @override
  ConsumerState<FlashcardPage> createState() => _FlashcardPageState();
}

class _FlashcardPageState extends ConsumerState<FlashcardPage> {
  List<LearningProgress> dueTodayCards = [];
  int currentCardIndex = 0;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadDueTodayCards();
  }

  Future<void> _loadDueTodayCards() async {
    setState(() {
      isLoading = true;
    });

    try {
      final getDueTodayCards = ref.read(getDueTodayCardsProvider);
      final cards = await getDueTodayCards.execute();
      setState(() {
        dueTodayCards = cards;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  double get _progressValue {
    if (dueTodayCards.isEmpty) return 0.0;
    return (currentCardIndex + 1) / dueTodayCards.length;
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(currentThemeProvider);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // カスタムヘッダー（タイトルなし、戻るボタンと進捗バーのみ）
            _buildCustomHeader(context, theme),
            // フラッシュカードコンテンツ
            Expanded(
              child: Center(
                child: FlashcardWidget(
                  onCardIndexChanged: (index) {
                    setState(() {
                      currentCardIndex = index;
                    });
                  },
                ),
              ),
            ),
            // ツールバー
            _buildToolbar(context, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomHeader(BuildContext context, AppTheme theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          // 戻るボタン
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.close, color: theme.textSecondaryColor, size: 24),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 20),
          // 進捗バー
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 進捗テキスト
                Text(
                  '${currentCardIndex + 1} / ${dueTodayCards.length}',
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.textSecondaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                // 進捗バー
                Container(
                  height: 10,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF333333), // 黒いパイプライン
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: _progressValue,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF5D97), // 写真に近いピンクの進捗
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(BuildContext context, AppTheme theme) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.borderColor, width: theme.borderWidth),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // タグ付けボタン
          _buildToolbarButton(
            icon: Icons.local_offer_outlined,
            onTap: () => _onTagButtonTap(),
            theme: theme,
          ),
          // 音声再生ボタン
          _buildToolbarButton(
            icon: Icons.volume_up_outlined,
            onTap: () => _onAudioButtonTap(),
            theme: theme,
          ),
          // 一つ戻るボタン
          _buildToolbarButton(
            icon: Icons.undo_outlined,
            onTap: () => _onUndoButtonTap(),
            theme: theme,
          ),
          // 編集ボタン
          _buildToolbarButton(
            icon: Icons.edit_outlined,
            onTap: () => _onEditButtonTap(),
            theme: theme,
          ),
        ],
      ),
    );
  }

  Widget _buildToolbarButton({
    required IconData icon,
    required VoidCallback onTap,
    required AppTheme theme,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: theme.backgroundColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: theme.borderColor, width: 1),
        ),
        child: Icon(icon, color: theme.primaryColor, size: 24),
      ),
    );
  }

  // ツールバーボタンのタップハンドラー
  void _onTagButtonTap() {
    // TODO: タグ付け機能の実装
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('タグ付け機能')));
  }

  void _onAudioButtonTap() {
    // TODO: 音声再生機能の実装
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('音声再生機能')));
  }

  void _onUndoButtonTap() {
    // TODO: 一つ戻る機能の実装
    if (currentCardIndex > 0) {
      setState(() {
        currentCardIndex--;
      });

      // フラッシュカードウィジェットの状態も更新
      ref.read(currentIndexProvider.notifier).state = currentCardIndex;
      ref.read(isAnswerVisibleProvider.notifier).state = false;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('一つ戻りました')));
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('これ以上戻れません')));
    }
  }

  void _onEditButtonTap() {
    // TODO: 編集機能の実装
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('編集機能')));
  }
}
