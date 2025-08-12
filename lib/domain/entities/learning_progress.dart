// 学習進捗エンティティ（ドメイン層）
class LearningProgress {
  final int wordId;
  final int srsLevel;
  final DateTime nextReviewDate;
  final double easinessFactor;
  final int repetitions;
  final int intervalDays;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String status;
  final DateTime? lastReviewedAt;

  LearningProgress({
    required this.wordId,
    required this.srsLevel,
    required this.nextReviewDate,
    required this.easinessFactor,
    required this.repetitions,
    required this.intervalDays,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
    this.lastReviewedAt,
  });

  // copyWithメソッドを追加
  LearningProgress copyWith({
    int? wordId,
    int? srsLevel,
    DateTime? nextReviewDate,
    double? easinessFactor,
    int? repetitions,
    int? intervalDays,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? status,
    DateTime? lastReviewedAt,
  }) {
    return LearningProgress(
      wordId: wordId ?? this.wordId,
      srsLevel: srsLevel ?? this.srsLevel,
      nextReviewDate: nextReviewDate ?? this.nextReviewDate,
      easinessFactor: easinessFactor ?? this.easinessFactor,
      repetitions: repetitions ?? this.repetitions,
      intervalDays: intervalDays ?? this.intervalDays,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
    );
  }

  // 初期状態の学習進捗を作成
  factory LearningProgress.initial(int wordId) {
    final now = DateTime.now();
    return LearningProgress(
      wordId: wordId,
      srsLevel: 1,
      nextReviewDate: now.add(const Duration(days: 1)),
      easinessFactor: 2.5,
      repetitions: 0,
      intervalDays: 0,
      createdAt: now,
      updatedAt: now,
      status: 'learning',
      lastReviewedAt: null,
    );
  }

  // 正解時の学習進捗を更新
  LearningProgress markAsCorrect() {
    final newSrsLevel = srsLevel + 1;
    final newRepetitions = repetitions + 1;
    final newIntervalDays = _calculateNewInterval(newRepetitions);
    final newNextReviewDate = DateTime.now().add(Duration(days: newIntervalDays));
    final now = DateTime.now();

    return LearningProgress(
      wordId: wordId,
      srsLevel: newSrsLevel,
      nextReviewDate: newNextReviewDate,
      easinessFactor: easinessFactor,
      repetitions: newRepetitions,
      intervalDays: newIntervalDays,
      createdAt: createdAt,
      updatedAt: now,
      status: newSrsLevel >= 5 ? 'mastered' : 'learning',
      lastReviewedAt: now,
    );
  }

  // 不正解時の学習進捗を更新
  LearningProgress markAsIncorrect() {
    final now = DateTime.now();
    return LearningProgress(
      wordId: wordId,
      srsLevel: 1,
      nextReviewDate: now.add(const Duration(days: 1)),
      easinessFactor: (easinessFactor - 0.2).clamp(1.3, 2.5),
      repetitions: 0,
      intervalDays: 1,
      createdAt: createdAt,
      updatedAt: now,
      status: 'learning',
      lastReviewedAt: now,
    );
  }

  // 新しい復習間隔を計算
  int _calculateNewInterval(int newRepetitions) {
    if (newRepetitions == 1) return 1;
    if (newRepetitions == 2) return 6;
    return (intervalDays * easinessFactor).round();
  }

  // 今日復習すべきかどうかを判定
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

  // マスター状態かどうかを判定
  bool get isMastered => status == 'mastered';

  // 等価性の比較
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LearningProgress && other.wordId == wordId;
  }

  @override
  int get hashCode => wordId.hashCode;

  @override
  String toString() {
    return 'LearningProgress(wordId: $wordId, srsLevel: $srsLevel, nextReviewDate: $nextReviewDate)';
  }
}
