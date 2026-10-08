import 'package:flutter/material.dart';

import '../core/animation/app_motion.dart';

/// Animates an integer stat from zero to [target] on first paint.
class CountUpText extends StatefulWidget {
  const CountUpText({
    super.key,
    required this.target,
    required this.style,
    this.duration = const Duration(milliseconds: 900),
  });

  final int target;
  final TextStyle? style;
  final Duration duration;

  @override
  State<CountUpText> createState() => _CountUpTextState();
}

class _CountUpTextState extends State<CountUpText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = CurvedAnimation(
      parent: _controller,
      curve: AppMotion.defaultCurve,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(CountUpText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.target != widget.target) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _format(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final value = (widget.target * _animation.value).round();
        return Text(
          _format(value),
          style: widget.style,
        );
      },
    );
  }
}
