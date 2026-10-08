import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';

import '../../core/platform/media_permissions.dart';
import '../../core/platform/platform_storage.dart';
import '../../core/routing/app_routes.dart';
import '../../core/routing/workflow_navigation.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/utils/user_facing_error.dart';
import '../../models/app_models.dart';
import '../../providers/engine_providers.dart';
import '../../providers/workflow_provider.dart';
import '../../widgets/file_card.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/upload_drop_zone.dart';
import '../../widgets/workflow_page.dart';

class UploadScreen extends ConsumerWidget {
  const UploadScreen({super.key});

  static const _allowedExtensions = [
    'jpg',
    'jpeg',
    'png',
    'pdf',
    'heic',
    'docx',
    'xlsx',
    'pptx',
    'zip',
    'txt',
    'json',
    'yaml',
    'yml',
    'xml',
    'env',
    'md',
    'csv',
    'js',
    'ts',
    'py',
    'dart',
  ];

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _extensionToType(String ext) => ext.toUpperCase();

  Future<void> _pickFile(BuildContext context, WidgetRef ref) async {
    await MediaPermissions.ensureForFilePicker(context);
    if (!context.mounted) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _allowedExtensions,
      withData: !PlatformStorage.supportsLocalFileSystem,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final name = file.name;
    final ext = name.contains('.') ? name.split('.').last : 'FILE';
    final bytes = file.size;

    String? localPath;
    Object? stagingError;
    try {
      await ref.read(engineBootstrapProvider.future);
      final staging = ref.read(fileStagingProvider);
      if (file.path != null && PlatformStorage.supportsLocalFileSystem) {
        final input = await staging.stageFromPicker(
          sourcePath: file.path!,
          fileName: name,
          sizeBytes: bytes,
        );
        localPath = input.filePath;
      } else if (file.bytes != null) {
        final input = await staging.stageFromBytes(
          bytes: file.bytes!,
          fileName: name,
        );
        localPath = input.filePath;
      }
    } catch (e) {
      stagingError = e;
    }

    if (localPath == null && PlatformStorage.supportsLocalFileSystem) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              stagingError != null
                  ? UserFacingError.message(stagingError)
                  : 'File path unavailable. Pick the file again.',
            ),
          ),
        );
      }
      return;
    }

    ref.read(workflowProvider.notifier).selectFile(
          SelectedFile(
            name: name,
            size: _formatBytes(bytes),
            type: _extensionToType(ext),
            sizeBytes: bytes,
            localPath: localPath,
          ),
        );
  }

  void _clearFile(WidgetRef ref) {
    ref.read(workflowProvider.notifier).selectFile(null);
  }

  Future<void> _useSampleFile(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(engineBootstrapProvider.future);
      final data = await rootBundle.load('assets/samples/sample_invoice.jpg');
      final bytes = data.buffer.asUint8List();
      final staging = ref.read(fileStagingProvider);
      final input = await staging.stageFromBytes(
        bytes: bytes,
        fileName: 'sample_invoice.jpg',
      );
      ref.read(workflowProvider.notifier).selectFile(
            SelectedFile(
              name: 'sample_invoice.jpg',
              size: _formatBytes(bytes.length),
              type: 'JPEG',
              sizeBytes: bytes.length,
              localPath: input.filePath,
            ),
          );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(UserFacingError.message(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workflow = ref.watch(workflowProvider);
    final selectedFile = workflow.selectedFile;
    final deepScan = workflow.scanConfig.deepAiScan;
    final colorScheme = Theme.of(context).colorScheme;

    return WorkflowPage(
      title: 'Add file',
      currentStep: WorkflowStep.upload,
      centerBody: selectedFile == null,
      leading: WorkflowCloseButton(
        onPressed: () => WorkflowNavigation.exitUpload(context, ref),
      ),
      body: selectedFile == null
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                UploadDropZone(onTap: () => _pickFile(context, ref)),
                const SizedBox(height: AppSpacing.x4),
                TextButton.icon(
                  onPressed: () => _useSampleFile(context, ref),
                  icon: const Icon(Icons.science_outlined, size: 18),
                  label: const Text('Try sample invoice'),
                ),
              ],
            )
          : ListView(
              children: [
                FileCard(
                  fileName: selectedFile.name,
                  fileSize: selectedFile.size,
                  fileType: selectedFile.type,
                  trailing: IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => _clearFile(ref),
                    tooltip: 'Remove file',
                  ),
                ),
                const SizedBox(height: AppSpacing.x3),
                Text(
                  'Ready to scan',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: AppSpacing.x1),
                Text(
                  'Review your file options, then start the audit.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: AppSpacing.x5),
                _DeepScanCard(
                  value: deepScan,
                  colorScheme: colorScheme,
                  onChanged: (v) => ref
                      .read(workflowProvider.notifier)
                      .toggleScanOption(deepAiScan: v),
                ),
              ],
            ),
      bottomBar: WorkflowBottomBar(
        child: PrimaryButton(
          label: 'Start scan',
          icon: Icons.radar_outlined,
          onPressed: selectedFile != null &&
                  (selectedFile.localPath != null ||
                      !PlatformStorage.supportsLocalFileSystem)
              ? () => context.push(AppRoutes.scan)
              : null,
        ),
      ),
    );
  }
}

class _DeepScanCard extends StatelessWidget {
  const _DeepScanCard({
    required this.value,
    required this.colorScheme,
    required this.onChanged,
  });

  final bool value;
  final ColorScheme colorScheme;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Deep AI scan',
      child: Material(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        child: SwitchListTile(
          value: value,
          onChanged: onChanged,
          secondary: Icon(
            Icons.psychology_outlined,
            color: value
                ? CosmosColors.concentricTeal
                : colorScheme.onSurfaceVariant,
          ),
          title: const Text(
            'Deep AI scan',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: const Text(
            'Uses optional document OCR packs when installed. '
            'Slightly slower scan.',
          ),
        ),
      ),
    );
  }
}
