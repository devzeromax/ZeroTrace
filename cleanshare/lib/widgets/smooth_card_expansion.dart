import 'package:flutter/material.dart';

import '../core/animation/app_motion.dart';

/// Height + fade expansion for accordion panels — inspired by
/// [pksunny/flutter-ui-and-animations #78-smooth-card-expansion](https://github.com/pksunny/flutter-ui-and-animations/tree/main/lib/screens/78-smooth-card-expansion).
class SmoothCardExpansion extends StatefulWidget {
  const SmoothCardExpansion({
    super.key,
    required this.expanded,
    required this.child,
    this.duration = const Duration(milliseconds: 420),
  });

  final bool expanded;
  final Widget child;
  final Duration duration;

  @override
  State<SmoothCardExpansion> createState() => _SmoothCardExpansionState();
}

class _SmoothCardExpansionState extends State<SmoothCardExpansion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _reveal;

  @override
  void initState() {
    super.initState();
    _reveal = AnimationController(vsync: this, duration: widget.duration);
    if (widget.expanded) _reveal.value = 1;
  }

  @override
  void didUpdateWidget(covariant SmoothCardExpansion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expanded == widget.expanded) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _reveal.value = widget.expanded ? 1 : 0;
      return;
    }
    if (widget.expanded) {
      _reveal.forward(from: 0);
    } else {
      _reveal.reverse();
    }
  }

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return widget.expanded ? widget.child : const SizedBox.shrink();
    }

    return AnimatedSize(
      duration: widget.duration,
      curve: AppMotion.spring,
      alignment: Alignment.topCenter,
      clipBehavior: Clip.hardEdge,
      child: widget.expanded
          ? FadeTransition(
              opacity: CurvedAnimation(
                parent: _reveal,
                curve: AppMotion.defaultCurve,
              ),
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.04),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: _reveal,
                  curve: AppMotion.spring,
                )),
                child: widget.child,
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
