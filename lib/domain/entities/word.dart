class Word {
  final int? id;
  final String text;
  final String meaning;
  final String? sentence;
  final String? imageUrl;
  final String? tags;
  final DateTime? createdAt;
  final bool isLearned; // 学習済みかどうか
  final int reviewCount; // 復習回数
  final DateTime? lastReviewedAt; // 最後に復習した日時

  const Word({
    this.id,
    required this.text,
    required this.meaning,
    this.sentence,
    this.imageUrl,
    this.tags,
    this.createdAt,
    this.isLearned = false,
    this.reviewCount = 0,
    this.lastReviewedAt,
  });

  Word copyWith({
    int? id,
    String? text,
    String? meaning,
    String? sentence,
    String? imageUrl,
    String? tags,
    DateTime? createdAt,
    bool? isLearned,
    int? reviewCount,
    DateTime? lastReviewedAt,
  }) {
    return Word(
      id: id ?? this.id,
      text: text ?? this.text,
      meaning: meaning ?? this.meaning,
      sentence: sentence ?? this.sentence,
      imageUrl: imageUrl ?? this.imageUrl,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      isLearned: isLearned ?? this.isLearned,
      reviewCount: reviewCount ?? this.reviewCount,
      lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
    );
  }
}
