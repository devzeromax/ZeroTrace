import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/marketplace/marketplace_models.dart';
import '../infrastructure/marketplace/neural_pack_diagnostics.dart';
import 'engine_providers.dart';

/// Installed ONNX packs that are not scan-ready yet.
final inactiveNeuralPackDiagnosticsProvider =
    FutureProvider<List<NeuralPackDiagnostics>>((ref) async {
  await ref.watch(engineBootstrapProvider.future);
  final layout = ref.watch(zeroTraceLayoutProvider);
  final caps = ref.watch(engineCapabilitiesProvider);
  final marketplace = ref.watch(marketplaceServiceProvider);
  final items = await marketplace.listItems();

  final issues = <NeuralPackDiagnostics>[];
  for (final item in items.where((i) => i.entry.manifest.isOnnx)) {
    final installed = item.installState == ModelInstallState.installed ||
        item.installState == ModelInstallState.updateAvailable;
    final diagnostics = await NeuralPackDiagnostics.inspectPack(
      layout: layout,
      packId: item.entry.id,
      onnxRuntimeAvailable: caps.onnxRuntimeAvailable,
      installed: installed,
    );
    if (diagnostics.installed && !diagnostics.isOperational) {
      issues.add(diagnostics);
    }
  }
  return issues;
});

/// Back-compat for screens that only surface face-pack status.
final facePackDiagnosticsProvider =
    FutureProvider<NeuralPackDiagnostics?>((ref) async {
  final issues = await ref.watch(inactiveNeuralPackDiagnosticsProvider.future);
  for (final issue in issues) {
    if (issue.packId == 'face-protection') return issue;
  }
  return null;
});
