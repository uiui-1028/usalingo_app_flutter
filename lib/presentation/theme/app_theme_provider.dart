import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_theme.dart';

// 現在のテーマタイプを管理するプロバイダー
final appThemeTypeProvider = StateProvider<AppThemeType>((ref) {
  return AppThemeType.flat;
});

// 現在のテーマ名を管理するプロバイダー
final currentThemeNameProvider = StateProvider<String>((ref) {
  return AppThemeConfig.defaultTheme;
});

// 現在のテーマインスタンスを管理するプロバイダー
final currentThemeProvider = Provider<AppTheme>((ref) {
  final themeType = ref.watch(appThemeTypeProvider);
  return AppThemeConfig.getThemeFromType(themeType);
});

// テーマの切り替えを行うプロバイダー
final themeControllerProvider = Provider<ThemeController>((ref) {
  return ThemeController(ref);
});

// テーマ制御クラス
class ThemeController {
  final Ref _ref;

  ThemeController(this._ref);

  // テーマを切り替える
  void changeTheme(String themeName) {
    if (AppThemeConfig.isValidTheme(themeName)) {
      _ref.read(currentThemeNameProvider.notifier).state = themeName;
    }
  }

  // テーマタイプを切り替える
  void changeThemeType(AppThemeType type) {
    _ref.read(appThemeTypeProvider.notifier).state = type;
  }

  // デフォルトテーマに戻す
  void resetToDefault() {
    _ref.read(currentThemeNameProvider.notifier).state = AppThemeConfig.defaultTheme;
    _ref.read(appThemeTypeProvider.notifier).state = AppThemeType.flat;
  }

  // 現在のテーマ名を取得
  String get currentThemeName => _ref.read(currentThemeNameProvider);

  // 現在のテーマタイプを取得
  AppThemeType get currentThemeType => _ref.read(appThemeTypeProvider);

  // 利用可能なテーマ一覧を取得
  Map<String, String> get availableThemes => AppThemeConfig.availableThemes;
}
