import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme_provider.dart';
import '../theme/app_theme.dart';

// フラッシュカードウィジェット
class FlashcardWidget extends ConsumerStatefulWidget {
  final String word;
  final String definition;
  final String? sentence;
  final String? sentenceTranslation;
  final VoidCallback? onCorrect;
  final VoidCallback? onIncorrect;

  const FlashcardWidget({
    super.key,
    required this.word,
    required this.definition,
    this.sentence,
    this.sentenceTranslation,
    this.onCorrect,
    this.onIncorrect,
  });

  @override
  ConsumerState<FlashcardWidget> createState() => _FlashcardWidgetState();
}

class _FlashcardWidgetState extends ConsumerState<FlashcardWidget>
    with TickerProviderStateMixin {
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  bool _isFlipped = false;
  bool _showAnswer = false;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _flipAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _flipController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  // パンチアクション（タップで解答表示）
  void _punchAction() {
    setState(() {
      _showAnswer = !_showAnswer;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(currentThemeProvider);
    
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
            child: isFlipped ? _buildBackSide(theme) : _buildFrontSide(theme),
          );
        },
      ),
    );
  }

  // カードの表面（単語）
  Widget _buildFrontSide(AppTheme theme) {
    return Card(
      color: theme.surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(theme.cornerRadius),
        side: BorderSide(
          color: theme.borderColor,
          width: theme.borderWidth,
        ),
      ),
      child: Container(
        padding: EdgeInsets.all(theme.paddingLarge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              widget.word,
              style: TextStyle(
                fontSize: theme.fontSizeLarge,
                fontWeight: theme.fontWeightBold,
                color: theme.textColor,
                fontFamily: theme.fontFamily,
              ),
              textAlign: TextAlign.center,
            ),
            if (widget.sentence != null) ...[
              SizedBox(height: theme.marginMedium),
              Text(
                widget.sentence!,
                style: TextStyle(
                  fontSize: theme.fontSizeMedium,
                  fontWeight: theme.fontWeightNormal,
                  color: theme.textSecondaryColor,
                  fontFamily: theme.fontFamily,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // カードの裏面（意味）
  Widget _buildBackSide(AppTheme theme) {
    return Card(
      color: theme.surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(theme.cornerRadius),
        side: BorderSide(
          color: theme.borderColor,
          width: theme.borderWidth,
        ),
      ),
      child: Container(
        padding: EdgeInsets.all(theme.paddingLarge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              widget.definition,
              style: TextStyle(
                fontSize: theme.fontSizeLarge,
                fontWeight: theme.fontWeightBold,
                color: theme.textColor,
                fontFamily: theme.fontFamily,
              ),
              textAlign: TextAlign.center,
            ),
            if (widget.sentenceTranslation != null) ...[
              SizedBox(height: theme.marginMedium),
              Text(
                widget.sentenceTranslation!,
                style: TextStyle(
                  fontSize: theme.fontSizeMedium,
                  fontWeight: theme.fontWeightNormal,
                  color: theme.textSecondaryColor,
                  fontFamily: theme.fontFamily,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            SizedBox(height: theme.marginLarge),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: widget.onIncorrect,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: theme.textColor,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(theme.cornerRadius),
                      side: BorderSide(
                        color: Colors.red,
                        width: theme.borderWidth,
                      ),
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: theme.paddingMedium,
                      vertical: theme.paddingSmall,
                    ),
                  ),
                  child: const Text('わからない'),
                ),
                ElevatedButton(
                  onPressed: widget.onCorrect,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.accentColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(theme.cornerRadius),
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: theme.paddingMedium,
                      vertical: theme.paddingSmall,
                    ),
                  ),
                  child: const Text('わかる'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
