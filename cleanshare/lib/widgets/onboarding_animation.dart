import 'package:flutter/material.dart';
import 'package:rive/rive.dart';

import '../core/constants/app_rive.dart';
import '../core/constants/onboarding_content.dart';
import 'onboarding_lottie.dart';

/// Full-width interactive VEDIOS Rive illustration (no border frame).
class OnboardingAnimation extends StatelessWidget {
  const OnboardingAnimation({
    super.key,
    required this.step,
    this.size = 280,
  });

  final OnboardingStep step;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${step.semanticsLabel} Tap the animation to explore.',
      child: SizedBox(
        width: double.infinity,
        height: size,
        child: appRiveEnabled
            ? RiveWidgetBuilder(
                key: ValueKey(step),
                fileLoader: FileLoader.fromAsset(
                  step.riveAsset,
                  riveFactory: Factory.rive,
                ),
                builder: (context, state) => switch (state) {
                  RiveLoading() => const _LoadingIndicator(),
                  RiveFailed() => _OnboardingImageFallback(step: step, size: size),
                  RiveLoaded loaded => RiveWidget(
                      controller: loaded.controller,
                      fit: Fit.contain,
                      alignment: Alignment.center,
                      hitTestBehavior: RiveHitTestBehavior.opaque,
                      cursor: SystemMouseCursors.click,
                    ),
                },
              )
            : _OnboardingImageFallback(step: step, size: size),
      ),
    );
  }
}

class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _OnboardingImageFallback extends StatelessWidget {
  const _OnboardingImageFallback({
    required this.step,
    required this.size,
  });

  final OnboardingStep step;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      step.imageAsset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => OnboardingLottie(
        step: step,
        size: size * 0.88,
      ),
    );
  }
}
