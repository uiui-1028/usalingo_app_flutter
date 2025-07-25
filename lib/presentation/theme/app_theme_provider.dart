import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'themes/mockup_theme.dart';
import 'themes/flat_theme.dart';
import 'themes/material_theme.dart';
import 'themes/neumorphism_theme.dart';
import 'app_theme.dart';

enum AppThemeType { mockup, flat, material, neumorphism }

final appThemeTypeProvider = StateProvider<AppThemeType>(
  (ref) => AppThemeType.mockup,
);

final appThemeProvider = Provider<AppTheme>((ref) {
  final type = ref.watch(appThemeTypeProvider);
  switch (type) {
    case AppThemeType.flat:
      return FlatTheme();
    case AppThemeType.material:
      return MaterialTheme();
    case AppThemeType.neumorphism:
      return NeumorphismTheme();
    case AppThemeType.mockup:
    default:
      return MockupTheme();
  }
});
