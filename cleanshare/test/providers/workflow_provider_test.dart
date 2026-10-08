import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cleanshare/data/demo_data.dart';
import 'package:cleanshare/providers/workflow_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> drainHistory(ProviderContainer container) async {
    // Touch history so disk hydrate finishes before container disposal.
    container.read(historyProvider);
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 25));
      if (!container.read(historyHydratingProvider)) return;
    }
  }

  group('WorkflowNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() async {
      await drainHistory(container);
      container.dispose();
    });

    test('selectFile stores file and clears session', () {
      final notifier = container.read(workflowProvider.notifier);
      notifier.selectFile(DemoData.sampleFile);

      final state = container.read(workflowProvider);
      expect(state.selectedFile?.name, DemoData.sampleFile.name);
      expect(state.session, isNull);
    });

    test('completeScan creates session and findings', () async {
      final notifier = container.read(workflowProvider.notifier);
      notifier.selectFile(DemoData.sampleFile);
      notifier.completeScanDemo();
      await drainHistory(container);

      final state = container.read(workflowProvider);
      expect(state.hasSession, isTrue);
      expect(state.findings, isNotEmpty);
    });

    test('toggleFinding updates single finding', () async {
      final notifier = container.read(workflowProvider.notifier);
      notifier.selectFile(DemoData.sampleFile);
      notifier.completeScanDemo();
      await drainHistory(container);

      final id = DemoData.sampleFindings.first.id;
      notifier.toggleFinding(id, true);

      final state = container.read(workflowProvider);
      expect(state.appliedFixCount, 1);
    });

    test('loadFromHistory hydrates workflow for re-export', () async {
      final staged = File(
        '${Directory.systemTemp.path}/zt_staged_${DateTime.now().microsecondsSinceEpoch}.jpg',
      );
      await staged.writeAsBytes([1]);
      addTearDown(() {
        if (staged.existsSync()) staged.deleteSync();
      });

      final notifier = container.read(workflowProvider.notifier);
      final session = DemoData.sampleSession.copyWith(
        stagedFilePath: staged.path,
      );

      notifier.loadFromHistory(session);

      final state = container.read(workflowProvider);
      expect(state.session?.id, session.id);
      expect(state.selectedFile?.localPath, staged.path);
      expect(state.appliedFixCount, greaterThan(0));
      expect(state.canExportSafeCopy, isTrue);
    });

    test('reset clears workflow', () async {
      final notifier = container.read(workflowProvider.notifier);
      notifier.selectFile(DemoData.sampleFile);
      notifier.completeScanDemo();
      await drainHistory(container);
      notifier.reset();

      expect(container.read(workflowProvider).selectedFile, isNull);
    });
  });

  group('HistoryNotifier', () {
    test('upsert replaces session with same id', () async {
      final container = ProviderContainer();
      addTearDown(() async {
        await drainHistory(container);
        container.dispose();
      });

      await drainHistory(container);

      final notifier = container.read(historyProvider.notifier);
      notifier.upsert(DemoData.sampleSession);
      expect(container.read(historyProvider).length, 1);

      notifier.upsert(DemoData.sampleSession);
      expect(container.read(historyProvider).length, 1);
    });

    test('clear removes all sessions', () async {
      final container = ProviderContainer();
      addTearDown(() async {
        await drainHistory(container);
        container.dispose();
      });

      await drainHistory(container);

      container.read(historyProvider.notifier).clear();
      expect(container.read(historyProvider), isEmpty);
    });
  });
}
