import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cleanshare/widgets/fluid_progress_bar.dart';
import 'package:cleanshare/widgets/smooth_card_expansion.dart';

void main() {
  testWidgets('FluidProgressBar renders at a given progress', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 200,
            child: FluidProgressBar(progress: 0.5),
          ),
        ),
      ),
    );
    expect(find.byType(FluidProgressBar), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('SmoothCardExpansion hides content when collapsed', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SmoothCardExpansion(
            expanded: false,
            child: Text('details'),
          ),
        ),
      ),
    );
    expect(find.text('details'), findsNothing);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SmoothCardExpansion(
            expanded: true,
            child: Text('details'),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('details'), findsOneWidget);
  });
}
