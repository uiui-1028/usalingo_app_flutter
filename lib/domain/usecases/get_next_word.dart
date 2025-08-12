import '../repositories/word_repository.dart';
import '../entities/word.dart';

// 次の単語を取得するユースケース
class GetNextWord {
  final WordRepository _repository;

  GetNextWord(this._repository);

  // 次の学習すべき単語を取得
  Future<Word?> execute() async {
    try {
      // リポジトリから全ての単語を取得
      final allWords = await _repository.fetchAllWords();
      
      if (allWords.isEmpty) {
        return null;
      }

      // 学習済みでない単語をフィルタリング
      final unlearnedWords = allWords.where((word) => !word.isLearned).toList();
      
      if (unlearnedWords.isEmpty) {
        return null;
      }

      // ランダムに次の単語を選択
      final random = DateTime.now().millisecondsSinceEpoch;
      final index = random % unlearnedWords.length;
      
      return unlearnedWords[index];
    } catch (e) {
      // エラーが発生した場合はnullを返す
      return null;
    }
  }

  // 特定の条件に基づいて次の単語を取得
  Future<Word?> executeWithFilter({
    String? category,
    int? difficulty,
    List<String>? excludeWords,
  }) async {
    try {
      // リポジトリから全ての単語を取得
      final allWords = await _repository.fetchAllWords();
      
      if (allWords.isEmpty) {
        return null;
      }

      // フィルタリング条件を適用
      var filteredWords = allWords.where((word) => !word.isLearned).toList();
      
      // 除外する単語をフィルタリング
      if (excludeWords != null && excludeWords.isNotEmpty) {
        filteredWords = filteredWords.where((word) => 
          !excludeWords.contains(word.text)
        ).toList();
      }

      // カテゴリでフィルタリング
      if (category != null) {
        filteredWords = filteredWords.where((word) => 
          word.tags?.contains(category) == true
        ).toList();
      }

      if (filteredWords.isEmpty) {
        return null;
      }

      // ランダムに次の単語を選択
      final random = DateTime.now().millisecondsSinceEpoch;
      final index = random % filteredWords.length;
      
      return filteredWords[index];
    } catch (e) {
      // エラーが発生した場合はnullを返す
      return null;
    }
  }
}
