import 'package:flutter/material.dart';

import 'package:cleanshare/core/theme/design_tokens.dart';
import 'package:cleanshare/models/app_models.dart';

extension RiskLevelX on RiskLevel {
  String get riskLabel => switch (this) {
        RiskLevel.critical => 'Critical',
        RiskLevel.high => 'High',
        RiskLevel.medium => 'Medium',
        RiskLevel.low => 'Low',
        RiskLevel.none => 'None',
      };

  Color get color => switch (this) {
        RiskLevel.critical => AppColors.riskCritical,
        RiskLevel.high => AppColors.riskHigh,
        RiskLevel.medium => AppColors.riskMedium,
        RiskLevel.low => AppColors.riskLow,
        RiskLevel.none => AppColors.riskNone,
      };

  Color get backgroundColor => backgroundColorFor(Brightness.dark);

  Color backgroundColorFor(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return switch (this) {
      RiskLevel.critical =>
        dark ? AppColors.riskCriticalSubtle : AppColors.riskCriticalSubtleLight,
      RiskLevel.high =>
        dark ? AppColors.riskHighSubtle : AppColors.riskHighSubtleLight,
      RiskLevel.medium =>
        dark ? AppColors.riskMediumSubtle : AppColors.riskMediumSubtleLight,
      RiskLevel.low =>
        dark ? AppColors.riskLowSubtle : AppColors.riskLowSubtleLight,
      RiskLevel.none => dark ? AppColors.surfaceSubtle : AppColors.surfaceSubtleLight,
    };
  }

  Color subtleBackground(BuildContext context) =>
      backgroundColorFor(Theme.of(context).brightness);
}

extension ScanStageX on ScanStage {
  String get stageLabel => switch (this) {
        ScanStage.metadata => 'Metadata analysis',
        ScanStage.faces => 'Face detection',
        ScanStage.qrCodes => 'QR code scan',
        ScanStage.licensePlates => 'License plates',
        ScanStage.documents => 'Document / PII scan',
        ScanStage.report => 'Generating report',
      };

  /// Active-stage copy shown under the progress bar during scan.
  String get progressMessage => switch (this) {
        ScanStage.metadata => 'Checking metadata…',
        ScanStage.faces => 'Scanning for faces…',
        ScanStage.qrCodes => 'Reading QR codes…',
        ScanStage.licensePlates => 'Detecting license plates…',
        ScanStage.documents => 'Reading document text…',
        ScanStage.report => 'Building your report…',
      };
}

extension WorkflowStepX on WorkflowStep {
  String get stepLabel => switch (this) {
        WorkflowStep.upload => 'Add',
        WorkflowStep.scan => 'Scan',
        WorkflowStep.audit => 'Audit',
        WorkflowStep.fix => 'Fix',
        WorkflowStep.export => 'Export',
      };
}
