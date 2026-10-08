import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/onboarding_storage.dart';

final onboardingProvider =
    AsyncNotifierProvider<OnboardingNotifier, bool>(OnboardingNotifier.new);

class OnboardingNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() => OnboardingStorage.isComplete();

  Future<void> markComplete() async {
    await OnboardingStorage.setComplete(value: true);
    state = const AsyncData(true);
  }

  Future<void> reset() async {
    await OnboardingStorage.setComplete(value: false);
    state = const AsyncData(false);
  }
}
