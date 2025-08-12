import 'package:flutter/material.dart';
import '../app_theme.dart';

// ガラスモーフィズムテーマの実装
class GlassmorphismTheme implements AppTheme {
  @override
  Color get backgroundColor => const Color(0xFF1A1A1A);

  @override
  Color get surfaceColor => const Color(0x80FFFFFF);

  @override
  Color get primaryColor => const Color(0xFFFFFFFF);

  @override
  Color get accentColor => const Color(0xFFFF5D97);

  @override
  Color get textColor => const Color(0xFFFFFFFF);

  @override
  Color get textSecondaryColor => const Color(0xB3FFFFFF);

  @override
  Color get borderColor => const Color(0x40FFFFFF);

  @override
  Color get iconColor => const Color(0xFFFFFFFF);

  @override
  Color get overlayColor => const Color(0x80000000);

  @override
  double get cornerRadius => 20.0;

  @override
  double get borderWidth => 1.0;

  @override
  BorderStyle get borderStyle => BorderStyle.solid;

  @override
  String get fontFamily => 'SF Pro Display';

  @override
  double get fontSizeSmall => 12.0;

  @override
  double get fontSizeMedium => 16.0;

  @override
  double get fontSizeLarge => 24.0;

  @override
  FontWeight get fontWeightNormal => FontWeight.w400;

  @override
  FontWeight get fontWeightBold => FontWeight.w600;

  @override
  BoxShadow? get boxShadow => BoxShadow(
    color: const Color(0x40000000),
    offset: const Offset(0, 8),
    blurRadius: 32,
    spreadRadius: 0,
  );

  @override
  double get blurRadius => 32.0;

  @override
  double get marginSmall => 8.0;

  @override
  double get marginMedium => 16.0;

  @override
  double get marginLarge => 24.0;

  @override
  double get paddingSmall => 16.0;

  @override
  double get paddingMedium => 24.0;

  @override
  double get paddingLarge => 32.0;

  @override
  double get borderRadius => 20.0;

  @override
  Color get cardColor => surfaceColor;

  @override
  List<BoxShadow> get cardShadows => [
    BoxShadow(
      color: const Color(0x40000000),
      offset: const Offset(0, 8),
      blurRadius: 32,
      spreadRadius: 0,
    ),
  ];

  @override
  BorderSide get borderSide => BorderSide(
    color: borderColor,
    width: borderWidth,
  );

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
    useMaterial3: true,
    colorScheme: ColorScheme.dark(
      background: backgroundColor,
      surface: surfaceColor,
      primary: primaryColor,
      secondary: accentColor,
      onBackground: textColor,
      onSurface: textColor,
      onPrimary: Colors.black,
      onSecondary: Colors.white,
    ),
    textTheme: TextTheme(
      bodySmall: TextStyle(
        fontSize: fontSizeSmall,
        fontWeight: fontWeightNormal,
        color: textColor,
      ),
      bodyMedium: TextStyle(
        fontSize: fontSizeMedium,
        fontWeight: fontWeightNormal,
        color: textColor,
      ),
      bodyLarge: TextStyle(
        fontSize: fontSizeLarge,
        fontWeight: fontWeightBold,
        color: textColor,
      ),
    ),
    cardTheme: CardThemeData(
      color: surfaceColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(cornerRadius),
        side: BorderSide(
          color: borderColor,
          width: borderWidth,
        ),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: surfaceColor,
        foregroundColor: textColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cornerRadius),
          side: BorderSide(
            color: borderColor,
            width: borderWidth,
          ),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: paddingMedium,
          vertical: paddingSmall,
        ),
      ),
    ),
  );
}
