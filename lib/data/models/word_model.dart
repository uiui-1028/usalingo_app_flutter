// 単語のデータ転送オブジェクト（DTO）
class WordModel {
  final int id;
  final int rank;
  final String wordText;
  final String definition;
  final String? partOfSpeech;
  final String? etymology;
  final List<String>? synonyms;
  final List<String>? antonyms;
  final String? phoneticSymbol;
  final DateTime createdAt;

  WordModel({
    required this.id,
    required this.rank,
    required this.wordText,
    required this.definition,
    this.partOfSpeech,
    this.etymology,
    this.synonyms,
    this.antonyms,
    this.phoneticSymbol,
    required this.createdAt,
  });

  // JSONからモデルへの変換
  factory WordModel.fromJson(Map<String, dynamic> json) {
    return WordModel(
      id: json['id'],
      rank: json['rank'],
      wordText: json['word_text'],
      definition: json['definition'],
      partOfSpeech: json['part_of_speech'],
      etymology: json['etymology'],
      synonyms: json['synonyms'] != null ? List<String>.from(json['synonyms']) : null,
      antonyms: json['antonyms'] != null ? List<String>.from(json['antonyms']) : null,
      phoneticSymbol: json['phonetic_symbol'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  // モデルからJSONへの変換
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'rank': rank,
      'word_text': wordText,
      'definition': definition,
      'part_of_speech': partOfSpeech,
      'etymology': etymology,
      'synonyms': synonyms,
      'antonyms': antonyms,
      'phonetic_symbol': phoneticSymbol,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
