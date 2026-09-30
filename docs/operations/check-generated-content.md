# AIが作った教材データを確かめる手順

対象: USL-327。AIが作ったV5形式のデータを、受け取り用シートへ送る前に確かめる。
方針は [英単語のテキストをAIで作り、受け取り用シートへ送る](../decisions/text-generation-series-lists-20260930.md) にある。

## 結論

```sh
# 1回分（100語など）を確かめる。誤りがあれば 1 で終わる
python3 scripts/check-generated-content.py check --dir <フォルダ>

# 確かめてから、人が見る1割を選んでTSVにする
python3 scripts/check-generated-content.py sample --dir <フォルダ> --output sample.tsv --seed 1
```

生成データは公開リポジトリに置かない。フォルダはクラウドセッションの作業場所などに置く。

## フォルダに置くもの

1つのフォルダに、シート名のファイルを置く。拡張子は `.tsv`（タブ区切り）か `.csv` のどちらか。
同じシートで両方を置くと止まる。

| ファイル | 必須 | 中身 |
|---|---|---|
| `01_core_words` | 必須 | この回の見出し語 |
| `01_core_senses` | 必須 | この回の意味 |
| `02_content_examples` | 必須 | この回の例文 |
| `04_deck_words` | 必須 | この回の単語が入るデッキと、主の意味 |
| `02_content_concepts` | 必須 | 使うコンセプトの一覧（`simple`、`anime` など） |
| `04_decks` | 必須 | 使うデッキの一覧 |
| `03_audio_*` | 任意 | 置かなければ空のシートとして扱う |

列の決まりは [V5の設計](../content/source-database-v5.md) と同じ。TSVでは `"` を囲みの記号として扱わないので、
`inflections` のJSONはそのまま書く（`{"past": "ran"}`）。

## 何を確かめるか

**止める誤り**（1つでもあれば送らない）

- 同期スクリプトの確かめ（`scripts/sync-sheet-to-supabase.py` の `build_document` をそのまま使う）
  - IDが1〜999999の数字か、同じシートで重複していないか
  - 必須の列が空でないか、参照先の行があるか
  - CEFRが `A1`〜`C2` か、`concept_code` の形、`inflections` がJSONオブジェクトか
  - ` /&/ ` の間に空の項目がないか、同じデッキに同じ単語が2回ないか
- 生成データ向けに足した確かめ
  - セルにタブや改行が入っていないか（TSVでは、見出しと数が合わない行として見つける）
  - `part_of_speech_en` が次のどれかか: noun, verb, adjective, adverb, preposition, conjunction,
    pronoun, determiner, interjection, auxiliary
  - ` /&/ ` の1項目が「単語 :: 訳 :: 補足」の3つまでで、単語が空でないか
  - 1つの単語の意味の `priority` が、1から重ならず抜けずに並んでいるか
  - デッキの主の意味（`04_deck_words` の `sense_id`）に、そのデッキのコンセプトの例文があるか

**注意**（一覧に出すだけ。送ってよい）

- 例文に見出し語が入っていない。活用した形（`inflections` の値、-s・-ed・-ing など）は入っているとみなす
- `definition_jp`・`sentence_jp` に日本語の文字がない

## 1割の選び方

- デッキ（シリーズの段階）ごとに、単語の1割を選ぶ。どのデッキからも最低1語は選ぶ
- `--seed` が同じなら、何度流しても同じ単語を選ぶ。回ごとに変えたいときは数字を変える
- 同じ単語が2つのデッキに入っていれば、1回だけ出す
- 出力は1語1行のTSV。`ok` と `note` の列は空なので、確かめた人が書きこむ

## まだやらないこと

- 受け取り用シートにすでにある行との突き合わせ（IDの重なり）。
  受け取り用シートへ送るスクリプト（USL-329）でGoogleの鍵ができたら足す
- 語源・CEFR・IPAが正しいかどうか。人の抜き取りで確かめる

## テスト

```sh
python3 -m unittest discover -s scripts/tests
```
