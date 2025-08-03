# Cursur AI Editer｜Design

status: Will (https://www.notion.so/Will-21cc3d1f59e880baac37c00d7055d707?pvs=21)
type: 開発サポート

### **動的テーマエンジン 設計原則 Ver.2**

**目的**
本ドキュメントは、UsalingoアプリケーションのUI実装における「動的テーマエンジン」の技術仕様を定義する。この設計の核は、UIの構造と視覚的スタイルを分離し、テーマの動的な切り替えと高い拡張性を実現することにある。

**原則1：テーマの契約（Contract）を定義する**
全てのデザインテーマが実装すべき共通のインターフェースとして、抽象クラス `**AppTheme**` を定義する。このクラスは、Flutterの `**ThemeData**` オブジェクトを生成するためのプロパティと、アプリ独自のカスタムデザイン要素を全て含んだ契約として機能する。

- **Flutter連携**: `*AppTheme**` は、Flutter標準のテーマシステムと連携するため、 `*ThemeData get themeData;**` というgetterを必ず含めるものとする。
- **カスタムプロパティ**: `*AppTheme**` は、以下のカスタムデザイン要素をプロパティとして宣言する。
    - **色彩**: `*Color backgroundColor**`, `*Color primaryColor**`, `*Color accentColor**`, `*Color textColor**`, `*Color cardColor**` など。
    - **形状**: `*double borderRadius**`, `*double borderWidth**`, `*BorderStyle borderStyle**` など。
    - **エフェクト**: `*List<BoxShadow> cardShadows**` など、特定のウィジェットに適用する陰影効果。

**原則2：契約に基づきテーマを実装（Implementation）する**
個別のデザイン思想を、`**AppTheme**` を実装する具象クラスとして定義する。クラス名は `**[ThemeName]UsalingoTheme**` の形式を基本とする（例: `**MaterialUsalingoTheme**`）。

- **`WireframeTheme`**: 開発の基盤となるテーマ。全ての色彩プロパティは `*Colors.black**` や `*Colors.white**` に設定し、`*cardShadows**` は空のリスト、`*borderRadius**` は `*0.0**` を返すように実装する。
- **`NeumorphicTheme`**: ニューモーフィズムを表現するテーマ。`*backgroundColor**` にはオフホワイト（例: `*0xFFE0E5EC**`）を設定。`*cardShadows**` は、左上に明るい影、右下に暗い影を表現する2つの `*BoxShadow**` を含んだリストを返すように実装する。
- **`PixelArtTheme`**: ドット絵風テーマ。`*borderRadius**` は `*0.0**` とし、タイポグラフィ用のプロパティではドット絵風のカスタムフォントを指定する。

**原則3：選択されたテーマを注入（Injection）する**
テーマの選択と適用は、状態管理ライブラリ `**Riverpod**` を用いて行う。

- **Providerの定義**: 現在選択されている `*AppTheme**` のインスタンスを公開する `*StateNotifierProvider**` を、例えば `*themeProvider**` という名前で定義する。このProviderは、ユーザーの選択に応じて `*MaterialUsalingoTheme**` や `*NeumorphicTheme**` などのインスタンスを保持・更新する。
- **ウィジェットでの利用**: 各UIウィジェットは `*ConsumerWidget**` を継承するか、`*ref.watch(themeProvider)**` を使用して現在のテーマオブジェクトを取得する。ウィジェットのスタイルは、このオブジェクトのプロパティを直接参照して構築する。
    - **適用例**: `*Container**` ウィジェットの装飾は、`*decoration: BoxDecoration(color: theme.cardColor, boxShadow: theme.cardShadows, borderRadius: BorderRadius.circular(theme.borderRadius))**` のように記述する。これにより、`*themeProvider**` の状態が変わると、UIが自動的に再描画される。

**原則4：ワイヤーフレーム駆動開発（Wireframe-First）を実践する**
開発の初期段階および機能追加フェーズでは、`**themeProvider**` のデフォルト値を `**WireframeTheme**` のインスタンスに設定する。

これにより、開発者はスタイルの詳細に煩わされることなく、`**Column**` や `**Row**` を用いたレイアウト構造の構築、ウィジェットの機能実装、状態管理のロジックといった本質的な開発に集中できる。各デザインテーマでの表示確認は、特定の開発マイルストーンごとに行うことで、手戻りを減らし、開発効率を最大化する。