import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cleanshare/core/routing/page_transitions.dart';

Widget _buildTransition({
  required BuildContext context,
  required bool reduceMotion,
  required double animationValue,
}) {
  return MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: Builder(
      builder: (context) {
        return workflowSharedAxisPage<void>(
          key: const ValueKey('test'),
          child: const Text('screen'),
        ).transitionsBuilder(
          context,
          AlwaysStoppedAnimation(animationValue),
          const AlwaysStoppedAnimation(0),
          const Text('screen'),
        );
      },
    ),
  );
}

void main() {
  testWidgets('workflow push skips animation when reduce motion is on', (
    tester,
  ) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(
          builder: (context) => _buildTransition(
            context: context,
            reduceMotion: true,
            animationValue: 1,
          ),
        ),
      ),
    );

    expect(find.text('screen'), findsOneWidget);
    expect(find.byType(SlideTransition), findsNothing);
  });

  testWidgets('workflow push animates slide when motion is enabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(
          builder: (context) => _buildTransition(
            context: context,
            reduceMotion: false,
            animationValue: 0.5,
          ),
        ),
      ),
    );

    expect(find.byType(SlideTransition), findsWidgets);
    expect(find.text('screen'), findsOneWidget);
  });
}
