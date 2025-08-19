import '../../domain/repositories/word_repository.dart';
import '../../domain/entities/word.dart';

// SQLite単語リポジトリの実装クラス
class WordRepositorySQLite implements WordRepository {
  @override
  Future<List<Word>> fetchAllWords() async {
    // TODO: SQLiteから全ての単語を取得する実装
    // 一時的にサンプルデータを返す
    return [
      Word(
        id: 1,
        text: 'Hello',
        meaning: 'こんにちは',
        sentence: 'Hello, how are you?',
        tags: '挨拶',
        imageUrl: null,
      ),
      Word(
        id: 2,
        text: 'World',
        meaning: '世界',
        sentence: 'Hello, world!',
        tags: '名詞',
        imageUrl: null,
      ),
      Word(
        id: 3,
        text: 'Flutter',
        meaning: 'フラッター',
        sentence: 'Flutter is amazing!',
        tags: '技術',
        imageUrl: null,
      ),
      Word(
        id: 4,
        text: 'Dart',
        meaning: 'ダート',
        sentence: 'Dart is a programming language.',
        tags: '技術',
        imageUrl: null,
      ),
      Word(
        id: 5,
        text: 'App',
        meaning: 'アプリ',
        sentence: 'This is a great app!',
        tags: '技術',
        imageUrl: null,
      ),
    ];
  }

  @override
  Future<Word?> fetchWordById(int id) async {
    // TODO: SQLiteから特定のIDの単語を取得する実装
    throw UnimplementedError();
  }

  @override
  Future<int> insertWord(Word word) async {
    // TODO: SQLiteに単語を挿入する実装
    throw UnimplementedError();
  }

  @override
  Future<int> updateWord(Word word) async {
    // TODO: SQLiteの単語を更新する実装
    throw UnimplementedError();
  }

  @override
  Future<int> deleteWord(int id) async {
    // TODO: SQLiteから単語を削除する実装
    throw UnimplementedError();
  }

  @override
  Future<void> resetLearningProgress() async {
    // TODO: SQLiteの学習状況をリセットする実装
    throw UnimplementedError();
  }
}
