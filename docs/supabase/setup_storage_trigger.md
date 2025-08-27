# Supabase MCP を使用した Storage トリガー設定

## 📋 概要

このドキュメントでは、Supabase MCPを使用して、Storageトリガー機能を設定する手順を説明します。

## 🎯 設定する機能

1. **example_contentsテーブルの活用**: 既存の`illustration_url`カラムを使用
2. **Storageトリガー関数の作成**: 画像アップロード時の自動処理
3. **Storageバケットの設定**: `content-images`バケットの作成とポリシー設定

## 🔧 前提条件

- Supabase MCPが設定済み（`.cursor/mcp.json`）
- Supabaseプロジェクトへのアクセス権限
- 適切なアクセストークン
- `example_contents`テーブルが存在し、`illustration_url`カラムが利用可能

## 🚀 設定手順

### 1. MCPサーバーの確認

まず、MCPサーバーが正常に動作していることを確認します：

```bash
# MCPサーバーの状態確認
# Cursor内でMCPコマンドが実行可能かテスト
```

### 2. データベース構造の確認

#### 2.1 example_contentsテーブルの確認

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

### 3. Storageトリガー関数の作成

#### 3.1 トリガー関数の作成

`docs/supabase/sql/storage_trigger_setup.sql`の内容をSQL Editorで実行：

```sql
-- Storageトリガー関数の作成
CREATE OR REPLACE FUNCTION handle_storage_upload()
RETURNS TRIGGER AS $$
DECLARE
    word_text TEXT;
    image_url TEXT;
    example_content_id INT;
BEGIN
    -- 新しいファイルがアップロードされた場合のみ処理
    IF TG_OP = 'INSERT' THEN
        -- ファイル名から単語を抽出（例：responsibility_01.webp → responsibility）
        word_text := split_part(NEW.name, '_', 1);
        
        -- 公開URLを構築
        image_url := 'https://udvmzaodsrgwecfybkry.supabase.co/storage/v1/object/public/content-images/' || NEW.name;
        
        -- example_contentsテーブルから該当する単語のレコードを検索
        SELECT ec.id INTO example_content_id 
        FROM example_contents ec
        JOIN words w ON ec.word_id = w.id
        WHERE w.word_text = word_text
        LIMIT 1;
        
        -- レコードが見つかった場合、illustration_urlを更新
        IF example_content_id IS NOT NULL THEN
            UPDATE example_contents 
            SET illustration_url = image_url, 
                updated_at = NOW() 
            WHERE id = example_content_id;
            
            RAISE NOTICE 'Updated illustration_url for word "%": %', word_text, image_url;
        ELSE
            RAISE NOTICE 'Word "%" not found in example_contents table', word_text;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

#### 3.2 トリガーの作成

```sql
-- Storageトリガーの作成
DROP TRIGGER IF EXISTS storage_upload_trigger ON storage.objects;
CREATE TRIGGER storage_upload_trigger
    AFTER INSERT ON storage.objects
    FOR EACH ROW
    EXECUTE FUNCTION handle_storage_upload();
```

#### 3.3 確認用クエリ

```sql
-- トリガーの状態確認
SELECT 
    trigger_name,
    event_manipulation,
    action_statement
FROM information_schema.triggers 
WHERE trigger_name = 'storage_upload_trigger';

-- 関数の存在確認
SELECT 
    routine_name,
    routine_type,
    data_type
FROM information_schema.routines 
WHERE routine_name = 'handle_storage_upload';
```

### 4. Storageバケットの設定

#### 4.1 content-imagesバケットの作成

1. Supabase管理画面 → Storage → New Bucket
2. 設定項目：
   - **バケット名**: `content-images`
   - **公開設定**: `Public`（チェックを入れる）
   - **ファイルサイズ制限**: `5 MB`
   - **許可されるファイル形式**: `image/*`

#### 4.2 バケットポリシーの設定

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

-- 認証済みユーザーのみ削除可能
CREATE POLICY "Auth Users Delete" ON storage.objects
    FOR DELETE USING (
        bucket_id = 'content-images' 
        AND auth.role() = 'authenticated'
    );
```

#### 4.3 ポリシーの確認

```sql
-- 設定されたポリシーの確認
SELECT 
    policyname,
    permissive,
    roles,
    cmd,
    qual
FROM pg_policies 
WHERE tablename = 'objects' 
AND schemaname = 'storage';
```

### 5. テスト用データの準備

#### 5.1 テスト用単語とexample_contentsの追加

```sql
-- テスト用のサンプル単語を追加
INSERT INTO words (word_text, definition, part_of_speech) 
VALUES 
    ('responsibility', '責任、義務', 'noun'),
    ('opportunity', '機会、好機', 'noun'),
    ('communication', 'コミュニケーション、意思疎通', 'noun'),
    ('development', '発展、開発', 'noun'),
    ('environment', '環境、周囲', 'noun')
ON CONFLICT (word_text) DO NOTHING;

-- example_contentsテーブルにサンプルデータを追加
INSERT INTO example_contents (word_id, theme, sentence_en, sentence_ja) 
SELECT 
    w.id,
    'simple',
    'This is a sample sentence for ' || w.word_text,
    w.word_text || 'のサンプル例文です'
FROM words w
WHERE w.word_text IN ('responsibility', 'opportunity', 'communication', 'development', 'environment')
ON CONFLICT DO NOTHING;

-- 確認用クエリ
SELECT 
    ec.id,
    w.word_text,
    ec.sentence_ja,
    ec.illustration_url
FROM example_contents ec
JOIN words w ON ec.word_id = w.id
WHERE w.word_text IN ('responsibility', 'opportunity', 'communication', 'development', 'environment')
ORDER BY w.word_text;
```

#### 5.2 期待される結果

```
id | word_text      | sentence_ja                    | illustration_url
---+----------------+--------------------------------+------------------
 1 | communication  | communicationのサンプル例文です | NULL
 2 | development    | developmentのサンプル例文です   | NULL
 3 | environment    | environmentのサンプル例文です   | NULL
 4 | opportunity    | opportunityのサンプル例文です   | NULL
 5 | responsibility | responsibilityのサンプル例文です | NULL
```

### 6. テスト画像のアップロード

#### 6.1 テスト画像の準備

`docs/supabase/test_images/`ディレクトリに以下の画像ファイルを配置：

```
test_images/
├── responsibility_01.webp
├── opportunity_01.webp
└── communication_01.webp
```

#### 6.2 画像のアップロード

1. Supabase管理画面 → Storage → content-images
2. テスト画像をドラッグ&ドロップでアップロード
3. ファイル名が命名規則に従っていることを確認

#### 6.3 アップロード後の確認

```sql
-- Storage内のファイル確認
SELECT 
    name,
    bucket_id,
    created_at
FROM storage.objects 
WHERE bucket_id = 'content-images'
ORDER BY created_at DESC;

-- example_contentsテーブルの更新確認
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

### 7. 動作確認

#### 7.1 トリガーの動作確認

画像アップロード後、以下のような結果が表示されるはずです：

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

#### 7.2 ログの確認

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
- [Storage トリガー設定ガイド](storage_trigger_guide.md)

---

このドキュメントに従って設定を行うことで、Supabase MCPを使用したStorageトリガー機能が実現できます。
