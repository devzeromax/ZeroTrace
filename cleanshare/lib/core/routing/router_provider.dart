import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/intro_video_provider.dart';
import '../../providers/onboarding_provider.dart';
import '../../providers/welcome_celebration_provider.dart';
import '../../providers/workflow_provider.dart';
import '../../screens/audit/audit_screen.dart';
import '../../screens/error/error_screen.dart';
import '../../screens/export/export_screen.dart';
import '../../screens/fix/file_preview_comparison_screen.dart';
import '../../screens/fix/fix_review_screen.dart';
import '../../screens/history/scan_detail_screen.dart';
import '../../screens/history/scan_history_screen.dart';
import '../../screens/home/home_screen.dart';
import '../../screens/intro/intro_video_screen.dart';
import '../../screens/marketplace/marketplace_screen.dart';
import '../../screens/onboarding/onboarding_screen.dart';
import '../../screens/welcome/welcome_celebration_screen.dart';
import '../../screens/reports/reports_screen.dart';
import '../../screens/scan/scan_screen.dart';
import '../../screens/settings/legal_notice_screen.dart';
import '../../screens/settings/privacy_policy_screen.dart';
import '../../screens/settings/settings_screen.dart';
import '../../screens/upload/upload_screen.dart';
import '../../widgets/app_shell.dart';
import 'app_routes.dart';
import 'page_transitions.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorHomeKey = GlobalKey<NavigatorState>(debugLabel: 'home');
final _shellNavigatorHistoryKey =
    GlobalKey<NavigatorState>(debugLabel: 'history');
final _shellNavigatorReportsKey =
    GlobalKey<NavigatorState>(debugLabel: 'reports');
final _shellNavigatorSettingsKey =
    GlobalKey<NavigatorState>(debugLabel: 'settings');

final routerRefreshProvider = Provider<Listenable>((ref) {
  final notifier = _RouterRefreshNotifier();
  ref.listen(introVideoProvider, (_, __) => notifier.notify());
  ref.listen(onboardingProvider, (_, __) => notifier.notify());
  ref.listen(welcomeCelebrationProvider, (_, __) => notifier.notify());
  ref.listen(workflowProvider, (_, __) => notifier.notify());
  ref.onDispose(notifier.dispose);
  return notifier;
});

class _RouterRefreshNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}

