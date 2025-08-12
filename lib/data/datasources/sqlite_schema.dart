// SQLiteデータベースのスキーマ定義
class SQLiteSchema {
  // データベース名
  static const String databaseName = 'usalingo.db';
  
  // データベースバージョン
  static const int databaseVersion = 1;
  
  // 学習進捗テーブルの定義
  static const String learningProgressTable = '''
    CREATE TABLE learning_progress (
      word_id INTEGER PRIMARY KEY,
      srs_level INTEGER NOT NULL DEFAULT 1,
      next_review_date TEXT NOT NULL,
      easiness_factor REAL NOT NULL DEFAULT 2.5,
      repetitions INTEGER NOT NULL DEFAULT 0,
      interval_days INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
  ''';
  
  // チップスデータテーブルの定義
  static const String chipsDataTable = '''
    CREATE TABLE chips_data (
      chip_id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT NOT NULL,
      description TEXT NOT NULL,
      category TEXT NOT NULL,
      created_at TEXT NOT NULL
    )
  ''';
  
  // 単語テーブルの定義（ローカルキャッシュ用）
  static const String wordsTable = '''
    CREATE TABLE words (
      word_id INTEGER PRIMARY KEY,
      word_text TEXT NOT NULL,
      definition TEXT NOT NULL,
      part_of_speech TEXT,
      phonetic_symbol TEXT,
      created_at TEXT NOT NULL
    )
  ''';
  
  // 例文テーブルの定義（ローカルキャッシュ用）
  static const String exampleContentsTable = '''
    CREATE TABLE example_contents (
      id INTEGER PRIMARY KEY,
      word_id INTEGER NOT NULL,
      theme TEXT NOT NULL DEFAULT 'simple',
      sentence_en TEXT NOT NULL,
      sentence_ja TEXT NOT NULL,
      illustration_url TEXT,
      audio_url TEXT,
      created_at TEXT NOT NULL,
      FOREIGN KEY (word_id) REFERENCES words (word_id)
    )
  ''';
  
  // インデックスの定義
  static const List<String> indexes = [
    'CREATE INDEX idx_learning_progress_next_review ON learning_progress(next_review_date)',
    'CREATE INDEX idx_words_text ON words(word_text)',
    'CREATE INDEX idx_example_contents_word_id ON example_contents(word_id)',
    'CREATE INDEX idx_chips_data_category ON chips_data(category)',
  ];
  
  // 全テーブル定義の取得
  static List<String> get allTables => [
    learningProgressTable,
    chipsDataTable,
    wordsTable,
    exampleContentsTable,
  ];
  
  // 全インデックス定義の取得
  static List<String> get allIndexes => indexes;
}
