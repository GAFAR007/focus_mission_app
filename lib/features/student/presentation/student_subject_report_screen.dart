/**
 * WHAT:
 * StudentSubjectReportScreen shows one subject's assessment progress,
 * certification progress, and completed mission history in a read-only view.
 * WHY:
 * Students need one calm place to see what task focuses are left to pass and
 * which completed mission results already count toward certification.
 * HOW:
 * Load the subject report from the student API, render summary panels, and let
 * the student open individual completed result packages in a read-only screen.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'package:flutter/material.dart';

import '../../../core/constants/app_palette.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/focus_mission_api.dart';
import '../../../shared/models/focus_mission_models.dart';
import '../../../shared/widgets/focus_scaffold.dart';
import '../../../shared/widgets/soft_panel.dart';
import 'student_result_report_screen.dart';

Color _subjectReportParseColor(String? value) {
  final raw = (value ?? '').trim();
  if (raw.isEmpty) {
    return AppPalette.primaryBlue;
  }
  final normalized = raw.startsWith('#') ? raw.substring(1) : raw;
  if (normalized.length != 6) {
    return AppPalette.primaryBlue;
  }
  final parsed = int.tryParse(normalized, radix: 16);
  if (parsed == null) {
    return AppPalette.primaryBlue;
  }
  return Color(0xFF000000 | parsed);
}

IconData _subjectReportIcon(String subjectName, String rawIcon) {
  final source = '${subjectName.toLowerCase()} ${rawIcon.toLowerCase()}';
  if (source.contains('sport')) {
    return Icons.sports_soccer_rounded;
  }
  if (source.contains('science')) {
    return Icons.science_rounded;
  }
  if (source.contains('business')) {
    return Icons.work_rounded;
  }
  if (source.contains('english')) {
    return Icons.menu_book_rounded;
  }
  if (source.contains('math')) {
    return Icons.calculate_rounded;
  }
  if (source.contains('health')) {
    return Icons.favorite_rounded;
  }
  if (source.contains('ict') || source.contains('comput')) {
    return Icons.computer_rounded;
  }
  if (source.contains('art')) {
    return Icons.palette_rounded;
  }
  if (source.contains('re')) {
    return Icons.auto_stories_rounded;
  }
  return Icons.school_rounded;
}

String _subjectReportFormatDate(String? value) {
  if (value == null || value.trim().isEmpty) {
    return '-';
  }
  final parsed = DateTime.tryParse(value)?.toLocal();
  if (parsed == null) {
    return value;
  }
  final month = parsed.month.toString().padLeft(2, '0');
  final day = parsed.day.toString().padLeft(2, '0');
  return '${parsed.year}-$month-$day';
}

String _subjectReportFormatDateTime(String? value) {
  if (value == null || value.trim().isEmpty) {
    return '-';
  }
  final parsed = DateTime.tryParse(value)?.toLocal();
  if (parsed == null) {
    return value;
  }
  final month = parsed.month.toString().padLeft(2, '0');
  final day = parsed.day.toString().padLeft(2, '0');
  final hour = parsed.hour.toString().padLeft(2, '0');
  final minute = parsed.minute.toString().padLeft(2, '0');
  return '${parsed.year}-$month-$day $hour:$minute';
}

String _subjectReportFormatOneDecimal(double value) {
  return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
}

class StudentSubjectReportScreen extends StatefulWidget {
  const StudentSubjectReportScreen({
    super.key,
    required this.session,
    required this.subjectId,
    this.api,
  });

  final AuthSession session;
  final String subjectId;
  final FocusMissionApi? api;

  @override
  State<StudentSubjectReportScreen> createState() =>
      _StudentSubjectReportScreenState();
}

class _StudentSubjectReportScreenState extends State<StudentSubjectReportScreen> {
  late final FocusMissionApi _api;
  late Future<StudentSubjectReportData> _future;

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? FocusMissionApi();
    _future = _api.fetchStudentSubjectReport(
      token: widget.session.token,
      studentId: widget.session.user.id,
      subjectId: widget.subjectId,
    );
  }

  Future<void> _openResult(String resultPackageId) async {
    if (resultPackageId.trim().isEmpty) {
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => StudentResultReportScreen(
          session: widget.session,
          resultPackageId: resultPackageId,
          api: _api,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _future = _api.fetchStudentSubjectReport(
        token: widget.session.token,
        studentId: widget.session.user.id,
        subjectId: widget.subjectId,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return FocusScaffold(
      child: FutureBuilder<StudentSubjectReportData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _StudentSubjectErrorState(
              message: snapshot.error.toString(),
              onBack: () => Navigator.of(context).pop(),
            );
          }

          final report = snapshot.data!;
          final subjectColor = _subjectReportParseColor(report.subject.color);
          final passedCount = report.certification.passedTaskCodes.length;
          final requiredCount = report.certification.requiredTaskCodes.length;
          final remaining = report.certification.remainingTaskCodes;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.screen),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StudentSubjectHeader(
                  title: report.subject.name,
                  subtitle: 'Subject report',
                  onBack: () => Navigator.of(context).pop(),
                ),
                const SizedBox(height: AppSpacing.section),
                SoftPanel(
                  colors: [
                    subjectColor.withValues(alpha: 0.22),
                    Colors.white.withValues(alpha: 0.82),
                  ],
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: subjectColor,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Icon(
                          _subjectReportIcon(report.subject.name, report.subject.icon ?? ''),
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.item),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              report.subject.name,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              report.certification.certificateUnlocked
                                  ? 'Certificate unlocked for this subject.'
                                  : report.certification.certificationEnabled
                                      ? '$passedCount of $requiredCount task focuses passed. ${remaining.isEmpty ? 'Teacher review may still be pending.' : 'Still needed: ${remaining.join(', ')}'}'
                                      : 'Assessment history and completed mission results are ready here.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(color: AppPalette.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.section),
                _StudentCertificationPanel(
                  certification: report.certification,
                  onOpenResult: _openResult,
                ),
                const SizedBox(height: AppSpacing.section),
                _StudentAssessmentPanel(progress: report.assessmentProgress),
                const SizedBox(height: AppSpacing.section),
                _StudentMissionHistoryPanel(
                  history: report.missionHistory,
                  onOpenResult: _openResult,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StudentSubjectHeader extends StatelessWidget {
  const _StudentSubjectHeader({
    required this.title,
    required this.subtitle,
    required this.onBack,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        InkWell(
          onTap: onBack,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.76),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: AppPalette.navy,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppPalette.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StudentCertificationPanel extends StatelessWidget {
  const _StudentCertificationPanel({
    required this.certification,
    required this.onOpenResult,
  });

  final SubjectCertificationSummary certification;
  final ValueChanged<String> onOpenResult;

  CertificationEvidenceRow? _evidenceForTaskCode(String taskCode) {
    for (final row in certification.evidenceRows) {
      if (row.taskCode == taskCode) {
        return row;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (!certification.certificationEnabled) {
      return SoftPanel(
        colors: const [Color(0xFFF7FBFF), Color(0xFFEAF4FF)],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Task-focus certification',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.item),
            Text(
              'No certification template is active for this subject yet.',
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(color: AppPalette.textMuted),
            ),
          ],
        ),
      );
    }

    return SoftPanel(
      colors: certification.certificateUnlocked
          ? const [Color(0xFFF4FFF7), Color(0xFFE8FFF1)]
          : const [Color(0xFFFFFBF3), Color(0xFFFFF0D8)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      certification.certificationLabel,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      certification.certificateUnlocked
                          ? 'All required task focuses are complete.'
                          : certification.remainingTaskCodes.isEmpty
                              ? 'Teacher review may still be pending for your latest evidence.'
                              : 'Still needed: ${certification.remainingTaskCodes.join(', ')}',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppPalette.textMuted),
                    ),
                  ],
                ),
              ),
              _StudentLabelPill(
                label: certification.certificateUnlocked
                    ? 'Certificate unlocked'
                    : '${certification.passedTaskCodes.length}/${certification.requiredTaskCodes.length} passed',
                background: certification.certificateUnlocked
                    ? const Color(0xFFE8FFF0)
                    : Colors.white.withValues(alpha: 0.76),
                foreground: certification.certificateUnlocked
                    ? const Color(0xFF157347)
                    : AppPalette.navy,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.item),
          LinearProgressIndicator(
            minHeight: 10,
            value: (certification.completionPercentage / 100).clamp(0, 1),
            borderRadius: BorderRadius.circular(999),
            backgroundColor: Colors.white.withValues(alpha: 0.66),
            valueColor: AlwaysStoppedAnimation<Color>(
              certification.certificateUnlocked ? AppPalette.mint : AppPalette.sun,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${certification.completionPercentage}% complete · Average on passed task focuses ${_subjectReportFormatOneDecimal(certification.averagePassedScorePercent)}%',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.section),
          ...certification.requiredTaskCodes.map((taskCode) {
            final evidence = _evidenceForTaskCode(taskCode);
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.item),
              child: _StudentTaskFocusRow(
                taskCode: taskCode,
                evidence: evidence,
                onOpenResult: onOpenResult,
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _StudentTaskFocusRow extends StatelessWidget {
  const _StudentTaskFocusRow({
    required this.taskCode,
    required this.evidence,
    required this.onOpenResult,
  });

  final String taskCode;
  final CertificationEvidenceRow? evidence;
  final ValueChanged<String> onOpenResult;

  @override
  Widget build(BuildContext context) {
    final status = evidence?.status ?? 'not_started';
    final style = _taskFocusStatusStyle(status);
    final scoreText = evidence == null || evidence!.bestScorePercent <= 0
        ? ''
        : '${_subjectReportFormatOneDecimal(evidence!.bestScorePercent)}%';
    final openable = (evidence?.bestResultPackageId ?? '').trim().isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.item),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: style.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  taskCode,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              _StudentLabelPill(
                label: style.label,
                background: style.background,
                foreground: style.foreground,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            evidence == null
                ? 'No completed certification evidence yet.'
                : evidence!.reason.isNotEmpty
                    ? evidence!.reason
                    : status == 'passed'
                        ? 'Passed with ${scoreText.isEmpty ? 'recorded evidence' : scoreText}.'
                        : status == 'pending_review'
                            ? 'Submitted and waiting for teacher review.'
                            : 'This task focus is not passed yet.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppPalette.textMuted),
          ),
          if (evidence != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if ((evidence!.missionType).trim().isNotEmpty)
                  _StudentLabelPill(
                    label: evidence!.missionType,
                    background: const Color(0xFFEAF3FF),
                    foreground: AppPalette.navy,
                  ),
                if (scoreText.isNotEmpty)
                  _StudentLabelPill(
                    label: scoreText,
                    background: const Color(0xFFE8FFF0),
                    foreground: const Color(0xFF157347),
                  ),
                if (evidence!.completedAt != null)
                  _StudentLabelPill(
                    label: _subjectReportFormatDate(evidence!.completedAt),
                    background: const Color(0xFFF5F7FB),
                    foreground: AppPalette.navy,
                  ),
              ],
            ),
          ],
          if (openable) ...[
            const SizedBox(height: AppSpacing.item),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                onPressed: () => onOpenResult(evidence!.bestResultPackageId),
                icon: const Icon(Icons.visibility_rounded),
                label: const Text('Open result'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StudentAssessmentPanel extends StatelessWidget {
  const _StudentAssessmentPanel({required this.progress});

  final SubjectProgressSummary? progress;

  @override
  Widget build(BuildContext context) {
    return SoftPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Assessment progress', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.item),
          if (progress == null)
            Text(
              'No assessment progress is recorded for this subject yet.',
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(color: AppPalette.textMuted),
            )
          else ...[
            Text(
              '${progress!.completedAssessments}/${progress!.totalAssessments} assessments completed',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Average assessment score: ${progress!.averageScore}%'
              '${progress!.badgeUnlocked ? ' · Badge unlocked' : ''}',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppPalette.textMuted),
            ),
            const SizedBox(height: AppSpacing.item),
            LinearProgressIndicator(
              minHeight: 10,
              value: (progress!.completionPercentage / 100).clamp(0, 1),
              borderRadius: BorderRadius.circular(999),
              backgroundColor: Colors.white.withValues(alpha: 0.66),
              valueColor: const AlwaysStoppedAnimation<Color>(AppPalette.mint),
            ),
            const SizedBox(height: 8),
            Text(
              '${progress!.completionPercentage}% assessment completion',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _StudentMissionHistoryPanel extends StatelessWidget {
  const _StudentMissionHistoryPanel({
    required this.history,
    required this.onOpenResult,
  });

  final List<StudentSubjectMissionHistoryItem> history;
  final ValueChanged<String> onOpenResult;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Mission pass history', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.item),
        if (history.isEmpty)
          const SoftPanel(
            child: Text('No completed mission results are stored for this subject yet.'),
          )
        else
          ...history.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.item),
              child: _StudentMissionHistoryCard(
                item: item,
                onOpenResult: onOpenResult,
              ),
            ),
          ),
      ],
    );
  }
}

class _StudentMissionHistoryCard extends StatelessWidget {
  const _StudentMissionHistoryCard({
    required this.item,
    required this.onOpenResult,
  });

  final StudentSubjectMissionHistoryItem item;
  final ValueChanged<String> onOpenResult;

  @override
  Widget build(BuildContext context) {
    final statusStyle = _taskFocusStatusStyle(item.certificationPassStatus);
    final certificationLabel = item.certificationCounted
        ? 'Counts toward certification'
        : item.certificationPassStatus == 'pending_review'
            ? 'Pending review'
            : 'Does not count';
    return SoftPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Text(
                      '${item.missionType} · ${item.taskCodes.isEmpty ? 'No task focus' : item.taskCodes.join(', ')}',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppPalette.textMuted),
                    ),
                  ],
                ),
              ),
              _StudentLabelPill(
                label: item.statusLabel,
                background: statusStyle.background,
                foreground: statusStyle.foreground,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.item),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StudentLabelPill(
                label: 'Score ${item.scorePercent}%',
                background: const Color(0xFFEAF3FF),
                foreground: AppPalette.navy,
              ),
              _StudentLabelPill(
                label: 'XP ${item.xpAwarded}',
                background: const Color(0xFFE8FFF0),
                foreground: const Color(0xFF157347),
              ),
              _StudentLabelPill(
                label: _subjectReportFormatDate(item.assignedDate),
                background: const Color(0xFFF5F7FB),
                foreground: AppPalette.navy,
              ),
              if (item.submittedAt != null)
                _StudentLabelPill(
                  label: _subjectReportFormatDateTime(item.submittedAt),
                  background: const Color(0xFFFFF7E8),
                  foreground: const Color(0xFF9A5C00),
                ),
            ],
          ),
          const SizedBox(height: 10),
          _StudentLabelPill(
            label: certificationLabel,
            background: item.certificationCounted
                ? const Color(0xFFE8FFF0)
                : item.certificationPassStatus == 'pending_review'
                    ? const Color(0xFFFFF4DE)
                    : const Color(0xFFF5F7FB),
            foreground: item.certificationCounted
                ? const Color(0xFF157347)
                : item.certificationPassStatus == 'pending_review'
                    ? const Color(0xFF9A5C00)
                    : AppPalette.navy,
          ),
          const SizedBox(height: AppSpacing.item),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              onPressed: () => onOpenResult(item.resultPackageId),
              icon: const Icon(Icons.visibility_rounded),
              label: const Text('Open result'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentSubjectErrorState extends StatelessWidget {
  const _StudentSubjectErrorState({
    required this.message,
    required this.onBack,
  });

  final String message;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.screen),
        child: SoftPanel(
          colors: const [Color(0xFFFFF4F4), Color(0xFFFFE6E6)],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Could not load this subject report',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.item),
              Text(message, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: AppSpacing.section),
              FilledButton(onPressed: onBack, child: const Text('Go back')),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudentLabelPill extends StatelessWidget {
  const _StudentLabelPill({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _TaskFocusStatusStyle {
  const _TaskFocusStatusStyle({
    required this.label,
    required this.background,
    required this.border,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color border;
  final Color foreground;
}

_TaskFocusStatusStyle _taskFocusStatusStyle(String status) {
  switch (status) {
    case 'passed':
      return const _TaskFocusStatusStyle(
        label: 'Passed',
        background: Color(0xFFE8FFF0),
        border: Color(0xFF7AD9A6),
        foreground: Color(0xFF157347),
      );
    case 'pending_review':
      return const _TaskFocusStatusStyle(
        label: 'Pending review',
        background: Color(0xFFFFF7E5),
        border: Color(0xFFF2C56B),
        foreground: Color(0xFFAF6A00),
      );
    case 'not_passed':
      return const _TaskFocusStatusStyle(
        label: 'Not passed',
        background: Color(0xFFFFF0F0),
        border: Color(0xFFFFB3B3),
        foreground: Color(0xFFB42318),
      );
    default:
      return const _TaskFocusStatusStyle(
        label: 'Not started',
        background: Color(0xFFF5F7FB),
        border: Color(0xFFDCE7F8),
        foreground: AppPalette.navy,
      );
  }
}
