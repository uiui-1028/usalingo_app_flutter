import 'package:flutter/material.dart';

/// Defines the design rules for the app theme.
abstract class AppTheme {
  // --- Colors ---
  Color get background; // Background color for the entire app
  Color get surface; // Surface color for cards, etc.
  Color get primaryText; // Main text color
  Color get secondaryText; // Secondary text color
  Color get accent; // Accent color

  // --- Shapes ---
  BorderRadius get cornerRadius; // Corner radius for shapes

  // --- Shadows ---
  List<BoxShadow> get shadows; // Shadows for containers

  // --- Borders ---
  BorderSide get border; // Border style
}
