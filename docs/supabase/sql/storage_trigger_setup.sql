-- ===============================================
-- usalingo Storage トリガー設定
-- ===============================================

-- 1. example_contentsテーブルのillustration_urlカラムは既に存在するため追加不要

-- 2. Storageトリガー関数の作成
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

-- 3. Storageトリガーの作成
DROP TRIGGER IF EXISTS storage_upload_trigger ON storage.objects;
CREATE TRIGGER storage_upload_trigger
    AFTER INSERT ON storage.objects
    FOR EACH ROW
    EXECUTE FUNCTION handle_storage_upload();

-- 4. 既存の画像ファイルの処理（オプション）
-- 既存のStorageファイルがある場合、手動で更新するための関数
CREATE OR REPLACE FUNCTION sync_existing_images()
RETURNS VOID AS $$
DECLARE
    file_record RECORD;
    word_text TEXT;
    image_url TEXT;
    example_content_id INT;
BEGIN
    -- content-imagesバケット内の全ファイルを処理
    FOR file_record IN 
        SELECT name 
        FROM storage.objects 
        WHERE bucket_id = 'content-images'
    LOOP
        -- ファイル名から単語を抽出
        word_text := split_part(file_record.name, '_', 1);
        
        -- 公開URLを構築
        image_url := 'https://udvmzaodsrgwecfybkry.supabase.co/storage/v1/object/public/content-images/' || file_record.name;
        
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
            
            RAISE NOTICE 'Synced illustration_url for word "%": %', word_text, image_url;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. 権限設定
-- 関数の実行権限を適切なロールに付与
GRANT EXECUTE ON FUNCTION handle_storage_upload() TO authenticated;
GRANT EXECUTE ON FUNCTION sync_existing_images() TO authenticated;

-- 6. テスト用のサンプルデータを追加（example_contentsテーブルに）
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

-- 7. 確認用クエリ
-- 設定完了後の確認用
SELECT 
    'Storage trigger setup completed' as status,
    COUNT(*) as total_example_contents,
    COUNT(illustration_url) as contents_with_images
FROM example_contents;
