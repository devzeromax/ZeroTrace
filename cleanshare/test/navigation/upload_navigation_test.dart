import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:go_router/go_router.dart';

import 'package:cleanshare/core/routing/app_routes.dart';
import 'package:cleanshare/widgets/upload_drop_zone.dart';

import '../helpers/pump_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'onboarding_complete': true,
      'welcome_celebration_seen': true,
    });
  });

  testWidgets('upload close returns to home', (tester) async {
    await pumpZeroTraceHome(tester);

    final context = tester.element(find.text('Overview'));
    GoRouter.of(context).push(AppRoutes.upload);
    await pumpUntilFound(tester, find.widgetWithText(AppBar, 'Add file'));

    expect(find.widgetWithText(AppBar, 'Add file'), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await pumpAppFrames(tester, total: const Duration(seconds: 2));
    await pumpUntilFound(tester, find.text('Overview'));

    expect(find.byType(UploadDropZone), findsNothing);
    expect(find.text('Home'), findsWidgets);
    await flushPendingTimers(tester);
  });
}
