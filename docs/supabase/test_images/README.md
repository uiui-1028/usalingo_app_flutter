# テスト用画像ファイル

このディレクトリには、Storageトリガー機能のテストに使用する画像ファイルを配置してください。

## 📁 必要なファイル

以下の命名規則に従った画像ファイルを配置してください：

```
test_images/
├── responsibility_01.webp    # responsibility単語の1番目の画像
├── opportunity_01.webp       # opportunity単語の1番目の画像
└── communication_01.webp     # communication単語の1番目の画像
```

## 🎯 命名規則

### 基本形式
```
{単語名}_{バージョン番号}.{拡張子}
```

### 例
- `responsibility_01.webp` → responsibility単語の1番目の画像
- `opportunity_02.png` → opportunity単語の2番目の画像
- `communication_01.jpg` → communication単語の1番目の画像

## 📋 制約事項

1. **単語名**: `words`テーブルの`word_text`カラムと完全一致する必要があります
2. **区切り文字**: アンダースコア（`_`）を使用
3. **スペース**: ファイル名にスペースは使用不可（ハイフン`-`は使用可能）
4. **拡張子**: 画像ファイル形式（jpg, jpeg, png, webp, gif）

## 🔧 画像ファイルの準備方法

### 1. 既存の画像を使用
- 適切なサイズ（推奨: 512x512px以上）
- 適切なファイルサイズ（5MB以下）
- 適切なファイル形式

### 2. プレースホルダー画像の作成
画像がない場合は、以下のような方法でプレースホルダーを作成：

#### オンラインツール
- [Placeholder.com](https://placeholder.com/) - シンプルなプレースホルダー
- [Picsum Photos](https://picsum.photos/) - ランダムな画像
- [Lorem Picsum](https://picsum.photos/) - ランダムな画像

#### 例
```
# 512x512のプレースホルダー画像
https://picsum.photos/512/512

# 特定のIDの画像（毎回同じ画像）
https://picsum.photos/512/512?random=1
```

### 3. 画像のダウンロードとリネーム
```bash
# 例：curlを使用して画像をダウンロード
curl -o responsibility_01.webp "https://picsum.photos/512/512?random=1"
curl -o opportunity_01.webp "https://picsum.photos/512/512?random=2"
curl -o communication_01.webp "https://picsum.photos/512/512?random=3"
```

## 🧪 テスト手順

### 1. 画像ファイルの配置
このディレクトリに必要な画像ファイルを配置

### 2. Supabase Storageへのアップロード
1. Supabase管理画面 → Storage → content-images
2. 画像ファイルをドラッグ&ドロップでアップロード
3. ファイル名が命名規則に従っていることを確認

### 3. データベースの確認
SQL Editorで以下のクエリを実行：

```sql
-- 画像URLが更新されているか確認
SELECT 
    word_text,
    image_url,
    updated_at
FROM words 
WHERE image_url IS NOT NULL
ORDER BY updated_at DESC;
```

## 📊 期待される結果

画像アップロード後、以下のような結果が表示されるはずです：

```
word_text      | image_url                                                           | updated_at
---------------+--------------------------------------------------------------------+----------------------------
responsibility | https://udvmzaodsrgwecfybkry.supabase.co/storage/v1/object/public/ | 2025-01-27 15:30:00+00
               | content-images/responsibility_01.webp
opportunity    | https://udvmzaodsrgwecfybkry.supabase.co/storage/v1/object/public/ | 2025-01-27 15:31:00+00
               | content-images/opportunity_01.webp
communication  | https://udvmzaodsrgwecfybkry.supabase.co/storage/v1/object/public/ | 2025-01-27 15:32:00+00
               | content-images/communication_01.webp
```

## ⚠️ 注意事項

1. **ファイルサイズ**: 5MB以下の画像ファイルを使用
2. **ファイル形式**: サポートされている画像形式のみ使用
3. **命名規則**: 必ず指定された命名規則に従う
4. **文字エンコーディング**: ファイル名に日本語や特殊文字は使用しない

## 🔍 トラブルシューティング

### よくある問題

1. **ファイル名が正しくない**: 命名規則を確認
2. **ファイルサイズが大きすぎる**: 5MB以下に圧縮
3. **対応していないファイル形式**: サポートされている形式に変換
4. **単語がデータベースに存在しない**: `words`テーブルに単語を追加

### 解決方法

詳細なトラブルシューティングについては、`storage_trigger_guide.md`を参照してください。

---

このディレクトリに適切な画像ファイルを配置することで、Storageトリガー機能のテストが可能になります。
