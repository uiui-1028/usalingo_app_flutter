import 'package:flutter/material.dart';
import '../app_theme.dart';

/// Mockup theme for prototyping and development.
class MockupUsalingoTheme extends AppTheme {
  @override
  ThemeData get themeData => ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme.dark(
      background: Colors.black,
      surface: Color(0xFF1A1A1A),
      primary: Colors.blue,
      onPrimary: Colors.white,
      onBackground: Colors.white,
      onSurface: Colors.white,
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.white),
      bodyMedium: TextStyle(color: Colors.white),
      titleLarge: TextStyle(color: Colors.white),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      ),
    ),
  );

  @override
  Color get backgroundColor => Colors.black;

  @override
  Color get primaryColor => Colors.blue;

  @override
  Color get accentColor => Colors.blue;

  @override
  Color get textColor => Colors.white;

  @override
  Color get secondaryTextColor => const Color(0xFFB0B0B0);

  @override
  Color get surfaceColor => const Color(0xFF1A1A1A);

  @override
  Color get cardColor => const Color(0xFF1A1A1A);

  @override
  double get borderRadius => 8.0;

  @override
  double get borderWidth => 1.5;

  @override
  BorderStyle get borderStyle => BorderStyle.solid;

  @override
  List<BoxShadow> get cardShadows => [
    const BoxShadow(
      color: Color(0xFF333333),
      blurRadius: 4,
      offset: Offset(2, 2),
    ),
  ];

  @override
  BorderSide get borderSide =>
      const BorderSide(color: Color(0xFF333333), width: 1.5);

  @override
  TextStyle get primaryTextStyle =>
      const TextStyle(color: Colors.white, fontSize: 16.0);

  @override
  TextStyle get secondaryTextStyle =>
      const TextStyle(color: Color(0xFFB0B0B0), fontSize: 14.0);

  @override
  TextStyle get headingTextStyle => const TextStyle(
    color: Colors.white,
    fontSize: 24.0,
    fontWeight: FontWeight.bold,
  );
}
