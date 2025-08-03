import 'package:flutter/material.dart';
import '../app_theme.dart';

/// Wireframe theme for development foundation.
/// All color properties are set to black and white,
/// shadows are empty list, and border radius is 0.0.
class WireframeUsalingoTheme extends AppTheme {
  @override
  ThemeData get themeData => ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme.light(
      background: Colors.white,
      surface: Colors.white,
      primary: Colors.black,
      onPrimary: Colors.white,
      onBackground: Colors.black,
      onSurface: Colors.black,
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.black),
      bodyMedium: TextStyle(color: Colors.black),
      titleLarge: TextStyle(color: Colors.black),
    ),
  );

  @override
  Color get backgroundColor => Colors.white;

  @override
  Color get primaryColor => Colors.black;

  @override
  Color get accentColor => Colors.black;

  @override
  Color get textColor => Colors.black;

  @override
  Color get secondaryTextColor => Colors.black;

  @override
  Color get surfaceColor => Colors.white;

  @override
  Color get cardColor => Colors.white;

  @override
  double get borderRadius => 0.0;

  @override
  double get borderWidth => 1.0;

  @override
  BorderStyle get borderStyle => BorderStyle.solid;

  @override
  List<BoxShadow> get cardShadows => [];

  @override
  BorderSide get borderSide =>
      const BorderSide(color: Colors.black, width: 1.0);

  @override
  TextStyle get primaryTextStyle =>
      const TextStyle(color: Colors.black, fontSize: 16.0);

  @override
  TextStyle get secondaryTextStyle =>
      const TextStyle(color: Colors.black, fontSize: 14.0);

  @override
  TextStyle get headingTextStyle => const TextStyle(
    color: Colors.black,
    fontSize: 24.0,
    fontWeight: FontWeight.bold,
  );
}
