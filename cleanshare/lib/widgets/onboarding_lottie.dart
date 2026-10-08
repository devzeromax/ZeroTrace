import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../core/constants/onboarding_content.dart';

/// Onboarding illustration — Lottie with icon fallback.
class OnboardingLottie extends StatelessWidget {
  const OnboardingLottie({
    super.key,
    required this.step,
    this.size = 140,
  });

  final OnboardingStep step;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      label: step.semanticsLabel,
      child: SizedBox(
        width: size,
        height: size,
        child: Lottie.asset(
          step.lottieAsset,
          fit: BoxFit.contain,
          repeat: false,
          errorBuilder: (_, __, ___) => Icon(
            step.fallbackIcon,
            size: size * 0.45,
            color: colorScheme.primary,
          ),
        ),
      ),
    );
  }
}
