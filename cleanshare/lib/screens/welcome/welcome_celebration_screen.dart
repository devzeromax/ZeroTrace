import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import '../../core/audio/app_sound_player.dart';
import '../../core/constants/app_branding.dart';
import '../../core/constants/welcome_content.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/glass_scene.dart';
import '../../providers/welcome_celebration_provider.dart';
import '../../widgets/ambient_background.dart';
import '../../widgets/glass_surface.dart';
import '../../widgets/zerotrace_logo.dart';

/// First-run celebration — included packs + marketplace hint.
class WelcomeCelebrationScreen extends ConsumerStatefulWidget {
  const WelcomeCelebrationScreen({super.key});

  @override
  ConsumerState<WelcomeCelebrationScreen> createState() =>
      _WelcomeCelebrationScreenState();
}

class _WelcomeCelebrationScreenState extends ConsumerState<WelcomeCelebrationScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enter;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    );
    _fade = CurvedAnimation(parent: _enter, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _enter, curve: Curves.easeOutCubic));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AppSoundPlayer.playExportSuccess();
      if (MediaQuery.disableAnimationsOf(context)) {
        _enter.value = 1;
      } else {
        _enter.forward();
      }
    });
  }

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    await ref.read(welcomeCelebrationProvider.notifier).markSeen();
    if (!mounted) return;
    context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final lottieSize = MediaQuery.sizeOf(context).width.clamp(280.0, 420.0) * 0.42;

    return AmbientBackground(
      scene: GlassScene.onboarding,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: _slide,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.x5,
                      vertical: AppSpacing.x4,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight),
                      child: Column(
                        children: [
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: ZeroTraceLogo(size: 36, showWordmark: false),
                          ),
                          const SizedBox(height: AppSpacing.x4),
                          Semantics(
                            label: 'Congratulations animation',
                            child: SizedBox(
                              width: lottieSize,
                              height: lottieSize,
                              child: Lottie.asset(
                                WelcomeContent.lottieAsset,
                                fit: BoxFit.contain,
                                repeat: !reduceMotion,
                                errorBuilder: (_, __, ___) => Icon(
                                  Icons.celebration_outlined,
                                  size: lottieSize * 0.45,
                                  color: colorScheme.secondary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.x3),
                          Text(
                            WelcomeContent.headline,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                              color: colorScheme.secondary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.x2),
                          Text(
                            WelcomeContent.subtitle,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.x5),
                          GlassSurface(
                            scene: GlassScene.onboarding,
                            padding: const EdgeInsets.all(AppSpacing.x4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.inventory_2_outlined,
                                      size: 20,
                                      color: colorScheme.secondary,
                                    ),
                                    const SizedBox(width: AppSpacing.x2),
                                    Text(
                                      'Included with ${AppBranding.name}',
                                      style: theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.x1),
                                Text(
                                  'No download required — ready now',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.x4),
                                for (var i = 0; i < WelcomeContent.includedPacks.length; i++)
                                  _IncludedPackRow(
                                    pack: WelcomeContent.includedPacks[i],
                                    accent: colorScheme.secondary,
                                    delay: Duration(milliseconds: 80 * i),
                                    animate: !reduceMotion,
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.x4),
                          GlassSurface(
                            scene: GlassScene.onboarding,
                            intensity: 0.1,
                            padding: const EdgeInsets.all(AppSpacing.x4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.storefront_outlined,
                                  size: 22,
                                  color: colorScheme.secondary,
                                ),
                                const SizedBox(width: AppSpacing.x3),
                                Expanded(
                                  child: Text(
                                    WelcomeContent.marketplaceHint,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                      height: 1.45,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.x6),
                          Semantics(
                            button: true,
                            label: 'Start using ZeroTrace',
                            child: FilledButton(
                              onPressed: _continue,
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(double.infinity, 52),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppRadius.lg),
                                ),
                              ),
                              child: const Text('Start scanning'),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.x2),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IncludedPackRow extends StatefulWidget {
  const _IncludedPackRow({
    required this.pack,
    required this.accent,
    required this.delay,
    required this.animate,
  });

  final ({String title, String description, IconData icon}) pack;
  final Color accent;
  final Duration delay;
  final bool animate;

  @override
  State<_IncludedPackRow> createState() => _IncludedPackRowState();
}

class _IncludedPackRowState extends State<_IncludedPackRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    if (widget.animate) {
      Future<void>.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    } else {
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FadeTransition(
      opacity: _fade,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.x3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: widget.accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(widget.pack.icon, size: 20, color: widget.accent),
            ),
            const SizedBox(width: AppSpacing.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.pack.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.check_circle_rounded,
                        size: 18,
                        color: widget.accent,
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.pack.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
