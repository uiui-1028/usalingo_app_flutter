# よくある問題と解決方法

## ビルドエラー

### Flutter Doctor エラー
**症状**: `flutter doctor`でエラーが表示される
```bash
# 解決方法
flutter doctor --android-licenses
flutter config --android-sdk /path/to/android/sdk
```

### 依存関係エラー
**症状**: `flutter pub get`でエラーが発生
```bash
# 解決方法
flutter clean
flutter pub get
flutter pub upgrade
```

### iOSビルドエラー
**症状**: iOSビルドでエラーが発生
```bash
# 解決方法
cd ios
pod install
cd ..
flutter clean
flutter pub get
```

## ランタイムエラー

### データベースエラー
**症状**: SQLiteエラーが発生
```dart
// 解決方法: データベースの再初期化
await database.close();
await initializeDatabase();
```

### メモリリーク
**症状**: アプリが重くなる、クラッシュする
```dart
// 解決方法: 適切なdispose
@override
void dispose() {
  _controller.dispose();
  super.dispose();
}
```

### 音声再生エラー
**症状**: 音声が再生されない
```dart
// 解決方法: 権限の確認
await Permission.microphone.request();
```

## パフォーマンス問題

### アプリが重い
**症状**: アプリの動作が遅い
```dart
// 解決方法: ウィジェットの最適化
class OptimizedWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const SizedBox(); // constを使用
  }
}
```

### メモリ使用量が多い
**症状**: メモリ使用量が異常に多い
```dart
// 解決方法: 画像の最適化
Image.asset(
  'assets/images/example.png',
  cacheWidth: 300, // キャッシュサイズの制限
)
```

## ネットワーク問題

### Supabase接続エラー
**症状**: Supabaseに接続できない
```dart
// 解決方法: 接続設定の確認
final supabase = Supabase.instance.client;
try {
  await supabase.from('words').select();
} catch (e) {
  // オフライン対応
  await loadLocalData();
}
```

### 同期エラー
**症状**: データの同期が失敗する
```dart
// 解決方法: 手動同期の実装
Future<void> manualSync() async {
  try {
    await syncLocalToRemote();
    await syncRemoteToLocal();
  } catch (e) {
    // エラーハンドリング
  }
}
```

## UI/UX問題

### テーマが適用されない
**症状**: テーマが正しく表示されない
```dart
// 解決方法: テーマプロバイダーの確認
MaterialApp(
  theme: themeProvider.currentTheme,
  home: HomePage(),
)
```

### アニメーションが重い
**症状**: アニメーションがカクつく
```dart
// 解決方法: アニメーションの最適化
AnimatedContainer(
  duration: const Duration(milliseconds: 300),
  curve: Curves.easeInOut,
  // 軽量なアニメーション
)
```

## デバッグ方法

### ログの確認
```bash
# Flutterログの確認
flutter logs

# デバッグモードでの実行
flutter run --debug
```

### パフォーマンス分析
```bash
# パフォーマンスプロファイル
flutter run --profile

# メモリ使用量の確認
flutter run --trace-startup
```

### エラーの詳細確認
```dart
// エラーハンドリングの追加
try {
  // 問題のある処理
} catch (e, stackTrace) {
  print('Error: $e');
  print('Stack trace: $stackTrace');
}
```

## 予防策

### 定期的なメンテナンス
```bash
# 週次メンテナンス
flutter clean
flutter pub get
flutter analyze
flutter test
```

### コード品質の維持
```bash
# コードフォーマット
dart format .

# 静的解析
flutter analyze

# テスト実行
flutter test
```

### バックアップの作成
```bash
# データベースのバックアップ
cp app.db app.db.backup

# 設定ファイルのバックアップ
cp lib/secrets.dart lib/secrets.dart.backup
```

## 緊急時の対応

### アプリが起動しない
1. アプリの再インストール
2. データのクリア
3. 設定のリセット

### データが消失した
1. バックアップからの復元
2. Supabaseからの再同期
3. 手動でのデータ復旧

### 重大なバグの修正
1. 緊急ブランチの作成
2. 修正の実装
3. テストの実行
4. 緊急リリース 