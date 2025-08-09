-- ===============================================
-- usalingo アプリケーション ストレージ設定
-- ===============================================

-- ストレージバケットの作成
-- 画像ファイル用バケット
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'content-images',
    'content-images',
    true,
    5242880, -- 5MB
    ARRAY['image/webp', 'image/png', 'image/jpeg']
) ON CONFLICT (id) DO NOTHING;

-- 音声ファイル用バケット
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'content-audio',
    'content-audio',
    true,
    10485760, -- 10MB
    ARRAY['audio/mpeg', 'audio/mp3', 'audio/wav']
) ON CONFLICT (id) DO NOTHING;

-- ユーザーアップロード用バケット（非公開）
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'user-uploads',
    'user-uploads',
    false,
    20971520, -- 20MB
    ARRAY['image/webp', 'image/png', 'image/jpeg', 'audio/mpeg', 'audio/mp3']
) ON CONFLICT (id) DO NOTHING;

-- ===============================================
-- ストレージポリシー設定
-- ===============================================

-- content-imagesバケットのポリシー
-- 全ユーザーが読み取り可能
CREATE POLICY "content_images_select_policy" ON storage.objects
    FOR SELECT USING (bucket_id = 'content-images');

-- content-audioバケットのポリシー
-- 全ユーザーが読み取り可能
CREATE POLICY "content_audio_select_policy" ON storage.objects
    FOR SELECT USING (bucket_id = 'content-audio');

-- user-uploadsバケットのポリシー
-- 認証ユーザーのみアクセス可能
CREATE POLICY "user_uploads_select_policy" ON storage.objects
    FOR SELECT USING (
        bucket_id = 'user-uploads' 
        AND auth.uid()::text = (storage.foldername(name))[1]
    );

CREATE POLICY "user_uploads_insert_policy" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'user-uploads' 
        AND auth.uid()::text = (storage.foldername(name))[1]
    );

CREATE POLICY "user_uploads_update_policy" ON storage.objects
    FOR UPDATE USING (
        bucket_id = 'user-uploads' 
        AND auth.uid()::text = (storage.foldername(name))[1]
    );

CREATE POLICY "user_uploads_delete_policy" ON storage.objects
    FOR DELETE USING (
        bucket_id = 'user-uploads' 
        AND auth.uid()::text = (storage.foldername(name))[1]
    );


