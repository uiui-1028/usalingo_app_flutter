import 'package:flutter/material.dart';
import '../app_theme.dart';

// ワイヤーフレームテーマの実装
class WireframeTheme implements AppTheme {
  @override
  Color get backgroundColor => const Color(0xFFFFFFFF);

  @override
  Color get surfaceColor => const Color(0xFFF8F8F8);

  @override
  Color get primaryColor => const Color(0xFF000000);

  @override
  Color get accentColor => const Color(0xFF000000);

  @override
  Color get textColor => const Color(0xFF000000);

  @override
  Color get textSecondaryColor => const Color(0xFF666666);

  @override
  Color get borderColor => const Color(0xFF000000);

  @override
  Color get iconColor => const Color(0xFF000000);

  @override
  Color get overlayColor => const Color(0x66000000);

  @override
  double get cornerRadius => 0.0;

  @override
  double get borderWidth => 2.0;

  @override
  BorderStyle get borderStyle => BorderStyle.solid;

  @override
  String get fontFamily => 'Roboto Mono';

  @override
  double get fontSizeSmall => 12.0;

  @override
  double get fontSizeMedium => 16.0;

  @override
  double get fontSizeLarge => 24.0;

  @override
  FontWeight get fontWeightNormal => FontWeight.w400;

  @override
  FontWeight get fontWeightBold => FontWeight.w700;

  @override
  BoxShadow? get boxShadow => null;

  @override
  double get blurRadius => 0.0;

  @override
  double get marginSmall => 8.0;

  @override
  double get marginMedium => 16.0;

  @override
  double get marginLarge => 24.0;

  @override
  double get paddingSmall => 8.0;

  @override
  double get paddingMedium => 16.0;

  @override
  double get paddingLarge => 24.0;

  @override
  double get borderRadius => 0.0;

  @override
  Color get cardColor => surfaceColor;

  @override
  List<BoxShadow> get cardShadows => [];

  @override
  BorderSide get borderSide =>
      BorderSide(color: borderColor, width: borderWidth);

  @override
  TextStyle get headingTextStyle => TextStyle(
    fontSize: fontSizeLarge,
    fontWeight: fontWeightBold,
    color: textColor,
    fontFamily: fontFamily,
  );

  @override
  TextStyle get secondaryTextStyle => TextStyle(
    fontSize: fontSizeMedium,
    fontWeight: fontWeightNormal,
    color: textSecondaryColor,
    fontFamily: fontFamily,
  );

  @override
  ThemeData get themeData => ThemeData(
    useMaterial3: false,
    colorScheme: ColorScheme.light(
      background: backgroundColor,
      surface: surfaceColor,
      primary: primaryColor,
      secondary: accentColor,
      onBackground: textColor,
      onSurface: textColor,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
    ),
    textTheme: TextTheme(
      bodySmall: TextStyle(
        fontSize: fontSizeSmall,
        fontWeight: fontWeightNormal,
        color: textColor,
        fontFamily: fontFamily,
      ),
      bodyMedium: TextStyle(
        fontSize: fontSizeMedium,
        fontWeight: fontWeightNormal,
        color: textColor,
        fontFamily: fontFamily,
      ),
      bodyLarge: TextStyle(
        fontSize: fontSizeLarge,
        fontWeight: fontWeightBold,
        color: textColor,
        fontFamily: fontFamily,
      ),
    ),
    cardTheme: CardThemeData(
      color: surfaceColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(cornerRadius),
        side: BorderSide(color: borderColor, width: borderWidth),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.transparent,
        foregroundColor: textColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cornerRadius),
          side: BorderSide(color: borderColor, width: borderWidth),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: paddingMedium,
          vertical: paddingSmall,
        ),
      ),
    ),
  );
}
