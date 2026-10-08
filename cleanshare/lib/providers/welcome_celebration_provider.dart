import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/welcome_celebration_storage.dart';

final welcomeCelebrationProvider =
    AsyncNotifierProvider<WelcomeCelebrationNotifier, bool>(
  WelcomeCelebrationNotifier.new,
);

class WelcomeCelebrationNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() => WelcomeCelebrationStorage.hasSeen();

  Future<void> markSeen() async {
    await WelcomeCelebrationStorage.setSeen(value: true);
    state = const AsyncData(true);
  }

  Future<void> reset() async {
    await WelcomeCelebrationStorage.setSeen(value: false);
    state = const AsyncData(false);
  }
}
