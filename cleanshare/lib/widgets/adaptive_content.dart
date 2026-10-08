import 'package:flutter/material.dart';

import '../core/layout/adaptive_breakpoints.dart';

/// Centers content and caps width on large windows while filling available space.
class AdaptiveContent extends StatelessWidget {
  const AdaptiveContent({
    super.key,
    required this.child,
    this.maxWidth = AdaptiveBreakpoints.contentMaxWidth,
    this.padding,
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        Widget content = ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxWidth,
            maxHeight: constraints.maxHeight,
          ),
          child: SizedBox(
            width: double.infinity,
            child: child,
          ),
        );

        if (padding != null) {
          content = Padding(padding: padding!, child: content);
        }

        if (!constraints.hasBoundedHeight) {
          return Align(alignment: alignment, child: content);
        }

        return SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: Align(
            alignment: alignment,
            child: content,
          ),
        );
      },
    );
  }
}

/// Row on wide windows; column on narrow windows to prevent overflow.
class AdaptiveRowColumn extends StatelessWidget {
  const AdaptiveRowColumn({
    super.key,
    required this.leading,
    required this.trailing,
    this.breakpoint = AdaptiveBreakpoints.narrowFooterMaxWidth,
    this.spacing = 16,
  });

  final Widget leading;
  final Widget trailing;
  final double breakpoint;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= breakpoint) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              leading,
              SizedBox(height: spacing),
              trailing,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: leading),
            SizedBox(width: spacing),
            trailing,
          ],
        );
      },
    );
  }
}
