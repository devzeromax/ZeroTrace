import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/intro_video_storage.dart';

final introVideoProvider =
    AsyncNotifierProvider<IntroVideoNotifier, bool>(IntroVideoNotifier.new);

class IntroVideoNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() => IntroVideoStorage.hasSeen();

  Future<void> markSeen() async {
    await IntroVideoStorage.setSeen(value: true);
    state = const AsyncData(true);
  }

  Future<void> reset() async {
    await IntroVideoStorage.setSeen(value: false);
    state = const AsyncData(false);
  }
}
