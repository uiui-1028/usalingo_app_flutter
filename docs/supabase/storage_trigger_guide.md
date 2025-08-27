# usalingo Storage トリガー設定ガイド

## 📋 概要

このガイドでは、Supabase Storageに画像ファイルをアップロードした際に、自動的にデータベースの`example_contents`テーブルの`illustration_url`カラムを更新する機能の設定方法を説明します。

## 🎯 実現する機能

1. **自動画像URL更新**: Storageに画像をアップロードすると、自動的にデータベースが更新される
2. **命名規則対応**: `responsibility_01.webp`のような命名規則に対応
3. **リアルタイム同期**: アップロード完了と同時にデータベースが更新される
4. **example_contentsテーブル対応**: `illustration_url`カラムへの自動マッピング

## 🔧 前提条件

- Supabaseプロジェクトが設定済み
- データベーススキーマが作成済み（`example_contents`テーブルが存在）
- MCPサーバーが書き込み可能モードで設定済み

## 📁 ファイル構成

```
docs/supabase/
├── sql/
│   └── storage_trigger_setup.sql    # トリガー設定SQL
├── storage_trigger_guide.md         # このガイド
└── test_images/                     # テスト用画像ファイル
    ├── responsibility_01.webp
    ├── opportunity_01.webp
    └── communication_01.webp
```

## 🚀 設定手順

### 1. データベース構造の確認

`example_contents`テーブルの`illustration_url`カラムは既に存在するため、追加の変更は不要です。

確認用クエリ：
```sql
-- example_contentsテーブルの構造確認
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'example_contents' 
AND column_name = 'illustration_url';
```

期待される結果：
```
column_name      | data_type | is_nullable
-----------------+-----------+-------------
illustration_url | text      | YES
```

### 2. Storageトリガー関数の作成

`docs/supabase/sql/storage_trigger_setup.sql`の内容をSQL Editorで実行：

```sql
-- Storageトリガー関数の作成
CREATE OR REPLACE FUNCTION handle_storage_upload()
RETURNS TRIGGER AS $$
-- ... 関数の詳細はファイルを参照
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- トリガーの作成
CREATE TRIGGER storage_upload_trigger
    AFTER INSERT ON storage.objects
    FOR EACH ROW
    EXECUTE FUNCTION handle_storage_upload();
```

### 3. Storageバケットの設定

#### 3.1 content-imagesバケットの作成

1. Supabase管理画面 → Storage → New Bucket
2. バケット名: `content-images`
3. 公開設定: `Public`（チェックを入れる）
4. ファイルサイズ制限: `5 MB`
5. 許可されるファイル形式: `image/*`

#### 3.2 バケットポリシーの設定

```sql
-- 全ユーザーが画像を読み取り可能
CREATE POLICY "Public Access" ON storage.objects
    FOR SELECT USING (bucket_id = 'content-images');

-- 認証済みユーザーのみアップロード可能
CREATE POLICY "Auth Users Upload" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'content-images' 
        AND auth.role() = 'authenticated'
    );
```

## 📝 命名規則

### 画像ファイルの命名規則

```
{単語名}_{バージョン番号}.{拡張子}
```

#### 例：
- `responsibility_01.webp` → `responsibility`単語の1番目の画像
- `opportunity_02.png` → `opportunity`単語の2番目の画像
- `communication_01.jpg` → `communication`単語の1番目の画像

### 制約事項

- 単語名は`words`テーブルの`word_text`カラムと完全一致する必要がある
- アンダースコア（`_`）は単語名とバージョン番号の区切り文字として使用
- ファイル名にスペースは使用不可（ハイフン`-`は使用可能）
- `example_contents`テーブルに対応するレコードが存在する必要がある

## 🧪 テスト手順

### 1. テスト用画像の準備

`docs/supabase/test_images/`フォルダに以下の画像ファイルを配置：

```
test_images/
├── responsibility_01.webp
├── opportunity_01.webp
└── communication_01.webp
```

### 2. 画像のアップロード

1. Supabase管理画面 → Storage → content-images
2. テスト画像をドラッグ&ドロップでアップロード
3. ファイル名が命名規則に従っていることを確認

### 3. データベースの確認

SQL Editorで以下のクエリを実行：

```sql
-- illustration_urlが更新されているか確認
SELECT 
    ec.id,
    w.word_text,
    ec.sentence_ja,
    ec.illustration_url,
    ec.updated_at
FROM example_contents ec
JOIN words w ON ec.word_id = w.id
WHERE ec.illustration_url IS NOT NULL
ORDER BY ec.updated_at DESC;
```

### 4. 期待される結果

