import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cleanshare/app.dart';
import 'package:cleanshare/providers/workflow_provider.dart';

/// ponytail: bounded pump — shimmer/breathing animations never settle.
Future<void> pumpAppFrames(
  WidgetTester tester, {
  Duration total = const Duration(seconds: 5),
  Duration step = const Duration(milliseconds: 50),
}) async {
  final steps = total.inMilliseconds ~/ step.inMilliseconds;
  for (var i = 0; i < steps; i++) {
    await tester.pump(step);
  }
}

Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Timed out waiting for $finder');
}

void usePhoneViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void useTestAccessibility(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

Future<void> flushPendingTimers(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 2));
}

List<Override> get testAppOverrides => [
      historyHydratingProvider.overrideWith((ref) => false),
    ];

Future<void> pumpCleanShareApp(WidgetTester tester) async {
  usePhoneViewport(tester);
  useTestAccessibility(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: testAppOverrides,
      child: const ZeroTraceApp(skipSplash: true),
    ),
  );
  await pumpUntilFound(tester, find.text('Detect privacy risks'));
}

Future<void> pumpZeroTraceHome(WidgetTester tester) async {
  usePhoneViewport(tester);
  useTestAccessibility(tester);
  SharedPreferences.setMockInitialValues({
    'onboarding_complete': true,
    'welcome_celebration_seen': true,
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: testAppOverrides,
      child: const ZeroTraceApp(skipSplash: true),
    ),
  );
  await pumpUntilFound(tester, find.text('Overview'));
  await pumpAppFrames(tester, total: const Duration(milliseconds: 800));
}
