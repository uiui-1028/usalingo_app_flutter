import '../entities/learning_progress.dart';
import '../repositories/learning_progress_repository.dart';

/// 特定の単語の学習進捗を取得するユースケース
class GetLearningProgress {
  final LearningProgressRepository _repository;

  GetLearningProgress(this._repository);

  /// 指定された単語IDの学習進捗を取得
  /// 存在しない場合はnullを返す
  Future<LearningProgress?> call(int wordId) async {
    return await _repository.getLearningProgress(wordId);
  }
}
