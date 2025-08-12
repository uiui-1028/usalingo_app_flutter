import 'package:flutter/material.dart';
import '../app_theme.dart';

// ニューモーフィズムテーマの実装
class NeumorphismTheme implements AppTheme {
  @override
  Color get backgroundColor => const Color(0xFFE0E5EC);

  @override
  Color get surfaceColor => const Color(0xFFE0E5EC);

  @override
  Color get primaryColor => const Color(0xFF2D3748);

  @override
  Color get accentColor => const Color(0xFFFF5D97);

  @override
  Color get textColor => const Color(0xFF2D3748);

  @override
  Color get textSecondaryColor => const Color(0xFF718096);

  @override
  Color get borderColor => const Color(0xFFE0E5EC);

  @override
  Color get iconColor => const Color(0xFF718096);

  @override
  Color get overlayColor => const Color(0x66000000);

  @override
  double get cornerRadius => 16.0;

  @override
  double get borderWidth => 0.0;

  @override
  BorderStyle get borderStyle => BorderStyle.none;

  @override
  String get fontFamily => 'Inter';

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
    color: const Color(0xFF9CA3AF),
    offset: const Offset(8, 8),
    blurRadius: 16,
    spreadRadius: 0,
  );

  @override
  double get blurRadius => 16.0;

  @override
  double get marginSmall => 8.0;

  @override
  double get marginMedium => 16.0;

  @override
  double get marginLarge => 24.0;

  @override
  double get paddingSmall => 12.0;

  @override
  double get paddingMedium => 20.0;

  @override
  double get paddingLarge => 32.0;

  @override
  double get borderRadius => 16.0;

  @override
  Color get cardColor => surfaceColor;

  @override
  List<BoxShadow> get cardShadows => [
    BoxShadow(
      color: const Color(0xFF9CA3AF),
      offset: const Offset(8, 8),
      blurRadius: 16,
      spreadRadius: 0,
    ),
    BoxShadow(
      color: Colors.white,
      offset: const Offset(-8, -8),
      blurRadius: 16,
      spreadRadius: 0,
    ),
  ];

  @override
  BorderSide get borderSide => BorderSide.none;

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
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: surfaceColor,
        foregroundColor: textColor,
        elevation: 0,
        shadowColor: const Color(0xFF9CA3AF),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cornerRadius),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: paddingMedium,
          vertical: paddingSmall,
        ),
      ),
    ),
  );
}
