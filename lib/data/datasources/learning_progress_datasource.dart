import '../../domain/entities/learning_progress.dart';

// 学習進捗データソースのインターフェース
abstract class LearningProgressDataSource {
  // 特定の単語の学習進捗を取得
  Future<LearningProgress?> getLearningProgress(int wordId);

  // 今日復習すべきカードを取得
  Future<List<LearningProgress>> getDueTodayProgress();

  // 全ての学習進捗を取得
  Future<List<LearningProgress>> getAllLearningProgress();

  // 学習進捗を保存
  Future<void> saveLearningProgress(LearningProgress progress);

  // 学習進捗を削除
  Future<void> deleteLearningProgress(int wordId);

  // 全ての学習進捗を削除
  Future<void> deleteAllLearningProgress();

  // カードを正解として記録
  Future<void> markCardAsCorrect(int wordId);

  // カードを不正解として記録
  Future<void> markCardAsIncorrect(int wordId);
}

// Supabase学習進捗データソースの実装
class LearningProgressSupabaseDataSource implements LearningProgressDataSource {
  @override
  Future<LearningProgress?> getLearningProgress(int wordId) async {
    // TODO: Supabaseから学習進捗データを取得する実装
    throw UnimplementedError();
  }

  @override
  Future<List<LearningProgress>> getDueTodayProgress() async {
    // TODO: 今日復習すべきカードをSupabaseから取得する実装
    throw UnimplementedError();
  }

  @override
  Future<List<LearningProgress>> getAllLearningProgress() async {
    // TODO: 全ての学習進捗をSupabaseから取得する実装
    throw UnimplementedError();
  }

  @override
  Future<void> saveLearningProgress(LearningProgress progress) async {
    // TODO: Supabaseに学習進捗データを保存する実装
    throw UnimplementedError();
  }

  @override
  Future<void> deleteLearningProgress(int wordId) async {
    // TODO: Supabaseの学習進捗データを削除する実装
    throw UnimplementedError();
  }

  @override
  Future<void> deleteAllLearningProgress() async {
    // TODO: 全ての学習進捗をSupabaseから削除する実装
    throw UnimplementedError();
  }

  @override
  Future<void> markCardAsCorrect(int wordId) async {
    // TODO: カードを正解として記録する実装
    throw UnimplementedError();
  }

  @override
  Future<void> markCardAsIncorrect(int wordId) async {
    // TODO: カードを不正解として記録する実装
    throw UnimplementedError();
  }
}
