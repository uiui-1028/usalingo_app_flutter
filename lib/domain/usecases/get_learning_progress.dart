import '../repositories/learning_progress_repository.dart';
import '../entities/learning_progress.dart';

// 学習進捗を取得するユースケース
class GetLearningProgress {
  final LearningProgressRepository _repository;

  GetLearningProgress(this._repository);

  // 特定の単語の学習進捗を取得
  Future<LearningProgress?> execute(int wordId) async {
    try {
      return await _repository.getLearningProgress(wordId);
    } catch (e) {
      // エラーが発生した場合はnullを返す
      return null;
    }
  }

  // 全ての学習進捗を取得
  Future<List<LearningProgress>> executeAll() async {
    try {
      return await _repository.getAllLearningProgress();
    } catch (e) {
      // エラーが発生した場合は空のリストを返す
      return [];
    }
  }

  // 特定のユーザーの学習進捗を取得
  Future<List<LearningProgress>> executeForUser(String userId) async {
    // TODO: ユーザーIDに基づいて学習進捗を取得する実装
    throw UnimplementedError();
  }
}
