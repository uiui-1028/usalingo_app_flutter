/// SQLite schema for the English wordbook app.
/// Supabase(PostgreSQL)でも同じ構造でテーブルを作成できます。
library;

const String createWordsTable = '''
CREATE TABLE words (
  id INTEGER PRIMARY KEY AUTOINCREMENT, -- 単語ID（自動採番）
  text TEXT NOT NULL,                  -- 英単語
  meaning TEXT NOT NULL,               -- 意味
  sentence TEXT,                       -- 例文（任意）
  image_url TEXT,                      -- イラスト画像のURLまたはパス（任意）
  tags TEXT,                           -- カンマ区切りタグ（任意）
  created_at TEXT DEFAULT CURRENT_TIMESTAMP, -- 登録日時
  is_learned INTEGER DEFAULT 0,        -- 学習済みかどうか（0=未学習, 1=学習済み）
  review_count INTEGER DEFAULT 0,      -- 復習回数
  last_reviewed_at TEXT               -- 最後に復習した日時
);
''';

/// カラム仕様
/// - id: int, 主キー, 自動採番
/// - text: string, 必須, 英単語
/// - meaning: string, 必須, 意味
/// - sentence: string, 任意, 例文
/// - image_url: string, 任意, イラスト画像のURLやファイルパス
/// - tags: string, 任意, カンマ区切りのタグ
/// - created_at: string, 自動, 登録日時
/// - is_learned: int, 自動, 学習済みフラグ（0=未学習, 1=学習済み）
/// - review_count: int, 自動, 復習回数
/// - last_reviewed_at: string, 任意, 最後に復習した日時
