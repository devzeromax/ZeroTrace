import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cleanshare/providers/onboarding_provider.dart';

void main() {
  group('OnboardingNotifier', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('starts incomplete when preference unset', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(onboardingProvider.future);
      expect(container.read(onboardingProvider).value, false);
    });

    test('markComplete persists completion', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(onboardingProvider.future);
      await container.read(onboardingProvider.notifier).markComplete();

      expect(container.read(onboardingProvider).value, true);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('onboarding_complete'), true);
    });
  });
}
