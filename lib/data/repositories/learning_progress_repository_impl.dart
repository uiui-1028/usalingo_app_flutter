import '../../domain/repositories/learning_progress_repository.dart';
import '../../domain/entities/learning_progress.dart';
import '../datasources/learning_progress_datasource.dart';

// 学習進捗リポジトリの実装クラス
class LearningProgressRepositoryImpl implements LearningProgressRepository {
  final LearningProgressDataSource _dataSource;

  LearningProgressRepositoryImpl(this._dataSource);

  @override
  Future<LearningProgress?> getLearningProgress(int wordId) async {
    try {
      return await _dataSource.getLearningProgress(wordId);
    } catch (e) {
      // エラーハンドリング
      throw Exception('Failed to get learning progress: $e');
    }
  }

  @override
  Future<List<LearningProgress>> getDueTodayProgress() async {
    try {
      return await _dataSource.getDueTodayProgress();
    } catch (e) {
      // エラーハンドリング
      throw Exception('Failed to get due today progress: $e');
    }
  }

  @override
  Future<List<LearningProgress>> getAllLearningProgress() async {
    try {
      return await _dataSource.getAllLearningProgress();
    } catch (e) {
      // エラーハンドリング
      throw Exception('Failed to get all learning progress: $e');
    }
  }

  @override
  Future<void> saveLearningProgress(LearningProgress progress) async {
    try {
      await _dataSource.saveLearningProgress(progress);
    } catch (e) {
      // エラーハンドリング
      throw Exception('Failed to save learning progress: $e');
    }
  }

  @override
  Future<void> deleteLearningProgress(int wordId) async {
    try {
      await _dataSource.deleteLearningProgress(wordId);
    } catch (e) {
      // エラーハンドリング
      throw Exception('Failed to delete learning progress: $e');
    }
  }

  @override
  Future<void> deleteAllLearningProgress() async {
    try {
      await _dataSource.deleteAllLearningProgress();
    } catch (e) {
      // エラーハンドリング
      throw Exception('Failed to delete all learning progress: $e');
    }
  }

  @override
  Future<void> markCardAsCorrect(int wordId) async {
    try {
      await _dataSource.markCardAsCorrect(wordId);
    } catch (e) {
      // エラーハンドリング
      throw Exception('Failed to mark card as correct: $e');
    }
  }

  @override
  Future<void> markCardAsIncorrect(int wordId) async {
    try {
      await _dataSource.markCardAsIncorrect(wordId);
    } catch (e) {
      // エラーハンドリング
      throw Exception('Failed to mark card as incorrect: $e');
    }
  }
}
