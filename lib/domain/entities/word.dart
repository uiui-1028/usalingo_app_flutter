// 単語エンティティ（ドメイン層）
class Word {
  final int? id;
  final String text;
  final String meaning;
  final String? sentence;
  final String? imageUrl;
  final String? tags;
  final DateTime? createdAt;
  final bool isLearned;
  final int reviewCount;
  final DateTime? lastReviewedAt;

  Word({
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

  // copyWithメソッドを追加
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

  // 単語の学習状態を更新
  Word markAsLearned() {
    return Word(
      id: id,
      text: text,
      meaning: meaning,
      sentence: sentence,
      imageUrl: imageUrl,
      tags: tags,
      createdAt: createdAt,
      isLearned: true,
      reviewCount: reviewCount + 1,
      lastReviewedAt: DateTime.now(),
    );
  }

  // 単語の学習状態をリセット
  Word resetLearning() {
    return Word(
      id: id,
      text: text,
      meaning: meaning,
      sentence: sentence,
      imageUrl: imageUrl,
      tags: tags,
      createdAt: createdAt,
      isLearned: false,
      reviewCount: 0,
      lastReviewedAt: null,
    );
  }

  // 単語の復習回数を更新
  Word updateReviewCount(int newCount) {
    return Word(
      id: id,
      text: text,
      meaning: meaning,
      sentence: sentence,
      imageUrl: imageUrl,
      tags: tags,
      createdAt: createdAt,
      isLearned: isLearned,
      reviewCount: newCount,
      lastReviewedAt: DateTime.now(),
    );
  }

  // 等価性の比較
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Word && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Word(id: $id, text: $text, meaning: $meaning)';
  }
}
