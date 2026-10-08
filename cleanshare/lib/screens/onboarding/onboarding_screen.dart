import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_branding.dart';
import '../../core/routing/app_routes.dart';
import '../../core/constants/onboarding_content.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/glass_scene.dart';
import '../../providers/onboarding_provider.dart';
import '../../providers/welcome_celebration_provider.dart';
import '../../widgets/ambient_background.dart';
import '../../widgets/onboarding_animation.dart';

/// Tokoto-style onboarding — logo, headline, illustration, dots, Continue.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  static final _steps = OnboardingStep.values;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await ref.read(onboardingProvider.notifier).markComplete();
    if (!mounted) return;
    final welcomeSeen = ref.read(welcomeCelebrationProvider).value ?? false;
    context.go(welcomeSeen ? AppRoutes.home : AppRoutes.welcome);
  }

  void _onContinue() {
    if (_currentPage < _steps.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    _finish();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.secondary;
    final isLast = _currentPage == _steps.length - 1;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return AmbientBackground(
      scene: GlassScene.onboarding,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: SizedBox(
            width: double.infinity,
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Semantics(
                    button: true,
                    label: 'Skip onboarding',
                    child: TextButton(
                      onPressed: _finish,
                      child: Text(
                        'Skip',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 5,
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) => setState(() => _currentPage = index),
                    itemCount: _steps.length,
                    itemBuilder: (context, index) => _OnboardingSlide(
                      step: _steps[index],
                      accent: accent,
                      animate: !reduceMotion && index == _currentPage,
                      showBrand: index == 0,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x5),
                    child: Column(
                      children: [
                        const Spacer(),
                        Semantics(
                          label:
                              'Onboarding step ${_currentPage + 1} of ${_steps.length}',
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              _steps.length,
                              (index) => _PageDot(
                                active: _currentPage == index,
                                accent: accent,
                              ),
                            ),
                          ),
                        ),
                        const Spacer(flex: 3),
                        Semantics(
                          button: true,
                          label: isLast ? 'Get started' : 'Continue to next step',
                          child: FilledButton(
                            onPressed: _onContinue,
                            style: FilledButton.styleFrom(
                              elevation: 0,
                              minimumSize: const Size(double.infinity, 52),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppRadius.lg),
                              ),
                            ),
                            child: Text(isLast ? 'Get started' : 'Continue'),
                          ),
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardingSlide extends StatefulWidget {
  const _OnboardingSlide({
    required this.step,
    required this.accent,
    required this.animate,
    this.showBrand = false,
  });

  final OnboardingStep step;
  final Color accent;
  final bool animate;
  final bool showBrand;

  @override
  State<_OnboardingSlide> createState() => _OnboardingSlideState();
}

class _OnboardingSlideState extends State<_OnboardingSlide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    if (widget.animate) _controller.forward();
  }

  @override
  void didUpdateWidget(covariant _OnboardingSlide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_controller.isCompleted) {
      _controller.forward();
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
    final size = MediaQuery.sizeOf(context);
    final illustrationSize = math.min(
      size.width * 0.92,
      size.height * 0.44,
    ).clamp(280.0, 420.0);

    return SlideTransition(
      position: _slide,
      child: FadeTransition(
        opacity: _fade,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x5),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: AppSpacing.x2),
                    OnboardingAnimation(
                      step: widget.step,
                      size: illustrationSize,
                    ),
                    const SizedBox(height: AppSpacing.x5),
                    if (widget.showBrand) ...[
                      Text(
                        AppBranding.nameUpper,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: widget.accent,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.4,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.x3),
                    ],
                    Text(
                      widget.step.title,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.x2),
                    Text(
                      widget.step.body,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.x4),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PageDot extends StatelessWidget {
  const _PageDot({required this.active, required this.accent});

  final bool active;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.only(right: AppSpacing.x1),
      height: 6,
      width: active ? 22 : 6,
      decoration: BoxDecoration(
        color: active
            ? accent
            : Theme.of(context).colorScheme.outline.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}
