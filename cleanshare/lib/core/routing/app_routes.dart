abstract final class AppRoutes {
  static const intro = '/intro';
  static const onboarding = '/onboarding';
  static const welcome = '/welcome';
  static const home = '/';
  static const upload = '/upload';
  static const scan = '/scan';
  static const audit = '/audit';
  static const fix = '/fix';
  static const fixPreview = '/fix/preview';
  static const filePreviewComparison = '/filePreviewComparison';
  static const export = '/export';
  static const exportProcessing = '/export/processing';
  static const exportSuccess = '/export/success';
  static const history = '/history';
  static const reports = '/reports';
  static const settings = '/settings';
  static const marketplace = '/settings/marketplace';
  static const privacyPolicy = '/settings/privacy';
  static const legalNotice = '/settings/legal';

  static String scanDetail(String id) => '$history/$id';
}
