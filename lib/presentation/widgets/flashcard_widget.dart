import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import '../../domain/entities/word.dart';
import 'lottie_feedback_widget.dart';
import 'dart:math';
import '../theme/app_theme_provider.dart';
import '../theme/app_theme.dart';
import '../../app/providers.dart';

final wordListProvider = FutureProvider<List<Word>>((ref) async {
  final repo = ref.watch(wordRepositoryProvider);
  return await repo.fetchAllWords();
});
final currentIndexProvider = StateProvider<int>((ref) => 0);
final isAnswerVisibleProvider = StateProvider<bool>((ref) => false);

class FlashcardWidget extends ConsumerStatefulWidget {
  final Function(int)? onCardIndexChanged;

  const FlashcardWidget({super.key, this.onCardIndexChanged});

  @override
  ConsumerState<FlashcardWidget> createState() => _FlashcardWidgetState();
}

class _FlashcardWidgetState extends ConsumerState<FlashcardWidget>
    with SingleTickerProviderStateMixin {
  Offset cardOffset = Offset.zero;
  double cardAngle = 0.0;
  bool isDragging = false;
  late AnimationController _animationController;
  late Animation<Offset> _offsetAnimation;
  late Animation<double> _angleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _offsetAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(_animationController);
    _angleAnimation = Tween<double>(
      begin: 0,
      end: 0,
    ).animate(_animationController);
    _animationController.addListener(() {
      setState(() {
        cardOffset = _offsetAnimation.value;
        cardAngle = _angleAnimation.value;
      });
    });
    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        cardOffset = Offset.zero;
        cardAngle = 0.0;
        isDragging = false;
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void animateCardBack() {
    _offsetAnimation = Tween<Offset>(
      begin: cardOffset,
      end: Offset.zero,
    ).animate(_animationController);
    _angleAnimation = Tween<double>(
      begin: cardAngle,
      end: 0,
    ).animate(_animationController);
    _animationController.forward(from: 0);
  }

  void animateCardOffScreen(bool isRight) {
    final width = MediaQuery.of(context).size.width;
    final endOffset = Offset(isRight ? width : -width, 0);
    _offsetAnimation = Tween<Offset>(
      begin: cardOffset,
      end: endOffset,
    ).animate(_animationController);
    _angleAnimation = Tween<double>(
      begin: cardAngle,
      end: isRight ? pi / 8 : -pi / 8,
    ).animate(_animationController);
    _animationController.forward(from: 0).then((_) {
      HapticFeedback.mediumImpact();
      Future.delayed(const Duration(milliseconds: 100), () {
        final newIndex = ref.read(currentIndexProvider.notifier).state + 1;
        ref.read(currentIndexProvider.notifier).state = newIndex;
        ref.read(isAnswerVisibleProvider.notifier).state = false;

        // 親ページにカードインデックスの変更を通知
        if (widget.onCardIndexChanged != null) {
          widget.onCardIndexChanged!(newIndex);
        }

        setState(() {
          cardOffset = Offset.zero;
          cardAngle = 0.0;
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final wordListAsync = ref.watch(wordListProvider);
    final currentIndex = ref.watch(currentIndexProvider);
    final isAnswerVisible = ref.watch(isAnswerVisibleProvider);
    return wordListAsync.when(
      data: (wordList) {
        if (currentIndex >= wordList.length) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  '学習完了！',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                LottieFeedbackWidget(
                  assetPath: 'assets/test_lottie/Feather (2).json',
                ),
              ],
            ),
          );
        }
        final word = wordList[currentIndex];
        final nextWord = currentIndex + 1 < wordList.length
            ? wordList[currentIndex + 1]
            : null;
        final cardSize = MediaQuery.of(context).size.width * 0.8;
        return Stack(
          children: [
            // 画面中央に配置
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 次のカード（重なり感）
                  if (nextWord != null)
                    Transform.translate(
                      offset: const Offset(0, 8),
                      child: _buildCard(
                        context,
                        nextWord,
                        cardSize,
                        false,
                        false,
                      ),
                    ),
                  // 現在のカード
                  Transform.translate(
                    offset: cardOffset,
                    child: Transform.rotate(
                      angle: cardAngle,
                      child: GestureDetector(
                        onPanStart: (_) {
                          setState(() => isDragging = true);
                        },
                        onPanUpdate: (details) {
                          setState(() {
                            cardOffset += details.delta;
                            cardAngle = cardOffset.dx / (cardSize * 2.5);
                          });
                        },
                        onPanEnd: (details) {
                          setState(() => isDragging = false);
                          final threshold = cardSize * 0.35;
                          if (cardOffset.dx > threshold) {
                            animateCardOffScreen(true);
                          } else if (cardOffset.dx < -threshold) {
                            animateCardOffScreen(false);
                          } else {
                            animateCardBack();
                          }
                        },
                        child: _buildCard(
                          context,
                          word,
                          cardSize,
                          true,
                          isAnswerVisible,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('エラー: $err')),
    );
  }

  Widget _buildCard(
    BuildContext context,
    Word word,
    double size,
    bool isFront,
    bool isAnswerVisible,
  ) {
    final theme = ref.watch(currentThemeProvider);
    return Container(
      width: size,
      height: size * 1.35,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: BorderRadius.circular(theme.cornerRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: theme.borderColor, width: theme.borderWidth),
      ),
      child: Stack(
        children: [
          // グリッド模様
          CustomPaint(
            size: Size(size, size * 1.35),
            painter: GridPatternPainter(),
          ),
          // カード内容
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '10',
                      style: TextStyle(
                        fontSize: 22,
                        color: theme.textColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Transform.rotate(
                      angle: pi,
                      child: Text(
                        '10',
                        style: TextStyle(
                          fontSize: 22,
                          color: theme.textColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(Icons.favorite, color: theme.primaryColor, size: 28),
                    Transform.rotate(
                      angle: pi,
                      child: Icon(
                        Icons.favorite,
                        color: theme.primaryColor,
                        size: 28,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // ハート型シンボル配置（中央）
                if (word.imageUrl != null && word.imageUrl!.isNotEmpty)
                  Center(
                    child: Image.network(
                      word.imageUrl!,
                      width: 120,
                      height: 120,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          _buildHeartGrid(theme),
                    ),
                  )
                else
                  Center(child: _buildHeartGrid(theme)),
                const Spacer(),
                // 単語・意味・例文
                Center(
                  child: Column(
                    children: [
                      Text(
                        word.text,
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      AnimatedOpacity(
                        opacity: isFront && isAnswerVisible ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          word.meaning,
                          style: Theme.of(context).textTheme.titleLarge,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      if (isFront && !isAnswerVisible)
                        Text(
                          'タップで解答表示',
                          style: TextStyle(color: theme.textSecondaryColor),
                        ),
                      const SizedBox(height: 12),
                      Text(
                        word.sentence ?? '例文なし',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      if (word.tags != null && word.tags!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            'タグ: ${word.tags}',
                            style: TextStyle(
                              color: theme.textSecondaryColor,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // タップ領域
          if (isFront)
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(theme.cornerRadius),
                  onTap: () {
                    ref.read(isAnswerVisibleProvider.notifier).state = true;
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeartGrid(AppTheme theme) {
    // 添付画像のようなハート配置（10個）
    // 3-2-2-3のダイヤ型配置
    final positions = [
      const Offset(0, 0),
      const Offset(-24, 24),
      const Offset(24, 24),
      const Offset(-48, 48),
      const Offset(0, 48),
      const Offset(48, 48),
      const Offset(-24, 72),
      const Offset(24, 72),
      const Offset(0, 96),
      const Offset(0, 120),
    ];
    return SizedBox(
      width: 120,
      height: 140,
      child: Stack(
        children: [
          for (final pos in positions)
            Positioned(
              left: 60 + pos.dx - 14,
              top: pos.dy,
              child: Icon(Icons.favorite, color: theme.primaryColor, size: 28),
            ),
        ],
      ),
    );
  }
}

class GridPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.12)
      ..strokeWidth = 1;
    const step = 18.0;
    for (double x = 0; x < size.width; x += step) {
      for (double y = 0; y < size.height; y += step) {
        canvas.drawLine(Offset(x, y), Offset(x + step, y), paint);
        canvas.drawLine(Offset(x, y), Offset(x, y + step), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
