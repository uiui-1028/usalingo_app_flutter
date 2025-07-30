import 'package:flutter/material.dart';
import '../app_theme.dart';

class MaterialTheme implements AppTheme {
  @override
  Color get background => Colors.black;

  @override
  Color get surface => const Color(0xFF1A1A1A);

  @override
  Color get primaryText => Colors.white;

  @override
  Color get secondaryText => const Color(0xFFB0B0B0);

  @override
  Color get accent => const Color(0xFF6200EE);

  @override
  BorderRadius get cornerRadius => BorderRadius.circular(4.0);

  @override
  List<BoxShadow> get shadows => [
    const BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.2),
      offset: Offset(0, 3),
      blurRadius: 6,
    ),
  ];

  @override
  BorderSide get border =>
      const BorderSide(color: Color(0xFFE0E0E0), width: 1.0);
}
