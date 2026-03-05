/**
 * WHAT:
 * TeacherAnalyticsScreen renders student analytics from SessionLog-backed
 * teacher endpoints.
 * WHY:
 * Teachers need one dashboard to review XP trends, lesson-slot performance,
 * subject outcomes, and behaviour signals without recalculating metrics.
 * HOW:
 * Fetch dedicated analytics endpoints once, then show chart-like panels with
 * progress bars and comparative summaries.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/constants/app_palette.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/focus_mission_api.dart';
import '../../../shared/models/focus_mission_models.dart';
import '../../../shared/widgets/focus_scaffold.dart';
import '../../../shared/widgets/soft_panel.dart';
import '../models/analytics_models.dart';

class TeacherAnalyticsScreen extends StatefulWidget {
  const TeacherAnalyticsScreen({
    super.key,
    required this.session,
    required this.student,
  });

  final AuthSession session;
  final StudentSummary student;

  @override
  State<TeacherAnalyticsScreen> createState() => _TeacherAnalyticsScreenState();
}

class _TeacherAnalyticsScreenState extends State<TeacherAnalyticsScreen> {
  final FocusMissionApi _api = FocusMissionApi();
  late Future<_TeacherAnalyticsBundle> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadAnalytics();
  }

  Future<_TeacherAnalyticsBundle> _loadAnalytics() async {
    final results = await Future.wait<dynamic>([
      _api.getDailyTrend(
        token: widget.session.token,
        studentId: widget.student.id,
      ),
      _api.getSessionBreakdown(
        token: widget.session.token,
        studentId: widget.student.id,
      ),
      _api.getSubjectAnalytics(
        token: widget.session.token,
        studentId: widget.student.id,
      ),
      _api.getBehaviourTrend(
        token: widget.session.token,
        studentId: widget.student.id,
      ),
    ]);

    return _TeacherAnalyticsBundle(
      dailyTrend: results[0] as List<DailyTrendPoint>,
      sessionBreakdown: results[1] as List<SessionBreakdown>,
      subjectAnalytics: results[2] as List<SubjectAnalytics>,
      behaviourTrend: results[3] as List<BehaviourDistribution>,
    );
  }

  void _refresh() {
    setState(() {
      _future = _loadAnalytics();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FocusScaffold(
      child: FutureBuilder<_TeacherAnalyticsBundle>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _LoadingState(label: 'Loading analytics...');
          }

          if (snapshot.hasError) {
            return _ErrorState(
              message: snapshot.error.toString(),
              onBack: () => Navigator.of(context).pop(),
            );
          }

          final analytics = snapshot.data!;
          final totalXp = analytics.dailyTrend.fold<int>(
            0,
            (sum, item) => sum + item.totalXp,
          );
          final totalSessions = analytics.sessionBreakdown.fold<int>(
            0,
            (sum, item) => sum + item.sessions,
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.screen),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    Expanded(
                      child: Text(
                        '${widget.student.name} Analytics',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    IconButton(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.item),
                SoftPanel(
                  colors: const [Color(0xFFEFF7FF), Color(0xFFF8FDFF)],
                  child: Wrap(
                    spacing: AppSpacing.item,
                    runSpacing: AppSpacing.item,
                    children: [
                      _MetricPill(label: 'Total XP', value: '$totalXp'),
                      _MetricPill(label: 'Sessions', value: '$totalSessions'),
                      _MetricPill(
                        label: 'Tracked subjects',
                        value: '${analytics.subjectAnalytics.length}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.item),
                _SectionPanel(
                  title: 'Daily XP Trend',
                  subtitle: 'Total vs performance vs target XP by date.',
                  child: _DailyTrendChart(points: analytics.dailyTrend),
                ),
                const SizedBox(height: AppSpacing.item),
                _SectionPanel(
                  title: 'Session Breakdown',
                  subtitle: 'Morning vs afternoon averages and totals.',
                  child: _SessionBreakdownChart(
                    points: analytics.sessionBreakdown,
                  ),
                ),
                const SizedBox(height: AppSpacing.item),
                _SectionPanel(
                  title: 'Subject Analytics',
                  subtitle: 'Average score and XP by subject.',
                  child: _SubjectAnalyticsChart(
                    points: analytics.subjectAnalytics,
                  ),
                ),
                const SizedBox(height: AppSpacing.item),
                _SectionPanel(
                  title: 'Behaviour Distribution',
                  subtitle: 'Session count by behaviour status.',
                  child: _BehaviourChart(points: analytics.behaviourTrend),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TeacherAnalyticsBundle {
  const _TeacherAnalyticsBundle({
    required this.dailyTrend,
    required this.sessionBreakdown,
    required this.subjectAnalytics,
    required this.behaviourTrend,
  });

  final List<DailyTrendPoint> dailyTrend;
  final List<SessionBreakdown> sessionBreakdown;
  final List<SubjectAnalytics> subjectAnalytics;
  final List<BehaviourDistribution> behaviourTrend;
}

class _SectionPanel extends StatelessWidget {
  const _SectionPanel({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SoftPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppPalette.textMuted),
          ),
          const SizedBox(height: AppSpacing.item),
          child,
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.item,
        vertical: AppSpacing.compact,
      ),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppPalette.textMuted),
          ),
        ],
      ),
    );
  }
}

class _DailyTrendChart extends StatelessWidget {
  const _DailyTrendChart({required this.points});

  final List<DailyTrendPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const Text('No session logs yet for this date range.');
    }

    final maxTotal = points.map((item) => item.totalXp).fold<int>(1, math.max);

    return Column(
      children: points
          .map((point) {
            final totalRatio = point.totalXp / maxTotal;
            final performanceRatio = point.performanceXp / maxTotal;
            final targetRatio = point.targetXp / maxTotal;

            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.compact),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          point.date,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      Text(
                        '${point.totalXp} XP',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _StackedBar(
                    totalRatio: totalRatio,
                    performanceRatio: performanceRatio,
                    targetRatio: targetRatio,
                  ),
                ],
              ),
            );
          })
          .toList(growable: false),
    );
  }
}

class _StackedBar extends StatelessWidget {
  const _StackedBar({
    required this.totalRatio,
    required this.performanceRatio,
    required this.targetRatio,
  });

  final double totalRatio;
  final double performanceRatio;
  final double targetRatio;

  @override
  Widget build(BuildContext context) {
    final clampedTotal = totalRatio.clamp(0, 1).toDouble();
    final clampedPerformance = performanceRatio
        .clamp(0, clampedTotal)
        .toDouble();
    final clampedTarget = targetRatio
        .clamp(0, math.max(0, clampedTotal - clampedPerformance))
        .toDouble();

    return LayoutBuilder(
      builder: (context, constraints) {
        final fullWidth = constraints.maxWidth;
        final totalWidth = fullWidth * clampedTotal;
        final performanceWidth = fullWidth * clampedPerformance;
        final targetWidth = fullWidth * clampedTarget;

        return Container(
          height: 12,
          decoration: BoxDecoration(
            color: const Color(0xFFE9EEF9),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Stack(
            children: [
              Container(
                width: totalWidth,
                decoration: BoxDecoration(
                  color: AppPalette.sky,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Container(
                width: performanceWidth,
                decoration: BoxDecoration(
                  color: AppPalette.primaryBlue,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Positioned(
                left: performanceWidth,
                child: Container(
                  width: targetWidth,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppPalette.mint,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SessionBreakdownChart extends StatelessWidget {
  const _SessionBreakdownChart({required this.points});

  final List<SessionBreakdown> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const Text('No morning/afternoon session data yet.');
    }

    final maxXp = points.map((item) => item.totalXp).fold<int>(1, math.max);

    return Column(
      children: points
          .map((point) {
            final ratio = point.totalXp / maxXp;
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.compact),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${point.sessionType} · sessions ${point.sessions} · score ${point.avgScore}% · focus ${point.avgFocus}%',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    minHeight: 10,
                    value: ratio.clamp(0, 1).toDouble(),
                    borderRadius: BorderRadius.circular(99),
                    backgroundColor: const Color(0xFFE9EEF9),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppPalette.primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${point.totalXp} XP',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppPalette.textMuted,
                    ),
                  ),
                ],
              ),
            );
          })
          .toList(growable: false),
    );
  }
}

class _SubjectAnalyticsChart extends StatelessWidget {
  const _SubjectAnalyticsChart({required this.points});

  final List<SubjectAnalytics> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const Text('No subject analytics data yet.');
    }

    return Column(
      children: points
          .map((point) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.compact),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Subject ${point.subjectId} · sessions ${point.sessions}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    minHeight: 10,
                    value: (point.avgScore / 100).clamp(0, 1).toDouble(),
                    borderRadius: BorderRadius.circular(99),
                    backgroundColor: const Color(0xFFE9EEF9),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppPalette.mint,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Avg score ${point.avgScore}% · ${point.totalXp} XP',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppPalette.textMuted,
                    ),
                  ),
                ],
              ),
            );
          })
          .toList(growable: false),
    );
  }
}

class _BehaviourChart extends StatelessWidget {
  const _BehaviourChart({required this.points});

  final List<BehaviourDistribution> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const Text('No behaviour records yet.');
    }

    final total = points.fold<int>(0, (sum, item) => sum + item.count);
    final safeTotal = math.max(total, 1);

    return Column(
      children: points
          .map((point) {
            final ratio = point.count / safeTotal;
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.compact),
              child: Row(
                children: [
                  SizedBox(
                    width: 96,
                    child: Text(
                      point.behaviourStatus,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  Expanded(
                    child: LinearProgressIndicator(
                      minHeight: 10,
                      value: ratio.clamp(0, 1).toDouble(),
                      borderRadius: BorderRadius.circular(99),
                      backgroundColor: const Color(0xFFE9EEF9),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppPalette.orange,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.compact),
                  Text(
                    '${point.count}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            );
          })
          .toList(growable: false),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.screen),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.item),
            Text(label),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onBack});

  final String message;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.screen),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: AppPalette.navy,
            ),
            const SizedBox(height: AppSpacing.item),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: AppPalette.navy),
            ),
            const SizedBox(height: AppSpacing.item),
            TextButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Back'),
            ),
          ],
        ),
      ),
    );
  }
}
