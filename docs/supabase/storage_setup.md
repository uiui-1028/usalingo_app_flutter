# usalingo ストレージバケット設定手順

## 概要

このドキュメントは、usalingoアプリケーションのSupabaseストレージバケットの手動設定手順を説明します。

## 前提条件

- Supabaseプロジェクトが作成済みであること
- プロジェクトの管理者権限があること
- データベーススキーマが既に作成済みであること

## 手動設定手順

### 1. Supabaseダッシュボードにアクセス

1. [Supabase Dashboard](https://supabase.com/dashboard) にアクセス
2. usalingoプロジェクトを選択

### 2. ストレージバケットの作成

#### 2.1 content-imagesバケット（画像ファイル用）

1. **Storage** → **Buckets** に移動
2. **New bucket** をクリック
3. 以下の設定を入力：
   - **Name**: `content-images`
   - **Public bucket**: ✅ チェック
   - **File size limit**: `5 MB`
   - **Allowed MIME types**: `image/webp, image/png, image/jpeg`

#### 2.2 content-audioバケット（音声ファイル用）

1. **New bucket** をクリック
2. 以下の設定を入力：
   - **Name**: `content-audio`
   - **Public bucket**: ✅ チェック
   - **File size limit**: `10 MB`
   - **Allowed MIME types**: `audio/mpeg, audio/mp3, audio/wav`

#### 2.3 user-uploadsバケット（ユーザーアップロード用）

1. **New bucket** をクリック
2. 以下の設定を入力：
   - **Name**: `user-uploads`
   - **Public bucket**: ❌ チェックしない
   - **File size limit**: `20 MB`
   - **Allowed MIME types**: `image/webp, image/png, image/jpeg, audio/mpeg, audio/mp3`

### 3. RLSポリシーの設定

#### 3.1 content-imagesバケットのポリシー

1. **content-images**バケットを選択
2. **Policies**タブをクリック
3. **New policy**をクリック
4. 以下の設定を入力：
   - **Policy name**: `content_images_select_policy`
   - **Allowed operation**: `SELECT`
   - **Policy definition**: `true`

#### 3.2 content-audioバケットのポリシー

1. **content-audio**バケットを選択
2. **Policies**タブをクリック
3. **New policy**をクリック
4. 以下の設定を入力：
   - **Policy name**: `content_audio_select_policy`
   - **Allowed operation**: `SELECT`
   - **Policy definition**: `true`

#### 3.3 user-uploadsバケットのポリシー

1. **user-uploads**バケットを選択
2. **Policies**タブをクリック
3. 以下の4つのポリシーを順番に作成：

**SELECT ポリシー:**
- **Policy name**: `user_uploads_select_policy`
- **Allowed operation**: `SELECT`
- **Policy definition**: 
```sql
bucket_id = 'user-uploads' AND auth.uid()::text = (storage.foldername(name))[1]
```

**INSERT ポリシー:**
- **Policy name**: `user_uploads_insert_policy`
- **Allowed operation**: `INSERT`
- **Policy definition**: 
```sql
bucket_id = 'user-uploads' AND auth.uid()::text = (storage.foldername(name))[1]
```

**UPDATE ポリシー:**
- **Policy name**: `user_uploads_update_policy`
- **Allowed operation**: `UPDATE`
- **Policy definition**: 
```sql
bucket_id = 'user-uploads' AND auth.uid()::text = (storage.foldername(name))[1]
```

**DELETE ポリシー:**
- **Policy name**: `user_uploads_delete_policy`
- **Allowed operation**: `DELETE`
- **Policy definition**: 
```sql
bucket_id = 'user-uploads' AND auth.uid()::text = (storage.foldername(name))[1]
```

## 動作確認

### 1. バケットの確認

1. **Storage** → **Buckets** で以下が表示されることを確認：
   - `content-images` (Public)
   - `content-audio` (Public)
   - `user-uploads` (Private)

### 2. ポリシーの確認

各バケットの **Policies** タブで、適切なポリシーが設定されていることを確認。

### 3. テストファイルのアップロード

1. **content-images**バケットにテスト画像をアップロード
2. 公開URLが生成されることを確認
3. **user-uploads**バケットにテストファイルをアップロード（認証が必要）

## トラブルシューティング

### よくある問題

1. **バケット作成エラー**
   - バケット名が既に使用されていないか確認
   - ファイルサイズ制限が適切か確認

2. **ポリシー設定エラー**
   - SQL構文が正しいか確認
   - 認証状態を確認

3. **ファイルアップロードエラー**
   - MIMEタイプが許可されているか確認
   - ファイルサイズが制限内か確認

## 次のステップ

1. Flutterアプリケーションでのストレージ機能実装
2. 画像・音声ファイルのアップロード機能
3. ファイル変換機能の実装

## 参考資料

- [Supabase Storage Documentation](https://supabase.com/docs/guides/storage)
- [Storage Policies](https://supabase.com/docs/guides/storage/policies)
- [usalingo技術仕様書](../development/usalingo_04_technical_requirements.md)


