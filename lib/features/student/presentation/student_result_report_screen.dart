/**
 * WHAT:
 * StudentResultReportScreen shows one completed mission result in a read-only
 * student-facing format.
 * WHY:
 * Students need access to their own mission evidence and certification status
 * without exposing teacher-only scoring, sending, or screenshot workflows.
 * HOW:
 * Load the student's own result package from the student API, then render
 * meta, certification, and evidence panels with calm ADHD-friendly cards.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'package:flutter/material.dart';

import '../../../core/constants/app_palette.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/focus_mission_api.dart';
import '../../../shared/models/focus_mission_models.dart';
import '../../../shared/widgets/focus_scaffold.dart';
import '../../../shared/widgets/soft_panel.dart';

int _studentReportAsInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _studentReportAsDouble(dynamic value) {
  if (value is double) {
    return value;
  }
  if (value is int) {
    return value.toDouble();
  }
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

Map<String, dynamic> _studentReportAsMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map<dynamic, dynamic>) {
    return value.cast<String, dynamic>();
  }
  return const <String, dynamic>{};
}

List<Map<String, dynamic>> _studentReportAsMapList(dynamic value) {
  final items = value as List<dynamic>? ?? const <dynamic>[];
  return items.map((item) => _studentReportAsMap(item)).toList(growable: false);
}

String _studentReportFormatDate(String? value) {
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

String _studentReportFormatOneDecimal(double value) {
  return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
}

Map<String, String> _studentReportQuestionOptions(
  Map<String, dynamic> question,
) {
  final normalized = <String, String>{'A': '', 'B': '', 'C': '', 'D': ''};
  final rawOptions = question['options'];
  if (rawOptions is Map<dynamic, dynamic>) {
    for (final letter in normalized.keys) {
      normalized[letter] = (rawOptions[letter] ?? '').toString().trim();
    }
  }
  return normalized;
}

Map<String, String> _studentReportBlankOptions(Map<String, dynamic> blank) {
  final normalized = <String, String>{'A': '', 'B': '', 'C': '', 'D': ''};
  final rawOptions = blank['options'];
  if (rawOptions is Map<dynamic, dynamic>) {
    for (final letter in normalized.keys) {
      normalized[letter] = (rawOptions[letter] ?? '').toString().trim();
    }
  }
  return normalized;
}

_ColorStatus _studentResultStatus(String status) {
  switch (status) {
    case 'passed':
    case 'correct':
    case 'scored':
      return const _ColorStatus(
        label: 'Passed',
        background: Color(0xFFE8FFF0),
        foreground: Color(0xFF157347),
      );
    case 'pending_review':
      return const _ColorStatus(
        label: 'Pending review',
        background: Color(0xFFFFF4DE),
        foreground: Color(0xFF9A5C00),
      );
    case 'not_passed':
    case 'incorrect':
      return const _ColorStatus(
        label: 'Not passed',
        background: Color(0xFFFFECEC),
        foreground: Color(0xFFB42318),
      );
    default:
      return const _ColorStatus(
        label: 'Submitted',
        background: Color(0xFFEAF3FF),
        foreground: AppPalette.navy,
      );
  }
}

class StudentResultReportScreen extends StatefulWidget {
  const StudentResultReportScreen({
    super.key,
    required this.session,
    required this.resultPackageId,
    this.api,
  });

  final AuthSession session;
  final String resultPackageId;
  final FocusMissionApi? api;

  @override
  State<StudentResultReportScreen> createState() =>
      _StudentResultReportScreenState();
}

class _StudentResultReportScreenState extends State<StudentResultReportScreen> {
  late final FocusMissionApi _api;
  late Future<ResultPackageData> _future;

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? FocusMissionApi();
    _future = _api.fetchStudentResultReport(
      token: widget.session.token,
      resultPackageId: widget.resultPackageId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FocusScaffold(
      child: FutureBuilder<ResultPackageData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _StudentResultLoadingState();
          }
          if (snapshot.hasError) {
            return _StudentResultErrorState(
              message: snapshot.error.toString(),
              onBack: () => Navigator.of(context).pop(),
            );
          }

          final resultPackage = snapshot.data!;
          final certification = resultPackage.certification;
          final paperReviewStatus =
              (resultPackage.evidence['reviewStatus'] ?? '').toString().trim();
          final reviewStatus = certification != null
              ? certification.certificationPassStatus
              : resultPackage.resultKind == 'paper_assessment' &&
                    paperReviewStatus.isNotEmpty
              ? paperReviewStatus
              : 'submitted';
          final status = _studentResultStatus(reviewStatus);

          // WHY: Student result view must stay read-only, so this screen only
          // renders evidence and summary state from the student-owned endpoint.
          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.screen),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StudentReportHeader(
                  title: 'My Result',
                  subtitle: resultPackage.meta.missionTitle,
                  onBack: () => Navigator.of(context).pop(),
                ),
                const SizedBox(height: AppSpacing.section),
                SoftPanel(
                  colors: const [Color(0xFFF4FBFF), Color(0xFFE8F7FF)],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _ResultPill(
                            label: 'Type: ${resultPackage.missionType}',
                          ),
                          _ResultPill(
                            label:
                                'Score: ${resultPackage.meta.scorePercent}% (${resultPackage.meta.scoreCorrect}/${resultPackage.meta.scoreTotal})',
                          ),
                          _ResultPill(
                            label: 'XP: ${resultPackage.meta.xpAwarded}',
                          ),
                          _ResultStatusPill(status: status),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.item),
                      Text(
                        resultPackage.meta.missionTitle,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${resultPackage.meta.subject} · ${resultPackage.meta.taskCodes.join(', ')}',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppPalette.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.section),
                _StudentResultMetaPanel(resultPackage: resultPackage),
                if (certification != null) ...[
                  const SizedBox(height: AppSpacing.section),
                  _StudentResultCertificationPanel(
                    certification: certification,
                  ),
                ],
                const SizedBox(height: AppSpacing.section),
                _StudentResultEvidencePanel(resultPackage: resultPackage),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StudentResultLoadingState extends StatelessWidget {
  const _StudentResultLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _StudentResultErrorState extends StatelessWidget {
  const _StudentResultErrorState({required this.message, required this.onBack});

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
                'Could not load this result',
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

class _StudentReportHeader extends StatelessWidget {
  const _StudentReportHeader({
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
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppPalette.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StudentResultMetaPanel extends StatelessWidget {
  const _StudentResultMetaPanel({required this.resultPackage});

  final ResultPackageData resultPackage;

  @override
  Widget build(BuildContext context) {
    return SoftPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Meta', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.item),
          _MetaRow(label: 'Student', value: resultPackage.meta.studentName),
          _MetaRow(label: 'Subject', value: resultPackage.meta.subject),
          _MetaRow(
            label: 'Task focus',
            value: resultPackage.meta.taskCodes.isEmpty
                ? '-'
                : resultPackage.meta.taskCodes.join(', '),
          ),
          _MetaRow(
            label: 'Assigned date',
            value: resultPackage.meta.assignedDate,
          ),
          _MetaRow(
            label: 'Started',
            value: _studentReportFormatDate(resultPackage.meta.startTime),
          ),
          _MetaRow(
            label: 'Submitted',
            value: _studentReportFormatDate(resultPackage.meta.submitTime),
          ),
          _MetaRow(
            label: 'Duration',
            value: '${resultPackage.meta.durationSeconds}s',
          ),
        ],
      ),
    );
  }
}

class _StudentResultCertificationPanel extends StatelessWidget {
  const _StudentResultCertificationPanel({required this.certification});

  final MissionCertificationSummary certification;

  @override
  Widget build(BuildContext context) {
    final status = _studentResultStatus(certification.certificationPassStatus);
    return SoftPanel(
      colors: certification.certificationCounted
          ? const [Color(0xFFF4FFF7), Color(0xFFE8FFF1)]
          : const [Color(0xFFFFFBF3), Color(0xFFFFF0D8)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            certification.certificationLabel.isEmpty
                ? 'Certification'
                : certification.certificationLabel,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.item),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _ResultStatusPill(status: status),
              if (certification.certificationTaskCode.isNotEmpty)
                _ResultPill(
                  label: 'Task focus: ${certification.certificationTaskCode}',
                ),
              if (certification.scorePercent > 0)
                _ResultPill(
                  label:
                      'Certification score: ${_studentReportFormatOneDecimal(certification.scorePercent)}%',
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.item),
          Text(
            certification.reason.isNotEmpty
                ? certification.reason
                : certification.certificationCounted
                ? 'This mission counted toward your certification progress.'
                : 'This mission did not count toward certification yet.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppPalette.textMuted),
          ),
        ],
      ),
    );
  }
}

class _StudentResultEvidencePanel extends StatelessWidget {
  const _StudentResultEvidencePanel({required this.resultPackage});

  final ResultPackageData resultPackage;

  @override
  Widget build(BuildContext context) {
    final format =
        (resultPackage.evidence['format'] ?? resultPackage.missionType)
            .toString()
            .trim()
            .toUpperCase();

    switch (format) {
      case 'THEORY':
        return _StudentTheoryEvidencePanel(resultPackage: resultPackage);
      case 'ESSAY_BUILDER':
        return _StudentEssayEvidencePanel(resultPackage: resultPackage);
      case 'QUESTIONS':
      default:
        return _StudentQuestionEvidencePanel(resultPackage: resultPackage);
    }
  }
}

class _StudentQuestionEvidencePanel extends StatelessWidget {
  const _StudentQuestionEvidencePanel({required this.resultPackage});

  final ResultPackageData resultPackage;

  @override
  Widget build(BuildContext context) {
    final evidence = resultPackage.evidence;
    final questions = _studentReportAsMapList(evidence['questions']);
    final legacyReason = (evidence['legacyBackfillReason'] ?? '').toString();
    final isStandalonePaper =
        (evidence['format'] ?? '').toString().trim().toUpperCase() ==
        'STANDALONE_PAPER';
    final reviewStatus = (evidence['reviewStatus'] ?? '').toString().trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (legacyReason.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.item),
            child: SoftPanel(
              colors: const [Color(0xFFFFFBF3), Color(0xFFFFF0D8)],
              child: Text(legacyReason),
            ),
          ),
        Text('Evidence', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.item),
        if (isStandalonePaper)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.item),
            child: SoftPanel(
              colors: reviewStatus == 'pending_review'
                  ? const [Color(0xFFFFFBF3), Color(0xFFFFF0D8)]
                  : const [Color(0xFFF4FBFF), Color(0xFFE8F7FF)],
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _ResultPill(
                    label:
                        'Answered: ${_studentReportAsInt(evidence['questionsAnsweredCount'])}/${_studentReportAsInt(evidence['totalQuestions'])}',
                  ),
                  _ResultPill(
                    label:
                        'Score: ${_studentReportAsInt(evidence['overallScorePercent'])}%',
                  ),
                  if (reviewStatus.isNotEmpty)
                    _ResultStatusPill(
                      status: _studentResultStatus(reviewStatus),
                    ),
                ],
              ),
            ),
          ),
        ...questions.asMap().entries.map((entry) {
          final index = entry.key;
          final question = entry.value;
          final itemType = (question['itemType'] ?? '')
              .toString()
              .trim()
              .toUpperCase();
          if (itemType == 'FILL_GAP') {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.item),
              child: _StudentFillGapEvidenceCard(
                itemNumber: index + 1,
                question: question,
              ),
            );
          }
          if (itemType == 'THEORY') {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.item),
              child: _StudentTheoryQuestionEvidenceCard(
                itemNumber: index + 1,
                question: question,
              ),
            );
          }
          final options = _studentReportQuestionOptions(question);
          final selectedLetter = (question['selectedOptionLetter'] ?? '')
              .toString()
              .trim()
              .toUpperCase();
          final correctLetter = (question['correctOptionLetter'] ?? '')
              .toString()
              .trim()
              .toUpperCase();
          final isCorrect = question['correctness'] == true;
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.item),
            child: _StudentObjectiveEvidenceCard(
              itemNumber: index + 1,
              question: question,
              options: options,
              selectedLetter: selectedLetter,
              correctLetter: correctLetter,
              isCorrect: isCorrect,
            ),
          );
        }),
      ],
    );
  }
}

class _StudentObjectiveEvidenceCard extends StatelessWidget {
  const _StudentObjectiveEvidenceCard({
    required this.itemNumber,
    required this.question,
    required this.options,
    required this.selectedLetter,
    required this.correctLetter,
    required this.isCorrect,
  });

  final int itemNumber;
  final Map<String, dynamic> question;
  final Map<String, String> options;
  final String selectedLetter;
  final String correctLetter;
  final bool isCorrect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Question $itemNumber',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            _ResultStatusPill(
              status: _studentResultStatus(isCorrect ? 'correct' : 'incorrect'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.compact),
        Text(
          (question['questionText'] ?? '').toString(),
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.item),
        ...options.entries.map((option) {
          final isSelected = option.key == selectedLetter;
          final isCorrectOption = option.key == correctLetter;
          final background = isCorrectOption
              ? const Color(0xFFE9FFF1)
              : isSelected
              ? const Color(0xFFEAF3FF)
              : Colors.white.withValues(alpha: 0.72);
          final border = isCorrectOption
              ? const Color(0xFF84D8A5)
              : isSelected
              ? const Color(0xFFB9D6FF)
              : const Color(0xFFDCE7F8);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: border),
              ),
              child: Text(
                '${option.key}) ${option.value.isEmpty ? '-' : option.value}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          );
        }),
        const SizedBox(height: 4),
        Text(
          'Selected: ${selectedLetter.isEmpty ? 'No answer recorded' : '$selectedLetter) ${(question['selectedAnswer'] ?? '').toString()}'}',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppPalette.primaryBlue,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Correct: ${correctLetter.isEmpty ? 'No correct answer recorded' : '$correctLetter) ${(question['correctAnswer'] ?? '').toString()}'}',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: const Color(0xFF157347),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _StudentFillGapEvidenceCard extends StatelessWidget {
  const _StudentFillGapEvidenceCard({
    required this.itemNumber,
    required this.question,
  });

  final int itemNumber;
  final Map<String, dynamic> question;

  @override
  Widget build(BuildContext context) {
    final isCorrect = question['correctness'] == true;
    final studentAnswer = (question['studentAnswer'] ?? '').toString();
    final expectedAnswer = (question['expectedAnswer'] ?? '').toString();
    final acceptedAnswers =
        (question['acceptedAnswers'] as List<dynamic>? ?? const <dynamic>[])
            .map((item) => item.toString())
            .where((item) => item.trim().isNotEmpty)
            .toList(growable: false);

    return SoftPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Item $itemNumber',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              _ResultStatusPill(
                status: _studentResultStatus(
                  isCorrect ? 'correct' : 'incorrect',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.compact),
          Text(
            (question['questionText'] ?? '').toString(),
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.item),
          Text(
            'Your answer',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppPalette.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(studentAnswer.isEmpty ? 'No answer recorded.' : studentAnswer),
          const SizedBox(height: 10),
          Text(
            'Expected answer',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppPalette.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(expectedAnswer.isEmpty ? '-' : expectedAnswer),
          if (acceptedAnswers.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Accepted answers',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppPalette.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(acceptedAnswers.join(', ')),
          ],
        ],
      ),
    );
  }
}

class _StudentTheoryQuestionEvidenceCard extends StatelessWidget {
  const _StudentTheoryQuestionEvidenceCard({
    required this.itemNumber,
    required this.question,
  });

  final int itemNumber;
  final Map<String, dynamic> question;

  @override
  Widget build(BuildContext context) {
    final teacherScore = _studentReportAsInt(question['teacherScorePercent']);
    final hasTeacherScore = question['teacherScorePercent'] != null;
    final teacherFeedback = (question['teacherFeedback'] ?? '').toString();
    final minimumWordCount = _studentReportAsInt(question['minimumWordCount']);
    final studentWordCount = _studentReportAsInt(question['studentWordCount']);
    final status = hasTeacherScore ? 'scored' : 'pending_review';

    return SoftPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Theory item $itemNumber',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              _ResultStatusPill(status: _studentResultStatus(status)),
            ],
          ),
          const SizedBox(height: AppSpacing.compact),
          Text(
            (question['questionText'] ?? '').toString(),
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.item),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _ResultPill(label: 'Words: $studentWordCount'),
              _ResultPill(label: 'Minimum: $minimumWordCount'),
              if (hasTeacherScore)
                _ResultPill(label: 'Score: $teacherScore / 100'),
            ],
          ),
          const SizedBox(height: AppSpacing.item),
          Text(
            'Your answer',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppPalette.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            ((question['studentAnswer'] ?? '').toString()).trim().isEmpty
                ? 'No written answer recorded.'
                : (question['studentAnswer'] ?? '').toString(),
          ),
          if (teacherFeedback.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.item),
            Text(
              'Teacher feedback',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppPalette.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(teacherFeedback),
          ],
        ],
      ),
    );
  }
}

class _StudentTheoryEvidencePanel extends StatelessWidget {
  const _StudentTheoryEvidencePanel({required this.resultPackage});

  final ResultPackageData resultPackage;

  @override
  Widget build(BuildContext context) {
    final evidence = resultPackage.evidence;
    final questions = _studentReportAsMapList(evidence['questions']);
    final reviewStatus = (evidence['reviewStatus'] ?? 'pending_review')
        .toString();
    final average = _studentReportAsDouble(
      evidence['averageTeacherScorePercent'],
    );
    final xpMax = _studentReportAsInt(evidence['xpMax']);
    final xpAwarded = _studentReportAsInt(evidence['xpAwarded']);
    final legacyReason = (evidence['legacyBackfillReason'] ?? '').toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (legacyReason.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.item),
            child: SoftPanel(
              colors: const [Color(0xFFFFFBF3), Color(0xFFFFF0D8)],
              child: Text(legacyReason),
            ),
          ),
        Text('Theory Review', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.item),
        SoftPanel(
          colors: reviewStatus == 'scored'
              ? const [Color(0xFFF4FFF7), Color(0xFFE8FFF1)]
              : const [Color(0xFFFFFBF3), Color(0xFFFFF0D8)],
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _ResultStatusPill(status: _studentResultStatus(reviewStatus)),
              _ResultPill(
                label:
                    'Average: ${_studentReportFormatOneDecimal(average)} / 100',
              ),
              _ResultPill(label: 'XP: $xpAwarded / $xpMax'),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.item),
        ...questions.asMap().entries.map((entry) {
          final index = entry.key;
          final question = entry.value;
          final teacherScore = question['teacherScorePercent'];
          final teacherFeedback = (question['teacherFeedback'] ?? '')
              .toString();
          final status = _studentResultStatus(
            teacherScore == null
                ? reviewStatus
                : (_studentReportAsInt(teacherScore) >= 70
                      ? 'passed'
                      : 'not_passed'),
          );
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.item),
            child: SoftPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Question ${index + 1}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      _ResultStatusPill(status: status),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.compact),
                  Text(
                    (question['questionText'] ?? '').toString(),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.item),
                  _EvidenceLabel(
                    label: 'Learn First',
                    value: (question['learnFirst'] ?? '').toString(),
                  ),
                  const SizedBox(height: 10),
                  _EvidenceLabel(
                    label: 'Expected answer',
                    value: (question['expectedAnswer'] ?? '').toString(),
                  ),
                  const SizedBox(height: 10),
                  _EvidenceLabel(
                    label: 'Your answer',
                    value: (question['studentAnswer'] ?? '').toString(),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _ResultPill(
                        label:
                            'Minimum words: ${_studentReportAsInt(question['minimumWordCount'])}',
                      ),
                      _ResultPill(
                        label:
                            'Your words: ${_studentReportAsInt(question['studentWordCount'])}',
                      ),
                      if (teacherScore != null)
                        _ResultPill(
                          label:
                              'Teacher score: ${_studentReportAsInt(teacherScore)} / 100',
                        ),
                    ],
                  ),
                  if (teacherFeedback.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _EvidenceLabel(
                      label: 'Teacher feedback',
                      value: teacherFeedback,
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _StudentEssayEvidencePanel extends StatelessWidget {
  const _StudentEssayEvidencePanel({required this.resultPackage});

  final ResultPackageData resultPackage;

  @override
  Widget build(BuildContext context) {
    final evidence = resultPackage.evidence;
    final sentences = _studentReportAsMapList(evidence['perSentence']);
    final finalEssayText = (evidence['finalEssayText'] ?? '').toString();
    final finalWordCount = _studentReportAsInt(evidence['finalWordCount']);
    final blankCount = _studentReportAsInt(evidence['blankCompletionCount']);
    final blankTarget = _studentReportAsInt(evidence['blankTargetCount']);
    final legacyReason = (evidence['legacyBackfillReason'] ?? '').toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (legacyReason.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.item),
            child: SoftPanel(
              colors: const [Color(0xFFFFFBF3), Color(0xFFFFF0D8)],
              child: Text(legacyReason),
            ),
          ),
        Text('Essay Builder', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.item),
        SoftPanel(
          colors: const [Color(0xFFF4FBFF), Color(0xFFE8F6FF)],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _ResultPill(label: 'Word count: $finalWordCount'),
                  _ResultPill(label: 'Blanks: $blankCount / $blankTarget'),
                ],
              ),
              const SizedBox(height: AppSpacing.item),
              _EvidenceLabel(label: 'Final essay', value: finalEssayText),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.item),
        ...sentences.asMap().entries.map((entry) {
          final index = entry.key;
          final sentence = entry.value;
          final blanks = _studentReportAsMapList(sentence['blankSelections']);
          final learnFirstBullets =
              (sentence['learnFirstBullets'] as List<dynamic>? ?? const [])
                  .map((item) => item.toString().trim())
                  .where((item) => item.isNotEmpty)
                  .toList(growable: false);
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.item),
            child: SoftPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sentence ${index + 1} · ${(sentence['role'] ?? '').toString()}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.compact),
                  if (learnFirstBullets.isNotEmpty) ...[
                    Text(
                      'Learn First',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 6),
                    ...learnFirstBullets.map(
                      (bullet) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('• $bullet'),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  ...blanks.map((blank) {
                    final options = _studentReportBlankOptions(blank);
                    final selectedLetter = (blank['chosenOptionLetter'] ?? '')
                        .toString()
                        .trim()
                        .toUpperCase();
                    final correctLetter = (blank['correctOptionLetter'] ?? '')
                        .toString()
                        .trim()
                        .toUpperCase();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Blank ${(blank['blankId'] ?? '').toString()}',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 6),
                          ...options.entries.map(
                            (option) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text('${option.key}) ${option.value}'),
                            ),
                          ),
                          Text(
                            'Selected: ${selectedLetter.isEmpty ? '-' : '$selectedLetter) ${(blank['chosenOptionText'] ?? '').toString()}'}',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: AppPalette.primaryBlue,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Correct: ${correctLetter.isEmpty ? '-' : '$correctLetter) ${(blank['correctOptionText'] ?? '').toString()}'}',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: const Color(0xFF157347),
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                    );
                  }),
                  _EvidenceLabel(
                    label: 'Sentence output',
                    value: (sentence['fullSentenceOutput'] ?? '').toString(),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _EvidenceLabel extends StatelessWidget {
  const _EvidenceLabel({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(color: AppPalette.navy),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(value.isEmpty ? '-' : value),
        ),
      ],
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppPalette.textMuted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultPill extends StatelessWidget {
  const _ResultPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ResultStatusPill extends StatelessWidget {
  const _ResultStatusPill({required this.status});

  final _ColorStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: status.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: status.foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ColorStatus {
  const _ColorStatus({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;
}
