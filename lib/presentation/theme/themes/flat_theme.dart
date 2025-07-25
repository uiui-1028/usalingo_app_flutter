import 'package:flutter/material.dart';
import '../app_theme.dart';

class FlatTheme implements AppTheme {
  @override
  Color get background => const Color(0xFFF7F7F7);

  @override
  Color get surface => Colors.white;

  @override
  Color get primaryText => const Color(0xFF222222);

  @override
  Color get secondaryText => const Color(0xFF888888);

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
