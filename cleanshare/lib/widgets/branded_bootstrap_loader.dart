import 'package:flutter/material.dart';

import '../core/constants/app_assets.dart';
import '../core/constants/app_branding.dart';
import '../core/theme/design_tokens.dart';
import '../core/theme/glass_scene.dart';
import 'ambient_background.dart';

/// Branded loading — shown while app data initializes after splash.
class BrandedBootstrapLoader extends StatefulWidget {
  const BrandedBootstrapLoader({super.key});

  @override
  State<BrandedBootstrapLoader> createState() => _BrandedBootstrapLoaderState();
}

class _BrandedBootstrapLoaderState extends State<BrandedBootstrapLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.secondary;

    return AmbientBackground(
      scene: GlassScene.onboarding,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FadeTransition(
                opacity: Tween<double>(begin: 0.55, end: 1).animate(
                  CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
                ),
                child: Image.asset(
                  AppAssets.logoMark,
                  width: 72,
                  height: 72,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),
              const SizedBox(height: AppSpacing.x6),
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: accent,
                ),
              ),
              const SizedBox(height: AppSpacing.x4),
              Text(
                'Loading ${AppBranding.name}…',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fades main app content in on first paint after bootstrap.
class AppEntryFade extends StatefulWidget {
  const AppEntryFade({super.key, required this.child});

  final Widget child;

  @override
  State<AppEntryFade> createState() => _AppEntryFadeState();
}

class _AppEntryFadeState extends State<AppEntryFade>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _fade, child: widget.child);
  }
}
