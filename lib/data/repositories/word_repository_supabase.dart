import '../../domain/repositories/word_repository.dart';
import '../../domain/entities/word.dart';

// Supabase単語リポジトリの実装クラス
class WordRepositorySupabase implements WordRepository {
  @override
  Future<List<Word>> fetchAllWords() async {
    // TODO: Supabaseから全ての単語を取得する実装
    throw UnimplementedError();
  }

  @override
  Future<Word?> fetchWordById(int id) async {
    // TODO: Supabaseから特定のIDの単語を取得する実装
    throw UnimplementedError();
  }

  @override
  Future<int> insertWord(Word word) async {
    // TODO: Supabaseに単語を挿入する実装
    throw UnimplementedError();
  }

  @override
  Future<int> updateWord(Word word) async {
    // TODO: Supabaseの単語を更新する実装
    throw UnimplementedError();
  }

  @override
  Future<int> deleteWord(int id) async {
    // TODO: Supabaseから単語を削除する実装
    throw UnimplementedError();
  }

  @override
  Future<void> resetLearningProgress() async {
    // TODO: Supabaseの学習状況をリセットする実装
    throw UnimplementedError();
  }
}
