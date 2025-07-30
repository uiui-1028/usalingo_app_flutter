import 'package:flutter/material.dart';
import '../app_theme.dart';

class FlatTheme implements AppTheme {
  @override
  Color get background => Colors.black;

  @override
  Color get surface => const Color(0xFF1A1A1A);

  @override
  Color get primaryText => Colors.white;

  @override
  Color get secondaryText => const Color(0xFFB0B0B0);

  @override
  Color get accent => const Color(0xFF2196F3);

  @override
  BorderRadius get cornerRadius => BorderRadius.circular(12.0);

  @override
  List<BoxShadow> get shadows => [];

  @override
  BorderSide get border =>
      BorderSide(color: const Color(0xFFE0E0E0), width: 1.0);
}
