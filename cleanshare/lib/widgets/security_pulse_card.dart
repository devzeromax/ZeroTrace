import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/design_tokens.dart';
import 'glass_surface.dart';

/// Metric tile with optional sparkline (Security Pulse section).
class SecurityPulseCard extends StatelessWidget {
  const SecurityPulseCard({
    super.key,
    required this.label,
    required this.value,
    this.sparklineColor,
    this.sparklinePoints = const [1, 0.5, 0.75, 0.25, 0],
  });

  final String label;
  final String value;
  final Color? sparklineColor;
  final List<double> sparklinePoints;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GlassSurface(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: SizedBox(
        height: 128,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 120;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: compact ? 11 : null,
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          value,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: colorScheme.onSurface,
                              ),
                        ),
                      ),
                    ),
                    if (!compact) ...[
                      const SizedBox(width: AppSpacing.x2),
                      CustomPaint(
                        size: const Size(40, 20),
                        painter: _SparklinePainter(
                          points: sparklinePoints,
                          color: sparklineColor ?? colorScheme.primary,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.points, required this.color});

  final List<double> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = size.width * (i / (points.length - 1));
      final y = size.height * (1 - points[i].clamp(0.0, 1.0));
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.color != color ||
        !listEquals(oldDelegate.points, points);
  }

  bool listEquals(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if ((a[i] - b[i]).abs() > math.pow(10, -9)) return false;
    }
    return true;
  }
}
