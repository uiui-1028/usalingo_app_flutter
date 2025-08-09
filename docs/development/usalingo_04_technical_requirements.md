# *【 usalingo_04_technical_requirements.md 】*

*プロダクトを「どう作るか (How to build)」を定義する。技術的な実装の設計図。*

---

## ***【 usalingo_04_01｜開発環境 & 技術スタック 】***

<aside>

**● ハードウェア環境**

| 開発マシン | MacBook Air (15-inch, M2, 2023)
**チップ**: Apple M2
**メモリ**: 16 GB
**OS**: macOS Sequoia 15.6 |
| --- | --- |
| テスト用実機 | iPhone 12 (64GB) |

---

**● ソフトウェア環境**

[https://github.com/uiui-1028/usalingo_app_flutter](https://github.com/uiui-1028/usalingo_app_flutter)

| IDE | Cursur AI Editer (VS Codeベース) |
| --- | --- |
| 言語／フレーム | Flutter (Dart) |
| AIエージェント | Claude Code, Gemini CLI |
| バージョン管理 | Git / GitHub |
| CI／CD | GitHub Actions |
| デザイン | Figma, Canva, iconComposer, ibisPaint |
| プロジェクト管理 | Notion, Gemini, Claude, Cursur, GoogleWorkspace |

---

**● クラウド環境**

| BaaS | Supabase |
| --- | --- |
| データベース | Supabase Database (PostgreSQL) |
| 認証 | Supabase Auth |
| ストレージ | Supabase Storage (画像・音声) |
| アセット調達 | LottieFiles Marketplace |

---

**● Flutter ライブラリ／パッケージング** *⚠️ 保留*

</aside>

---

## ***【 usalingo_04_02｜ディレクトリツリー 】***

<aside>

```yaml
# 【 03-04｜リポジトリ構成 】
usalingo_app/
├── .git/                    # Gitリポジトリの管理ファイル
├── .dart_tool/              # Dartツールのキャッシュと設定
├── .idea/                   # IntelliJ IDEAの設定ファイル
├── build/                   # ビルド出力ディレクトリ
├── lib/                     # メインのDartソースコード
│   ├── app/                 # アプリケーションの初期化とDI設定
│   │   ├── app.dart         # アプリケーションのメイン設定
│   │   └── providers.dart   # 依存性注入のプロバイダー設定
│   ├── data/                # データ層（Clean Architecture）
│   │   ├── datasources/     # データソース（Supabase、SQLite等）
│   │   │   ├── learning_progress_datasource.dart  # 学習進捗データソース
│   │   │   ├── local_word_datasource.dart         # ローカル単語データソース
│   │   │   └── sqlite_schema.dart                 # SQLiteスキーマ定義
│   │   ├── models/          # データ転送オブジェクト（DTO）
│   │   └── repositories/    # リポジトリの実装
│   │       ├── learning_progress_repository_impl.dart  # 学習進捗リポジトリ実装
│   │       ├── word_repository_impl.dart              # 単語リポジトリ実装
│   │       ├── word_repository_selector.dart          # リポジトリ選択ロジック
│   │       ├── word_repository_sqlite.dart            # SQLite単語リポジトリ
│   │       └── word_repository_supabase.dart          # Supabase単語リポジトリ
│   ├── domain/              # ドメイン層（Clean Architecture）
│   │   ├── entities/        # ビジネスエンティティ
│   │   │   ├── learning_progress.dart  # 学習進捗エンティティ
│   │   │   └── word.dart               # 単語エンティティ
│   │   ├── repositories/    # リポジトリのインターフェース
│   │   └── usecases/       # ビジネスロジック（ユースケース）
│   │       ├── get_due_today_cards.dart      # 今日学習すべきカード取得
│   │       ├── get_learning_progress.dart    # 学習進捗取得
│   │       ├── get_next_word.dart            # 次の単語取得
│   │       └── mark_card_result.dart         # カード結果記録
│   ├── presentation/        # プレゼンテーション層（Clean Architecture）
│   │   ├── pages/          # 画面UIと状態管理
│   │   │   ├── flashcard_page.dart              # フラッシュカード画面
│   │   │   ├── learning_progress_test_page.dart # 学習進捗テスト画面
│   │   │   ├── root_page.dart                   # ルート画面
│   │   │   ├── supabase_test_page.dart          # Supabaseテスト画面
│   │   │   ├── test_3d_card_screen.dart         # 3Dカードテスト画面
│   │   │   ├── theme_selector_page.dart         # テーマ選択画面
│   │   │   └── word_list_page.dart              # 単語リスト画面
│   │   ├── theme/          # テーマ設定
│   │   │   ├── app_theme.dart                   # アプリテーマ設定
│   │   │   ├── app_theme_provider.dart          # テーマプロバイダー
│   │   │   └── themes/                          # 各テーマの実装
│   │   │       ├── flat_theme.dart              # フラットテーマ
│   │   │       ├── material_theme.dart          # Materialテーマ
│   │   │       ├── mockup_theme.dart            # モックアップテーマ
│   │   │       ├── neumorphism_theme.dart       # ニューモーフィズムテーマ
│   │   │       ├── pixel_art_theme.dart         # ピクセルアートテーマ
│   │   │       └── wireframe_theme.dart         # ワイヤーフレームテーマ
│   │   └── widgets/        # 再利用可能なウィジェット
│   │       ├── flashcard_widget.dart            # フラッシュカードウィジェット
│   │       └── lottie_feedback_widget.dart      # Lottieフィードバックウィジェット
│   ├── main.dart           # アプリケーションのエントリーポイント
│   └── secrets.dart        # 機密情報（APIキー等）
├── docs/                     # メインのDartソースコード
│   ├── README.md                  # ドキュメント全体の概要
│   ├── rules/                     # 開発ルール（既存）
│   │   ├── README.md
│   │   ├── common-rules.md        # Cursor AI Editor用のルール
│   │   ├── cursor-rules.md        # Claude用のルール
│   │   └── claude-rules.md        # 共通ルール（重複部分）
│   ├── architecture/              # アーキテクチャ設計
│   │   └── overview.md            # システム設計概要
│   ├── development/               # 開発ガイド
│   │   └── setup.md               # 開発環境セットアップ
│   ├── features/                  # 機能仕様書
│   │   └── flashcard-system.md    # フラッシュカード機能
│   └── troubleshooting/           # トラブルシューティング
│       └── common-issues.md       # よくある問題と解決方法
├── assets/                 # 静的アセット
│   ├── audio/              # 音声ファイル
│   └── lottie/             # Lottieアニメーションファイル
├── android/                # Androidプラットフォーム固有のファイル
├── ios/                    # iOSプラットフォーム固有のファイル
├── linux/                  # Linuxプラットフォーム固有のファイル
├── macos/                  # macOSプラットフォーム固有のファイル
├── windows/                # Windowsプラットフォーム固有のファイル
├── web/                    # Webプラットフォーム固有のファイル
├── test/                   # テストコード
├── .DS_Store               # macOSシステムファイル
├── .flutter-plugins-dependencies # Flutterプラグイン依存関係
├── .gitignore              # Git除外設定
├── .metadata               # Flutterメタデータ
├── analysis_options.yaml    # Dart解析設定
├── devtools_options.yaml   # Flutter DevTools設定
├── pubspec.lock            # 依存関係ロックファイル
├── pubspec.yaml            # プロジェクト設定と依存関係
├── README.md               # プロジェクト概要
└── usalingo_app.iml       # IntelliJ IDEAプロジェクト設定
```

</aside>

---

## ***【 usalingo_04_03｜データベース設計 】***

<aside>

### ✦ 設計原則

---

### ● **命名規則**

- **基本:** 半角英小文字のスネークケース (`snake_case`) のみを使用する。日本語、スペース、その他の特殊文字は使用しない。これにより、URLエンコーディングやクエリでの問題を回避する。
- **テーブル:** 複数のデータを格納するため、**複数形** (`users`, `words`, `user_settings`) を使用する。
- **カラム:** 単一の属性を表すため、**単数形** (`email`, `word_text`, `created_at`) を使用する。
- **主キー (PK):** カラム名を `id` とする。
- **外部キー (FK):** `[参照先テーブルの単数形]_id` という形式（例: `user_id`, `word_id`）を採用する。
- **タイムスタンプ:** 作成日時を `created_at`、更新日時を `updated_at` とする。
- **真偽値:** `is_` プレフィックスを使用する（例: `is_public`, `is_completed`）。

### ● **アセット管理方針**

- **単一マスターイメージの原則:** ストレージには高解像度のオリジナル画像を1つだけ保存する。
- **動的変換の活用:** 画像の配信には、Supabaseの**「Storage Image Transformation」**機能を全面的に活用する。URLのクエリパラメータ（例: `?transform=width=200`）で、表示箇所に応じた最適なサイズの画像を動的に生成・配信する。これにより、開発効率とパフォーマンスを最大化する。
- **ファイル命名:** `[単語テキスト]_[タイプ].[拡張子]` (例: `apple_illustration.webp`) の形式で、内容が推測できるファイル名とする。

---

### ✦ セキュリティ方針（RLS）

*アクセスは原則として全て拒否し、これから定義するポリシーで許可された操作のみを可能とします。これにより、意図しないデータ漏洩のリスクを最小限に抑えます。*

---

### ● **ポリシー定義**

- **公開データ (Public Data):**
    - **対象テーブル:** `words`, `example_contents`, `decks`
    - **ポリシー:** **全てのユーザー（非認証ユーザーを含む）が読み取り (`SELECT`) 可能。** 書き込み（`INSERT`, `UPDATE`, `DELETE`）は全てのユーザーに対して不可とする。
- **認証ユーザー共通データ (Authenticated User Data):**
    - **対象テーブル:** `users`
    - **ポリシー:** **認証済みのユーザーは、自身のユーザー情報のみ読み取り可能。** 他のユーザーの情報は読み取れない。
- **所有権に基づくデータ (Ownership-based Data):**
    - **対象テーブル:** `user_profiles`, `user_settings`, `user_learning_progress`, `user_widget_layouts`
    - **ポリシー:** **ユーザーは、自身の `user_id` に紐づくデータのみ、全ての操作（`SELECT`, `INSERT`, `UPDATE`, `DELETE`）が可能。**
        - **具体例:** `user_profiles` テーブルを操作しようとする場合、`auth.uid() = user_id` が真となる行にしかアクセスできないようにポリシーを設定します。これはSupabase Authが提供する `auth.users` テーブルと連携することで実現します。

---

### ✦ストレージ戦略

アプリケーションを構成するデータの種類、論理構造、物理的な保存場所を定義する。

---

### 【01】データスタイル定義

| データ種別 | 形式 | 主な用途 |
| --- | --- | --- |
| テキスト | TEXT / String | 単語、例文、UI上の文言など |
| 画像 | WEBP / PNG | 単語に紐づくイラスト、UIアイコンなど (※WEBPを優先し軽量化) |
| 音声 | MP3 | 単語・例文の読み上げ音声 |
| Lottie | JSON | UIアニメーション、マイクロインタラクション、学習完了時のリワードなど |

---

### 【02】データベース俯瞰図 (論理構造)

| テーブル名 | 概要 | ストレージ | 主なカラム |
| --- | --- | --- | --- |
| users | ユーザーアカウント情報 | Supabase | user_id, email, created_at |
| user_learning_progress | ユーザーごとの学習進捗と忘却曲線データ | Supabase & SQLite | id, user_id, content_id, last_reviewed, next_review_date, correct_count |
| contents | 単語や例文などのコアコンテンツ（テキスト情報） | Supabase & SQLite | content_id, word, example_sentence |
| content_assets | コンテンツに紐づくアセット（画像・音声）のパスを管理 | Supabase | asset_id, content_id, asset_type, storage_path |
| chips_data | アプリ内で使用する静的なTipsなどの情報 | SQLite | chip_id, title, description |

---

### 【03】ストレージ俯瞰図 (物理構造)

| 格納データ | ストレージ名 | 概要 |
| --- | --- | --- |
| 上記 users や contents などのテーブルデータ | Supabase Database | 構造化されたメタデータ。リレーショナルな関係性を持ち、クエリで操作される。 |
| 画像ファイル (.webp), 音声ファイル (.mp3) | Supabase Storage | コンテンツに紐づくバイナリファイル。DBからはパスで参照する。 |
| chips_data テーブル | SQLite | 頻繁な更新が不要で、オフラインでも利用したい静的な構造化データ。 |
| Lottieファイル (.json), UI用画像 | App Asset Bundle | アプリに同梱する静的アセット。UIのアニメーションなど、高速な表示が求められるもの。 |

---

### 【04】ストレージの定義

```yaml
storage_positions:
  - type: "クラウドストレージ"
    service: "Supabase"
    description: "動的に変化し、かつ複数のデバイス間で同期が必要なデータに適している。ユーザーがどのデバイスからアクセスしても、同じ学習環境を提供できる。"
    use_cases:
      - "ユーザー学習データ"
      - "コンテンツマスター"

  - type: "ローカルストレージ"
    service: "SQLite"
    description: "配布後は変更の頻度が低く、オフラインでの利用が想定される静的コンテンツに適している。アプリケーションに組み込むことで、通信環境に依存しない高速なデータアクセスが可能になる。"
    use_cases:
      - "チップスデータ"
      - "Lottieファイル"
```

---

### ✦ テーブル定義

*本ドキュメントは、usalingo アプリケーションの根幹をなす Supabase (PostgreSQL) データベースの論理設計を定義する。*

---

### ユーザー関連 (User & Profile)

```yaml
# -----------------------------------------------
# Table: users (Supabase Authと同期)
# -----------------------------------------------
- table: users
  description: "Supabaseの認証機能と1対1で対応する、ユーザーの基本認証情報。このテーブルへの直接的な書き込みはAuth経由で行われる。"
  columns:
    - name: id
      type: UUID (Primary Key)
      description: "Supabase Authによって自動的に割り当てられる、ユーザーの一意なID。"
    - name: email
      type: TEXT
      description: "ユーザーのメールアドレス。"
    - name: created_at
      type: TIMESTAMPTZ
      description: "アカウントの作成日時。"

# -----------------------------------------------
# Table: user_profiles
# -----------------------------------------------
- table: user_profiles
  description: "ユーザーのプランやニックネームなど、付加的なプロフィール情報を格納する。"
  columns:
    - name: user_id
      type: UUID (Primary Key, Foreign Key to users.id)
      description: "ユーザーID。usersテーブルとのリレーションを確立する。"
    - name: plan
      type: TEXT (default: 'free')
      description: "ユーザーの現在のプラン ('free' or 'pro') 。"
    - name: nickname
      type: TEXT
      description: "アプリ内で表示されるユーザーの名前。"

# -----------------------------------------------
# Table: user_settings
# -----------------------------------------------
- table: user_settings
  description: "UIテーマ、フォント、音声など、ユーザーがカスタマイズしたアプリの表示・挙動設定を管理する。"
  columns:
    - name: user_id
      type: UUID (Primary Key, Foreign Key to users.id)
      description: "ユーザーID。"
    - name: design_style
      type: TEXT (default: 'flat_design')
      description: "UIの基本スタイル (例: 'flat_design', 'neumorphism') 。"
    - name: color_mode
      type: TEXT (default: 'system')
      description: "カラーモード ('light', 'dark', 'system') 。"
    - name: accent_color
      type: TEXT (default: '#FF5D97')
      description: "アクセントカラーのHEXコード。"
    - name: font_family
      type: TEXT (default: 'system_default')
      description: "アプリ全体のフォントファミリー名。"
    - name: card_interaction_mode
      type: TEXT (default: 'punch')
      description: "解答インタラクション ('punch' or 'flip') 。"
    - name: tts_config
      type: JSONB
      description: "Text-to-Speechの音声（性別、速度など）に関する設定を格納する。"

# -----------------------------------------------
# Table: user_widget_layouts
# -----------------------------------------------
- table: user_widget_layouts
  description: "ユーザーが「学習」「プロフィール」の各タブに配置したウィジェットのレイアウト情報を管理する。"
  columns:
    - name: id
      type: SERIAL (Primary Key)
      description: "レイアウト情報の一意なID。"
    - name: user_id
      type: UUID (Foreign Key to users.id)
      description: "このレイアウトを所有するユーザーID。"
    - name: tab_name
      type: TEXT
      description: "ウィジェットが配置されているタブ名 ('learning' or 'profile') 。"
    - name: widget_type
      type: TEXT
      description: "ウィジェットの種類 (例: 'deck', 'streak', 'heatmap') 。"
    - name: related_id
      type: INT
      description: "ウィジェットのマスターデータへの参照ID。widget_typeが'deck'の場合は、decks.idを指す。"
    - name: display_order
      type: INT
      description: "タブ内での表示順序。"
    - name: settings
      type: JSONB
      description: "ウィジェット固有の設定（例：学習デッキの出題範囲やスタイル）を格納する。"
```

---

### コンテンツ関連 (Content & Deck)

```yaml
# -----------------------------------------------
# Table: words
# -----------------------------------------------
- table: words
  description: "全ての英単語の基本情報を格納するマスターテーブル。「ワードファミリー」の基幹となる単語を登録する。"
  columns:
    - name: id
      type: SERIAL (Primary Key)
      description: "単語の一意なID。"
    - name: word_text
      type: TEXT (UNIQUE)
      description: "英単語の文字列。"
    - name: definition
      type: TEXT
      description: "単語の主要な日本語訳。"
    - name: part_of_speech
      type: TEXT
      description: "品詞。"
    - name: etymology
      type: TEXT
      description: "語源の解説。"
    - name: synonyms
      type: TEXT[]
      description: "類義語のリストを配列で格納する。"
    - name: antonyms
      type: TEXT[]
      description: "対義語のリストを配列で格納する。"

# -----------------------------------------------
# Table: example_contents
# -----------------------------------------------
- table: example_contents
  description: "一つの単語に対して、テーマ（シンプル、ツンデレ等）ごとに存在する例文、イラスト、音声を管理する。"
  columns:
    - name: id
      type: SERIAL (Primary Key)
      description: "コンテンツセットの一意なID。"
    - name: word_id
      type: INT (Foreign Key to words.id)
      description: "関連する単語のID。"
    - name: theme
      type: TEXT (default: 'simple')
      description: "コンテンツのテーマ ('simple', 'tsundere', 'animal'など) 。"
    - name: sentence_en
      type: TEXT
      description: "英語の例文。"
    - name: sentence_ja
      type: TEXT
      description: "例文の日本語訳。"
    - name: illustration_url
      type: TEXT
      description: "例文イラスト画像のURL (Supabase Storage) 。"
    - name: audio_url
      type: TEXT
      description: "例文読み上げ音声のURL (Supabase Storage) 。"

# -----------------------------------------------
# Table: decks
# -----------------------------------------------
- table: decks
  description: "NGSLやTSLといった、学習デッキのマスターデータを定義する。"
  columns:
    - name: id
      type: SERIAL (Primary Key)
      description: "デッキの一意なID。"
    - name: deck_name
      type: TEXT (UNIQUE)
      description: "デッキの名称 (例: 'NGSL - 基礎単語') 。"
    - name: description
      type: TEXT
      description: "デッキの内容に関する詳細な説明。"
    - name: source_list_name
      type: TEXT
      description: "参照元の単語リスト名 (例: 'NGSL', 'TSL') 。"
    - name: license
      type: TEXT
      description: "コンテンツのライセンス情報 (例: 'CC BY-SA 4.0') 。"

# -----------------------------------------------
# Table: deck_words
# -----------------------------------------------
- table: deck_words
  description: "どのデッキにどの単語が含まれるか、多対多の関係を定義する中間テーブル。"
  columns:
    - name: deck_id
      type: INT (Primary Key, Foreign Key to decks.id)
      description: "デッキID。"
    - name: word_id
      type: INT (Primary Key, Foreign Key to words.id)
      description: "単語ID。"
```

---

### 学習進捗関連 (Learning Progress)

```yaml
# -----------------------------------------------
# Table: user_learning_progress
# -----------------------------------------------
- table: user_learning_progress
  description: "ユーザーごとの単語学習進捗。忘却曲線アルゴリズムのパラメータもここで管理する。"
  columns:
    - name: user_id
      type: UUID (Primary Key, Foreign Key to users.id)
      description: "ユーザーID。"
    - name: word_id
      type: INT (Primary Key, Foreign Key to words.id)
      description: "学習対象の単語ID。"
    - name: status
      type: TEXT (default: 'new')
      description: "学習ステータス ('new', 'learning', 'mastered') 。"
    - name: last_reviewed_at
      type: TIMESTAMPTZ
      description: "最後にこの単語を復習した日時。"
    - name: next_review_date
      type: TIMESTAMPTZ
      description: "アルゴリズムによって算出された、次回復習推奨日時。"
    - name: srs_level
      type: INT (default: 1)
      description: "リートナー方式における現在のレベル。"
    - name: easiness_factor
      type: REAL (default: 2.5)
      description: "SM-2アルゴリズムにおける易しさ係数（E-Factor）。"
    - name: repetitions
      type: INT (default: 0)
      description: "SM-2アルゴリズムにおける連続正解回数。"
    - name: interval_days
      type: INT (default: 0)
      description: "SM-2アルゴリズムにおける前回の復習間隔。"
```

</aside>

---

## ***【 usalingo_04_04｜アルゴリズム設計 】***

### 【01】忘却曲線 アルゴリズム（ リートナー方式 ）

 *MVP段階では、オフライン学習機能テストとコスト削減のため、ユーザー端末のローカルDB（SQLite）で管理する**リートナー方式**を採用する。*

---

**● データモデル（ローカルDB｜SQLite）**

| カラム名 | 型 | 説明 |
| --- | --- | --- |
| word_id | INTEGER | どの単語の進捗かを示す一意な ID |
| srs_level | INTEGER | リートナー方式のレベル（1〜5）, 数値が高いほど定着している状態を示す |
| next_review_date | TEXT | 次回復習日を YYYY-MM-DDTHH:MM:SS 形式の文字列で格納 |

---

**● アルゴリズム仕様**

```yaml
# ===============================================
# Algorithm Spec: Leitner System (MVP)
# ===============================================

# -----------------------------------------------
# 1. 復習間隔の定義 (SRS Levels)
# -----------------------------------------------
- level: 1
  interval_days: 1
  description: "「わからない」と評価されたカードが属する初期レベル"
- level: 2
  interval_days: 3
- level: 3
  interval_days: 7
- level: 4
  interval_days: 14
- level: 5
  interval_days: 30
  description: "このレベルをクリアすると「マスター済み」と見なす"

# -----------------------------------------------
# 2. ロジックフロー
# -----------------------------------------------
- event: "カードを「わかる」にスワイプ"
  action:
    - "srs_level を 1つ進める (例: level 2 -> level 3)。"
    - "進んだ先のレベルに対応する interval_days を現在日時に加算し、next_review_date を更新する"

- event: "カードを「わからない」にスワイプ"
  action:
    - "srs_level を 1 にリセットする。"
    - "レベル1の interval_days を現在日時に加算し、next_review_date を更新する"

# -----------------------------------------------
# 3. データ同期方針
# -----------------------------------------------
- primary_storage: "ユーザー端末内のローカルDB (SQLite)"
  description: "オフラインでの軽快な動作を保証する"
```

---

### 【02】忘却曲線 アルゴリズム（ SM-2 ）

 *本来は4択でグラデーションを持って計量するところを, 2択のシンプルなUIUXで独自に再編成した、SM-2のパーソナライズ機能を一部取り入れたハイブリッド方式。*

---

**● データモデル（ローカルDB｜SQLite）**

| カラム名 | 型 | 説明 |
| --- | --- | --- |
| word_id | INTEGER | どの単語の進捗かを示す一意なID。 |
| easiness_factor | REAL | 易しさ係数（E-Factor）。初期値は2.5。 |
| repetitions | INTEGER | 連続正解回数。不正解で0にリセットされる。 |
| interval_days | INTEGER | 前回の復習間隔（日数）。 |
| next_review_date | TEXT | 次回復習日。 |

---

**● アルゴリズム仕様**

```yaml
# ===============================================
# Algorithm Spec: 2-Choice SM-2 (Hybrid)
# ===============================================

# -----------------------------------------------
# 1. ユーザー入力の定義
# -----------------------------------------------
# ユーザーの操作は「わかる」「わからない」の2択のみ。
- event: "カードを「わかる」にスワイプ"
  is_correct: true

- event: "カードを「わからない」にスワイプ"
  is_correct: false

# -----------------------------------------------
# 2. ロジックフロー
# -----------------------------------------------
- event: "is_correct が false の場合"
  action:
    - "repetitions を 0 にリセットする。"
    - "interval_days を 1 にリセットする。"
    - "easiness_factor を 0.2 減少させる（下限は1.3）。"

- event: "is_correct が true の場合"
  action:
    - "repetitions を 1つ進める。"
    - "easiness_factor は変更しない（または僅かに増加させる）。"
    - "repetitions の値に応じて interval_days を計算・更新する。"
    - "  - 1回目: 1日"
    - "  - 2回目: 6日"
    - "  - 3回目以降: 前回のinterval_days * easiness_factor"
    - "最後に、計算された interval_days を基に next_review_date を更新する。"

# -----------------------------------------------
# 3. データ同期方針
# -----------------------------------------------
- primary_storage: "ユーザー端末内のローカルDB (SQLite)"
- secondary_storage: "クラウドDB (Supabase)"
- sync_trigger: "定期的、または手動でのバックアップと復元。"
```

---

### 【03】学習履歴に基づく動的コンテンツ生成

### **✦ AIによる学習コンテンツ生成機能の詳細**

「AIによる学習コンテンツ生成」は、Proプラン限定の機能である。ユーザーがこれまでに学習した単語の中から、AIが自動で複数の単語をピックアップし、それらを用いてリアルタイムでユニークな例文（英文＋和訳）を生成する。これにより、ユーザーは自身の学習履歴に基づいた文脈で単語を復習でき、記憶の定着を促進する。本機能の優先度は「P3（中長期的な改善・追加機能）」と位置づけられる。例えば、学習した単語が予期せぬ組み合わせで文章に登場することにより、ユーザーは自身の理解度を多角的に試すことができる。

### **✦ 技術的な仕様**

技術的には、OpenAI（GPTシリーズ）またはGoogle（Geminiシリーズ）のAIモデルを利用する。APIキーを安全に管理するため、アプリから直接AIを呼び出すのではなく、SupabaseのEdge Functionsを介してリクエストを中継する。データの品質を保つため、AIへの指示はあらかじめ定義されたテンプレートを使用し、常にJSON形式でデータをやり取りする。

```yaml
1. ユーザーがアプリで例文生成をリクエストする。
2. アプリはSupabase Edge Functionにリクエストを送信する。
3. Edge Functionは、ユーザーの学習進捗データ（user_learning_progress）を参照し、復習対象となる単語を複数抽出する。
4. Edge Functionが抽出した単語群と、任意で指定された文脈テーマを基に、AIモデルへ最適な指示（プロンプト）を組み立て、例文の生成をリクエストする。
5. AIが生成した例文のデータをEdge Functionが受け取る。
6. Edge Functionがデータを整形し、安全にアプリへ返す。
7. アプリが受け取った例文を画面に表示する。
```

### **✦ ユーザー体験の流れ**

ユーザーは学習タブに配置できる「AI例文生成ウィジェット」からこの機能を使う。ウィジェットには、任意で文脈（例：'ビジネス'、'医療'など）を指定する欄が用意される。「例文を生成する」ボタンを押すと、AIが応答するまでの待機時間には、処理中であることが分かるようにローディングアニメーションが表示される。生成された例文は、学習カード形式ではなく、ニュース記事を読むような感覚でスクロールしながら読めるシンプルなテキストビューとして表示される。ここでは「わかる／わからない」といった評価操作は行わず、純粋な読解と復習に集中することができる。APIでエラーが発生した場合は、その旨を分かりやすく伝え、再試行を促する。

### **✦ 機能制約と前提条件**

- **APIコスト**: AIモデルの呼び出しごとに従量課金が発生する。本機能の事業採算性は、Proプランの価格とユーザー一人あたりのAPI利用回数制限のバランスに依存する。
- **応答遅延 (Latency)**: AIの応答には数秒の遅延が内在する。この待機時間がユーザー体験を損なわないよう、適切なUI/UX（ローディング表示等）によるハンドリングを前提とする。
- **品質の不確実性**: AIが不正確、または文脈に合わない不適切な例文を生成するリスクは常に存在する。機能の信頼性は、プロンプトエンジニアリングの継続的な改善によって担保される。
- **ロジック依存性**: 本機能が提供する学習価値は、ユーザーの学習履歴から復習に最適な単語を選び出す、その選定ロジックの精度に直接的に依存する。

---

### 【04】**英語力別のデータパーソナライズ方法**

*本アルゴリズムは、ユーザーがアプリを使い始めた瞬間の体験価値を最大化し、学習離脱率を低減させることを目的とする。*

---

### **✦ 基本思想**

多くのユーザーは、学習を開始する前の「選択」や「登録」といった行為に負荷を感じ、意欲を削がれてしまう。この障壁を取り除くため、アプリ初回起動時にはアカウント登録を要求せず、標準の「ウェルカムデッキ」を自動提供し、即座に学習を開始できる環境を用意する。その後、ユーザーがアカウント登録を行った際には、それまでの学習履歴を失うことなく新しいアカウントへ引き継ぐ。同時に、アンケートに基づきユーザーの目的に合った「パーソナライズドデッキ」を新しいウィジェットとして追加することで、気軽な体験から本格的なパーソナライズ学習へのシームレスな移行を実現する。

---

### **✦ アルゴリズム仕様**

```yaml
# ===============================================
# Algorithm Spec: Initial Content Personalization Strategy (Integrated Ver.)
# ===============================================

# -----------------------------------------------
# 1. フェーズ1：ゲスト体験（アプリ初回起動時）
# -----------------------------------------------
- event: ユーザーがアプリを初めて起動する
- action:
    - 1. ウェルカムデッキの自動配置：約300語を収録した標準のウェルカムデッキを、学習タブのウィジェットエリアに自動で配置する。
    - 2. ゲスト学習の開始：ユーザーはアカウント登録なしで、すぐにウェルカムデッキの学習を開始できる。学習進捗は端末のローカルDB（SQLite）に一時的に保存される。
- result: ユーザーは一切の摩擦なく、即座に学習体験を開始できる。

# -----------------------------------------------
# 2. フェーズ2：パーソナライズ（アカウント登録完了後）
# -----------------------------------------------
- event: ユーザーが新規アカウント登録を正常に完了する
- action:
------------------------------------------
    - 1. 学習履歴の継承：ローカルDBに保存されていたゲスト時の学習進捗（ウェルカムデッキの進捗）を、新しく作成されたユーザーアカウントに紐付け、Supabaseに保存する。
------------------------------------------
    - 2. オンボーディング・アンケートの実施：ユーザーに単一選択式の質問を提示し、学習目的を特定する。
    -   question_text: あなたの主な学習目的を教えてください
    -   options:
          - id: daily_conversation
            label: 日常英会話
          - id: business
            label: ビジネス英会話
          - id: toeic
            label: TOEIC / 英検対策
          - id: exam
            label: 大学受験
          - id: junior_english
            label: 中学・高校の復習
          - id: none
            label: 特に決まっていない
------------------------------------------
    - 3. 最適な学習デッキの追加：アンケートの回答（option.id）に基づき、以下のマッピングルールに従ってパーソナライズドデッキを決定し、学習タブに新しいウィジェットとして追加する。
    -   mapping_rules:
          - if: option.id is 'daily_conversation'
            then: deck_id: 1 (NGSL基礎単語デッキ) をウィジェットとして追加する
          - if: option.id is 'business'
            then: deck_id: 2 (BSLビジネス単語デッキ) をウィジェットとして追加する
          - if: option.id is 'toeic'
            then: deck_id: 3 (TSL TOEIC頻出単語デッキ) をウィジェットとして追加する
          - if: option.id is 'exam' or 'junior_english'
            then: deck_id: 4 (学術基礎単語デッキ) をウィジェットとして追加する
          - if: option.id is 'none'
            then: deck_id: 1 (NGSL基礎単語デッキ) をデフォルトとして追加し、さらにデッキ選択を促すUIを表示する
- result: 学習タブにはウェルカムデッキと新しいパーソナライズドデッキが別々のウィジェットとして共存する。ユーザーは自身の学習履歴を維持したまま、新たな目的の学習へとスムーズに移行できる。
```

---

### 【05】動的UIテーマシステム

*本アルゴリズムは、競争優位性の一つである「適応型パーソナル空間（アダプティブ・スペース）」を実現するための技術的根幹である。中心的な思想は、UIの構造的骨格と、その視覚的表現であるデザイン思想を完全に分離することにある。これにより、UIデザインの拡張性とメンテナンス性を最大化する。*

*本アルゴリズムは、競争優位性の一つである「適応型パーソナル空間（アダプティブ・スペース）」を実現するための技術的根幹である。中心的な思想は、UIの構造的骨格と、その視覚的表現であるデザイン思想を完全に分離することにある。これにより、UIデザインの拡張性とメンテナンス性を最大化する。*

---

### **1. テーマの契約**

全てのデザイン思想が遵守すべき統一のインターフェース、すなわち「契約」として、一つの抽象クラスを定義する。この契約には、アプリケーションのUIを構成するために必要な、全てのデザイン要素をプロパティとして網羅的に宣言する。これにより、どのデザイン思想を実装する際にも考慮すべき要素の漏れを防ぎ、アプリケーション全体の一貫性を保証する。

| カテゴリ | 属性（例） | 説明 |
| --- | --- | --- |
| **色彩** | 背景色, 基本色, アクセントカラー, テキスト色 | アプリ内で使用する全ての色を定義する。 |
| **タイポグラフィ** | 見出し/本文のフォントファミリー, サイズ, ウェイト | 役割に応じたフォントの階層を定義する。 |
| **形状** | 角丸の半径, 境界線のスタイル | コンポーネントの形状に関する規定を定義する。 |
| **エフェクト** | 陰影の付け方, ブラーの強度 | 視覚効果に関する規定を定義する。 |
| **スペーシング**  | 標準マージン, パディング | コンポーネント間の余白に関する値を定義する。 |

---

### **2. テーマの実装規約（提供側）**

「マテリアルデザイン」や「ニューモーフィズム」といった個別のデザイン思想を、原則1で定義した契約を実装する具体的なクラスとして作成する。各クラスは、契約で定められた全てのプロパティに対し、自身のデザイン思想に基づいた具体的な値を設定する必要がある。このルールにより、将来的に新しいデザイン思想を追加したい場合でも、この契約に準拠した新しいクラスファイルを追加するだけで対応が完了し、既存コードへの影響は最小限に抑えられる。

---

### **3. テーマの利用規約（参照側）**

アプリケーションのUIを構築する際、個々のウィジェットは特定の色やフォントサイズといった値を直接コード内に記述しません。その代わり、状態管理システムを通じて、現在ユーザーに選択されているテーマオブジェクトを一元的に受け取る。全てのウィジェットは、この注入されたテーマオブジェクトから「基本色」や「標準の角丸」といった値を参照して自身のスタイルを決定する。これにより、注入するテーマオブジェクトを切り替えるだけで、アプリケーション全体のルックアンドフィールを瞬時に、かつ整合性を保ったまま変更することが可能になる。

---

### **4. ワイヤーフレーム駆動開発**

開発の基本フェーズにおいては、原則2で定義したテーマ実装の一つである「ワイヤーフレームテーマ」をデフォルトで適用する。このテーマは、色彩や装飾的エフェクトを極限まで削ぎ落とし、UIの構造とレイアウトの骨格のみを可視化するものである。このアプローチによって、開発者は視覚的なデザインの細部に気を取られることなく、機能、データの流れ、そしてビジネスロジックの実装といった、より本質的なタスクに集中できる。

---

## ***【 usalingo_04_05｜アセット管理規定 】***

---

**✦ Lottieアセット利用規定**

| 項目 | 仕様 | 備考 |
| --- | --- | --- |
| **アセット調達方針** | MVPおよびVer.1.0段階では、LottieFiles Marketplace等でライセンス購入した汎用アセットを利用する。 | UI/UXの魅力を迅速に高めることを目的とし、独自アセット（キャラクターアニメーション等）の制作は後のフェーズに設定する。 |
| **アセット格納** | 購入したLottieのJSONファイルは、Flutterプロジェクト内の `assets/lottie/` ディレクトリに格納し、アプリパッケージに同梱する。 | これにより、オフライン環境でもアニメーションの表示を保証し、外部からの読み込み遅延を防ぐ。 |
| **ライセンス管理** | プロジェクトルートに `LOTTIE_LICENSES.md` を作成し、購入した全アセットの名称、購入元URL、ライセンス種別を明記する。 | 権利関係を明確化し、ライセンス違反のリスクを回避するための必須要件である。 |
| **将来的な方針** | ブランドキャラクター「うさぎ」の独自アニメーションは、Ver.2.0以降での内製化を計画する。 | 内製した独自アセットも、本規定で定義した格納方法とライセンス管理の規則に準拠して運用する。 |

---
