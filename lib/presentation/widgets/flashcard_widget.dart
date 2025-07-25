import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import '../../domain/entities/word.dart';
import '../../data/datasources/local_word_datasource.dart';
import '../widgets/lottie_feedback_widget.dart';
import 'dart:math';
import '../../presentation/theme/app_theme_provider.dart';
import '../../presentation/theme/app_theme.dart';

final wordListProvider = Provider<List<Word>>(
  (ref) => LocalWordDatasource().getWords(),
);
final currentIndexProvider = StateProvider<int>((ref) => 0);
final isAnswerVisibleProvider = StateProvider<bool>((ref) => false);
final lottieFeedbackProvider = StateProvider<String?>((ref) => null);

class FlashcardWidget extends ConsumerStatefulWidget {
  const FlashcardWidget({super.key});
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
      ref.read(lottieFeedbackProvider.notifier).state = isRight
          ? 'assets/lottie/Feather (2).json'
          : 'assets/lottie/Feather (3).json';
      HapticFeedback.mediumImpact();
      Future.delayed(const Duration(milliseconds: 500), () {
        ref.read(lottieFeedbackProvider.notifier).state = null;
        ref.read(currentIndexProvider.notifier).state++;
        ref.read(isAnswerVisibleProvider.notifier).state = false;
        setState(() {
          cardOffset = Offset.zero;
          cardAngle = 0.0;
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final wordList = ref.watch(wordListProvider);
    final currentIndex = ref.watch(currentIndexProvider);
    final isAnswerVisible = ref.watch(isAnswerVisibleProvider);
    final lottieFeedback = ref.watch(lottieFeedbackProvider);
    if (currentIndex >= wordList.length) {
      return const Text('学習完了！');
    }
    final word = wordList[currentIndex];
    final nextWord = currentIndex + 1 < wordList.length
        ? wordList[currentIndex + 1]
        : null;
    final cardSize = MediaQuery.of(context).size.width * 0.8;
    return Stack(
      alignment: Alignment.center,
      children: [
        // 次のカード（重なり感）
        if (nextWord != null && lottieFeedback == null)
          Transform.scale(
            scale: 0.95,
            child: _buildCard(context, nextWord, cardSize, false, false),
          ),
        // 現在のカード
        if (lottieFeedback == null)
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
        if (lottieFeedback != null)
          LottieFeedbackWidget(assetPath: lottieFeedback),
      ],
    );
  }

  Widget _buildCard(
    BuildContext context,
    Word word,
    double size,
    bool isFront,
    bool isAnswerVisible,
  ) {
    final theme = ref.watch(appThemeProvider);
    return Container(
      width: size,
      height: size * 1.35,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: theme.cornerRadius,
        boxShadow: theme.shadows,
        border: Border.fromBorderSide(theme.border),
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
                        color: theme.primaryText,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Transform.rotate(
                      angle: pi,
                      child: Text(
                        '10',
                        style: TextStyle(
                          fontSize: 22,
                          color: theme.primaryText,
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
                    Icon(Icons.favorite, color: theme.accent, size: 28),
                    Transform.rotate(
                      angle: pi,
                      child: Icon(
                        Icons.favorite,
                        color: theme.accent,
                        size: 28,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // ハート型シンボル配置（中央）
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
                          style: TextStyle(color: theme.secondaryText),
                        ),
                      const SizedBox(height: 12),
                      Text(
                        word.sentence,
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
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
                  borderRadius: theme.cornerRadius,
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
              child: Icon(Icons.favorite, color: theme.accent, size: 28),
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
      ..color = Colors.grey.withOpacity(0.12)
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
