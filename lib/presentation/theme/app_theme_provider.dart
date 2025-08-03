import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'themes/wireframe_theme.dart';
import 'themes/mockup_theme.dart';
import 'themes/flat_theme.dart';
import 'themes/material_theme.dart';
import 'themes/neumorphism_theme.dart';
import 'themes/pixel_art_theme.dart';
import 'app_theme.dart';

/// Available theme types for the Usalingo app
enum AppThemeType {
  wireframe, // Development foundation theme
  mockup, // Prototyping theme
  flat, // Flat design theme
  material, // Material Design theme
  neumorphism, // Neumorphic design theme
  pixelArt, // Pixel art theme
}

/// Provider for the current theme type selection
final appThemeTypeProvider = StateProvider<AppThemeType>(
  (ref) => AppThemeType.wireframe, // Default to wireframe for development
);

/// Provider that returns the current AppTheme instance based on the selected theme type
final appThemeProvider = Provider<AppTheme>((ref) {
  final type = ref.watch(appThemeTypeProvider);
  switch (type) {
    case AppThemeType.wireframe:
      return WireframeUsalingoTheme();
    case AppThemeType.mockup:
      return MockupUsalingoTheme();
    case AppThemeType.flat:
      return FlatUsalingoTheme();
    case AppThemeType.material:
      return MaterialUsalingoTheme();
    case AppThemeType.neumorphism:
      return NeumorphicUsalingoTheme();
    case AppThemeType.pixelArt:
      return PixelArtUsalingoTheme();
  }
});

/// Provider that returns the Flutter ThemeData for the current theme
final themeDataProvider = Provider<ThemeData>((ref) {
  final theme = ref.watch(appThemeProvider);
  return theme.themeData;
});
