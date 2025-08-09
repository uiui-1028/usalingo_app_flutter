# *【 usalingo_02_content_requirements.md 】*

*アプリで扱う「素材」の仕様を定義する。学習コンテンツの設計図。*

---

## ***【** usalingo_02_**01｜学習コンテンツ設計 】***

<aside>

### **✦ 単語の計数方針**

*本アプリでは、学習対象となる単語の数を「**ワードファミリー（Word Family）**」を基準に計測・管理する。*

---

**● ワードファミリーの定義**

ワードファミリーとは、`persist`（動詞）を覚える際に、文法的な変化形（`persists`, `persisted`）だけでなく、派生接辞によって生まれる `persistence`（名詞）や `persistent`（形容詞）なども含めて一つの「語族」として捉えるカウント方法である。

**● 採用理由**

この方法は語彙研究において最も一般的に用いられており、ネイティブスピーカーが接辞のルールから派生語を理解する感覚に近いアプローチである。これにより、例えば「高頻度語3000語」という目標を立てる際も、学術的な基準との一貫性を保つことができる。

---

### **✦ 学習単語ソースの選定**

| **参照リスト名** | 単語数 | 対象 | 参考文献 | タイプ | ライセンス料 | **商用利用可否** | **備考** |
| --- | --- | --- | --- | --- | --- | --- | --- |
| NGSL | 2800 | 基礎 | [https://www.newgeneralservicelist.com/](https://www.newgeneralservicelist.com/new-general-service-list) | オンラインリスト | **無料（CC BY-SA 4.0）** | **可（条件あり）** | クレジット表示＆同ライセンス継承必須 |
| NAWL | 963 | 学術 | [https://www.newgeneralservicelist.com/new-general-service-list-1](https://www.newgeneralservicelist.com/new-general-service-list-1) | オンラインリスト | **無料（CC BY-SA 4.0）** | **可（条件あり）** | クレジット表示＆同ライセンス継承必須 |
| BSL | 1754 | ビジネス | [https://www.newgeneralservicelist.com/business-service-list](https://www.newgeneralservicelist.com/business-service-list) | オンラインリスト | **無料（CC BY-SA 4.0）** | **可（条件あり）** | クレジット表示＆同ライセンス継承必須 |
| TSL | 1200 | TOEIC | [https://www.newgeneralservicelist.com/toeic-service-list](https://www.newgeneralservicelist.com/toeic-service-list) | オンラインリスト | **無料（CC BY-SA 4.0）** | **可（条件あり）** | クレジット表示＆同ライセンス継承必須 |
| Oxford 3000 | 3000 | 日常 | [https://www.oxfordlearnersdictionaries.com/about/wordlists/oxford3000-5000](https://www.oxfordlearnersdictionaries.com/about/wordlists/oxford3000-5000) | オンラインリスト | 有料 | 許可なく不可 | 個別の権利者に事前許諾要 |
| Oxford 5000 | 5000 | 日常 | - | オンラインリスト | 有料 | 許可なく不可 | 個別の権利者に事前許諾要 |
| 鉄壁 | 1981 | 大学受験 |  | 単語帳 | 有料 | 許可なく不可 |  |
| システム英単語 | 2027 | 大学受験 |  | 単語帳 | 有料 | 許可なく不可 |  |
| ターゲット英単語 1000 | 1000 | 大学受験 | - | 単語帳 | 有料 | 許可なく不可 |  |
| ターゲット英単語 1400 | 1400 | 大学受験 | - | 単語帳 | 有料 | 許可なく不可 |  |
| ターゲット英単語 1900 | 1900 | 大学受験 | [https://www.obunsha.co.jp/pr/target/](https://www.obunsha.co.jp/pr/target/) | 単語帳 | 有料 | 許可なく不可 |  |
| 単語王 | 2000 | 大学受験 |  | 単語帳 | 有料 | 許可なく不可 |  |
| 英検準１級 でる順 パス単 | 1900 | 英検 |  | 単語帳 | 有料 | 許可なく不可 |  |
| 速読英単語 必修編 | 1900 | 大学受験 |  | 単語帳 | 有料 | 許可なく不可 |  |
| 速読英単語 上級編 | 1200 | 大学受験 |  | 単語帳 | 有料 | 許可なく不可 |  |
| 出る単特急 銀のフレーズ | 1000 | TOEIC | - | 単語帳 | 有料 | 許可なく不可 |  |
| 出る単特急 金のフレーズ | 1000 | TOEIC |  | 単語帳 | 有料 | 許可なく不可 |  |

---

### **✦ 例文テーマ & 例文イラスト**

*本アプリで提供する学習コンテンツの中核となる、例文のテーマと、それに付随するイラストのビジュアルスタイルを定義する。*

---

### **Thema｜🔰 シンプル系**

---

**✦ 例文サンプル**

特定のテーマといった縛りのない, 一般的な形式。長めの例文と短めの例文でさらに分ける案も検討中。

```yaml
.example-sentence-concern {
  name: "concern";
  english: "This issue concerns everyone.";
  japanese: "この問題は全員に関係する。";
}

.example-sentence-design {
  name: "design";
  english: "She designed the new logo.";
  japanese: "彼女は新しいロゴをデザインした。";
}

.example-sentence-interest {
  name: "interest";
  english: "He has a strong interest in science.";
  japanese: "彼は科学に強い関心を持っている。";
}
```

---

**✦ 例文イラストスタイル**

このテーマのイラストは、Midjourneyのバージョン`--v 6.1`を用いて生成する。ただし、視覚的な多様性を確保するため、スタイル参照（`--sref`）を用いない「基本スタイル」と、「sref管理シート」から承認済みIDをランダムに引用して`--sref`を適用する「参照スタイル」の2種類を意図的に混在させる。全パターンのプロンプトは、GeminiまたはGPTsによる最適化を必須とする。

---

### **Thema｜🙃 ツンデレ系**

- **タイトル候補**
    - 「高嶺の花からの挑戦状」
    - 「ツンデレパートナーと学ぶ英単語」
    - 「ツンデレ彼女のスパルタレッスン」
    - 「ポーカーフェイスな彼女の特別レッスン」
- **例文サンプル**
    
    ```yaml
    .example-sentence-presence {
      name: "presence";
      english: "Your presence is so weak, I forgot you were even here.";
      japanese: "存在感なさすぎて、ここにいるの忘れてたわ。";
    }
    
    .example-sentence-circumstance {
      name: "circumstance";
      english: "Blaming the circumstance again? Classic you.";
      japanese: "また状況のせいにしてるの？いつものあんたね。";
    }
    
    .example-sentence-capability {
      name: "capability";
      english: "I questioned your capability, and now... you've really confirmed it.";
      japanese: "あんたの能力に疑問あったけど、もう確信に変わったよ。";
    }
    
    .example-sentence-attempt {
      name: "attempt";
      english: "That was your best attempt? I'm almost impressed... almost.";
      japanese: "それがあんたの全力の試み？ちょっと...いや、やっぱ無理。";
    }
    
    .example-sentence-responsibility {
      name: "responsibility";
      english: "Taking responsibility means more than just saying 'my bad,' you know.";
      japanese: "責任取るって、「ごめん」で済む話じゃないんだけど？";
    }
    ```
    
- **例文イラストスタイル**
    - このテーマのイラストは、アニメ調の表現に特化したNizijourneyを用いて生成する。ツール自体が持つ独自のスタイルを最大限に活かすため、追加のスタイル参照（`--sref`）は行わない。常に最新バージョン（`--v 6`など）のモデルを使用し、例文の意図を正確に反映させるため、プロンプトはGeminiまたはGPTsを介して最適化する。

---

### **Thema｜🐶 どうぶつ系**

---

今日の主役は、森の動物たち。
ほのぼのとしたストーリーで学ぶ英単語シリーズ。
可愛らしいキャラクターと一緒に、新しい言葉の世界へ出かけよう。

---

```yaml
.example-sentence-technology {
  name: "technology";
  english: "All the forest animals were surprised by the new dam technology Mr. Beaver made!";
  japanese: "森の動物たちは、ビーバーさんが作った新しいダムの技術にみんなびっくり！";
}

.example-sentence-appropriate {
  name: "appropriate";
  english: "Walking quietly is the appropriate action so we don't wake up the hibernating bear.";
  japanese: "冬眠しているクマさんを起こさないように、静かに歩くのが適切な行動だね。";
}

.example-sentence-possible {
  name: "possible";
  english: "If they try hard, it's possible for even small ants to carry a big leaf.";
  japanese: "がんばれば、小さなアリさんでも大きな葉っぱを運ぶことは可能なんだ。";
}

.example-sentence-individual {
  name: "individual";
  english: "The animals in the forest each have their own individual calls, making them very unique.";
  japanese: "森の動物たちは、みんなそれぞれ違う鳴き声を持っていて、とっても個性的だね。";
}

.example-sentence-certain {
  name: "certain";
  english: "Grandpa Owl knows everything about the forest, so his stories are certain to be true.";
  japanese: "フクロウおじいさんは、森のことなら何でも知っているから、彼の話は確かだよ。";
}
```

---

**例文イラストスタイル**

xxx

</aside>

---

## ***【** usalingo_02_**02｜コンテンツ生成フロー 】***

---

### **● テキストコンテンツ生成と品質管理**

```yaml
.property_generation_workflow-summary {
  name: 単語帳プロパティ生成;
  description: "回答出力の一貫性を保つため、Googleスプレッドシート上でのAPI一括生成は行わず、専用のGem/GPTsモジュールを介して各プロパティを丁寧に生成する。";
}

.property_generation_workflow-steps {
  name: プロセスフローと注意点;
  process: "1.【単語リストの準備】対象となる英単語リストを Google-Spreedsheet に用意する。";
  process: "2.【プロパティコンテンツ生成】各単語について、定義済みのプロンプトテンプレートを用いてGem/GPTsモジュールにリクエストを送信し、表形式でプロパティコンテンツを出力する。";
  process: "3.【品質管理】生成された全コンテンツは、後述の `usalingo_02_04｜AIGC ガイドライン` に基づき、自動フィルタリングおよび人間による監査を受ける。";
  process: "4.【csv-エクスポート】承認済みのデータをcsv形式でSupabaseの各テーブルにインポートする。";
  notes: "プロンプトのバージョン管理を徹底し、品質の一貫性を維持する。";
}

.property_generation_workflow-dependencies {
  name: 利用ツール;
  tool: "Google-Spreadsheet";
  tool: "Gemini(Gem) / OpenAI(GPTs)";
  tool: "Notebook-LM";
  tool: "Supabase";
}
```

---

### **● イラストコンテンツ制作と管理**

```yaml
.illustration_generation_workflow-summary {
  name: 例文イラスト生成;
  description: "画像生成AIの精度を向上させ、人間による検品工数を削減するため、生成AIが解釈しやすいプロンプトを生成し、後続の画像処理・DB紐付けまでを自動化するワークフローを採用する。";
}

.illustration_generation_workflow-steps {
  name: プロセスフローと注意点;
  process: "1.【例文の抽出】データベースから、イラストを生成する対象の例文をリストアップする。";
  process: "2.【プロンプトの自動生成】API-Appscriptなどを利用し、例文からMidjourneyが解釈しやすい形式のプロンプトを自動生成する。";
  process: "3.【画像生成】生成されたプロンプトをMidjourney APIで実行し、イラストを生成する。";
  process: "4.【人間による評価】`usalingo_02_04｜AIGC ガイドライン` に基づき、生成されたイラストの中から、例文の意図と最も合致し、かつ品質・安全性の高いものを1点選定する。";
  process: "5.【一次アップロードと自動処理起動】選定した画像をSupabase Storageの一時保管場所にアップロードする。このアップロードをトリガーとして、後続の自動処理を実行する。";
  process: "6.【画像最適化｜Edge Function】Supabase Edge Functionが起動し、アップロードされた画像を自動で処理する。具体的には、WebP形式への**拡張子変換**と、規定サイズ（150KB以下）への**圧縮**を行う。";
  process: "7.【URL紐付けと正規配置】最適化された画像の公開URLを取得し、データベース内の該当する例文レコードにその**URLを自動で紐付ける**。同時に、最適化済みの画像を公開用の正規バケットへ移動させる。";
  process: "8.【後処理】一時保管場所にアップロードされた変換元の画像は、プロセス完了後に自動で削除する。";
  notes: "この自動化ワークフローにより、手作業によるミスをなくし、コンテンツ制作のスケーラビリティを確保する。";
}

.illustration_generation_workflow-specifications {
  name: ファイル仕様と保存場所;
  file-format: WebP;
  resolution: "1280px x 720px (16:9)"//Midjourney のデフォルト出力値;
  max-file-size: "150KB";
  naming-convention: "{word_text}_{illustration_id}.webp";
  storage-bucket: "Supabase Storage (illustrations / Public)";
  folder-structure: "v1/{word_text}/";
}

.illustration_generation_workflow-dependencies {
  name: 利用ツール;
  tool: "Gemini (Gem) / OpenAI (GPTs)";
  tool: "GoAPI（Midjourney）";
  tool: "Supabase Storage";
  tool: "Supabase Edge Functions";
}
```

---

### **● 音声コンテンツの仕様と実装**

---

### **実装ロードマップ**

事業フェーズに応じて、以下の通り段階的に音声機能を進化させる。

- **MVP段階： 静的音声ファイルの同梱**
Ankiアドオンの「AwesomeTTS」などを利用し、サービス提供前に全ての単語・例文の音声ファイル（MP3）を一括で生成する。これらのファイルをアプリパッケージに同梱することで、オフライン環境での安定した音声再生と、API呼び出しコストの完全なゼロ化を実現する。ただし、アプリ容量の増加や、コンテンツ追加時の運用コストが課題となる。
- **Ver.1.x以降： 高品質クラウドTTSの導入（Proプラン向け）**
サービスの収益化に合わせ、より自然で高品質な音声を生成できるクラウドベースのTTS（例: Google Cloud Text-to-Speech, ElevenLabs API）を導入する。これはProプラン限定の機能とし、優れた音声体験を付加価値として提供する。これにより、MVP段階の課題であったアプリ容量の問題を解消し、動的な音声生成も可能になる。

---

### **再生制御とカスタマイズ**

ユーザーが自身の学習スタイルに合わせて挙動を調整できるよう、以下の設定項目を提供する。

- **再生トリガー:**
デフォルトでは、カード表示時に単語や例文が1回だけ自動再生される。
- **リピート機能:**
認知コストを最小限に抑えるため、リピートボタンは初期状態では非表示とする。ユーザーが設定画面で有効化した場合にのみ、カード上に表示されるオプトイン方式を採用する。
- **音声の選択:**
ユーザーは、以下のプリセットされた音声から任意に選択・混合できる。
    - アクセント（例: アメリカ英語 / イギリス英語）
    - 性別（例: 男性 / 女性）
- **再生速度の調整:**
ユーザーは、自身の聞き取りやすさに合わせて再生速度を調整できる（例: 0.75x, 1.0x, 1.25x）。

---

### **技術仕様**

- **データ形式:** 生成する音声ファイルは、圧縮率と音質のバランスに優れるMP3形式で統一する。
- **命名規則:** `word_text`と音声の属性（例: `us_female`）を組み合わせ、一意のファイル名とする。（例: `apple_us_female.mp3`）

---

## ***【** usalingo_02_**03｜チップスコンテンツ定義 】***

*アプリケーションのロード画面などで表示する、短い豆知識（チップス）コンテンツの仕様を定義する。待ち時間を、有益なだけでなく、視覚的にも楽しい「マイクロ体験」へと転換させることを目的とする。*

---

<aside>

### **● コンテンツ構成と表現**

各チップスは、**テキスト情報**とそれを補完する**Lottieアニメーション**のペアで構成される。テキストが持つ意味合い（例: 応援、豆知識、機能紹介）に合わせて、ユーモアのあるものや、分かりやすく概念を表現するものなど、最適なアニメーションを組み合わせる。これにより、ユーザーに情報の理解を促すと同時に、視覚的な楽しさを提供する。

| カテゴリ | 内容例 |
| --- | --- |
| **学習法に関する知識** | 「忘却曲線によると、復習は1日後、3日後、1週間後が効果的である」 |
| **英単語の豆知識** | 「"goodbye"は"God be with ye"（神が汝と共にありますように）が語源なんだよ」 |
| **アプリ機能の紹介** | 「デザインタブから、アプリの色やアイコンを自分好みに変えられます」 |
| **応援メッセージ** | 「1日1単語でも大丈夫。続けることが一番の近道である」 |

---

### **● データ構造と管理**

チップスデータは、更新頻度が低くオフラインでの利用が望ましいため、ローカルDB（SQLite）の`chips_data`テーブルで管理する。

| カラム名 | 型 | 説明 |
| --- | --- | --- |
| chip_id | INTEGER | チップスの一意なID |
| title | TEXT | チップスのタイトル（例：「効果的な復習法」） |
| description | TEXT | チップスの本文 |
| lottie_asset_path | TEXT | アプリ内に同梱されたLottieファイルへのパス
（例: `assets/lottie/tips/forgetting_curve.json`） |
</aside>

---

## ***【** usalingo_02_**04｜AIGC ガイドライン 】***

*本ガイドラインは、usalingoで提供するすべてのAIGC（単語、例文、イラスト等）が、Apple App StoreおよびGoogle Play Storeのポリシーを遵守し、かつusalingoブランドの品質基準を満たすことを保証するために策定された、**コンテンツ生成プロセスの技術的・運用的仕様書**である。コンテンツ生成に関わる全てのプロセス（プロンプト設計、AIによる生成、フィルタリング、人間によるレビュー）は、本ガイドラインを絶対的な基準として運用する。*

---

### ✦ コンテンツ品質管理パイプライン

<aside>

---

### 【フェーズ①】入力制御 (ゲートキーパー)

**目的：** 不適切なコンテンツ生成の可能性を、AIへの指示段階で根絶する。

```
# フェーズ① 入力制御 (ゲートキーパー)
name: "フェーズ① 入力制御"
purpose: "不適切なコンテンツ生成の可能性を、AIへの指示段階で根絶する。"
process_flow:
  - step: 1
    name: "生成要求の受付"
    input: "単語 / テーマ"
    output: "次のプロセスへの入力"

  # --------------------------------------------------------------------

  - step: 2
    name: "プロンプトの構築"
    process: "構造化プロンプトテンプレートを適用"
    details: "役割(Role), 厳格な制約(Constraints), ポジティブな指示(Positive Instruction)をAIへの指示に埋め込む。"
    dependency: "ポリシー準拠フレームワーク"
    output: "安全なAPIリクエストとしてAIモデルへ送信"
```

---

### 【フェーズ②】一次検証 (自動フィルター)

**目的：** AIが生成したコンテンツから、明白な規約違反を機械的に、かつ即座にふるい落とし、大量のコンテンツを高速で分類する。

```
# フェーズ② 一次検証 (自動フィルター)
name: "フェーズ② 一次検証"
purpose: "AIが生成したコンテンツから、明白な規約違反を機械的に、かつ即座にふるい落とし、大量のコンテンツを高速で分類する。"
process_flow:
  - step: 1
    name: "入力受付"
    input: "AIからの生成物 (JSON)"

  # --------------------------------------------------------------------

  - step: 2
    name: "自動検証処理"
    process: "フィルタリング処理 (Supabase Function)"
    details: "テキストデータに対して、以下の検証を自動実行する。"
    dependencies:
      - "NGワードリスト (usalingo_main.pdf)"
      - "有害性判定API (Google Cloud Natural Language API)"

  # --------------------------------------------------------------------

  - step: 3
    name: "出力"
    output: "分類結果: [OK], [要レビュー], [却下]"
```

### ✦ **実装レベル1 (必須): キーワード・フィルタリング**

- **処理内容:** `usalingo_main`スプレッドシート [cite: usalingo_main - Google スプレッドシート.pdf] を基に作成した**NGワードリスト**と生成テキストを照合する。NGワードが一つでも含まれていた場合、その生成結果は自動的に「要レビュー」フラグを立てる。
- **技術仕様:** Supabase Functions内で、生成されたテキストデータに対し、事前に定義した正規表現パターンまたは文字列リストとのマッチング処理を実行する。
- **限界:** この方法は文脈を理解できないため、誤検知（例: `ass`ist）や検知漏れ（隠語など）が発生する可能性がある。そのため、あくまで一次スクリーニングとして位置づける。

### ✦ **実装レベル2 (将来的に推奨): APIによる有害性判定**

- **処理内容:** Google Cloud Natural Language APIの**有害コンテンツ分類**などの外部APIを利用し、生成テキストの有害性（ヘイトスピーチ、性的、暴力的など）をスコアリングする。
- **技術仕様:** 各カテゴリのスコアが事前に設定した閾値を超えた場合、自動的に「却下」または「要レビュー」として分類する。
- **メリット:** 文脈をある程度理解できるため、キーワード・フィルタリングよりも高精度な一次検証が可能となる。

---

### 【フェーズ③】最終承認 (人間による監査)

**目的：** 機械では判断が難しい文脈やニュアンスを人間が判断し、ブランド適合性を含めた最終的な品質を保証する。

```
# フェーズ③ 最終承認 (人間による監査)
name: "フェーズ③ 最終承認"
purpose: "機械では判断が難しい文脈やニュアンスを人間が判断し、ブランド適合性を含めた最終的な品質を保証する。"
process_flow:
  - step: 1
    name: "入力受付"
    input: "「要レビュー」と分類されたコンテンツ"

  # --------------------------------------------------------------------

  - step: 2
    name: "人間による監査"
    process: "レビュワーによる監査"
    details: "定義されたチェックリストに基づき、コンテンツを評価する。"
    dependencies:
      - "レビュー用チェックリスト"
      - "App/Play Store規約"

  # --------------------------------------------------------------------

  - step: 3
    name: "出力"
    output: "判定結果: [承認], [修正], [却下]"

```

### ✦ **レビュワー向けチェックリスト**

自動フィルタリングを通過した、あるいは「要レビュー」と判定されたコンテンツは、人間による最終承認プロセスに回される。レビュワーは以下の項目に基づき、客観的にコンテンツを評価する。

<aside>

- [ ]  **ポリシー準拠:** 「ポリシー準拠フレームワーク」の全カテゴリに抵触する要素は一切ないか？
    - [ ]  性的・冒涜的
    - [ ]  暴力・残虐的
    - [ ]  ヘイト・差別
    - [ ]  違法・危険
    - [ ]  デリケートな事象
- [ ]  **ストア規約準拠:** [Apple App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) [cite: App Review Guidelines.pdf] および [Google Play 不適切なコンテンツポリシー](https://support.google.com/googleplay/android-developer/answer/9878810?hl=ja) [cite: 不適切なコンテンツ - Play Console ヘルプ.pdf] に違反していないか？
- [ ]  **ブランド適合性:** `usalingo`のトーン＆マナー（ポジティブ、学習意欲を削がない）に合致しているか？
- [ ]  **独自コンテンツの文脈:** （例:「ポーカーフェイスな彼女」）キャラクター性が、単なる人格否定や罵倒になっていないか？ユーモアの範囲内か？
- [ ]  **品質:** 誤字脱字、不自然な文法はないか？教育コンテンツとして正確か？
</aside>

### ✦ **判定基準**

- **承認 (Approved):** 全てのチェック項目をクリア。
- **修正 (Edit Required):** 軽微な表現（例: 句読点、単語の選択）の調整で承認基準を満たせるもの。
- **却下 (Rejected):** フレームワークの根本的なルールに違反しており、修正が困難なもの。再生成を指示する。

---

### 【フェーズ④】改善 (フィードバックループ)

**目的：** 本ガイドラインは固定的なものではなく、市場と規約の変化に対応し、品質保証プロセスを継続的に改善する。

```
# フェーズ④ 改善 (フィードバックループ)
name: "フェーズ④ 改善"
purpose: "市場と規約の変化に対応し、品質保証プロセスを継続的に改善する。"
process_flow:
  - step: 1
    name: "情報収集"
    input:
      - "ユーザー報告"
      - "ストアレビュー"
      - "規約変更 / 社会情勢"

  # --------------------------------------------------------------------

  - step: 2
    name: "評価と意思決定"
    process: "定期的レビュー会議 (四半期に一度)"
    details: "収集したフィードバックを基に、ガイドライン全体の見直しを行う。"

  # --------------------------------------------------------------------

  - step: 3
    name: "ガイドラインへの反映"
    output: "更新されたガイドライン"
    details:
      - "プロンプトテンプレートの改善"
      - "NGワードリストの更新"
      - "レビュー基準の精緻化"

```

### ✦ **フィードバック収集**

- アプリ内に**コンテンツの報告機能**を実装し、ユーザーから不適切と思われるコンテンツのフィードバックを収集する。
- App Store / Google Playのレビューや、カスタマーサポートへの問い合わせ内容を定期的に分析する。
</aside>

---

### ✦ 【資料抜選】ポリシー準拠フレームワーク

| カテゴリ | 抵触する可能性のある要素 | 具体的なNG例（単語/テーマ） | ✅ Usalingoでの許容/注意ライン（例文生成時の指針） |
| --- | --- | --- | --- |
| **🚫 1. 性的・冒涜的** | ・露骨な性的描写、ポルノ
・性的満足を目的としたコンテンツ
・ヌードや性的な身体部位の強調
・冒涜的な言葉、卑語 | **単語例:** sex, porn, naked, fuck, breasts, penis 等

**テーマ:** 性行為、売春、性的フェチ、過度な露出 | ・**原則生成禁止。**
・学習対象とする場合も、単語の定義や語源解説に留め、**例文での使用は一切不可**とする。
・hot や sexy 等の多義語は、性的でない文脈でのみ使用を許可する。（例: This coffee is hot.） |
| **🚫 2. 暴力・残虐的** | ・現実的な暴力の描写
・殺人、拷問、虐待、自傷行為
・テロリズム、暴力的過激主義の助長
・兵器の製造や使用の推奨 | **単語例:** blood, corpse, kill, torture, suicide, slaughter 等

**テーマ:** 殺人、戦争、虐待、テロ行為、銃乱射 | ・kill 等の単語は、Kill two birds with one stone. のような**慣用句**や、架空の物語の中など、**現実の暴力を想起させない抽象的な表現に限定**する。
・兵器や犯罪行為を美化・推奨する例文は生成しない。 |
| **🚫 3. ヘイトスピーチ・差別** | ・人種、民族、宗教、国籍、性別、性的指向、障害などに基づく差別、憎悪、暴力の助長
・特定の集団に対する中傷や非人間的な表現 | **単語例:** Nazi, Fascist、各種差別用語

**テーマ:** 特定の集団への偏見、ステレオタイプの助長、陰謀論 | ・**一切生成禁止。例外はない。**
・歴史学習の文脈で扱う場合でも、その行為を中立的または否定的に記述し、決して肯定・美化しない。
・特定の国籍、人種、宗教、性的マイノリティ等を否定的に描写する例文は厳禁。 |
| **🚫 4. 違法行為・危険な活動** | ・規制薬物（マリファナ等）の販売, 助長
・爆発物、銃器の製造方法
・危険なチャレンジ、いじめ、嫌がらせ | **単語例:** 違法薬物の名称、銃器の具体的なモデル名

**テーマ:** 薬物使用の推奨、爆弾の作り方、特定の個人への嫌がらせ | ・**原則として一切生成を禁止する。**
・犯罪を描写する例文は、それがフィクション（例：推理小説の一節）であることが明確で、犯罪行為を推奨するものでない場合に限り、慎重に検討する。 |
| **⚠️ 5. デリケートな事象** | ・災害、紛争、死亡、その他の悲劇的な出来事に対する無神経な言及
・被害者やその関係者を不当に扱うコンテンツ | **テーマ:** 実際に起きた災害、事故、テロ事件、進行中の紛争 | ・実際に起きた悲劇的な出来事を、軽々しく学習例文の題材として利用しない。
・歴史的な出来事として扱う場合も、被害者への配慮を欠いた表現は避ける。 |

---

</aside>
