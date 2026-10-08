import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cleanshare/core/animation/app_motion.dart';
import 'package:cleanshare/core/theme/design_tokens.dart';

void main() {
  test('Export processing minimum duration is user-visible', () {
    expect(AppDurations.exportProcessingMinimum.inSeconds, greaterThanOrEqualTo(5));
  });

  testWidgets('AnimatedSuccessCheck paints without error', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: AnimatedSuccessCheck()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(AnimatedSuccessCheck), findsOneWidget);
  });

  testWidgets('ContentRevealSwap crossfades placeholder to content', (tester) async {
    var showPlaceholder = true;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return Scaffold(
              body: ContentRevealSwap(
                showPlaceholder: showPlaceholder,
                placeholder: const Text('loading', key: ValueKey('loading')),
                content: const Text('ready', key: ValueKey('ready')),
              ),
            );
          },
        ),
      ),
    );

    expect(find.text('loading'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: ContentRevealSwap(
          showPlaceholder: false,
          placeholder: Text('loading', key: ValueKey('loading')),
          content: Text('ready', key: ValueKey('ready')),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('ready'), findsOneWidget);
  });

  testWidgets('PopUpReveal animates without opacity overflow', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PopUpReveal(child: Text('hello')),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('hello'), findsOneWidget);
  });

  testWidgets('TextFlipReveal updates message with key', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TextFlipReveal(text: 'Step one'),
        ),
      ),
    );
    expect(find.text('Step one'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TextFlipReveal(text: 'Step two'),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Step two'), findsOneWidget);
  });
}
