import 'package:flutter/material.dart';
import 'themes/flat_theme.dart';
import 'themes/material_theme.dart';
import 'themes/neumorphism_theme.dart';
import 'themes/glassmorphism_theme.dart';
import 'themes/pixel_art_theme.dart';
import 'themes/wireframe_theme.dart';
import 'themes/mockup_theme.dart';

// テーマタイプの列挙型
enum AppThemeType {
  flat,
  material,
  neumorphism,
  glassmorphism,
  pixelArt,
  wireframe,
  mockup,
}

// アプリテーマの基本インターフェース
abstract class AppTheme {
  // 基本色
  Color get backgroundColor;
  Color get surfaceColor;
  Color get primaryColor;
  Color get accentColor;
  Color get textColor;
  Color get textSecondaryColor;
  Color get borderColor;
  Color get iconColor;
  Color get overlayColor;

  // 形状
  double get cornerRadius;
  double get borderWidth;
  BorderStyle get borderStyle;

  // タイポグラフィ
  String get fontFamily;
  double get fontSizeSmall;
  double get fontSizeMedium;
  double get fontSizeLarge;
  FontWeight get fontWeightNormal;
  FontWeight get fontWeightBold;

  // エフェクト
  BoxShadow? get boxShadow;
  double get blurRadius;

  // スペーシング
  double get marginSmall;
  double get marginMedium;
  double get marginLarge;
  double get paddingSmall;
  double get paddingMedium;
  double get paddingLarge;

  // 追加プロパティ
  double get borderRadius;
  Color get cardColor;
  List<BoxShadow> get cardShadows;
  BorderSide get borderSide;
  TextStyle get headingTextStyle;
  TextStyle get secondaryTextStyle;

  // テーマデータの取得
  ThemeData get themeData;
}

// アプリテーマ設定クラス
class AppThemeConfig {
  static const String _defaultTheme = 'flat_design';
  
  // 利用可能なテーマ一覧
  static const Map<String, String> availableThemes = {
    'flat_design': 'フラットデザイン',
    'material_design': 'マテリアルデザイン',
    'neumorphism': 'ニューモーフィズム',
    'glassmorphism': 'ガラスモーフィズム',
    'pixel_art': 'ピクセルアート',
    'wireframe': 'ワイヤーフレーム',
  };

  // テーマ名からテーマインスタンスを取得
  static AppTheme getTheme(String themeName) {
    switch (themeName) {
      case 'flat_design':
        return FlatTheme();
      case 'material_design':
        return MaterialTheme();
      case 'neumorphism':
        return NeumorphismTheme();
      case 'glassmorphism':
        return GlassmorphismTheme();
      case 'pixel_art':
        return PixelArtTheme();
      case 'wireframe':
        return WireframeTheme();
      default:
        return FlatTheme(); // デフォルトはフラットデザイン
    }
  }

  // AppThemeTypeからテーマインスタンスを取得
  static AppTheme getThemeFromType(AppThemeType type) {
    switch (type) {
      case AppThemeType.flat:
        return FlatTheme();
      case AppThemeType.material:
        return MaterialTheme();
      case AppThemeType.neumorphism:
        return NeumorphismTheme();
      case AppThemeType.glassmorphism:
        return GlassmorphismTheme();
      case AppThemeType.pixelArt:
        return PixelArtTheme();
      case AppThemeType.wireframe:
        return WireframeTheme();
      case AppThemeType.mockup:
        return MockupUsalingoTheme();
    }
  }

  // デフォルトテーマ名を取得
  static String get defaultTheme => _defaultTheme;

  // テーマが有効かどうかを判定
  static bool isValidTheme(String themeName) {
    return availableThemes.containsKey(themeName);
  }
}
