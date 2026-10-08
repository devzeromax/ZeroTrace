import 'package:flutter/material.dart';

import '../../domain/marketplace/marketplace_models.dart';
import '../theme/design_tokens.dart';

/// Visual identity for marketplace model packs (thumbnail + accent).
abstract final class ModelPackArt {
  static IconData iconFor(MarketplaceCategory category) => switch (category) {
        MarketplaceCategory.faceDetection => Icons.face_retouching_natural_outlined,
        MarketplaceCategory.qrDetection => Icons.qr_code_scanner_outlined,
        MarketplaceCategory.licensePlateDetection => Icons.directions_car_outlined,
        MarketplaceCategory.ocr => Icons.text_fields_outlined,
        MarketplaceCategory.documentScanner => Icons.document_scanner_outlined,
        MarketplaceCategory.metadataScanner => Icons.photo_library_outlined,
        MarketplaceCategory.developerTools => Icons.code_outlined,
        MarketplaceCategory.futureModels => Icons.auto_awesome_outlined,
      };

  static List<Color> swatchFor(MarketplaceCategory category) => switch (category) {
        MarketplaceCategory.faceDetection => [
            const Color(0xFF836DB8),
            const Color(0xFFB8A4E8),
          ],
        MarketplaceCategory.qrDetection => [
            const Color(0xFF22E2A8),
            const Color(0xFF0A8F6A),
          ],
        MarketplaceCategory.licensePlateDetection => [
            const Color(0xFFFFB347),
            const Color(0xFFE07A2F),
          ],
        MarketplaceCategory.ocr => [
            const Color(0xFF5B8DEF),
            const Color(0xFF3D5A9E),
          ],
        MarketplaceCategory.documentScanner => [
            const Color(0xFFDECB9C),
            const Color(0xFFB89B5E),
          ],
        MarketplaceCategory.metadataScanner => [
            const Color(0xFFF6625E),
            const Color(0xFFC93D3A),
          ],
        MarketplaceCategory.developerTools => [
            const Color(0xFF393939),
            const Color(0xFF1E1F20),
          ],
        MarketplaceCategory.futureModels => [
            AppColors.accent,
            AppColors.accentDark,
          ],
      };

  static LinearGradient gradientFor(MarketplaceCategory category) {
    final colors = swatchFor(category);
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        colors.first.withValues(alpha: 0.22),
        colors.last.withValues(alpha: 0.08),
      ],
    );
  }

  static String formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
