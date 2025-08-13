import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/flashcard_widget.dart';
import '../theme/app_theme_provider.dart';
import '../theme/app_theme.dart';

class FlashcardPage extends ConsumerStatefulWidget {
  const FlashcardPage({super.key});

  @override
  ConsumerState<FlashcardPage> createState() => _FlashcardPageState();
}

class _FlashcardPageState extends ConsumerState<FlashcardPage>
    with TickerProviderStateMixin {
  late AnimationController _punchController;
  late AnimationController _flipController;
  late Animation<double> _punchAnimation;
  late Animation<double> _flipAnimation;
  bool _isFlipped = false;
  bool _showAnswer = false;
  int _currentCardIndex = 0;
  int _totalCards = 10;
  int _correctAnswers = 0;
  int _wrongAnswers = 0;

  // サンプルデータ（実際のアプリではデータベースから取得）
  final List<Map<String, String>> _cards = [
    {'word': 'Hello', 'definition': 'こんにちは', 'sentence': 'Hello, how are you?'},
    {'word': 'World', 'definition': '世界', 'sentence': 'Hello, world!'},
    {
      'word': 'Flutter',
      'definition': 'フラッター',
      'sentence': 'Flutter is amazing!',
    },
    {
      'word': 'Dart',
      'definition': 'ダート',
      'sentence': 'Dart is a programming language.',
    },
    {'word': 'App', 'definition': 'アプリ', 'sentence': 'This is a great app!'},
  ];

  @override
  void initState() {
    super.initState();
    _punchController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _punchAnimation = Tween<double>(begin: 1.0, end: 0.8).animate(
      CurvedAnimation(parent: _punchController, curve: Curves.easeInOut),
    );

    _flipAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _punchController.dispose();
    _flipController.dispose();
    super.dispose();
  }

  void _punchAction() {
    _punchController.forward().then((_) {
      _punchController.reverse();
    });
    setState(() {
      _showAnswer = !_showAnswer;
    });
  }

  void _flipAction() {
    if (_flipAnimation.status == AnimationStatus.completed) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }
    setState(() {
      _isFlipped = !_isFlipped;
    });
  }

  void _handleSwipe(DragEndDetails details) {
    if (details.primaryVelocity! > 500) {
      // 右スワイプ - 正解
      _handleCorrectAnswer();
    } else if (details.primaryVelocity! < -500) {
      // 左スワイプ - 間違い
      _handleWrongAnswer();
    }
  }

  void _handleCorrectAnswer() {
    setState(() {
      _correctAnswers++;
      _currentCardIndex++;
    });

    if (_currentCardIndex >= _totalCards) {
      _showCompletionDialog();
    } else {
      _resetCardState();
      _showFeedback(true);
    }
  }

  void _handleWrongAnswer() {
    setState(() {
      _wrongAnswers++;
      _currentCardIndex++;
    });

    if (_currentCardIndex >= _totalCards) {
      _showCompletionDialog();
    } else {
      _resetCardState();
      _showFeedback(false);
    }
  }

  void _resetCardState() {
    _isFlipped = false;
    _showAnswer = false;
    _flipController.reset();
  }

  void _showFeedback(bool isCorrect) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isCorrect ? '正解です！' : '間違えました...'),
        backgroundColor: isCorrect ? Colors.green : Colors.red,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('学習完了！'),
        content: Text(
          'お疲れさまでした！\n'
          '正解: $_correctAnswers問\n'
          '間違い: $_wrongAnswers問\n'
          '正答率: ${((_correctAnswers / _totalCards) * 100).toStringAsFixed(1)}%',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('完了'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                      '進捗: ${_currentCardIndex + 1}/$_totalCards',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: theme.textColor,
                      ),
                    ),
                    Text(
                      '残り: ${_totalCards - _currentCardIndex - 1}枚',
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
                child: GestureDetector(
                  onPanEnd: _handleSwipe,
                  child: Center(
                    child: AnimatedBuilder(
                      animation: _punchAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _punchAnimation.value,
                          child: _buildFlashCard(theme),
                        );
                      },
                    ),
                  ),
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
                    _handleWrongAnswer,
                  ),
                  _buildActionButton(
                    context,
                    theme,
                    Icons.flip,
                    'フリップ',
                    Colors.blue,
                    _flipAction,
                  ),
                  _buildActionButton(
                    context,
                    theme,
                    Icons.check,
                    '正解',
                    Colors.green,
                    _handleCorrectAnswer,
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // 操作説明
              Text(
                '💡 カードをタップでパンチ、スワイプで回答、フリップボタンで裏返し',
                style: TextStyle(fontSize: 12, color: theme.textSecondaryColor),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFlashCard(AppTheme theme) {
    final currentCard = _cards[_currentCardIndex % _cards.length];

    return GestureDetector(
      onTap: _punchAction,
      child: AnimatedBuilder(
        animation: _flipAnimation,
        builder: (context, child) {
          final flipValue = _flipAnimation.value;
          final isFlipped = flipValue >= 0.5;

          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(flipValue * 3.14159),
            child: isFlipped
                ? _buildBackSide(theme, currentCard)
                : _buildFrontSide(theme, currentCard),
          );
        },
      ),
    );
  }

  Widget _buildFrontSide(AppTheme theme, Map<String, String> card) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 300,
        height: 400,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [theme.cardColor, theme.cardColor.withValues(alpha: 0.8)],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lightbulb_outline, size: 48, color: theme.primaryColor),
            const SizedBox(height: 24),
            Text(
              card['word']!,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: theme.textColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              card['sentence']!,
              style: TextStyle(
                fontSize: 16,
                color: theme.textSecondaryColor,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Text(
              'タップしてパンチ！',
              style: TextStyle(
                fontSize: 14,
                color: theme.primaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackSide(AppTheme theme, Map<String, String> card) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 300,
        height: 400,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.primaryColor.withValues(alpha: 0.1),
              theme.primaryColor.withValues(alpha: 0.05),
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.translate, size: 48, color: theme.primaryColor),
            const SizedBox(height: 24),
            Text(
              card['definition']!,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: theme.textColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              '意味',
              style: TextStyle(
                fontSize: 14,
                color: theme.textSecondaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAnswerButton(
                  context,
                  theme,
                  '間違えた',
                  Colors.red,
                  _handleWrongAnswer,
                ),
                _buildAnswerButton(
                  context,
                  theme,
                  '正解',
                  Colors.green,
                  _handleCorrectAnswer,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnswerButton(
    BuildContext context,
    AppTheme theme,
    String label,
    Color color,
    VoidCallback onPressed,
  ) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
}
