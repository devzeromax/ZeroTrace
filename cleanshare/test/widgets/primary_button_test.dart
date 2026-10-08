import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cleanshare/widgets/primary_button.dart';

void main() {
  testWidgets('PrimaryButton disabled when onPressed is null', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PrimaryButton(
            label: 'Submit',
            onPressed: null,
          ),
        ),
      ),
    );

    final semantics = tester.getSemantics(find.text('Submit'));
    expect(semantics.flagsCollection.isEnabled, Tristate.isFalse);
  });

  testWidgets('PrimaryButton shows loading indicator', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PrimaryButton(
            label: 'Submit',
            onPressed: null,
            isLoading: true,
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
