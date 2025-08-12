import '../../domain/repositories/word_repository.dart';
import '../../domain/entities/word.dart';

// SQLite単語リポジトリの実装クラス
class WordRepositorySQLite implements WordRepository {
  @override
  Future<List<Word>> fetchAllWords() async {
    // TODO: SQLiteから全ての単語を取得する実装
    throw UnimplementedError();
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
