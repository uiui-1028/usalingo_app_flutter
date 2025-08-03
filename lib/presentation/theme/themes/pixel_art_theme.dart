import 'package:flutter/material.dart';
import '../app_theme.dart';

/// Pixel art theme with retro gaming aesthetics.
/// Features sharp corners and pixelated appearance.
class PixelArtUsalingoTheme extends AppTheme {
  @override
  ThemeData get themeData => ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme.light(
      background: Color(0xFF2C3E50),
      surface: Color(0xFF34495E),
      primary: Color(0xFFE74C3C),
      onPrimary: Colors.white,
      onBackground: Colors.white,
      onSurface: Colors.white,
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.white, fontFamily: 'Courier'),
      bodyMedium: TextStyle(color: Colors.white, fontFamily: 'Courier'),
      titleLarge: TextStyle(
        color: Colors.white,
        fontFamily: 'Courier',
        fontWeight: FontWeight.bold,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFE74C3C),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0.0)),
        elevation: 0,
      ),
    ),
  );

  @override
  Color get backgroundColor => const Color(0xFF2C3E50);

  @override
  Color get primaryColor => const Color(0xFFE74C3C);

  @override
  Color get accentColor => const Color(0xFFF39C12);

  @override
  Color get textColor => Colors.white;

  @override
  Color get secondaryTextColor => const Color(0xFFBDC3C7);

  @override
  Color get surfaceColor => const Color(0xFF34495E);

  @override
  Color get cardColor => const Color(0xFF34495E);

  @override
  double get borderRadius => 0.0;

  @override
  double get borderWidth => 2.0;

  @override
  BorderStyle get borderStyle => BorderStyle.solid;

  @override
  List<BoxShadow> get cardShadows => [
    const BoxShadow(
      color: Color(0xFF1A1A1A),
      offset: Offset(4, 4),
      blurRadius: 0,
    ),
  ];

  @override
  BorderSide get borderSide =>
      const BorderSide(color: Color(0xFFE74C3C), width: 2.0);

  @override
  TextStyle get primaryTextStyle => const TextStyle(
    color: Colors.white,
    fontSize: 16.0,
    fontFamily: 'Courier',
  );

  @override
  TextStyle get secondaryTextStyle => const TextStyle(
    color: Color(0xFFBDC3C7),
    fontSize: 14.0,
    fontFamily: 'Courier',
  );

  @override
  TextStyle get headingTextStyle => const TextStyle(
    color: Colors.white,
    fontSize: 24.0,
    fontWeight: FontWeight.bold,
    fontFamily: 'Courier',
  );
}
