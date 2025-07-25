import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class LottieFeedbackWidget extends StatelessWidget {
  final String assetPath;
  const LottieFeedbackWidget({super.key, required this.assetPath});

  @override
  Widget build(BuildContext context) {
    return Center(child: Lottie.asset(assetPath, repeat: false));
  }
}
