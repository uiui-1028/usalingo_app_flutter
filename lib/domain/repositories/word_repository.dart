import '../entities/word.dart';

abstract class WordRepository {
  Future<List<Word>> fetchAllWords();
  Future<Word?> fetchWordById(int id);
  Future<int> insertWord(Word word);
  Future<int> updateWord(Word word);
  Future<int> deleteWord(int id);
}
