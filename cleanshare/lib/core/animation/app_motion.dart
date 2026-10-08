import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// Shared motion tokens — iOS-like ease curves and stagger delays.
abstract final class AppMotion {
  static const defaultCurve = Curves.easeOutCubic;
  /// Overshoots past 1.0 — safe for scale/slide only, never wire to opacity.
  static const spring = Curves.easeOutBack;
  static const staggerStep = Duration(milliseconds: 50);
  static const pageTransition = Duration(milliseconds: 260);
  static const sheetTransition = Duration(milliseconds: 280);

  static Duration staggerDelay(int index, {int maxMs = 400}) {
    final ms = (index * staggerStep.inMilliseconds).clamp(0, maxMs);
    return Duration(milliseconds: ms);
  }

  static Animation<double> fadeIn(
    Animation<double> parent, {
    double begin = 0,
    double end = 1,
    Curve curve = defaultCurve,
  }) {
    return CurvedAnimation(parent: parent, curve: curve).drive(
      Tween(begin: begin, end: end),
    );
  }

  static Animation<Offset> slideUp(
    Animation<double> parent, {
    double offset = 0.08,
    Curve curve = defaultCurve,
  }) {
    return CurvedAnimation(parent: parent, curve: curve).drive(
      Tween<Offset>(
        begin: Offset(0, offset),
        end: Offset.zero,
      ),
    );
  }
}

/// Fade + slide reveal for list items and sections.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.delay = Duration.zero,
  });

  final Widget child;
  final int index;
  final Duration delay;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  static const _maxAnimatedIndex = 2;
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppDurations.slow,
    );
    _fade = AppMotion.fadeIn(_controller);
    _slide = AppMotion.slideUp(_controller);
    final reduceMotion = WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations;
    final shouldAnimate = !reduceMotion && widget.index <= _maxAnimatedIndex;
    if (!shouldAnimate) {
      _controller.value = 1;
      return;
    }
    Future<void>.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

/// Slide-up + fade text reveal.
/// Inspired by [pksunny/flutter-ui-and-animations #74-slide-up-text-animation](https://github.com/pksunny/flutter-ui-and-animations/tree/main/lib/screens/74-slide-up-text-animation).
class SlideUpReveal extends StatefulWidget {
  const SlideUpReveal({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.slideOffset = 0.14,
    this.duration = AppDurations.slow,
    this.curve = AppMotion.spring,
  });

  final Widget child;
  final Duration delay;
  final double slideOffset;
  final Duration duration;
  final Curve curve;

  @override
  State<SlideUpReveal> createState() => _SlideUpRevealState();
}

class _SlideUpRevealState extends State<SlideUpReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _fade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: AppMotion.defaultCurve),
    );
    _slide = Tween<Offset>(
      begin: Offset(0, widget.slideOffset),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));

    if (WidgetsBinding.instance.platformDispatcher.accessibilityFeatures
        .disableAnimations) {
      _controller.value = 1;
      return;
    }
    Future<void>.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

/// Pop-up scale + fade for secondary lines.
/// Inspired by [pksunny/flutter-ui-and-animations #106-pop-up-text-animation](https://github.com/pksunny/flutter-ui-and-animations/tree/main/lib/screens/106-pop-up-text-animation).
class PopUpReveal extends StatefulWidget {
  const PopUpReveal({
    super.key,
    required this.child,
    this.delay = const Duration(milliseconds: 140),
    this.duration = AppDurations.normal,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;

  @override
  State<PopUpReveal> createState() => _PopUpRevealState();
}

class _PopUpRevealState extends State<PopUpReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _fade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: AppMotion.defaultCurve),
    );
    _scale = Tween<double>(begin: 0.92, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: AppMotion.spring),
    );

    if (WidgetsBinding.instance.platformDispatcher.accessibilityFeatures
        .disableAnimations) {
      _controller.value = 1;
      return;
    }
    Future<void>.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}

/// iOS-like press scale feedback.
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    required this.onPressed,
    this.scale = 0.97,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final double scale;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onPressed != null ? (_) => setState(() => _pressed = true) : null,
      onTapUp: widget.onPressed != null ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onPressed == null
          ? null
          : () {
              HapticFeedback.lightImpact();
              widget.onPressed!();
            },
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1,
        duration: AppDurations.fast,
        curve: _pressed ? Curves.easeInCubic : AppMotion.spring,
        child: widget.child,
      ),
    );
  }
}

