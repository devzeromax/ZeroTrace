import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cleanshare/widgets/skeleton.dart';

void main() {
  testWidgets('SkeletonExampleCard renders placeholder blocks', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: SkeletonExampleCard()),
        ),
      ),
    );

    expect(find.byType(Skeleton), findsWidgets);
    expect(find.byType(SkeletonText), findsNWidgets(2));
  });

  testWidgets('SkeletonText renders requested line count', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ShimmerScope(
            child: SizedBox(
              width: 200,
              child: SkeletonText(lines: 3),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(Skeleton), findsNWidgets(3));
  });
}
