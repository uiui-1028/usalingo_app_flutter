import '../repositories/learning_progress_repository.dart';
import '../entities/learning_progress.dart';

// 今日学習すべきカードを取得するユースケース
class GetDueTodayCards {
  final LearningProgressRepository _repository;

  GetDueTodayCards(this._repository);

  // 今日復習すべきカードの一覧を取得
  Future<List<LearningProgress>> execute() async {
    try {
      // リポジトリから今日復習すべきカードを取得
      final dueCards = await _repository.getDueTodayProgress();
      
      // 今日復習すべきカードのみをフィルタリング
      final today = DateTime.now();
      final todayCards = dueCards.where((card) {
        final reviewDate = card.nextReviewDate;
        final reviewDay = DateTime(
          reviewDate.year,
          reviewDate.month,
          reviewDate.day,
        );
        final todayDay = DateTime(
          today.year,
          today.month,
          today.day,
        );
        return reviewDay.isBefore(todayDay) || reviewDay.isAtSameMomentAs(todayDay);
      }).toList();

      return todayCards;
    } catch (e) {
      // エラーが発生した場合は空のリストを返す
      return [];
    }
  }

  // 特定のユーザーの今日復習すべきカードを取得
  Future<List<LearningProgress>> executeForUser(String userId) async {
    // TODO: ユーザーIDに基づいて今日復習すべきカードを取得する実装
    throw UnimplementedError();
  }
}