/// Soft lift + scale on press — inspired by
/// [pksunny/flutter-ui-and-animations #173-soft-card-tap](https://github.com/pksunny/flutter-ui-and-animations/tree/main/lib/screens/173-soft-card-tap).
class SoftPress extends StatefulWidget {
  const SoftPress({
    super.key,
    required this.child,
    this.onPressed,
    this.pressedScale = 0.985,
    this.lift = 4,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final double pressedScale;
  final double lift;

  @override
  State<SoftPress> createState() => _SoftPressState();
}

class _SoftPressState extends State<SoftPress> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      onTap: enabled
          ? () {
              HapticFeedback.selectionClick();
              widget.onPressed!();
            }
          : null,
      child: AnimatedScale(
        scale: _pressed && !reduceMotion ? widget.pressedScale : 1,
        duration: AppDurations.fast,
        curve: _pressed ? Curves.easeInCubic : AppMotion.spring,
        child: AnimatedContainer(
          duration: AppDurations.fast,
          curve: AppMotion.defaultCurve,
          transform: Matrix4.translationValues(
            0,
            _pressed && !reduceMotion ? widget.lift / 2 : 0,
            0,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Cross-fades skeleton placeholders into loaded content.
/// Inspired by [pksunny/flutter-ui-and-animations #142-smart-loading-swap](https://github.com/pksunny/flutter-ui-and-animations/tree/main/lib/screens/142-smart-loading-swap).
class ContentRevealSwap extends StatelessWidget {
  const ContentRevealSwap({
    super.key,
    required this.showPlaceholder,
    required this.placeholder,
    required this.content,
    this.duration = AppDurations.slow,
  });

  final bool showPlaceholder;
  final Widget placeholder;
  final Widget content;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return showPlaceholder ? placeholder : content;
    }

    return AnimatedSwitcher(
      duration: duration,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final fade = CurvedAnimation(
          parent: animation,
          curve: AppMotion.defaultCurve,
        );
        final slide = CurvedAnimation(
          parent: animation,
          curve: AppMotion.spring,
        );
        return FadeTransition(
          opacity: fade,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.035),
              end: Offset.zero,
            ).animate(slide),
            child: child,
          ),
        );
      },
      child: showPlaceholder
          ? KeyedSubtree(key: const ValueKey('placeholder'), child: placeholder)
          : KeyedSubtree(key: const ValueKey('content'), child: content),
    );
  }
}

/// Flips status copy upward when the message changes.
/// Inspired by [pksunny/flutter-ui-and-animations #43-text-flip-animation](https://github.com/pksunny/flutter-ui-and-animations/tree/main/lib/screens/43-text-flip-animation).
class TextFlipReveal extends StatelessWidget {
  const TextFlipReveal({
    super.key,
    required this.text,
    this.style,
    this.textAlign,
    this.duration = AppDurations.normal,
  });

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final child = Text(
      text,
      key: ValueKey<String>(text),
      style: style,
      textAlign: textAlign,
    );

    if (MediaQuery.disableAnimationsOf(context)) return child;

    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: AppMotion.defaultCurve,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: AppMotion.defaultCurve,
        );
        return ClipRect(
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.35),
              end: Offset.zero,
            ).animate(curved),
            child: FadeTransition(opacity: curved, child: child),
          ),
        );
      },
      child: child,
    );
  }
}

/// Drawn checkmark with ring reveal — inspired by
/// [pksunny/flutter-ui-and-animations #102-animated-check-marks](https://github.com/pksunny/flutter-ui-and-animations/tree/main/lib/screens/102-animated-check-marks).
class AnimatedSuccessCheck extends StatefulWidget {
  const AnimatedSuccessCheck({
    super.key,
    this.size = 72,
    this.color,
    this.ringColor,
  });

  final double size;
  final Color? color;
  final Color? ringColor;

  @override
  State<AnimatedSuccessCheck> createState() => _AnimatedSuccessCheckState();
}

class _AnimatedSuccessCheckState extends State<AnimatedSuccessCheck>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    );
    if (WidgetsBinding.instance.platformDispatcher.accessibilityFeatures
        .disableAnimations) {
      _controller.value = 1;
      return;
    }
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = widget.color ?? colorScheme.secondary;
    final ring = widget.ringColor ?? colorScheme.outline.withValues(alpha: 0.35);

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _SuccessCheckPainter(
              progress: _controller.value,
              color: color,
              ringColor: ring,
              surfaceColor: colorScheme.onSurface.withValues(alpha: 0.06),
            ),
          );
        },
      ),
    );
  }
}

class _SuccessCheckPainter extends CustomPainter {
  _SuccessCheckPainter({
    required this.progress,
    required this.color,
    required this.ringColor,
    required this.surfaceColor,
  });

  final double progress;
  final Color color;
  final Color ringColor;
  final Color surfaceColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 3;

    final fillT = (progress * 1.4).clamp(0.0, 1.0);
    if (fillT > 0) {
      canvas.drawCircle(
        center,
        radius * (0.85 + 0.15 * fillT),
        Paint()..color = surfaceColor.withValues(alpha: 0.06 * fillT),
      );
    }

    final ringPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius, ringPaint);

    final ringProgress = (progress * 1.2).clamp(0.0, 1.0);
    if (ringProgress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -1.2,
        6.4 * ringProgress,
        false,
        Paint()
          ..color = color.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );
    }

    final checkT = ((progress - 0.28) / 0.72).clamp(0.0, 1.0);
    if (checkT <= 0) return;

    final path = Path()
      ..moveTo(size.width * 0.28, size.height * 0.54)
      ..lineTo(size.width * 0.44, size.height * 0.7)
      ..lineTo(size.width * 0.74, size.height * 0.36);

    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * checkT),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _SuccessCheckPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.ringColor != ringColor;
}
