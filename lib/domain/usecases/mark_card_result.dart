import '../repositories/learning_progress_repository.dart';

/// カードの学習結果を記録するユースケース
class MarkCardResult {
  final LearningProgressRepository _repository;

  MarkCardResult(this._repository);

  /// カードを正解として記録
  Future<void> markAsCorrect(int wordId) async {
    await _repository.markCardAsCorrect(wordId);
  }

  /// カードを不正解として記録
  Future<void> markAsIncorrect(int wordId) async {
    await _repository.markCardAsIncorrect(wordId);
  }
}
