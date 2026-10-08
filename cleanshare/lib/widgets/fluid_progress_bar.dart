import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/design_tokens.dart';

/// Wave-style progress bar — inspired by
/// [pksunny/flutter-ui-and-animations #26-fluid-progress-bar](https://github.com/pksunny/flutter-ui-and-animations/tree/main/lib/screens/26-fluid-progress-bar).
class FluidProgressBar extends StatefulWidget {
  const FluidProgressBar({
    super.key,
    this.progress,
    this.height = 8,
    this.color,
  });

  /// 0–1 fill. When null, runs an indeterminate wave.
  final double? progress;
  final double height;
  final Color? color;

  @override
  State<FluidProgressBar> createState() => _FluidProgressBarState();
}

class _FluidProgressBarState extends State<FluidProgressBar>
    with TickerProviderStateMixin {
  late final AnimationController _wave;
  late final AnimationController _fill;
  double _from = 0;
  double _to = 0;

  @override
  void initState() {
    super.initState();
    _to = widget.progress ?? 0;
    _wave = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _fill = AnimationController(
      vsync: this,
      duration: AppDurations.normal,
    )..value = _to;
    if (!_reduceMotion) _wave.repeat();
  }

  bool get _reduceMotion =>
      WidgetsBinding.instance.platformDispatcher.accessibilityFeatures
          .disableAnimations;

  @override
  void didUpdateWidget(covariant FluidProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.progress;
    if (next == null || next == oldWidget.progress) return;
    _from = _fill.value;
    _to = next.clamp(0.0, 1.0);
    _fill.forward(from: 0);
  }

  @override
  void dispose() {
    _wave.dispose();
    _fill.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    final track = color.withValues(alpha: 0.14);

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.height),
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: AnimatedBuilder(
          animation: Listenable.merge([_wave, _fill]),
          builder: (context, _) {
            final animatedProgress = widget.progress == null
                ? null
                : (_from + (_to - _from) * _fill.value).clamp(0.0, 1.0);
            return CustomPaint(
              painter: _FluidProgressPainter(
                progress: animatedProgress,
                wavePhase: _wave.value,
                color: color,
                trackColor: track,
                indeterminate: widget.progress == null,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FluidProgressPainter extends CustomPainter {
  _FluidProgressPainter({
    required this.progress,
    required this.wavePhase,
    required this.color,
    required this.trackColor,
    required this.indeterminate,
  });

  final double? progress;
  final double wavePhase;
  final Color color;
  final Color trackColor;
  final bool indeterminate;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(size.height / 2)),
      Paint()..color = trackColor,
    );

    final fillWidth = indeterminate
        ? size.width * (0.35 + 0.1 * math.sin(wavePhase * math.pi * 2))
        : size.width * (progress ?? 0).clamp(0.0, 1.0);

    if (fillWidth <= 0) return;

    final shift = indeterminate
        ? (size.width + fillWidth) * wavePhase - fillWidth
        : 0.0;

    final fillRect = Rect.fromLTWH(shift, 0, fillWidth, size.height);
    final gradient = LinearGradient(
      colors: [
        color.withValues(alpha: 0.55),
        color,
        color.withValues(alpha: 0.75),
      ],
      stops: [
        (wavePhase * 0.4).clamp(0.0, 0.35),
        (0.35 + wavePhase * 0.3).clamp(0.2, 0.8),
        1,
      ],
    );

    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(size.height / 2)),
    );
    canvas.drawRect(
      fillRect,
      Paint()..shader = gradient.createShader(fillRect),
    );

    final glossX = fillRect.left + fillRect.width * (0.25 + wavePhase * 0.5);
    canvas.drawCircle(
      Offset(glossX, size.height / 2),
      size.height * 0.9,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FluidProgressPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.wavePhase != wavePhase ||
      oldDelegate.indeterminate != indeterminate;
}
