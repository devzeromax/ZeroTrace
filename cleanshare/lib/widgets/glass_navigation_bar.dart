import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../core/theme/design_tokens.dart';
import '../core/theme/glass_tokens.dart';
import '../core/performance/display_tuning.dart';

/// Liquid glass navigation — floating bar with dynamic refraction.
class GlassNavigationBar extends StatelessWidget {
  const GlassNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavigationDestination> destinations;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final selectedColor = isDark
        ? colorScheme.secondary
        : CosmosColors.concentricTeal;
    final unselectedColor = isDark
        ? Colors.white.withValues(alpha: 0.72)
        : colorScheme.onSurface.withValues(alpha: 0.55);
    final media = MediaQuery.of(context);
    final prefersPlainNav =
        media.highContrast || MediaQuery.disableAnimationsOf(context);
    final tabs = destinations
        .map((destination) => _toGlassTab(destination, unselectedColor))
        .toList(growable: false);

    if (prefersPlainNav) {
      return NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
        destinations: destinations,
      );
    }

    return GlassRepaintBoundary(
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(
          AppSpacing.x4,
          0,
          AppSpacing.x4,
          AppSpacing.x2,
        ),
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset > 0 ? 0 : AppSpacing.x2),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.navPill),
              boxShadow: GlassTokens.navGlow(context),
            ),
            child: GlassTabBar.bottom(
              selectedIndex: selectedIndex,
              onTabSelected: (index) {
                HapticFeedback.selectionClick();
                onDestinationSelected(index);
              },
              adaptiveBrightness: isDark,
              tabs: tabs,
              quality: GlassQuality.standard,
              settings: LiquidGlassSettings(
                blur: isDark ? 8 : 10,
                thickness: isDark ? 24 : 28,
                glassColor: isDark
                    ? const Color(0x2EFFFFFF)
                    : const Color(0x66FFFFFF),
              ),
              indicatorColor: isDark
                  ? colorScheme.secondary.withValues(alpha: 0.22)
                  : colorScheme.secondary.withValues(alpha: 0.18),
              selectedIconColor: selectedColor,
              selectedLabelColor: selectedColor,
              unselectedIconColor: unselectedColor,
              unselectedLabelColor: unselectedColor,
              barHeight: 68,
              horizontalPadding: 12,
              verticalPadding: 10,
            ),
          ),
        ),
      ),
    );
  }

  GlassTab _toGlassTab(NavigationDestination destination, Color iconColor) {
    final icon = destination.icon;
    final selectedIcon = destination.selectedIcon ?? destination.icon;
    final label = destination.label;
    return GlassTab(
      icon: _iconFrom(icon, iconColor),
      activeIcon: _iconFrom(selectedIcon, iconColor),
      label: label,
    );
  }

  Icon _iconFrom(Widget icon, Color color) {
    if (icon case Icon i) {
      return Icon(
        i.icon,
        size: i.size,
        semanticLabel: i.semanticLabel,
        color: color,
      );
    }
    return Icon(Icons.circle_outlined, color: color);
  }
}
