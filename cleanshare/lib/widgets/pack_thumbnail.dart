import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/constants/model_pack_art.dart';
import '../core/theme/design_tokens.dart';
import '../domain/marketplace/marketplace_models.dart';

/// Pack cover art — bundled image with category gradient fallback.
class PackThumbnail extends StatelessWidget {
  const PackThumbnail({
    super.key,
    required this.entry,
    this.iconSize = 56,
    this.borderRadius = AppRadius.sm,
    this.fit = BoxFit.cover,
  });

  final ModelCatalogEntry entry;
  final double iconSize;
  final double borderRadius;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final swatch = ModelPackArt.swatchFor(entry.category);

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: ColoredBox(
        color: Colors.transparent,
        child: entry.iconAsset != null
            ? _PackImage(
                assetPath: entry.iconAsset!,
                fit: fit,
                fallback: _CategoryIcon(
                  category: entry.category,
                  iconSize: iconSize,
                  swatch: swatch,
                ),
              )
            : _CategoryIcon(
                category: entry.category,
                iconSize: iconSize,
                swatch: swatch,
              ),
      ),
    );
  }
}

class _PackImage extends StatelessWidget {
  const _PackImage({
    required this.assetPath,
    required this.fit,
    required this.fallback,
  });

  final String assetPath;
  final BoxFit fit;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _assetExists(assetPath),
      builder: (context, snapshot) {
        if (snapshot.data != true) return fallback;
        return Image.asset(
          assetPath,
          fit: fit,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, __, ___) => fallback,
        );
      },
    );
  }

  static Future<bool> _assetExists(String path) async {
    try {
      await rootBundle.load(path);
      return true;
    } catch (_) {
      return false;
    }
  }
}

class _CategoryIcon extends StatelessWidget {
  const _CategoryIcon({
    required this.category,
    required this.iconSize,
    required this.swatch,
  });

  final MarketplaceCategory category;
  final double iconSize;
  final List<Color> swatch;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(
        ModelPackArt.iconFor(category),
        size: iconSize,
        color: swatch.first.withValues(alpha: 0.9),
      ),
    );
  }
}
