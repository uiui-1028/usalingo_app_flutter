import 'package:flutter/material.dart';
import '../app_theme.dart';

class MockupTheme implements AppTheme {
  @override
  Color get background => Colors.black;

  @override
  Color get surface => const Color(0xFF1A1A1A);

  @override
  Color get primaryText => Colors.white;

  @override
  Color get secondaryText => const Color(0xFFB0B0B0);

  @override
  Color get accent => Colors.blue;

  @override
  BorderRadius get cornerRadius => BorderRadius.circular(8.0);

  @override
  List<BoxShadow> get shadows => [
    const BoxShadow(
      color: Color(0xFF333333),
      blurRadius: 4,
      offset: Offset(2, 2),
    ),
  ];

  @override
  BorderSide get border => const BorderSide(color: Color(0xFF333333), width: 1.5);
}