```
id | word_text      | sentence_ja                    | illustration_url                                                           | updated_at
---+----------------+--------------------------------+--------------------------------------------------------------------+----------------------------
 1 | responsibility | responsibilityのサンプル例文です | https://udvmzaodsrgwecfybkry.supabase.co/storage/v1/object/public/ | 2025-01-27 15:30:00+00
    |                |                                | content-images/responsibility_01.webp
 2 | opportunity    | opportunityのサンプル例文です   | https://udvmzaodsrgwecfybkry.supabase.co/storage/v1/object/public/ | 2025-01-27 15:31:00+00
    |                |                                | content-images/opportunity_01.webp
 3 | communication  | communicationのサンプル例文です | https://udvmzaodsrgwecfybkry.supabase.co/storage/v1/object/public/ | 2025-01-27 15:32:00+00
    |                |                                | content-images/communication_01.webp
```

## 🔍 トラブルシューティング

### よくある問題と解決方法

#### 1. トリガーが動作しない

**症状**: 画像をアップロードしてもデータベースが更新されない

**確認事項**:
- トリガー関数が正しく作成されているか
- ファイル名が命名規則に従っているか
- `words`テーブルに対応する単語が存在するか
- `example_contents`テーブルに対応するレコードが存在するか

**解決方法**:
```sql
-- トリガーの状態確認
SELECT 
    trigger_name,
    event_manipulation,
    action_statement
FROM information_schema.triggers 
WHERE trigger_name = 'storage_upload_trigger';

-- 手動で関数を実行してテスト
SELECT handle_storage_upload();

-- example_contentsテーブルの確認
SELECT 
    ec.id,
    w.word_text,
    ec.sentence_ja
FROM example_contents ec
JOIN words w ON ec.word_id = w.id
WHERE w.word_text = 'responsibility';
```

#### 2. 権限エラーが発生する

**症状**: `permission denied`エラーが表示される

**解決方法**:
```sql
-- 関数の実行権限を確認
GRANT EXECUTE ON FUNCTION handle_storage_upload() TO authenticated;
GRANT EXECUTE ON FUNCTION handle_storage_upload() TO service_role;
```

#### 3. ファイル名の解析が正しく動作しない

**症状**: 単語名が正しく抽出されない

**確認事項**:
- ファイル名にスペースが含まれていないか
- アンダースコアの位置が正しいか

**解決方法**:
```sql
-- ファイル名の解析をテスト
SELECT 
    'responsibility_01.webp' as filename,
    split_part('responsibility_01.webp', '_', 1) as extracted_word;
```

## 📊 パフォーマンス最適化

### 1. インデックスの追加

```sql
-- illustration_urlカラムにインデックスを追加
CREATE INDEX IF NOT EXISTS idx_example_contents_illustration_url ON example_contents(illustration_url);

-- 更新日時での検索用インデックス
CREATE INDEX IF NOT EXISTS idx_example_contents_updated_at ON example_contents(updated_at);

-- word_idでの検索用インデックス（既存）
CREATE INDEX IF NOT EXISTS idx_example_contents_word_id ON example_contents(word_id);
```

### 2. バッチ処理の最適化

大量の画像を一括アップロードする場合：

```sql
-- 既存画像の一括同期
SELECT sync_existing_images();
```

## 🔒 セキュリティ考慮事項

### 1. ファイル形式の制限

```sql
-- 許可されるファイル形式を制限
CREATE POLICY "Image Files Only" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'content-images' 
        AND (storage.extension(name) = ANY(ARRAY['jpg', 'jpeg', 'png', 'webp', 'gif']))
    );
```

### 2. ファイルサイズの制限

- バケットレベル: 5MB
- アプリケーションレベル: 追加の検証を実装

### 3. 認証の確認

- 認証済みユーザーのみアップロード可能
- 必要に応じて特定のロールのみに制限

## 📈 監視とログ

### 1. トリガー実行ログの確認

```sql
-- 最近のトリガー実行状況を確認
SELECT 
    ec.id,
    w.word_text,
    ec.illustration_url,
    ec.updated_at
FROM example_contents ec
JOIN words w ON ec.word_id = w.id
WHERE ec.updated_at > NOW() - INTERVAL '1 hour'
ORDER BY ec.updated_at DESC;
```

### 2. エラーログの確認

Supabase管理画面 → Logs → Database Logs でエラーを確認

## 🎉 完了確認

設定が完了したら、以下の項目を確認してください：

- [ ] `example_contents`テーブルの`illustration_url`カラムが存在する
- [ ] Storageトリガー関数が作成されている
- [ ] `content-images`バケットが作成されている
- [ ] テスト画像のアップロードが成功している
- [ ] データベースの`illustration_url`が自動更新されている
- [ ] 命名規則に従ったファイル名で正しく動作している

## 📚 参考資料

- [Supabase Storage Documentation](https://supabase.com/docs/guides/storage)
- [PostgreSQL Triggers](https://www.postgresql.org/docs/current/triggers.html)
- [usalingo 技術仕様書](../Usalingo_Specification/)

---

このガイドに従って設定を行うことで、Supabase Storageへの画像アップロード時に自動的に`example_contents`テーブルの`illustration_url`カラムが更新される機能が実現できます。
