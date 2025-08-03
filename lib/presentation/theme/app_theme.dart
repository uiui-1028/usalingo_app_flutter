import 'package:flutter/material.dart';

/// Defines the design contract for all themes in the Usalingo app.
/// This abstract class serves as a contract that all design themes must implement.
abstract class AppTheme {
  // --- Flutter Integration ---
  /// Returns the Flutter ThemeData object for this theme
  ThemeData get themeData;

  // --- Colors ---
  /// Background color for the entire app
  Color get backgroundColor;

  /// Primary color for main UI elements
  Color get primaryColor;

  /// Accent color for highlights and interactive elements
  Color get accentColor;

  /// Main text color
  Color get textColor;

  /// Secondary text color
  Color get secondaryTextColor;

  /// Surface color for cards and containers
  Color get surfaceColor;

  /// Card background color
  Color get cardColor;

  // --- Shapes ---
  /// Border radius for rounded corners
  double get borderRadius;

  /// Border width for elements
  double get borderWidth;

  /// Border style for elements
  BorderStyle get borderStyle;

  // --- Effects ---
  /// Shadows for cards and containers
  List<BoxShadow> get cardShadows;

  /// Border side for elements
  BorderSide get borderSide;

  // --- Typography ---
  /// Primary text style
  TextStyle get primaryTextStyle;

  /// Secondary text style
  TextStyle get secondaryTextStyle;

  /// Heading text style
  TextStyle get headingTextStyle;
}
