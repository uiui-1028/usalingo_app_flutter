-- ===============================================
-- usalingo アプリケーション データベーススキーマ
-- ===============================================

-- 既存のテーブルを削除（依存関係を考慮して逆順で削除）
DROP TABLE IF EXISTS user_learning_progress CASCADE;
DROP TABLE IF EXISTS deck_words CASCADE;
DROP TABLE IF EXISTS user_widget_layouts CASCADE;
DROP TABLE IF EXISTS user_settings CASCADE;
DROP TABLE IF EXISTS user_profiles CASCADE;
DROP TABLE IF EXISTS example_contents CASCADE;
DROP TABLE IF EXISTS decks CASCADE;
DROP TABLE IF EXISTS words CASCADE;

-- ===============================================
-- 1. ユーザー関連テーブル
-- ===============================================

-- usersテーブル（Supabase Authと連携）
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- user_profilesテーブル
CREATE TABLE IF NOT EXISTS user_profiles (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    plan TEXT DEFAULT 'free',
    nickname TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- user_settingsテーブル
CREATE TABLE IF NOT EXISTS user_settings (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    design_style TEXT DEFAULT 'flat_design',
    color_mode TEXT DEFAULT 'system',
    accent_color TEXT DEFAULT '#FF5D97',
    font_family TEXT DEFAULT 'system_default',
    card_interaction_mode TEXT DEFAULT 'punch',
    tts_config JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- user_widget_layoutsテーブル
CREATE TABLE IF NOT EXISTS user_widget_layouts (
    id SERIAL PRIMARY KEY,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    tab_name TEXT NOT NULL,
    widget_type TEXT NOT NULL,
    related_id INT,
    display_order INT NOT NULL,
    settings JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ===============================================
-- 2. コンテンツ関連テーブル
-- ===============================================

-- wordsテーブル（単語マスター）
CREATE TABLE IF NOT EXISTS words (
    id SERIAL PRIMARY KEY,
    word_text TEXT UNIQUE NOT NULL,
    definition TEXT,
    part_of_speech TEXT,
    etymology TEXT,
    synonyms TEXT[],
    antonyms TEXT[],
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- decksテーブル（学習デッキマスター）
CREATE TABLE IF NOT EXISTS decks (
    id SERIAL PRIMARY KEY,
    deck_name TEXT UNIQUE NOT NULL,
    description TEXT,
    source_list_name TEXT,
    license TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- deck_wordsテーブル（デッキと単語の中間テーブル）
CREATE TABLE IF NOT EXISTS deck_words (
    deck_id INT REFERENCES decks(id) ON DELETE CASCADE,
    word_id INT REFERENCES words(id) ON DELETE CASCADE,
    PRIMARY KEY (deck_id, word_id)
);

-- example_contentsテーブル（例文・イラスト・音声）
CREATE TABLE IF NOT EXISTS example_contents (
    id SERIAL PRIMARY KEY,
    word_id INT REFERENCES words(id) ON DELETE CASCADE,
    theme TEXT DEFAULT 'simple',
    sentence_en TEXT,
    sentence_ja TEXT,
    illustration_url TEXT,
    audio_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ===============================================
-- 3. 学習進捗関連テーブル
-- ===============================================

-- user_learning_progressテーブル
CREATE TABLE IF NOT EXISTS user_learning_progress (
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    word_id INT REFERENCES words(id) ON DELETE CASCADE,
    status TEXT DEFAULT 'new',
    last_reviewed_at TIMESTAMPTZ,
    next_review_date TIMESTAMPTZ,
    srs_level INT DEFAULT 1,
    easiness_factor REAL DEFAULT 2.5,
    repetitions INT DEFAULT 0,
    interval_days INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (user_id, word_id)
);

-- ===============================================
-- 4. インデックス作成
-- ===============================================

-- パフォーマンス向上のためのインデックス
CREATE INDEX IF NOT EXISTS idx_words_word_text ON words(word_text);
CREATE INDEX IF NOT EXISTS idx_decks_deck_name ON decks(deck_name);
CREATE INDEX IF NOT EXISTS idx_example_contents_word_id ON example_contents(word_id);
CREATE INDEX IF NOT EXISTS idx_example_contents_theme ON example_contents(theme);
CREATE INDEX IF NOT EXISTS idx_user_learning_progress_user_id ON user_learning_progress(user_id);
CREATE INDEX IF NOT EXISTS idx_user_learning_progress_word_id ON user_learning_progress(word_id);
CREATE INDEX IF NOT EXISTS idx_user_learning_progress_next_review ON user_learning_progress(next_review_date);
CREATE INDEX IF NOT EXISTS idx_user_widget_layouts_user_id ON user_widget_layouts(user_id);
CREATE INDEX IF NOT EXISTS idx_user_widget_layouts_tab_name ON user_widget_layouts(tab_name);

-- ===============================================
-- 5. RLS（Row Level Security）ポリシー設定
-- ===============================================

-- 全テーブルでRLSを有効化
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_widget_layouts ENABLE ROW LEVEL SECURITY;
ALTER TABLE words ENABLE ROW LEVEL SECURITY;
ALTER TABLE decks ENABLE ROW LEVEL SECURITY;
ALTER TABLE deck_words ENABLE ROW LEVEL SECURITY;
ALTER TABLE example_contents ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_learning_progress ENABLE ROW LEVEL SECURITY;

-- 公開データ（全ユーザーが読み取り可能）
-- wordsテーブル
CREATE POLICY "words_select_policy" ON words
    FOR SELECT USING (true);

-- decksテーブル
CREATE POLICY "decks_select_policy" ON decks
    FOR SELECT USING (true);

-- example_contentsテーブル
CREATE POLICY "example_contents_select_policy" ON example_contents
    FOR SELECT USING (true);

-- deck_wordsテーブル
CREATE POLICY "deck_words_select_policy" ON deck_words
    FOR SELECT USING (true);

-- 認証ユーザー共通データ
-- usersテーブル
CREATE POLICY "users_select_policy" ON users
    FOR SELECT USING (auth.uid() = id);

-- 所有権に基づくデータ
-- user_profilesテーブル
CREATE POLICY "user_profiles_policy" ON user_profiles
    FOR ALL USING (auth.uid() = user_id);

-- user_settingsテーブル
CREATE POLICY "user_settings_policy" ON user_settings
    FOR ALL USING (auth.uid() = user_id);

-- user_widget_layoutsテーブル
CREATE POLICY "user_widget_layouts_policy" ON user_widget_layouts
    FOR ALL USING (auth.uid() = user_id);

-- user_learning_progressテーブル
CREATE POLICY "user_learning_progress_policy" ON user_learning_progress
    FOR ALL USING (auth.uid() = user_id);

-- ===============================================
-- 6. サンプルデータ挿入
-- ===============================================

-- サンプルデッキの挿入
INSERT INTO decks (deck_name, description, source_list_name, license) VALUES
('NGSL - 基礎単語', '日常英会話で使用頻度の高い基礎単語集', 'NGSL', 'CC BY-SA 4.0'),
('BSL - ビジネス単語', 'ビジネスシーンで使用頻度の高い単語集', 'BSL', 'CC BY-SA 4.0'),
('TSL - TOEIC頻出単語', 'TOEIC試験で頻出する単語集', 'TSL', 'CC BY-SA 4.0'),
('学術基礎単語', '大学受験や学術論文で使用される基礎単語集', 'Academic', 'CC BY-SA 4.0')
ON CONFLICT (deck_name) DO NOTHING;

-- サンプル単語の挿入
INSERT INTO words (word_text, definition, part_of_speech) VALUES
('apple', 'りんご', 'noun'),
('book', '本', 'noun'),
('cat', '猫', 'noun'),
('dog', '犬', 'noun'),
('eat', '食べる', 'verb'),
('friend', '友達', 'noun'),
('good', '良い', 'adjective'),
('house', '家', 'noun'),
('important', '重要な', 'adjective'),
('job', '仕事', 'noun')
ON CONFLICT (word_text) DO NOTHING;

-- サンプル例文の挿入
INSERT INTO example_contents (word_id, theme, sentence_en, sentence_ja) VALUES
(1, 'simple', 'I eat an apple every day.', '私は毎日りんごを食べます。'),
(2, 'simple', 'I read a book before bed.', '私は寝る前に本を読みます。'),
(3, 'simple', 'The cat is sleeping on the sofa.', '猫がソファで寝ています。'),
(4, 'simple', 'The dog is playing in the park.', '犬が公園で遊んでいます。'),
(5, 'simple', 'I eat breakfast at 7 AM.', '私は朝7時に朝食を食べます。')
ON CONFLICT DO NOTHING;

-- デッキと単語の関連付け
INSERT INTO deck_words (deck_id, word_id) VALUES
(1, 1), (1, 2), (1, 3), (1, 4), (1, 5), (1, 6), (1, 7), (1, 8), (1, 9), (1, 10)
ON CONFLICT DO NOTHING;


