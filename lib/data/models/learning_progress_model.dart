// 学習進捗のデータ転送オブジェクト（DTO）
class LearningProgressModel {
  final String userId;
  final int wordId;
  final String status;
  final DateTime? lastReviewedAt;
  final DateTime nextReviewDate;
  final int srsLevel;
  final double easinessFactor;
  final int repetitions;
  final int intervalDays;
  final DateTime createdAt;
  final DateTime updatedAt;

  LearningProgressModel({
    required this.userId,
    required this.wordId,
    required this.status,
    this.lastReviewedAt,
    required this.nextReviewDate,
    required this.srsLevel,
    required this.easinessFactor,
    required this.repetitions,
    required this.intervalDays,
    required this.createdAt,
    required this.updatedAt,
  });

  // JSONからモデルへの変換
  factory LearningProgressModel.fromJson(Map<String, dynamic> json) {
    return LearningProgressModel(
      userId: json['user_id'],
      wordId: json['word_id'],
      status: json['status'],
      lastReviewedAt: json['last_reviewed_at'] != null 
          ? DateTime.parse(json['last_reviewed_at']) 
          : null,
      nextReviewDate: DateTime.parse(json['next_review_date']),
      srsLevel: json['srs_level'],
      easinessFactor: json['easiness_factor'].toDouble(),
      repetitions: json['repetitions'],
      intervalDays: json['interval_days'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  // モデルからJSONへの変換
  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'word_id': wordId,
      'status': status,
      'last_reviewed_at': lastReviewedAt?.toIso8601String(),
      'next_review_date': nextReviewDate.toIso8601String(),
      'srs_level': srsLevel,
      'easiness_factor': easinessFactor,
      'repetitions': repetitions,
      'interval_days': intervalDays,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // 学習進捗の更新（コピーして新しいインスタンスを作成）
  LearningProgressModel copyWith({
    String? userId,
    int? wordId,
    String? status,
    DateTime? lastReviewedAt,
    DateTime? nextReviewDate,
    int? srsLevel,
    double? easinessFactor,
    int? repetitions,
    int? intervalDays,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LearningProgressModel(
      userId: userId ?? this.userId,
      wordId: wordId ?? this.wordId,
      status: status ?? this.status,
      lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
      nextReviewDate: nextReviewDate ?? this.nextReviewDate,
      srsLevel: srsLevel ?? this.srsLevel,
      easinessFactor: easinessFactor ?? this.easinessFactor,
      repetitions: repetitions ?? this.repetitions,
      intervalDays: intervalDays ?? this.intervalDays,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
