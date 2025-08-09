# Supabase MCP ドキュメント保管場所

このディレクトリは、Supabase に関する MCP（モデル/エージェントによる自動生成）ドキュメントの専用保管場所です。

## 命名規約
- ファイル名: `YYYY-MM-DD_topic.md`
  - 例: `2025-08-09_storage-policy-review.md`
- タイトル: 「[MCP] {トピック名}」で開始
- 冒頭メタ情報（YAML Front Matter 推奨）:
  - `date`, `author`, `scope`（例: schema | storage | auth | realtime | client | ops）

## 配置ルール
- Supabase 関連で自動生成された文書は必ず本ディレクトリ直下に配置すること
- 長編のシリーズ物は `mcp/<series-slug>/` を作成して格納可
- 生成後は `docs/supabase/README.md` の「更新履歴」にリンクを追記

## レビュー/品質
- PR 作成時に `Supabase` と `Docs` ラベルを付与
- 重要な設定変更を含む場合は `docs/rules/supabase-docs-rules.md` の該当規約も更新


