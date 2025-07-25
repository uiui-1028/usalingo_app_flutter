import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import '../../domain/entities/word.dart';
import '../../data/datasources/local_word_datasource.dart';
import '../widgets/lottie_feedback_widget.dart';
import 'dart:math';

final wordListProvider = Provider<List<Word>>(
  (ref) => LocalWordDatasource().getWords(),
);
final currentIndexProvider = StateProvider<int>((ref) => 0);
final isAnswerVisibleProvider = StateProvider<bool>((ref) => false);
final lottieFeedbackProvider = StateProvider<String?>((ref) => null);

class FlashcardWidget extends ConsumerWidget {
  const FlashcardWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wordList = ref.watch(wordListProvider);
    final currentIndex = ref.watch(currentIndexProvider);
    final isAnswerVisible = ref.watch(isAnswerVisibleProvider);
    final lottieFeedback = ref.watch(lottieFeedbackProvider);
    if (currentIndex >= wordList.length) {
      return const Text('学習完了！');
    }
    final word = wordList[currentIndex];
    return Stack(
      alignment: Alignment.center,
      children: [
        GestureDetector(
          onTap: () {
            ref.read(isAnswerVisibleProvider.notifier).state = true;
          },
          onHorizontalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0;
            if (velocity.abs() > 200) {
              // 右スワイプ: わかった, 左スワイプ: わからない
              final isRight = velocity > 0;
              final lottieFiles = [
                'assets/lottie/Feather (2).json', // チェック
                'assets/lottie/Feather (3).json', // バツ
              ];
              ref.read(lottieFeedbackProvider.notifier).state = isRight
                  ? lottieFiles[0]
                  : lottieFiles[1];
              HapticFeedback.mediumImpact();
              Future.delayed(const Duration(milliseconds: 500), () {
                ref.read(lottieFeedbackProvider.notifier).state = null;
                ref.read(currentIndexProvider.notifier).state++;
                ref.read(isAnswerVisibleProvider.notifier).state = false;
              });
            }
          },
          child: Card(
            elevation: 8,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    word.text,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 16),
                  AnimatedOpacity(
                    opacity: isAnswerVisible ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      word.meaning,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  if (!isAnswerVisible) const Text('タップで解答表示'),
                  const SizedBox(height: 16),
                  Text(
                    word.sentence,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (lottieFeedback != null)
          LottieFeedbackWidget(assetPath: lottieFeedback),
      ],
    );
  }
}
