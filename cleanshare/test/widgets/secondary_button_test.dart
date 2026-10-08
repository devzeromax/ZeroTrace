import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cleanshare/core/theme/design_tokens.dart';
import 'package:cleanshare/widgets/secondary_button.dart';

void main() {
  testWidgets('SecondaryButton has 48dp minimum height', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SecondaryButton(
            label: 'Test',
            onPressed: () {},
          ),
        ),
      ),
    );

    final size = tester.getSize(find.byType(SecondaryButton));
    expect(size.height, AppSpacing.x12);
  });
}
