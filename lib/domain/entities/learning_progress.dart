/// 忘却曲線アルゴリズムによる学習進捗を管理するエンティティ
class LearningProgress {
  final int wordId; // どの単語の進捗かを示す一意なID
  final String status; // 学習ステータス ('new', 'learning', 'mastered')
  final DateTime? lastReviewedAt; // 最後に復習した日時
  final DateTime? nextReviewDate; // 次回復習日
  final int srsLevel; // リートナー方式のレベル（1〜5）
  final double easinessFactor; // SM-2アルゴリズムの易しさ係数
  final int repetitions; // 連続正解回数
  final int intervalDays; // 前回の復習間隔

  const LearningProgress({
    required this.wordId,
    this.status = 'new',
    this.lastReviewedAt,
    this.nextReviewDate,
    this.srsLevel = 1,
    this.easinessFactor = 2.5,
    this.repetitions = 0,
    this.intervalDays = 0,
  });

  /// 新しいインスタンスを作成（デフォルト値付き）
  factory LearningProgress.initial(int wordId) {
    return LearningProgress(
      wordId: wordId,
      srsLevel: 1,
      nextReviewDate: DateTime.now().add(const Duration(days: 1)),
    );
  }

  /// 正解時の進捗更新（SM-2アルゴリズム）
  LearningProgress markAsCorrect() {
    final now = DateTime.now();
    final newRepetitions = repetitions + 1;
    final newIntervalDays = _calculateNextInterval(
      newRepetitions,
      easinessFactor,
    );
    final newNextReviewDate = now.add(Duration(days: newIntervalDays));
    final newStatus = newRepetitions >= 3 ? 'mastered' : 'learning';

    return LearningProgress(
      wordId: wordId,
      status: newStatus,
      lastReviewedAt: now,
      nextReviewDate: newNextReviewDate,
      srsLevel: srsLevel,
      easinessFactor: easinessFactor,
      repetitions: newRepetitions,
      intervalDays: newIntervalDays,
    );
  }

  /// 不正解時の進捗更新（SM-2アルゴリズム）
  LearningProgress markAsIncorrect() {
    final now = DateTime.now();
    final newEasinessFactor = (easinessFactor - 0.2).clamp(1.3, 2.5);
    final newNextReviewDate = now.add(const Duration(days: 1));

    return LearningProgress(
      wordId: wordId,
      status: 'new',
      lastReviewedAt: now,
      nextReviewDate: newNextReviewDate,
      srsLevel: 1,
      easinessFactor: newEasinessFactor,
      repetitions: 0,
      intervalDays: 1,
    );
  }

  /// 次回の復習間隔を計算（SM-2アルゴリズム）
  int _calculateNextInterval(int repetitions, double easinessFactor) {
    if (repetitions == 1) return 1;
    if (repetitions == 2) return 6;
    return (intervalDays * easinessFactor).round();
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
    if (nextReviewDate == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final reviewDate = DateTime(
      nextReviewDate!.year,
      nextReviewDate!.month,
      nextReviewDate!.day,
    );
    return reviewDate.isBefore(today) || reviewDate.isAtSameMomentAs(today);
  }

  /// マスター済みかどうかを判定（レベル5に達しているか）
  bool get isMastered => srsLevel >= 5;

  /// コピーウィズメソッド
  LearningProgress copyWith({
    int? wordId,
    String? status,
    DateTime? lastReviewedAt,
    DateTime? nextReviewDate,
    int? srsLevel,
    double? easinessFactor,
    int? repetitions,
    int? intervalDays,
  }) {
    return LearningProgress(
      wordId: wordId ?? this.wordId,
      status: status ?? this.status,
      lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
      nextReviewDate: nextReviewDate ?? this.nextReviewDate,
      srsLevel: srsLevel ?? this.srsLevel,
      easinessFactor: easinessFactor ?? this.easinessFactor,
      repetitions: repetitions ?? this.repetitions,
      intervalDays: intervalDays ?? this.intervalDays,
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
