import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Display and frame pacing helpers for smooth UI on high-refresh devices.
abstract final class DisplayTuning {
  /// Lets the engine render as fast as the display allows (no artificial cap).
  static void configure() {
    final binding = SchedulerBinding.instance;
    binding.scheduleWarmUpFrame();
  }
}

/// Isolates expensive glass layers from scrollable content repaints.
class GlassRepaintBoundary extends StatelessWidget {
  const GlassRepaintBoundary({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => RepaintBoundary(child: child);
}
