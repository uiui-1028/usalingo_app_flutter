import '../entities/learning_progress.dart';
import '../repositories/learning_progress_repository.dart';

/// 今日復習すべきカードを取得するユースケース
class GetDueTodayCards {
  final LearningProgressRepository _repository;

  GetDueTodayCards(this._repository);

  /// 今日復習すべき学習進捗一覧を取得
  Future<List<LearningProgress>> call() async {
    return await _repository.getDueTodayProgress();
  }
}
