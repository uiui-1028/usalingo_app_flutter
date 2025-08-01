import '../entities/learning_progress.dart';

/// 学習進捗管理のリポジトリインターフェース
abstract class LearningProgressRepository {
  /// 指定された単語IDの学習進捗を取得
  /// 存在しない場合はnullを返す
  Future<LearningProgress?> getLearningProgress(int wordId);

  /// 今日復習すべき学習進捗一覧を取得
  Future<List<LearningProgress>> getDueTodayProgress();

  /// すべての学習進捗を取得
  Future<List<LearningProgress>> getAllLearningProgress();

  /// 学習進捗を保存または更新
  Future<void> saveLearningProgress(LearningProgress progress);

  /// 指定された単語IDの学習進捗を削除
  Future<void> deleteLearningProgress(int wordId);

  /// すべての学習進捗を削除
  Future<void> deleteAllLearningProgress();

  /// カードを正解として記録し、進捗を更新
  Future<void> markCardAsCorrect(int wordId);

  /// カードを不正解として記録し、進捗を更新
  Future<void> markCardAsIncorrect(int wordId);
}