GoRouter createAppRouter(Ref ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.intro,
    refreshListenable: ref.watch(routerRefreshProvider),
    redirect: (context, state) {
      final intro = ref.read(introVideoProvider);
      final onboarding = ref.read(onboardingProvider);
      final welcome = ref.read(welcomeCelebrationProvider);
      if (intro.isLoading || onboarding.isLoading || welcome.isLoading) {
        return null;
      }

      final introSeen = intro.value ?? false;
      final complete = onboarding.value ?? false;
      final welcomeSeen = welcome.value ?? false;
      final location = state.matchedLocation;
      final onIntro = location == AppRoutes.intro;
      final onOnboarding = location == AppRoutes.onboarding;
      final onWelcome = location == AppRoutes.welcome;

      // First launch only: splash → intro video → onboarding.
      // Returning users (onboarding already complete) skip intro.
      if (!complete && !introSeen && !onIntro) return AppRoutes.intro;
      if (!complete && !introSeen && onIntro) return null;
      if (onIntro) {
        return complete
            ? (welcomeSeen ? AppRoutes.home : AppRoutes.welcome)
            : AppRoutes.onboarding;
      }

      if (!complete && !onOnboarding) return AppRoutes.onboarding;
      if (complete && onOnboarding) {
        return welcomeSeen ? AppRoutes.home : AppRoutes.welcome;
      }
      if (complete && !welcomeSeen && !onWelcome && location == AppRoutes.home) {
        return AppRoutes.welcome;
      }
      if (complete && welcomeSeen && onWelcome) return AppRoutes.home;

      final workflow = ref.read(workflowProvider);
      if (location == AppRoutes.scan && workflow.selectedFile == null) {
        return AppRoutes.upload;
      }
      if (location == AppRoutes.audit && !workflow.hasSession) {
        return AppRoutes.upload;
      }
      if (location == AppRoutes.fix && !workflow.hasSession) {
        return AppRoutes.audit;
      }
      if ((location == AppRoutes.fixPreview ||
              location == AppRoutes.filePreviewComparison) &&
          !workflow.hasSession) {
        return AppRoutes.upload;
      }
      if (location == AppRoutes.export && !workflow.canExportSafeCopy) {
        return AppRoutes.fix;
      }

      return null;
    },
    errorBuilder: (context, state) => ErrorScreen(error: state.error),
    routes: [
      GoRoute(
        path: AppRoutes.intro,
        pageBuilder: (context, state) => appFadeThroughPage(
          key: state.pageKey,
          child: const IntroVideoScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        pageBuilder: (context, state) => appFadeThroughPage(
          key: state.pageKey,
          child: const OnboardingScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.welcome,
        pageBuilder: (context, state) => appFadeThroughPage(
          key: state.pageKey,
          child: const WelcomeCelebrationScreen(),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            navigatorKey: _shellNavigatorHomeKey,
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellNavigatorHistoryKey,
            routes: [
              GoRoute(
                path: AppRoutes.history,
                builder: (context, state) => const ScanHistoryScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    pageBuilder: (context, state) => workflowSharedAxisPage(
                      key: state.pageKey,
                      child: ScanDetailScreen(
                        scanId: state.pathParameters['id']!,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellNavigatorReportsKey,
            routes: [
              GoRoute(
                path: AppRoutes.reports,
                builder: (context, state) => const ReportsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellNavigatorSettingsKey,
            routes: [
              GoRoute(
                path: AppRoutes.settings,
                builder: (context, state) => const SettingsScreen(),
                routes: [
                  GoRoute(
                    path: 'marketplace',
                    pageBuilder: (context, state) => glassSlidePage(
                      key: state.pageKey,
                      child: const MarketplaceScreen(),
                    ),
                  ),
                  GoRoute(
                    path: 'privacy',
                    pageBuilder: (context, state) => glassSlidePage(
                      key: state.pageKey,
                      child: const PrivacyPolicyScreen(),
                    ),
                  ),
                  GoRoute(
                    path: 'legal',
                    pageBuilder: (context, state) => glassSlidePage(
                      key: state.pageKey,
                      child: const LegalNoticeScreen(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.upload,
        pageBuilder: (context, state) => workflowSharedAxisPage(
          key: state.pageKey,
          child: const UploadScreen(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.scan,
        pageBuilder: (context, state) => workflowSharedAxisPage(
          key: state.pageKey,
          child: const ScanScreen(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.audit,
        pageBuilder: (context, state) => workflowSharedAxisPage(
          key: state.pageKey,
          child: const AuditScreen(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.fix,
        pageBuilder: (context, state) => workflowSharedAxisPage(
          key: state.pageKey,
          child: const FixReviewScreen(),
        ),
        routes: [
          GoRoute(
            parentNavigatorKey: _rootNavigatorKey,
            path: 'preview',
            pageBuilder: (context, state) => workflowSharedAxisPage(
              key: state.pageKey,
              child: FilePreviewComparisonScreen(
                fileId: state.uri.queryParameters['fileId'],
              ),
            ),
          ),
        ],
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.filePreviewComparison,
        pageBuilder: (context, state) => workflowSharedAxisPage(
          key: state.pageKey,
          child: FilePreviewComparisonScreen(
            fileId: state.uri.queryParameters['fileId'],
          ),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.export,
        pageBuilder: (context, state) => glassSlidePage(
          key: state.pageKey,
          child: const ExportScreen(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.exportProcessing,
        redirect: (_, __) => AppRoutes.export,
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.exportSuccess,
        redirect: (_, __) => AppRoutes.export,
      ),
    ],
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  return createAppRouter(ref);
});
