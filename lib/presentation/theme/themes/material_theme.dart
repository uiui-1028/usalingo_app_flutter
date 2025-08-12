import 'package:flutter/material.dart';
import '../app_theme.dart';

// マテリアルテーマの実装
class MaterialTheme implements AppTheme {
  @override
  Color get backgroundColor => const Color(0xFFFFFFFF);

  @override
  Color get surfaceColor => const Color(0xFFFFFFFF);

  @override
  Color get primaryColor => const Color(0xFF2196F3);

  @override
  Color get accentColor => const Color(0xFFFF5D97);

  @override
  Color get textColor => const Color(0xFF212121);

  @override
  Color get textSecondaryColor => const Color(0xFF757575);

  @override
  Color get borderColor => const Color(0xFFE0E0E0);

  @override
  Color get iconColor => const Color(0xFF757575);

  @override
  Color get overlayColor => const Color(0x52000000);

  @override
  double get cornerRadius => 8.0;

  @override
  double get borderWidth => 1.0;

  @override
  BorderStyle get borderStyle => BorderStyle.solid;

  @override
  String get fontFamily => 'Roboto';

  @override
  double get fontSizeSmall => 12.0;

  @override
  double get fontSizeMedium => 16.0;

  @override
  double get fontSizeLarge => 24.0;

  @override
  FontWeight get fontWeightNormal => FontWeight.w400;

  @override
  FontWeight get fontWeightBold => FontWeight.w500;

  @override
  BoxShadow? get boxShadow => BoxShadow(
    color: const Color(0x1F000000),
    offset: const Offset(0, 2),
    blurRadius: 4,
    spreadRadius: 0,
  );

  @override
  double get blurRadius => 4.0;

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
  double get borderRadius => 8.0;

  @override
  Color get cardColor => surfaceColor;

  @override
  List<BoxShadow> get cardShadows => [
    BoxShadow(
      color: const Color(0x1F000000),
      offset: const Offset(0, 2),
      blurRadius: 4,
      spreadRadius: 0,
    ),
  ];

  @override
  BorderSide get borderSide => BorderSide(color: borderColor, width: borderWidth);

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
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(cornerRadius),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
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
