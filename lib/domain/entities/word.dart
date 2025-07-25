class Word {
  final int? id;
  final String text;
  final String meaning;
  final String? sentence;
  final String? imageUrl;
  final String? tags;
  final DateTime? createdAt;

  const Word({
    this.id,
    required this.text,
    required this.meaning,
    this.sentence,
    this.imageUrl,
    this.tags,
    this.createdAt,
  });

  Word copyWith({
    int? id,
    String? text,
    String? meaning,
    String? sentence,
    String? imageUrl,
    String? tags,
    DateTime? createdAt,
  }) {
    return Word(
      id: id ?? this.id,
      text: text ?? this.text,
      meaning: meaning ?? this.meaning,
      sentence: sentence ?? this.sentence,
      imageUrl: imageUrl ?? this.imageUrl,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
