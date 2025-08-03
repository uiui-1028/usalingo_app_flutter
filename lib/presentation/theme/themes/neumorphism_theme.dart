import 'package:flutter/material.dart';
import '../app_theme.dart';

/// Neumorphic theme that implements the neumorphism design style.
/// Features soft shadows and off-white background color.
class NeumorphicUsalingoTheme extends AppTheme {
  @override
  ThemeData get themeData => ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme.light(
      background: Color(0xFFE0E5EC),
      surface: Color(0xFFE0E5EC),
      primary: Color(0xFF4A7AFF),
      onPrimary: Colors.white,
      onBackground: Color(0xFF2D3748),
      onSurface: Color(0xFF2D3748),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Color(0xFF2D3748)),
      bodyMedium: TextStyle(color: Color(0xFF2D3748)),
      titleLarge: TextStyle(color: Color(0xFF2D3748)),
    ),
  );

  @override
  Color get backgroundColor => const Color(0xFFE0E5EC);

  @override
  Color get primaryColor => const Color(0xFF4A7AFF);

  @override
  Color get accentColor => const Color(0xFF4A7AFF);

  @override
  Color get textColor => const Color(0xFF2D3748);

  @override
  Color get secondaryTextColor => const Color(0xFF718096);

  @override
  Color get surfaceColor => const Color(0xFFE0E5EC);

  @override
  Color get cardColor => const Color(0xFFE0E5EC);

  @override
  double get borderRadius => 20.0;

  @override
  double get borderWidth => 0.0;

  @override
  BorderStyle get borderStyle => BorderStyle.none;

  @override
  List<BoxShadow> get cardShadows => [
    const BoxShadow(
      color: Color.fromRGBO(40, 40, 40, 0.8),
      offset: Offset(-4, -4),
      blurRadius: 8,
    ),
    const BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.6),
      offset: Offset(4, 4),
      blurRadius: 8,
    ),
  ];

  @override
  BorderSide get borderSide =>
      const BorderSide(color: Colors.transparent, width: 0.0);

  @override
  TextStyle get primaryTextStyle =>
      const TextStyle(color: Color(0xFF2D3748), fontSize: 16.0);

  @override
  TextStyle get secondaryTextStyle =>
      const TextStyle(color: Color(0xFF718096), fontSize: 14.0);

  @override
  TextStyle get headingTextStyle => const TextStyle(
    color: Color(0xFF2D3748),
    fontSize: 24.0,
    fontWeight: FontWeight.bold,
  );
}
