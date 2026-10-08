import 'package:flutter_test/flutter_test.dart';

import 'package:cleanshare/core/constants/app_sounds.dart';

void main() {
  test('sound assets are categorized for export vs UI confirm', () {
    expect(AppSounds.exportSuccess, endsWith('export_success.mp3'));
    expect(AppSounds.uiConfirm, endsWith('ui_confirm.wav'));
    expect(AppSounds.exportSuccess, isNot(AppSounds.uiConfirm));
  });
}
