import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/animation/app_motion.dart';
import '../../core/layout/shell_scroll_padding.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/design_tokens.dart';
import '../../models/app_models.dart';
import '../../providers/workflow_provider.dart';
import '../../core/theme/glass_scene.dart';
import '../../widgets/premium_page.dart';
import '../../widgets/shell_page_header.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/recent_scan_row.dart';
import '../../widgets/skeleton.dart';

enum _HistoryRiskFilter { all, critical, high, medium, clean }

class ScanHistoryScreen extends ConsumerStatefulWidget {
  const ScanHistoryScreen({super.key});

  @override
  ConsumerState<ScanHistoryScreen> createState() => _ScanHistoryScreenState();
}

class _ScanHistoryScreenState extends ConsumerState<ScanHistoryScreen> {
  final _query = TextEditingController();
  _HistoryRiskFilter _filter = _HistoryRiskFilter.all;
  final _selected = <String>{};
  var _selecting = false;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  List<ScanSession> _filtered(List<ScanSession> sessions) {
    final q = _query.text.trim().toLowerCase();
    return sessions.where((s) {
      if (q.isNotEmpty && !s.fileName.toLowerCase().contains(q)) {
        return false;
      }
      final open = s.findings.where((f) => !f.isFixed).length;
      return switch (_filter) {
        _HistoryRiskFilter.all => true,
        _HistoryRiskFilter.clean => open == 0,
        _HistoryRiskFilter.critical => s.criticalCount > 0,
        _HistoryRiskFilter.high => s.highCount > 0 || s.criticalCount > 0,
        _HistoryRiskFilter.medium =>
          s.mediumCount > 0 || s.highCount > 0 || s.criticalCount > 0,
      };
    }).toList();
  }

  Future<void> _deleteIds(Iterable<String> ids) async {
    final notifier = ref.read(historyProvider.notifier);
    for (final id in ids) {
      await notifier.remove(id);
    }
    setState(() {
      _selected.clear();
      _selecting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(historyProvider);
    final hydrating = ref.watch(historyHydratingProvider);
    final listPadding = ShellScrollPadding.list(context);
    final filtered = _filtered(sessions);
    final colorScheme = Theme.of(context).colorScheme;

    return PremiumPage(
      scene: GlassScene.history,
      body: ContentRevealSwap(
        showPlaceholder: hydrating && sessions.isEmpty,
        placeholder: ListView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.marginMobile,
            AppSpacing.marginMobile,
            AppSpacing.marginMobile,
            listPadding.bottom,
          ),
          children: const [
            ShellPageHeader(
              title: 'Scan history',
              subtitle: 'Recent scans saved on this device.',
            ),
            SizedBox(height: AppSpacing.x4),
            RecentScanRowSkeleton(),
            SizedBox(height: AppSpacing.x2),
            RecentScanRowSkeleton(),
            SizedBox(height: AppSpacing.x2),
            RecentScanRowSkeleton(),
          ],
        ),
        content: sessions.isEmpty
            ? Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.marginMobile,
                  AppSpacing.marginMobile,
                  AppSpacing.marginMobile,
                  listPadding.bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const ShellPageHeader(
                      title: 'Scan history',
                      subtitle: 'Recent scans saved on this device.',
                    ),
                    Expanded(
                      child: EmptyStatePanel(
                        scene: GlassScene.history,
                        title: 'No scans yet',
                        description:
                            'Complete a scan and it will show up here.',
                        action: PrimaryButton(
                          label: 'Add file',
                          onPressed: () => context.push(AppRoutes.upload),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(
                        AppSpacing.marginMobile,
                        AppSpacing.marginMobile,
                        AppSpacing.marginMobile,
                        listPadding.bottom,
                      ),
                      children: [
                        ShellPageHeader(
                          title: 'Scan history',
                          subtitle: 'Recent scans saved on this device.',
                          actions: [
                            IconButton(
                              tooltip: _selecting ? 'Done' : 'Select',
                              icon: Icon(
                                _selecting
                                    ? Icons.check_circle_outline
                                    : Icons.checklist_outlined,
                              ),
                              onPressed: () => setState(() {
                                _selecting = !_selecting;
                                if (!_selecting) _selected.clear();
                              }),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.x3),
                        TextField(
                          controller: _query,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: 'Search by file name',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _query.text.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: 'Clear search',
                                    icon: const Icon(Icons.close),
                                    onPressed: () {
                                      _query.clear();
                                      setState(() {});
                                    },
                                  ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.x3),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final filter in _HistoryRiskFilter.values)
                                Padding(
                                  padding:
                                      const EdgeInsets.only(right: AppSpacing.x2),
                                  child: FilterChip(
                                    label: Text(switch (filter) {
                                      _HistoryRiskFilter.all => 'All',
                                      _HistoryRiskFilter.critical => 'Critical',
                                      _HistoryRiskFilter.high => 'High+',
                                      _HistoryRiskFilter.medium => 'Medium+',
                                      _HistoryRiskFilter.clean => 'Clean',
                                    }),
                                    selected: _filter == filter,
                                    onSelected: (_) =>
                                        setState(() => _filter = filter),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.x4),
                        if (filtered.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.x8),
                            child: Text(
                              'No scans match this filter.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          )
                        else
                          ...filtered.asMap().entries.map((entry) {
                            final index = entry.key;
                            final session = entry.value;
                            final selected = _selected.contains(session.id);
                            return FadeSlideIn(
                              index: index,
                              delay: AppMotion.staggerDelay(index),
                              child: Padding(
                                padding:
                                    const EdgeInsets.only(bottom: AppSpacing.x2),
                                child: Dismissible(
                                  key: ValueKey(session.id),
                                  direction: _selecting
                                      ? DismissDirection.none
                                      : DismissDirection.endToStart,
                                  background: Container(
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(
                                      right: AppSpacing.x5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colorScheme.errorContainer,
                                      borderRadius:
                                          BorderRadius.circular(AppRadius.md),
                                    ),
                                    child: Icon(
                                      Icons.delete_outline,
                                      color: colorScheme.onErrorContainer,
                                    ),
                                  ),
                                  confirmDismiss: (_) async {
                                    await _deleteIds([session.id]);
                                    return false;
                                  },
                                  child: Row(
                                    children: [
                                      if (_selecting)
                                        Checkbox(
                                          value: selected,
                                          onChanged: (v) => setState(() {
                                            if (v == true) {
                                              _selected.add(session.id);
                                            } else {
                                              _selected.remove(session.id);
                                            }
                                          }),
                                        ),
                                      Expanded(
                                        child: RecentScanRow(
                                          session: session,
                                          onTap: () {
                                            if (_selecting) {
                                              setState(() {
                                                if (selected) {
                                                  _selected.remove(session.id);
                                                } else {
                                                  _selected.add(session.id);
                                                }
                                              });
                                              return;
                                            }
                                            context.push(
                                              AppRoutes.scanDetail(session.id),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                  if (_selecting && _selected.isNotEmpty)
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.x4),
                        child: PrimaryButton(
                          label: 'Delete ${_selected.length} selected',
                          icon: Icons.delete_outline,
                          onPressed: () => _deleteIds(_selected.toList()),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
