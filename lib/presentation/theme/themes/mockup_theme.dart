import 'package:flutter/material.dart';
import '../app_theme.dart';

class MockupTheme implements AppTheme {
  @override
  Color get background => Colors.grey[200]!;

  @override
  Color get surface => Colors.white;

  @override
  Color get primaryText => Colors.black87;

  @override
  Color get secondaryText => Colors.black54;

  @override
  Color get accent => Colors.blue;

  @override
  BorderRadius get cornerRadius => BorderRadius.circular(8.0);

  @override
  List<BoxShadow> get shadows => [
    BoxShadow(
      color: Colors.grey[400]!,
      blurRadius: 4,
      offset: const Offset(2, 2),
    ),
  ];

  @override
  BorderSide get border => BorderSide(color: Colors.grey[400]!, width: 1.5);
}
