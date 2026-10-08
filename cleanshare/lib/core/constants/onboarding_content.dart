import 'package:flutter/material.dart';

/// Onboarding steps — single source for copy, Lottie assets, and fallbacks.
enum OnboardingStep {
  detectRisks,
  staysLocal,
  sanitizeShare,
}

extension OnboardingStepData on OnboardingStep {
  String get title => switch (this) {
        OnboardingStep.detectRisks => 'Detect privacy risks',
        OnboardingStep.staysLocal => 'Everything stays local',
        OnboardingStep.sanitizeShare => 'Sanitize and share safely',
      };

  String get body => switch (this) {
        OnboardingStep.detectRisks =>
          'Find metadata, faces, and QR codes before you share.',
        OnboardingStep.staysLocal =>
          'Scanned on your device. Nothing is uploaded.',
        OnboardingStep.sanitizeShare =>
          'Fix issues and export a clean file with a report.',
      };

  String get lottieAsset => switch (this) {
        OnboardingStep.detectRisks => 'assets/lottie/onboarding_scan.json',
        OnboardingStep.staysLocal => 'assets/lottie/onboarding_local.json',
        OnboardingStep.sanitizeShare => 'assets/lottie/onboarding_export.json',
      };

  String get riveAsset => switch (this) {
        OnboardingStep.detectRisks => 'assets/rive/onboarding_scan.riv',
        OnboardingStep.staysLocal => 'assets/rive/onboarding_local.riv',
        OnboardingStep.sanitizeShare => 'assets/rive/onboarding_export.riv',
      };

  /// Static illustration from [cleanshare/VEDIOS] when Rive cannot load.
  String get imageAsset => switch (this) {
        OnboardingStep.detectRisks => 'assets/onboarding/detect_risks.png',
        OnboardingStep.staysLocal => 'assets/onboarding/stays_local.webp',
        OnboardingStep.sanitizeShare => 'assets/onboarding/sanitize_share.png',
      };

  IconData get fallbackIcon => switch (this) {
        OnboardingStep.detectRisks => Icons.document_scanner_outlined,
        OnboardingStep.staysLocal => Icons.phonelink_lock_outlined,
        OnboardingStep.sanitizeShare => Icons.verified_user_outlined,
      };

  String get semanticsLabel => '$title. $body';

  static List<OnboardingStep> get ordered => OnboardingStep.values;
}
