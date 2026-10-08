import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/pump_app.dart';

Future<void> pumpZeroTraceWithOnboardingComplete(WidgetTester tester) async {
  await pumpZeroTraceHome(tester);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('app loads onboarding on first launch', (tester) async {
    await pumpCleanShareApp(tester);
    expect(find.text('Detect privacy risks'), findsOneWidget);
    await flushPendingTimers(tester);
  });

  testWidgets('home screen renders after onboarding complete', (tester) async {
    await pumpZeroTraceWithOnboardingComplete(tester);
    expect(find.text('Home'), findsWidgets);
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Add file'), findsWidgets);
    await flushPendingTimers(tester);
  });

  testWidgets('settings screen renders theme controls', (tester) async {
    await pumpZeroTraceWithOnboardingComplete(tester);

    final settingsTab = find.text('Settings');
    await tester.ensureVisible(settingsTab.last);
    await tester.tap(settingsTab.last);
    await pumpAppFrames(tester);

    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
    await flushPendingTimers(tester);
  });
}
