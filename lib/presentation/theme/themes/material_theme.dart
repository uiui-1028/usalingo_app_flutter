import 'package:flutter/material.dart';
import '../app_theme.dart';

class MaterialTheme implements AppTheme {
  @override
  Color get background => const Color(0xFFF5F5F5);

  @override
  Color get surface => Colors.white;

  @override
  Color get primaryText => const Color(0xFF212121);

  @override
  Color get secondaryText => const Color(0xFF757575);

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
