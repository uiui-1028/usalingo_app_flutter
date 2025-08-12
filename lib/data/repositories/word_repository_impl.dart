import '../../domain/repositories/word_repository.dart';
import '../../domain/entities/word.dart';

// 単語リポジトリの実装クラス
class WordRepositoryImpl implements WordRepository {
  @override
  Future<List<Word>> fetchAllWords() async {
    // TODO: 全ての単語を取得する実装
    throw UnimplementedError();
  }

  @override
  Future<Word?> fetchWordById(int id) async {
    // TODO: 特定のIDの単語を取得する実装
    throw UnimplementedError();
  }

  @override
  Future<int> insertWord(Word word) async {
    // TODO: 単語を挿入する実装
    throw UnimplementedError();
  }

  @override
  Future<int> updateWord(Word word) async {
    // TODO: 単語を更新する実装
    throw UnimplementedError();
  }

  @override
  Future<int> deleteWord(int id) async {
    // TODO: 単語を削除する実装
    throw UnimplementedError();
  }

  @override
  Future<void> resetLearningProgress() async {
    // TODO: 学習状況をリセットする実装
    throw UnimplementedError();
  }
}
