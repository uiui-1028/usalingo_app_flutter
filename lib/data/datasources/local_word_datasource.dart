// ローカル単語データソースのインターフェース
abstract class LocalWordDataSource {
  // ローカルDBから単語データを取得
  Future<List<Map<String, dynamic>>> getLocalWords();
  
  // ローカルDBに単語データを保存
  Future<void> saveLocalWords(List<Map<String, dynamic>> words);
  
  // 特定の単語IDのデータを取得
  Future<Map<String, dynamic>?> getWordById(int wordId);
  
  // ローカルDBの単語データを更新
  Future<void> updateLocalWord(int wordId, Map<String, dynamic> wordData);
  
  // ローカルDBから単語データを削除
  Future<void> deleteLocalWord(int wordId);
}

// SQLite単語データソースの実装
class LocalWordSQLiteDataSource implements LocalWordDataSource {
  @override
  Future<List<Map<String, dynamic>>> getLocalWords() async {
    // TODO: SQLiteから単語データを取得する実装
    throw UnimplementedError();
  }

  @override
  Future<void> saveLocalWords(List<Map<String, dynamic>> words) async {
    // TODO: SQLiteに単語データを保存する実装
    throw UnimplementedError();
  }

  @override
  Future<Map<String, dynamic>?> getWordById(int wordId) async {
    // TODO: SQLiteから特定の単語IDのデータを取得する実装
    throw UnimplementedError();
  }

  @override
  Future<void> updateLocalWord(int wordId, Map<String, dynamic> wordData) async {
    // TODO: SQLiteの単語データを更新する実装
    throw UnimplementedError();
  }

  @override
  Future<void> deleteLocalWord(int wordId) async {
    // TODO: SQLiteから単語データを削除する実装
    throw UnimplementedError();
  }
}
