# Supabase ドキュメント運用ルール

本規約は、Supabase 関連ドキュメントの配置、命名、更新、MCP 自動生成ドキュメントの取り扱いを定義します。

## 配置ポリシー
- すべての Supabase 関連ドキュメントは `docs/supabase/` に格納する
- MCP により新規に生成される Supabase 文書は `docs/supabase/mcp/` に格納する
- セットアップ系: `setup_guide.md`
- ストレージ系: `storage_setup.md`
- 補助資料/個別トピック: `docs/supabase/<topic>.md`

## 命名規約
- 固定ガイドはスネークケースの英語名（例: `setup_guide.md`, `storage_setup.md`）
- MCP 生成ファイルは `YYYY-MM-DD_topic.md`（例: `2025-08-09_rls-audit.md`）
- 見出し H1 は簡潔に、先頭に目的語を含める（例: 「Supabase ストレージ設定手順」）

## リンク/参照
- `docs/supabase/` 配下から `docs/` 直下への相対リンクは `../` を用いる
- 外部リンクは公式ドキュメントを最優先
- 重要な参照先: `../development/usalingo_04_technical_requirements.md`

## 更新フロー
1. ドキュメント追加/更新
2. `docs/supabase/README.md` の目次/更新履歴を反映
3. PR を作成し、`Supabase`/`Docs` ラベルを付与
4. レビュー観点
   - セキュリティ（RLS/ポリシー）
   - 一貫性（命名/用語）
   - 再現性（手順の網羅性/検証）

## 非互換変更
- 破壊的なスキーマ/ポリシー変更を伴う提案は、必ず「変更理由」「影響範囲」「ロールバック手順」を含める

## 廃止/移行
- 古いドキュメントを廃止する場合、`docs/supabase/README.md` の更新履歴に移行先を明記


