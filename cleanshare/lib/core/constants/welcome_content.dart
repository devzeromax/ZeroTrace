import 'package:flutter/material.dart';

/// Copy and included-pack list for the first-run welcome celebration.
abstract final class WelcomeContent {
  static const lottieAsset = 'assets/lottie/onboarding_export.json';

  static const headline = 'Congratulations!';
  static const subtitle =
      'Your ZeroTrace workspace is ready — core privacy scanners are '
      'already installed and work offline.';

  static const marketplaceHint =
      'Want face blur, license plates, or document OCR? '
      'Open Settings → Pack marketplace to download optional add-ons anytime.';

  static const includedPacks = [
    (
      title: 'Privacy Essentials',
      description: 'EXIF metadata, GPS, and privacy reporting',
      icon: Icons.shield_outlined,
    ),
    (
      title: 'Metadata Cleaner',
      description: 'PDF, Office, and ZIP header detection',
      icon: Icons.description_outlined,
    ),
    (
      title: 'Developer Protection',
      description: 'API keys, tokens, and secret patterns',
      icon: Icons.code_outlined,
    ),
    (
      title: 'QR Protection',
      description: 'QR and barcode sensitive URL scanning',
      icon: Icons.qr_code_scanner_outlined,
    ),
  ];
}
