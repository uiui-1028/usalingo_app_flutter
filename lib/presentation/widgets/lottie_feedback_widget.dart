import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

// Lottieフィードバックウィジェット
class LottieFeedbackWidget extends StatefulWidget {
  final String assetPath;
  final double? width;
  final double? height;
  final VoidCallback? onComplete;
  final bool autoPlay;
  final bool loop;

  const LottieFeedbackWidget({
    super.key,
    required this.assetPath,
    this.width,
    this.height,
    this.onComplete,
    this.autoPlay = true,
    this.loop = false,
  });

  @override
  State<LottieFeedbackWidget> createState() => _LottieFeedbackWidgetState();
}

class _LottieFeedbackWidgetState extends State<LottieFeedbackWidget>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    if (widget.autoPlay) {
      _playAnimation();
    }

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (widget.onComplete != null) {
          widget.onComplete!();
        }
        if (!widget.loop) {
          setState(() {
            _isPlaying = false;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _playAnimation() {
    setState(() {
      _isPlaying = true;
    });
    if (widget.loop) {
      _controller.repeat();
    } else {
      _controller.forward();
    }
  }

  void _stopAnimation() {
    _controller.stop();
    setState(() {
      _isPlaying = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _isPlaying ? _stopAnimation : _playAnimation,
      child: Container(
        width: widget.width ?? 200,
        height: widget.height ?? 200,
        child: Lottie.asset(
          widget.assetPath,
          controller: _controller,
          onLoaded: (composition) {
            _controller.duration = composition.duration;
          },
        ),
      ),
    );
  }
}

// 学習完了時のLottieフィードバックウィジェット
class LearningCompletionLottieWidget extends StatelessWidget {
  final VoidCallback? onComplete;

  const LearningCompletionLottieWidget({
    super.key,
    this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    return LottieFeedbackWidget(
      assetPath: 'assets/test_lottie/Feather (2).json',
      width: 300,
      height: 300,
      onComplete: onComplete,
      autoPlay: true,
      loop: false,
    );
  }
}

// 正解時のLottieフィードバックウィジェット
class CorrectAnswerLottieWidget extends StatelessWidget {
  final VoidCallback? onComplete;

  const CorrectAnswerLottieWidget({
    super.key,
    this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    return LottieFeedbackWidget(
      assetPath: 'assets/test_lottie/celebration.json',
      width: 200,
      height: 200,
      onComplete: onComplete,
      autoPlay: true,
      loop: false,
    );
  }
}

// 不正解時のLottieフィードバックウィジェット
class IncorrectAnswerLottieWidget extends StatelessWidget {
  final VoidCallback? onComplete;

  const IncorrectAnswerLottieWidget({
    super.key,
    this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    return LottieFeedbackWidget(
      assetPath: 'assets/test_lottie/caution.json',
      width: 200,
      height: 200,
      onComplete: onComplete,
      autoPlay: true,
      loop: false,
    );
  }
}
