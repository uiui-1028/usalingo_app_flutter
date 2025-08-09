# usalingo アプリケーション Supabase セットアップガイド

## 概要

このドキュメントは、usalingoアプリケーションのSupabaseデータベースとストレージのセットアップ手順を説明します。

## 前提条件

- Supabaseプロジェクトが作成済みであること
- Supabase CLIがインストールされていること（推奨）
- プロジェクトの管理者権限があること

## セットアップ手順

### 1. データベーススキーマの作成

SupabaseダッシュボードのSQL Editorで以下のファイルを実行してください：

1. `./sql/supabase_schema.sql` - メインのデータベーススキーマ
2. `./sql/supabase_storage_setup.sql` - ストレージバケットの設定

### 2. 実行順序

```bash
# 1. データベーススキーマの作成
# Supabaseダッシュボード → SQL Editor → ./sql/supabase_schema.sql を実行

# 2. ストレージバケットの設定
# Supabaseダッシュボード → SQL Editor → ./sql/supabase_storage_setup.sql を実行
```

## テーブル構造

### ユーザー関連テーブル

| テーブル名 | 説明 | RLSポリシー |
|------------|------|-------------|
| `users` | Supabase Authと連携するユーザー基本情報 | 認証ユーザーのみ読み取り可能 |
| `user_profiles` | ユーザーのプロフィール情報 | 所有権ベース（自分のデータのみ） |
| `user_settings` | ユーザーのアプリ設定 | 所有権ベース（自分のデータのみ） |
| `user_widget_layouts` | ウィジェットレイアウト情報 | 所有権ベース（自分のデータのみ） |

### コンテンツ関連テーブル

| テーブル名 | 説明 | RLSポリシー |
|------------|------|-------------|
| `words` | 単語マスターデータ | 公開（全ユーザー読み取り可能） |
| `decks` | 学習デッキマスターデータ | 公開（全ユーザー読み取り可能） |
| `deck_words` | デッキと単語の中間テーブル | 公開（全ユーザー読み取り可能） |
| `example_contents` | 例文・イラスト・音声データ | 公開（全ユーザー読み取り可能） |

### 学習進捗関連テーブル

| テーブル名 | 説明 | RLSポリシー |
|------------|------|-------------|
| `user_learning_progress` | ユーザーごとの学習進捗 | 所有権ベース（自分のデータのみ） |

## ストレージバケット

| バケット名 | 用途 | 公開設定 | ファイルサイズ制限 |
|------------|------|----------|-------------------|
| `content-images` | コンテンツ画像（例文イラスト等） | 公開 | 5MB |
| `content-audio` | コンテンツ音声（例文読み上げ等） | 公開 | 10MB |
| `user-uploads` | ユーザーアップロードファイル | 非公開 | 20MB |

## セキュリティ設定

### RLS（Row Level Security）ポリシー

1. **公開データ**: `words`, `decks`, `deck_words`, `example_contents`
   - 全ユーザー（非認証ユーザーを含む）が読み取り可能
   - 書き込みは全てのユーザーに対して不可

2. **認証ユーザー共通データ**: `users`
   - 認証済みユーザーは自身の情報のみ読み取り可能

3. **所有権に基づくデータ**: `user_profiles`, `user_settings`, `user_widget_layouts`, `user_learning_progress`
   - ユーザーは自身のデータのみ全ての操作（CRUD）が可能

## 注意事項

### 1. 既存データの削除

セットアップ前に既存のテーブルがある場合は、以下の順序で削除してください：

```sql
DROP TABLE IF EXISTS user_learning_progress CASCADE;
DROP TABLE IF EXISTS deck_words CASCADE;
DROP TABLE IF EXISTS user_widget_layouts CASCADE;
DROP TABLE IF EXISTS user_settings CASCADE;
DROP TABLE IF EXISTS user_profiles CASCADE;
DROP TABLE IF EXISTS example_contents CASCADE;
DROP TABLE IF EXISTS decks CASCADE;
DROP TABLE IF EXISTS words CASCADE;
```

### 2. インデックス

パフォーマンス向上のため、以下のインデックスが自動的に作成されます：

- `words(word_text)` - 単語検索用
- `decks(deck_name)` - デッキ名検索用
- `example_contents(word_id, theme)` - 例文検索用
- `user_learning_progress(user_id, word_id, next_review_date)` - 学習進捗検索用
- `user_widget_layouts(user_id, tab_name)` - ウィジェットレイアウト検索用

### 3. サンプルデータ

セットアップ時に以下のサンプルデータが自動的に挿入されます：

- 4つの学習デッキ（NGSL、BSL、TSL、学術基礎）
- 10個のサンプル単語
- 5個のサンプル例文
- デッキと単語の関連付け

## 動作確認

セットアップ完了後、以下のクエリで動作確認ができます：

```sql
-- テーブル一覧の確認
SELECT table_name FROM information_schema.tables 
WHERE table_schema = 'public' 
ORDER BY table_name;

-- サンプルデータの確認
SELECT * FROM decks;
SELECT * FROM words LIMIT 5;
SELECT * FROM example_contents LIMIT 3;

-- RLSポリシーの確認
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual 
FROM pg_policies 
WHERE schemaname = 'public';
```

## トラブルシューティング

### よくある問題

1. **RLSポリシーエラー**
   - ポリシーが正しく設定されているか確認
   - 認証状態を確認

2. **外部キー制約エラー**
   - テーブル作成順序を確認
   - 参照先のテーブルが存在するか確認

3. **ストレージアクセスエラー**
   - バケットが正しく作成されているか確認
   - ポリシーが正しく設定されているか確認

## 次のステップ

1. FlutterアプリケーションでのSupabase接続設定
2. 認証機能の実装
3. データ同期機能の実装
4. ストレージ機能の実装

## 参考資料

- [Supabase Documentation](https://supabase.com/docs)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [usalingo技術仕様書](../development/usalingo_04_technical_requirements.md)


