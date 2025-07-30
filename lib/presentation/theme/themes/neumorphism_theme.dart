import 'package:flutter/material.dart';
import '../app_theme.dart';

class NeumorphismTheme implements AppTheme {
  @override
  Color get background => Colors.black;

  @override
  Color get surface => const Color(0xFF1A1A1A);

  @override
  Color get primaryText => Colors.white;

  @override
  Color get secondaryText => const Color(0xFFB0B0B0);

  @override
  Color get accent => const Color(0xFF4A7AFF);

  @override
  BorderRadius get cornerRadius => BorderRadius.circular(20.0);

  @override
  List<BoxShadow> get shadows => [
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
  BorderSide get border =>
      const BorderSide(color: Colors.transparent, width: 0.0);
}
