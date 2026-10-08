import 'package:flutter/material.dart';

import '../core/theme/design_tokens.dart';
import '../core/theme/theme_surfaces.dart';

/// Command Center add-file panel — solid surface, dashed border, no mint glow.
/// Idle border breathes (#177-breathing-border-radius).
class StagedDropZone extends StatefulWidget {
  const StagedDropZone({
    super.key,
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  State<StagedDropZone> createState() => _StagedDropZoneState();
}

class _StagedDropZoneState extends State<StagedDropZone>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;
  bool _pressed = false;
  late final AnimationController _breathe;

  @override
  void initState() {
    super.initState();
    _breathe = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    if (!WidgetsBinding.instance.platformDispatcher.accessibilityFeatures
        .disableAnimations) {
      _breathe.repeat(reverse: true);
    } else {
      _breathe.value = 0.5;
    }
  }

  @override
  void dispose() {
    _breathe.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = _hovered || _pressed;
    final breathe = accent ? 0.0 : _breathe.value;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = ThemeSurfaces.isDark(context);
    final borderBase = ThemeSurfaces.border(context);
    final mint = colorScheme.secondary;
    final teal = CosmosColors.concentricTeal;
    final borderColor = accent ? mint : borderBase.withValues(alpha: 0.85);
    final fill = accent
        ? mint.withValues(alpha: isDark ? 0.10 : 0.06)
        : colorScheme.surface;

    return Semantics(
      button: true,
      label: 'Add file. Tap to browse.',
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _pressed ? 0.99 : 1,
            duration: AppDurations.fast,
            curve: Curves.easeOutCubic,
            child: AnimatedBuilder(
              animation: _breathe,
              builder: (context, _) {
                return CustomPaint(
                  painter: _DashedBorderPainter(
                    color: borderColor,
                    radius: AppRadius.hero,
                    breathe: breathe,
                    accent: accent,
                  ),
                  child: AnimatedContainer(
                    duration: AppDurations.normal,
                    width: double.infinity,
                    constraints: const BoxConstraints(minHeight: 300),
                    decoration: BoxDecoration(
                      color: fill,
                      borderRadius: BorderRadius.circular(AppRadius.hero),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black
                              .withValues(alpha: isDark ? 0.28 : 0.06),
                          blurRadius: isDark ? 20 : 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(AppSpacing.x8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: AppDurations.normal,
                          padding: const EdgeInsets.all(AppSpacing.x4),
                          decoration: BoxDecoration(
                            color: accent
                                ? mint.withValues(alpha: 0.18)
                                : AppColors.riskLowSubtleLight,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.add_rounded,
                            size: 32,
                            color: accent ? teal : teal.withValues(alpha: 0.9),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.x4),
                        Text(
                          'Add file',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: colorScheme.onSurface,
                                    fontWeight: FontWeight.w600,
                                  ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.x2),
                        Text(
                          'Tap to browse photos, PDFs, Office, or code.',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.x4),
                        Text(
                          'JPEG, PNG, HEIC, PDF, Office, code (max 100MB)',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({
    required this.color,
    required this.radius,
    this.breathe = 0,
    this.accent = false,
  });

  final Color color;
  final double radius;
  final double breathe;
  final bool accent;

  @override
  void paint(Canvas canvas, Size size) {
    // ponytail: idle breathe only; accent uses static border (no pulse fight)
    final pulse = accent ? 0.0 : breathe;
    final stroke = 2 + pulse * 0.6;
    final expanded = 1 + pulse * 0.004;

    final paint = Paint()
      ..color = color.withValues(alpha: 0.55 + pulse * 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    final inset = 1.0 - pulse * 0.5;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        inset,
        inset,
        (size.width - inset * 2) * expanded,
        (size.height - inset * 2) * expanded,
      ),
      Radius.circular(radius),
    );

    final path = Path()..addRRect(rect);
    final dash = 8 + pulse * 2;
    final gap = 8 - pulse * 2;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dash;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.breathe != breathe ||
        oldDelegate.accent != accent;
  }
}
