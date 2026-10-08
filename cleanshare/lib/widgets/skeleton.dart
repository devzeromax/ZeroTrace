import 'package:flutter/material.dart';

import '../core/theme/design_tokens.dart';

/// Shimmer variants — mirrors Gluestack `Skeleton` shapes.
enum SkeletonVariant {
  sharp,
  rounded,
  circular,
}

/// Shared shimmer driver for a skeleton group (one controller per layout).
class ShimmerScope extends StatefulWidget {
  const ShimmerScope({super.key, required this.child});

  final Widget child;

  static Animation<double>? animationOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_ShimmerScopeData>()
        ?.animation;
  }

  @override
  State<ShimmerScope> createState() => _ShimmerScopeState();
}

class _ShimmerScopeState extends State<ShimmerScope>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (!WidgetsBinding.instance.platformDispatcher.accessibilityFeatures
        .disableAnimations) {
      _controller.repeat();
    } else {
      _controller.value = 0.5;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ShimmerScopeData(
      animation: _controller,
      child: widget.child,
    );
  }
}

class _ShimmerScopeData extends InheritedWidget {
  const _ShimmerScopeData({
    required this.animation,
    required super.child,
  });

  final Animation<double> animation;

  @override
  bool updateShouldNotify(_ShimmerScopeData oldWidget) =>
      oldWidget.animation != animation;
}

/// Placeholder block with optional shimmer sweep.
class Skeleton extends StatelessWidget {
  const Skeleton({
    super.key,
    this.width,
    required this.height,
    this.variant = SkeletonVariant.rounded,
  });

  final double? width;
  final double height;
  final SkeletonVariant variant;

  BorderRadius _radius() => switch (variant) {
        SkeletonVariant.sharp => BorderRadius.zero,
        SkeletonVariant.rounded => BorderRadius.circular(AppRadius.sm),
        SkeletonVariant.circular => BorderRadius.circular(height / 2),
      };

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final base = colorScheme.surfaceContainerHighest;
    final highlight = Color.lerp(
      base,
      colorScheme.onSurface.withValues(alpha: 0.08),
      0.55,
    )!;

    final box = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: base,
        borderRadius: _radius(),
      ),
    );

    final animation = ShimmerScope.animationOf(context);
    if (animation == null) return box;

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = animation.value;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(-1 + 2 * t, 0),
              end: Alignment(t, 0),
              colors: [base, highlight, base],
              stops: const [0.1, 0.5, 0.9],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: box,
    );
  }
}

/// Multi-line text placeholder — mirrors Gluestack `SkeletonText`.
class SkeletonText extends StatelessWidget {
  const SkeletonText({
    super.key,
    this.lines = 3,
    this.gap = AppSpacing.x2,
    this.lineHeight = 8,
    this.lastLineWidthFactor = 0.65,
  });

  final int lines;
  final double gap;
  final double lineHeight;
  final double lastLineWidthFactor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < lines; i++) ...[
          if (i > 0) SizedBox(height: gap),
          Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: i == lines - 1 ? lastLineWidthFactor : 1,
              child: Skeleton(
                height: lineHeight,
                variant: SkeletonVariant.sharp,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Home command center while scan history hydrates from disk.
class HomeCommandCenterSkeleton extends StatelessWidget {
  const HomeCommandCenterSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerScope(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Skeleton(height: 28, width: 180),
          const SizedBox(height: AppSpacing.x2),
          const SkeletonText(lines: 1, lineHeight: 14, lastLineWidthFactor: 0.7),
          const SizedBox(height: AppSpacing.x6),
          const Skeleton(
            height: 140,
            variant: SkeletonVariant.rounded,
          ),
          const SizedBox(height: AppSpacing.x6),
          const Skeleton(
            height: 300,
            variant: SkeletonVariant.rounded,
          ),
          const SizedBox(height: AppSpacing.x8),
          const Skeleton(height: 20, width: 120),
          const SizedBox(height: AppSpacing.x3),
          for (var i = 0; i < 3; i++) ...[
            const RecentScanRowSkeleton(),
            if (i < 2) const SizedBox(height: AppSpacing.x2),
          ],
        ],
      ),
    );
  }
}

/// Single recent-scan row placeholder.
class RecentScanRowSkeleton extends StatelessWidget {
  const RecentScanRowSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.x1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Skeleton(
            variant: SkeletonVariant.circular,
            width: 36,
            height: 36,
          ),
          SizedBox(width: AppSpacing.x3),
          Expanded(
            child: SkeletonText(
              lines: 2,
              gap: AppSpacing.x2,
              lineHeight: 10,
              lastLineWidthFactor: 0.45,
            ),
          ),
          SizedBox(width: AppSpacing.x3),
          Skeleton(
            variant: SkeletonVariant.rounded,
            width: 56,
            height: 24,
          ),
        ],
      ),
    );
  }
}

/// Marketplace catalog grid while packs load.
class MarketplaceCatalogSkeleton extends StatelessWidget {
  const MarketplaceCatalogSkeleton({super.key, this.count = 4});

  final int count;

  @override
  Widget build(BuildContext context) {
    final crossAxisCount =
        MediaQuery.sizeOf(context).width < 400 ? 1 : 2;
    final aspectRatio = crossAxisCount == 1 ? 2.35 : 0.62;

    return ShimmerScope(
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 20,
          crossAxisSpacing: 16,
          childAspectRatio: aspectRatio,
        ),
        itemCount: count,
        itemBuilder: (_, __) => const _PackCardSkeleton(),
      ),
    );
  }
}

class _PackCardSkeleton extends StatelessWidget {
  const _PackCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Skeleton(
            variant: SkeletonVariant.rounded,
            height: double.infinity,
          ),
        ),
        SizedBox(height: AppSpacing.x3),
        SkeletonText(lines: 2, lineHeight: 10, lastLineWidthFactor: 0.55),
        SizedBox(height: AppSpacing.x3),
        Skeleton(
          height: 40,
          variant: SkeletonVariant.rounded,
        ),
      ],
    );
  }
}

/// Settings installed-packs list placeholder.
class InstalledPacksSkeleton extends StatelessWidget {
  const InstalledPacksSkeleton({super.key, this.rows = 3});

  final int rows;

  @override
  Widget build(BuildContext context) {
    return ShimmerScope(
      child: Column(
        children: [
          for (var i = 0; i < rows; i++) ...[
            const RecentScanRowSkeleton(),
            if (i < rows - 1) const SizedBox(height: AppSpacing.x2),
          ],
        ],
      ),
    );
  }
}

/// Audit report header while session loads.
class AuditReportSkeleton extends StatelessWidget {
  const AuditReportSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerScope(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Skeleton(
            height: 200,
            variant: SkeletonVariant.rounded,
          ),
          const SizedBox(height: AppSpacing.x6),
          const SkeletonText(lines: 3, lineHeight: 10),
          const SizedBox(height: AppSpacing.x6),
          for (var i = 0; i < 2; i++) ...[
            const Skeleton(
              height: 72,
              variant: SkeletonVariant.rounded,
            ),
            if (i < 1) const SizedBox(height: AppSpacing.x3),
          ],
        ],
      ),
    );
  }
}
