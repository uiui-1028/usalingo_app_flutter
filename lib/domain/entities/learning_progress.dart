/// リートナー方式による学習進捗を管理するエンティティ
class LearningProgress {
  final int wordId; // どの単語の進捗かを示す一意なID
  final int srsLevel; // リートナー方式のレベル（1〜5）
  final DateTime nextReviewDate; // 次回復習日

  const LearningProgress({
    required this.wordId,
    required this.srsLevel,
    required this.nextReviewDate,
  });

  /// 新しいインスタンスを作成（デフォルト値付き）
  factory LearningProgress.initial(int wordId) {
    return LearningProgress(
      wordId: wordId,
      srsLevel: 1,
      nextReviewDate: DateTime.now().add(const Duration(days: 1)),
    );
  }

  /// 正解時の進捗更新
  LearningProgress markAsCorrect() {
    final newLevel = srsLevel < 5 ? srsLevel + 1 : 5;
    final intervalDays = _getIntervalDays(newLevel);
    final newNextReviewDate = DateTime.now().add(Duration(days: intervalDays));

    return LearningProgress(
      wordId: wordId,
      srsLevel: newLevel,
      nextReviewDate: newNextReviewDate,
    );
  }

  /// 不正解時の進捗更新
  LearningProgress markAsIncorrect() {
    return LearningProgress(
      wordId: wordId,
      srsLevel: 1,
      nextReviewDate: DateTime.now().add(const Duration(days: 1)),
    );
  }

  /// レベルに対応する復習間隔を取得
  int _getIntervalDays(int level) {
    switch (level) {
      case 1:
        return 1;
      case 2:
        return 3;
      case 3:
        return 7;
      case 4:
        return 14;
      case 5:
        return 30;
      default:
        return 1;
    }
  }

  /// 今日復習すべきかどうかを判定
  bool get isDueToday {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final reviewDate = DateTime(
      nextReviewDate.year,
      nextReviewDate.month,
      nextReviewDate.day,
    );
    return reviewDate.isBefore(today) || reviewDate.isAtSameMomentAs(today);
  }

  /// マスター済みかどうかを判定（レベル5に達しているか）
  bool get isMastered => srsLevel >= 5;

  /// コピーウィズメソッド
  LearningProgress copyWith({
    int? wordId,
    int? srsLevel,
    DateTime? nextReviewDate,
  }) {
    return LearningProgress(
      wordId: wordId ?? this.wordId,
      srsLevel: srsLevel ?? this.srsLevel,
      nextReviewDate: nextReviewDate ?? this.nextReviewDate,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LearningProgress &&
        other.wordId == wordId &&
        other.srsLevel == srsLevel &&
        other.nextReviewDate == nextReviewDate;
  }

  @override
  int get hashCode =>
      wordId.hashCode ^ srsLevel.hashCode ^ nextReviewDate.hashCode;

  @override
  String toString() {
    return 'LearningProgress(wordId: $wordId, srsLevel: $srsLevel, nextReviewDate: $nextReviewDate)';
  }
}
