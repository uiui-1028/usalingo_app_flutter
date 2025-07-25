import 'package:flutter/material.dart';
import '../app_theme.dart';

class NeumorphismTheme implements AppTheme {
  @override
  Color get background => const Color(0xFFE0E5EC);

  @override
  Color get surface => const Color(0xFFE0E5EC);

  @override
  Color get primaryText => const Color(0xFF5A6472);

  @override
  Color get secondaryText => const Color(0xFF8A94A6);

  @override
  Color get accent => const Color(0xFF4A7AFF);

  @override
  BorderRadius get cornerRadius => BorderRadius.circular(20.0);

  @override
  List<BoxShadow> get shadows => [
    const BoxShadow(
      color: Color.fromRGBO(255, 255, 255, 0.8),
      offset: Offset(-4, -4),
      blurRadius: 8,
    ),
    const BoxShadow(
      color: Color.fromRGBO(163, 177, 198, 0.6),
      offset: Offset(4, 4),
      blurRadius: 8,
    ),
  ];

  @override
  BorderSide get border =>
      const BorderSide(color: Colors.transparent, width: 0.0);
}
