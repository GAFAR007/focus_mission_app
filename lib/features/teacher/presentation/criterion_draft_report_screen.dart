/**
 * WHAT:
 * CriterionDraftReportScreen renders one live student/subject/Task Focus report
 * with copyable evidence, editable teacher wording, compact scoring, and
 * separate Student Copy and Teacher Copy PDF exports.
 * WHY:
 * Teachers need a criterion-specific working report while original submitted
 * ResultPackage evidence remains unchanged and incomplete evidence stays clear.
 * HOW:
 * Load the backend-composed report, bind only comment overrides to controllers,
 * render student evidence as selectable text, request explicit PDF copy types,
 * and refresh after marking work.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_palette.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/download_binary_file.dart';
import '../../../core/utils/focus_mission_api.dart';
import '../../../shared/models/focus_mission_models.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../shared/widgets/soft_panel.dart';
import 'result_report_screen.dart';

class CriterionDraftReportScreen extends StatefulWidget {
  const CriterionDraftReportScreen({
    super.key,
    required this.session,
    required this.student,
    required this.subjectId,
    required this.taskCode,
    required this.missions,
    required this.api,
  });

  final AuthSession session;
  final StudentSummary student;
  final String subjectId;
  final String taskCode;
  final List<MissionPayload> missions;
  final FocusMissionApi api;

  @override
  State<CriterionDraftReportScreen> createState() =>
      _CriterionDraftReportScreenState();
}

class _CriterionDraftReportScreenState
    extends State<CriterionDraftReportScreen> {
  final TextEditingController _essayCommentController = TextEditingController();
  final TextEditingController _essayNextTimeController =
      TextEditingController();
  final Map<int, TextEditingController> _theoryCommentControllers = {};
  late Future<CriterionDraftReportData> _future;
  bool _controllersSeeded = false;
  bool _saving = false;
  final Set<String> _exportingCopies = <String>{};

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _essayCommentController.dispose();
    _essayNextTimeController.dispose();
    for (final controller in _theoryCommentControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<CriterionDraftReportData> _load() {
    return widget.api.fetchCriterionDraftReport(
      token: widget.session.token,
      studentId: widget.student.id,
      subjectId: widget.subjectId,
      taskCode: widget.taskCode,
    );
  }

  void _seedControllers(CriterionDraftReportData report) {
    if (!_controllersSeeded) {
      _essayCommentController.text = report.essay.teacherComment;
      _essayNextTimeController.text = report.essay.nextTime;
      _controllersSeeded = true;
    }
    for (final question in report.theory.questions) {
      _theoryCommentControllers.putIfAbsent(
        question.questionIndex,
        () => TextEditingController(text: question.teacherComment),
      );
    }
  }

  void _refresh() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _saveDraft(CriterionDraftReportData report) async {
    setState(() => _saving = true);
    try {
      final updated = await widget.api.saveCriterionDraftReport(
        token: widget.session.token,
        studentId: widget.student.id,
        subjectId: widget.subjectId,
        taskCode: widget.taskCode,
        essayTeacherComment: _essayCommentController.text,
        essayNextTime: _essayNextTimeController.text,
        theoryQuestionComments: report.theory.questions
            .map(
              (question) => {
                'questionIndex': question.questionIndex,
                'comment':
                    _theoryCommentControllers[question.questionIndex]?.text ??
                    '',
              },
            )
            .toList(growable: false),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _future = Future.value(updated);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Report comments saved.')));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _exportPdf(String copy) async {
    final copyLabel = copy == 'student' ? 'Student Copy' : 'Teacher Copy';
    setState(() => _exportingCopies.add(copy));
    try {
      final bytes = await widget.api.exportCriterionDraftReportPdf(
        token: widget.session.token,
        studentId: widget.student.id,
        subjectId: widget.subjectId,
        taskCode: widget.taskCode,
        copy: copy,
      );
      final downloaded = await downloadBinaryFile(
        fileName: '${widget.student.name}-${widget.taskCode}-$copy-copy.pdf'
            .replaceAll(RegExp(r'[^A-Za-z0-9.-]+'), '-'),
        bytes: bytes,
        mimeType: 'application/pdf',
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            downloaded
                ? '$copyLabel PDF downloaded.'
                : '$copyLabel download is available in the web app.',
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _exportingCopies.remove(copy));
      }
    }
  }

  Future<void> _copyText(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$label copied.')));
    }
  }

  Future<void> _openMarking(String resultPackageId) async {
    if (resultPackageId.trim().isEmpty) {
      return;
    }
    MissionPayload? mission;
    for (final candidate in widget.missions) {
      if (candidate.latestResultPackageId == resultPackageId) {
        mission = candidate;
        break;
      }
    }
    if (mission == null) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResultReportScreen(
          session: widget.session,
          mission: mission!,
          student: widget.student,
          resultPackageId: resultPackageId,
          api: widget.api,
        ),
      ),
    );
    if (mounted) {
      // WHY: Returning from the existing scoring flow rebuilds the report from
      // backend evidence so contributions and overall status cannot stay stale.
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.backgroundTop,
      appBar: AppBar(
        title: Text('${widget.taskCode} Report'),
        actions: [
          IconButton(
            tooltip: 'Refresh report',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<CriterionDraftReportData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.screen),
                child: SoftPanel(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(snapshot.error?.toString() ?? 'Report unavailable.'),
                      const SizedBox(height: AppSpacing.item),
                      TextButton(
                        onPressed: _refresh,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
          final report = snapshot.data!;
          _seedControllers(report);
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.screen),
            children: [
              Text(
                report.title.replaceAll(' Draft Report', ' Report'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.item),
              _ReportSection(
                title: 'Criterion wording',
                child: SelectableText(report.criterionWording),
              ),
              _ReportSection(
                title: 'Results overview',
                child: Column(
                  children: [
                    _ObjectiveResultRow(evidence: report.q5),
                    const SizedBox(height: 8),
                    _ObjectiveResultRow(evidence: report.q8),
                  ],
                ),
              ),
              _ReportSection(
                title: 'Essay evidence',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LabelledSelectableText(
                      label: 'Exact question / Teacher Note',
                      text: report.essay.question,
                    ),
                    _CopyableEvidence(
                      label: 'Student final Essay — exactly as submitted',
                      text: report.essay.finalEssayText,
                      onCopy: () => _copyText(
                        report.essay.finalEssayText,
                        'Student Essay',
                      ),
                    ),
                    Text(
                      report.essay.status == 'scored'
                          ? 'Original score: ${report.essay.scoreCorrect}/${report.essay.scoreTotal} — ${_percent(report.essay.percent)}'
                          : 'Original score: Pending',
                    ),
                    if (report.essay.history != null)
                      _EvidenceHistoryNote(note: report.essay.history!),
                    if (report.essay.resultPackageId.isNotEmpty)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () =>
                              _openMarking(report.essay.resultPackageId),
                          child: const Text('Review marking'),
                        ),
                      ),
                    TextField(
                      key: const Key('essay_report_comment'),
                      controller: _essayCommentController,
                      minLines: 3,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: 'Teacher Comment',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.item),
                    TextField(
                      controller: _essayNextTimeController,
                      minLines: 2,
                      maxLines: 5,
                      decoration: const InputDecoration(labelText: 'Next time'),
                    ),
                  ],
                ),
              ),
              _ReportSection(
                title: 'Theory evidence',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.theory.status == 'scored'
                          ? '${_percent(report.theory.percent)} — ${report.theory.passed ? 'Passed' : 'Not yet passed'}'
                          : 'Pending',
                    ),
                    if (report.theory.history != null)
                      _EvidenceHistoryNote(note: report.theory.history!),
                    if (report.theory.resultPackageId.isNotEmpty)
                      TextButton(
                        onPressed: () =>
                            _openMarking(report.theory.resultPackageId),
                        child: const Text('Review marking'),
                      ),
                    ...report.theory.questions.map(
                      (question) => Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.item),
                        child: SoftPanel(
                          colors: const [Color(0xFFF8FBFF), Color(0xFFEEF5FF)],
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Theory Question ${question.questionIndex + 1}',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              _LabelledSelectableText(
                                label: 'Exact question asked',
                                text: question.prompt,
                              ),
                              _CopyableEvidence(
                                label: 'Student answer — exactly as submitted',
                                text: question.studentAnswer,
                                onCopy: () => _copyText(
                                  question.studentAnswer,
                                  'Theory answer',
                                ),
                              ),
                              Text(
                                'Original teacher score: ${question.originalTeacherScore == null ? 'Pending' : '${_number(question.originalTeacherScore!)}/100'}',
                              ),
                              const SizedBox(height: AppSpacing.item),
                              TextField(
                                key: Key(
                                  'theory_report_comment_${question.questionIndex}',
                                ),
                                controller:
                                    _theoryCommentControllers[question
                                        .questionIndex],
                                minLines: 2,
                                maxLines: 5,
                                decoration: const InputDecoration(
                                  labelText: 'Teacher Comment',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _ReportSection(
                title: 'Assessment evidence',
                child: Column(
                  children: [
                    _ObjectiveResultRow(evidence: report.assessmentA),
                    const SizedBox(height: 8),
                    _ObjectiveResultRow(
                      evidence: report.assessmentB,
                      optional: true,
                    ),
                  ],
                ),
              ),
              _ReportSection(
                title: '${report.taskCode} Score calculation',
                child: CriterionReportCalculationPanel(report: report),
              ),
              _ReportSection(
                title: 'Final ${report.taskCode} Status',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.criterionPassed ? 'PASSED' : 'Not yet achieved',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: report.criterionPassed
                            ? AppPalette.aqua
                            : AppPalette.navy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(report.criterionReason),
                  ],
                ),
              ),
              GradientButton(
                label: _saving ? 'Saving comments...' : 'Save comments',
                colors: AppPalette.teacherGradient,
                onPressed: _saving ? () {} : () => _saveDraft(report),
              ),
              const SizedBox(height: AppSpacing.compact),
              LayoutBuilder(
                builder: (context, constraints) {
                  final buttonWidth = constraints.maxWidth < 620
                      ? constraints.maxWidth
                      : (constraints.maxWidth - AppSpacing.compact) / 2;
                  return Wrap(
                    spacing: AppSpacing.compact,
                    runSpacing: AppSpacing.compact,
                    children: [
                      SizedBox(
                        width: buttonWidth,
                        child: OutlinedButton.icon(
                          key: const Key('export_student_report_copy'),
                          onPressed: _exportingCopies.contains('student')
                              ? null
                              : () => _exportPdf('student'),
                          icon: const Icon(Icons.school_rounded),
                          label: Text(
                            _exportingCopies.contains('student')
                                ? 'Preparing Student Copy...'
                                : 'Export Student Copy',
                          ),
                        ),
                      ),
                      SizedBox(
                        width: buttonWidth,
                        child: OutlinedButton.icon(
                          key: const Key('export_teacher_report_copy'),
                          onPressed: _exportingCopies.contains('teacher')
                              ? null
                              : () => _exportPdf('teacher'),
                          icon: const Icon(Icons.picture_as_pdf_rounded),
                          label: Text(
                            _exportingCopies.contains('teacher')
                                ? 'Preparing Teacher Copy...'
                                : 'Export Teacher Copy',
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: AppSpacing.section),
            ],
          );
        },
      ),
    );
  }
}

String _number(double value) {
  return value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(2);
}

String _percent(double? value) =>
    value == null ? 'Pending' : '${_number(value)}%';

class _ReportSection extends StatelessWidget {
  const _ReportSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.item),
      child: SoftPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.item),
            child,
          ],
        ),
      ),
    );
  }
}

class _ObjectiveResultRow extends StatelessWidget {
  const _ObjectiveResultRow({required this.evidence, this.optional = false});

  final CriterionReportObjectiveEvidence evidence;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    final result = evidence.status == 'scored'
        ? '${evidence.correct}/${evidence.total} — ${_percent(evidence.percent)} — ${evidence.passed ? 'Passed' : 'Not yet passed'}'
        : evidence.status == 'not_created'
        ? 'Not created'
        : 'Pending';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.item),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFF),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            optional ? '${evidence.label} · Optional' : evidence.label,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(result),
        ],
      ),
    );
  }
}

class _LabelledSelectableText extends StatelessWidget {
  const _LabelledSelectableText({required this.label, required this.text});

  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.item),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          SelectableText(text.trim().isEmpty ? 'Pending' : text),
        ],
      ),
    );
  }
}

class _CopyableEvidence extends StatelessWidget {
  const _CopyableEvidence({
    required this.label,
    required this.text,
    required this.onCopy,
  });

  final String label;
  final String text;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.item),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              TextButton.icon(
                onPressed: text.trim().isEmpty ? null : onCopy,
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('Copy'),
              ),
            ],
          ),
          SelectableText(text.trim().isEmpty ? 'Pending' : text),
        ],
      ),
    );
  }
}

class _EvidenceHistoryNote extends StatelessWidget {
  const _EvidenceHistoryNote({required this.note});

  final CriterionReportHistoryNote note;

  @override
  Widget build(BuildContext context) {
    final parsed = note.at == null
        ? null
        : DateTime.tryParse(note.at!)?.toLocal();
    final timestamp = parsed == null
        ? ''
        : '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')} '
              '${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
    return Container(
      key: Key('evidence_history_${note.kind}'),
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDCE3EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            note.title,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          Text(
            [
              note.detail,
              timestamp,
            ].where((value) => value.isNotEmpty).join(' · '),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppPalette.textMuted),
          ),
        ],
      ),
    );
  }
}

class CriterionReportCalculationPanel extends StatelessWidget {
  const CriterionReportCalculationPanel({super.key, required this.report});

  final CriterionDraftReportData report;

  @override
  Widget build(BuildContext context) {
    final secured = report.securedContribution.clamp(0, 100).toDouble();
    final isPending = report.calculationStatus == 'pending';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.compact,
          runSpacing: AppSpacing.compact,
          children: [
            _CalculationMetric(
              label: 'Current secured',
              value: '${secured.toStringAsFixed(2)} / 100',
              color: AppPalette.primaryBlue,
            ),
            _CalculationMetric(
              label: 'Overall ${report.taskCode} score',
              value: isPending ? 'Pending' : _percent(report.overallPercent),
              color: isPending ? AppPalette.sun : AppPalette.mint,
              valueKey: const Key('criterion_report_overall_score'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.compact),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            key: const Key('criterion_report_secured_progress'),
            minHeight: 8,
            value: secured / 100,
            backgroundColor: const Color(0xFFE8EDF6),
            valueColor: const AlwaysStoppedAnimation<Color>(
              AppPalette.primaryBlue,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          isPending
              ? 'The overall score will appear when every required result is available.'
              : 'All required results are included in the overall score.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppPalette.textMuted),
        ),
        const SizedBox(height: AppSpacing.item),
        LayoutBuilder(
          builder: (context, constraints) {
            final useTable = constraints.maxWidth >= 680;
            return Column(
              children: [
                if (useTable) const _CalculationHeader(),
                ...report.calculationRows.map(
                  (row) => _CalculationRow(row: row, useTable: useTable),
                ),
                _CalculationTotalRow(useTable: useTable),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _CalculationMetric extends StatelessWidget {
  const _CalculationMetric({
    required this.label,
    required this.value,
    required this.color,
    this.valueKey,
  });

  final String label;
  final String value;
  final Color color;
  final Key? valueKey;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 190),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppPalette.textMuted),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            key: valueKey,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppPalette.navy,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _CalculationHeader extends StatelessWidget {
  const _CalculationHeader();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: AppPalette.textMuted,
      fontWeight: FontWeight.w700,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 7),
      child: Row(
        children: [
          Expanded(flex: 4, child: Text('Evidence', style: style)),
          Expanded(flex: 2, child: Text('Result', style: style)),
          Expanded(flex: 2, child: Text('Weight', style: style)),
          Expanded(flex: 2, child: Text('Contribution', style: style)),
        ],
      ),
    );
  }
}

class _CalculationRow extends StatelessWidget {
  const _CalculationRow({required this.row, required this.useTable});

  final CriterionReportCalculationRow row;
  final bool useTable;

  @override
  Widget build(BuildContext context) {
    final result = _percent(row.percent);
    final weight = '${_number(row.weightPercent)}%';
    final contribution = row.contribution == null
        ? 'Pending'
        : row.contribution!.toStringAsFixed(2);
    final resultStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: row.contribution == null ? AppPalette.textMuted : AppPalette.navy,
      fontWeight: FontWeight.w700,
    );

    return Container(
      key: Key('criterion_calculation_${row.key}'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E9F4)),
      ),
      child: useTable
          ? Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Text(
                    row.label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(flex: 2, child: Text(result, style: resultStyle)),
                Expanded(flex: 2, child: Text(weight)),
                Expanded(
                  flex: 2,
                  child: Text(contribution, style: resultStyle),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.label,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text('$result × $weight = $contribution', style: resultStyle),
              ],
            ),
    );
  }
}

class _CalculationTotalRow extends StatelessWidget {
  const _CalculationTotalRow({required this.useTable});

  final bool useTable;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: useTable
          ? Row(
              children: [
                Expanded(
                  flex: 6,
                  child: Text(
                    'Total weight',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Text(
                    '100%',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total weight',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(
                  '100%',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
    );
  }
}
