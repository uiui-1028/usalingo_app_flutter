import '../repositories/learning_progress_repository.dart';

// カードの学習結果を記録するユースケース
class MarkCardResult {
  final LearningProgressRepository _repository;

  MarkCardResult(this._repository);

  // カードを正解として記録
  Future<void> executeCorrect(int wordId) async {
    try {
      await _repository.markCardAsCorrect(wordId);
    } catch (e) {
      // エラーハンドリング
      throw Exception('Failed to mark card as correct: $e');
    }
  }

  // カードを不正解として記録
  Future<void> executeIncorrect(int wordId) async {
    try {
      await _repository.markCardAsIncorrect(wordId);
    } catch (e) {
      // エラーハンドリング
      throw Exception('Failed to mark card as incorrect: $e');
    }
  }

  // カードの学習結果を記録（正解・不正解の判定付き）
  Future<void> executeWithResult(int wordId, bool isCorrect) async {
    if (isCorrect) {
      await executeCorrect(wordId);
    } else {
      await executeIncorrect(wordId);
    }
  }

  // 複数のカードの結果を一括で記録
  Future<void> executeBatch(List<Map<String, dynamic>> results) async {
    try {
      for (final result in results) {
        final wordId = result['wordId'] as int;
        final isCorrect = result['isCorrect'] as bool;
        
        if (isCorrect) {
          await executeCorrect(wordId);
        } else {
          await executeIncorrect(wordId);
        }
      }
    } catch (e) {
      // エラーハンドリング
      throw Exception('Failed to mark batch results: $e');
    }
  }

  // 正解としてマーク（エイリアスメソッド）
  Future<void> markAsCorrect(int wordId) async {
    await executeCorrect(wordId);
  }

  // 不正解としてマーク（エイリアスメソッド）
  Future<void> markAsIncorrect(int wordId) async {
    await executeIncorrect(wordId);
  }
}
