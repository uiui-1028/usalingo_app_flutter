import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/datasources/learning_progress_datasource.dart';
import '../data/repositories/learning_progress_repository_impl.dart';
import '../domain/repositories/learning_progress_repository.dart';
import '../domain/usecases/get_due_today_cards.dart';
import '../domain/usecases/mark_card_result.dart';
import '../domain/usecases/get_learning_progress.dart';

/// 学習進捗データソースのプロバイダー
final learningProgressDataSourceProvider = Provider<LearningProgressDataSource>(
  (ref) => LearningProgressDataSource(),
);

/// 学習進捗リポジトリのプロバイダー
final learningProgressRepositoryProvider = Provider<LearningProgressRepository>(
  (ref) {
    final dataSource = ref.watch(learningProgressDataSourceProvider);
    return LearningProgressRepositoryImpl(dataSource);
  },
);

/// 今日復習すべきカードを取得するユースケースのプロバイダー
final getDueTodayCardsProvider = Provider<GetDueTodayCards>((ref) {
  final repository = ref.watch(learningProgressRepositoryProvider);
  return GetDueTodayCards(repository);
});

/// カードの学習結果を記録するユースケースのプロバイダー
final markCardResultProvider = Provider<MarkCardResult>((ref) {
  final repository = ref.watch(learningProgressRepositoryProvider);
  return MarkCardResult(repository);
});

/// 特定の単語の学習進捗を取得するユースケースのプロバイダー
final getLearningProgressProvider = Provider<GetLearningProgress>((ref) {
  final repository = ref.watch(learningProgressRepositoryProvider);
  return GetLearningProgress(repository);
});
