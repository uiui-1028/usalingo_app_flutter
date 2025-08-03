import 'package:flutter/material.dart';
import '../app_theme.dart';

/// Material Design theme that follows Google's Material Design guidelines.
class MaterialUsalingoTheme extends AppTheme {
  @override
  ThemeData get themeData => ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme.light(
      background: Colors.white,
      surface: Colors.white,
      primary: Color(0xFF6200EE),
      onPrimary: Colors.white,
      onBackground: Colors.black,
      onSurface: Colors.black,
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.black),
      bodyMedium: TextStyle(color: Colors.black),
      titleLarge: TextStyle(color: Colors.black),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF6200EE),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.0)),
      ),
    ),
  );

  @override
  Color get backgroundColor => Colors.white;

  @override
  Color get primaryColor => const Color(0xFF6200EE);

  @override
  Color get accentColor => const Color(0xFF6200EE);

  @override
  Color get textColor => Colors.black;

  @override
  Color get secondaryTextColor => const Color(0xFF666666);

  @override
  Color get surfaceColor => Colors.white;

  @override
  Color get cardColor => Colors.white;

  @override
  double get borderRadius => 4.0;

  @override
  double get borderWidth => 1.0;

  @override
  BorderStyle get borderStyle => BorderStyle.solid;

  @override
  List<BoxShadow> get cardShadows => [
    const BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.2),
      offset: Offset(0, 3),
      blurRadius: 6,
    ),
  ];

  @override
  BorderSide get borderSide =>
      const BorderSide(color: Color(0xFFE0E0E0), width: 1.0);

  @override
  TextStyle get primaryTextStyle =>
      const TextStyle(color: Colors.black, fontSize: 16.0);

  @override
  TextStyle get secondaryTextStyle =>
      const TextStyle(color: Color(0xFF666666), fontSize: 14.0);

  @override
  TextStyle get headingTextStyle => const TextStyle(
    color: Colors.black,
    fontSize: 24.0,
    fontWeight: FontWeight.bold,
  );
}
