import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cleanshare/core/layout/shell_scroll_padding.dart';
import 'package:cleanshare/core/theme/design_tokens.dart';

void main() {
  testWidgets('topOf includes status bar inset plus breathing room', (tester) async {
    const statusBar = 44.0;
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(padding: EdgeInsets.only(top: statusBar)),
          child: _Probe(),
        ),
      ),
    );

    expect(
      ShellScrollPadding.topOf(tester.element(find.byType(_Probe))),
      statusBar + ShellScrollPadding.topBreathingRoom,
    );
    expect(ShellScrollPadding.topBreathingRoom, AppSpacing.x4);
  });
}

class _Probe extends StatelessWidget {
  const _Probe();

  @override
  Widget build(BuildContext context) => const SizedBox();
}
