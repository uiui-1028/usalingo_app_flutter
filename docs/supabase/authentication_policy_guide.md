# usalingo Authentication ポリシー設定ガイド

## 概要

このドキュメントは、usalingoアプリケーションのSupabase Authenticationセクションでのポリシー設定について詳しく説明します。

## Authenticationポリシーとは

SupabaseのAuthenticationポリシーは、**データベースレベルでの行単位セキュリティ（RLS）**を指します。これは、ユーザーがどのデータにアクセスできるかを制御する仕組みです。

## 現在の状況

### 既に設定済みのポリシー

MCPで実行したSQLにより、以下のRLSポリシーが既に設定されています：

#### 1. 公開データ（全ユーザー読み取り可能）
```sql
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
```

#### 2. 認証ユーザー共通データ
```sql
-- usersテーブル
CREATE POLICY "users_select_policy" ON users
    FOR SELECT USING (auth.uid() = id);
```

#### 3. 所有権に基づくデータ
```sql
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
```

## Authenticationセクションでの確認方法

### 1. Supabaseダッシュボードでの確認

1. **Supabaseダッシュボード**にアクセス
2. **Authentication** → **Policies** に移動
3. 各テーブルのポリシーが表示されます

### 2. ポリシーの動作確認

#### 公開データの確認
```sql
-- 非認証ユーザーでも読み取り可能
SELECT * FROM words LIMIT 5;
SELECT * FROM decks;
SELECT * FROM example_contents LIMIT 3;
```

#### 認証ユーザーデータの確認
```sql
-- 認証済みユーザーのみアクセス可能
SELECT * FROM users WHERE id = auth.uid();
```

#### 所有権ベースデータの確認
```sql
-- 自分のデータのみアクセス可能
SELECT * FROM user_profiles WHERE user_id = auth.uid();
SELECT * FROM user_settings WHERE user_id = auth.uid();
SELECT * FROM user_learning_progress WHERE user_id = auth.uid();
```

## 追加設定が必要な場合

### 1. 新しいポリシーの追加

もし新しいテーブルを追加する場合は、以下のパターンでポリシーを設定します：

#### 公開データの場合
```sql
CREATE POLICY "table_name_select_policy" ON table_name
    FOR SELECT USING (true);
```

#### 認証ユーザーのみの場合
```sql
CREATE POLICY "table_name_policy" ON table_name
    FOR ALL USING (auth.uid() = user_id);
```

### 2. 既存ポリシーの修正

ポリシーを修正する場合は、まず削除してから再作成します：

```sql
-- ポリシーの削除
DROP POLICY IF EXISTS "policy_name" ON table_name;

-- 新しいポリシーの作成
CREATE POLICY "new_policy_name" ON table_name
    FOR SELECT USING (condition);
```

## セキュリティテスト

### 1. 非認証ユーザーのテスト
```sql
-- 公開データは読み取り可能
SELECT COUNT(*) FROM words;  -- 成功するはず

-- 認証ユーザーデータは読み取り不可
SELECT * FROM user_profiles;  -- エラーになるはず
```

### 2. 認証ユーザーのテスト
```sql
-- 自分のデータのみアクセス可能
SELECT * FROM user_profiles WHERE user_id = auth.uid();  -- 成功
SELECT * FROM user_profiles WHERE user_id != auth.uid(); -- 空の結果
```

## トラブルシューティング

### よくある問題

1. **ポリシーが適用されない**
   - RLSが有効になっているか確認
   - ポリシー名が正しいか確認
   - SQL構文が正しいか確認

2. **予期しないアクセス制限**
   - 認証状態を確認
   - ユーザーIDが正しく設定されているか確認

3. **パフォーマンスの問題**
   - インデックスが適切に設定されているか確認
   - クエリの最適化を検討

## 次のステップ

Authenticationポリシーが正しく設定されていることを確認したら、以下のステップに進みます：

1. **FlutterアプリケーションでのSupabase接続設定**
2. **認証機能の実装**
3. **データ同期機能の実装**

## 参考資料

- [Supabase RLS Documentation](https://supabase.com/docs/guides/auth/row-level-security)
- [Authentication Policies](https://supabase.com/docs/guides/auth/policies)
- [usalingo技術仕様書](../development/usalingo_04_technical_requirements.md)


