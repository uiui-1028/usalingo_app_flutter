import '../../domain/entities/learning_progress.dart';
import '../../domain/repositories/learning_progress_repository.dart';
import '../datasources/learning_progress_datasource.dart';

/// 学習進捗管理のリポジトリ実装クラス
class LearningProgressRepositoryImpl implements LearningProgressRepository {
  final LearningProgressDataSource _dataSource;

  LearningProgressRepositoryImpl(this._dataSource);

  @override
  Future<LearningProgress?> getLearningProgress(int wordId) async {
    return await _dataSource.getLearningProgress(wordId);
  }

  @override
  Future<List<LearningProgress>> getDueTodayProgress() async {
    return await _dataSource.getDueTodayProgress();
  }

  @override
  Future<List<LearningProgress>> getAllLearningProgress() async {
    return await _dataSource.getAllLearningProgress();
  }

  @override
  Future<void> saveLearningProgress(LearningProgress progress) async {
    await _dataSource.saveLearningProgress(progress);
  }

  @override
  Future<void> deleteLearningProgress(int wordId) async {
    await _dataSource.deleteLearningProgress(wordId);
  }

  @override
  Future<void> deleteAllLearningProgress() async {
    await _dataSource.deleteAllLearningProgress();
  }

  @override
  Future<void> markCardAsCorrect(int wordId) async {
    // 既存の進捗を取得、存在しない場合は初期値を設定
    final existingProgress = await _dataSource.getLearningProgress(wordId);
    final currentProgress =
        existingProgress ?? LearningProgress.initial(wordId);

    // 正解として進捗を更新
    final updatedProgress = currentProgress.markAsCorrect();
    await _dataSource.saveLearningProgress(updatedProgress);
  }

  @override
  Future<void> markCardAsIncorrect(int wordId) async {
    // 既存の進捗を取得、存在しない場合は初期値を設定
    final existingProgress = await _dataSource.getLearningProgress(wordId);
    final currentProgress =
        existingProgress ?? LearningProgress.initial(wordId);

    // 不正解として進捗を更新
    final updatedProgress = currentProgress.markAsIncorrect();
    await _dataSource.saveLearningProgress(updatedProgress);
  }
}
