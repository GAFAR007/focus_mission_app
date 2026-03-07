/**
 * WHAT:
 * ResultReportScreen shows one mission Result Package, allows screenshot capture
 * from the evidence view, and sends the package through in-app/email channels.
 * WHY:
 * Teachers need an auditable, single-screen report flow for mission outcomes,
 * including optional screenshot evidence and delivery status visibility.
 * HOW:
 * Fetch the result package by id, render meta + evidence dynamically by format,
 * upload report screenshots, and call send endpoint with chosen channels.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../core/constants/app_palette.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/focus_mission_api.dart';
import '../../../shared/models/focus_mission_models.dart';
import '../../../shared/widgets/focus_scaffold.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../shared/widgets/soft_panel.dart';

int _asIntValue(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String _formatReportDateTime(String? value) {
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

double _asDoubleValue(dynamic value) {
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

String _formatOneDecimal(double value) {
  final normalized = value % 1 == 0
      ? value.toInt().toString()
      : value.toStringAsFixed(1);
  return normalized;
}

Map<String, String> _extractQuestionOptions(Map<String, dynamic> question) {
  final normalized = <String, String>{'A': '', 'B': '', 'C': '', 'D': ''};
  final rawOptions = question['options'];
  if (rawOptions is Map<dynamic, dynamic>) {
    for (final letter in normalized.keys) {
      normalized[letter] = (rawOptions[letter] ?? '').toString().trim();
    }
  } else if (rawOptions is List<dynamic>) {
    for (var index = 0; index < rawOptions.length && index < 4; index += 1) {
      final letter = String.fromCharCode(65 + index);
      normalized[letter] = (rawOptions[index] ?? '').toString().trim();
    }
  }

  final selectedLetter = (question['selectedOptionLetter'] ?? '')
      .toString()
      .trim()
      .toUpperCase();
  final selectedAnswer = (question['selectedAnswer'] ?? '').toString().trim();
  final correctLetter = (question['correctOptionLetter'] ?? '')
      .toString()
      .trim()
      .toUpperCase();
  final correctAnswer = (question['correctAnswer'] ?? '').toString().trim();
  final remainingOptions =
      (question['remainingOptions'] as List<dynamic>? ?? const [])
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);

  if (normalized.values.where((value) => value.isNotEmpty).length >= 4) {
    return normalized;
  }

  // WHY: Older evidence snapshots did not persist full option maps. This fallback
  // reconstructs A/B/C/D from selected/correct/remaining fields for readability.
  if (selectedLetter.isNotEmpty && normalized.containsKey(selectedLetter)) {
    normalized[selectedLetter] = normalized[selectedLetter]!.isNotEmpty
        ? normalized[selectedLetter]!
        : selectedAnswer;
  }
  if (correctLetter.isNotEmpty && normalized.containsKey(correctLetter)) {
    normalized[correctLetter] = normalized[correctLetter]!.isNotEmpty
        ? normalized[correctLetter]!
        : correctAnswer;
  }

  var nextRemainingIndex = 0;
  for (final letter in ['A', 'B', 'C', 'D']) {
    if (normalized[letter]!.isNotEmpty) {
      continue;
    }
    if (nextRemainingIndex >= remainingOptions.length) {
      break;
    }
    normalized[letter] = remainingOptions[nextRemainingIndex];
    nextRemainingIndex += 1;
  }

  return normalized;
}

Map<String, String> _extractBlankOptions(Map<String, dynamic> blank) {
  final normalized = <String, String>{'A': '', 'B': '', 'C': '', 'D': ''};
  final rawOptions = blank['options'];
  if (rawOptions is Map<dynamic, dynamic>) {
    for (final letter in normalized.keys) {
      normalized[letter] = (rawOptions[letter] ?? '').toString().trim();
    }
  }

  final selectedLetter = (blank['chosenOptionLetter'] ?? '')
      .toString()
      .trim()
      .toUpperCase();
  final selectedText = (blank['chosenOptionText'] ?? '').toString().trim();
  final correctLetter = (blank['correctOptionLetter'] ?? '')
      .toString()
      .trim()
      .toUpperCase();
  final correctText = (blank['correctOptionText'] ?? '').toString().trim();

  if (selectedLetter.isNotEmpty && normalized.containsKey(selectedLetter)) {
    normalized[selectedLetter] = normalized[selectedLetter]!.isNotEmpty
        ? normalized[selectedLetter]!
        : selectedText;
  }
  if (correctLetter.isNotEmpty && normalized.containsKey(correctLetter)) {
    normalized[correctLetter] = normalized[correctLetter]!.isNotEmpty
        ? normalized[correctLetter]!
        : correctText;
  }

  return normalized;
}

Map<String, dynamic>? _findEssayDraftBlank({
  required Map<String, dynamic>? missionDraftJson,
  required String sentenceId,
  required int sentenceIndex,
  required String blankId,
  required int blankIndex,
}) {
  final draftSentences =
      missionDraftJson?['sentences'] as List<dynamic>? ?? const [];
  Map<String, dynamic>? draftSentence;

  if (sentenceId.trim().isNotEmpty) {
    for (final item in draftSentences) {
      final sentence = (item as Map<dynamic, dynamic>).cast<String, dynamic>();
      if ((sentence['id'] ?? '').toString().trim() == sentenceId.trim()) {
        draftSentence = sentence;
        break;
      }
    }
  }
  if (draftSentence == null &&
      sentenceIndex >= 0 &&
      sentenceIndex < draftSentences.length) {
    draftSentence = (draftSentences[sentenceIndex] as Map<dynamic, dynamic>)
        .cast<String, dynamic>();
  }
  if (draftSentence == null) {
    return null;
  }

  final parts = draftSentence['parts'] as List<dynamic>? ?? const [];
  final blankParts = parts
      .where((item) => (item as Map<dynamic, dynamic>)['type'] == 'blank')
      .map((item) => (item as Map<dynamic, dynamic>).cast<String, dynamic>())
      .toList(growable: false);

  if (blankId.trim().isNotEmpty) {
    for (final blank in blankParts) {
      if ((blank['blankId'] ?? '').toString().trim() == blankId.trim()) {
        return blank;
      }
    }
  }
  if (blankIndex >= 0 && blankIndex < blankParts.length) {
    return blankParts[blankIndex];
  }
  return null;
}

class ResultReportScreen extends StatefulWidget {
  const ResultReportScreen({
    super.key,
    required this.session,
    required this.mission,
    required this.student,
    required this.resultPackageId,
    required this.api,
    this.readOnly = false,
  });

  final AuthSession session;
  final MissionPayload mission;
  final StudentSummary student;
  final String resultPackageId;
  final FocusMissionApi api;
  final bool readOnly;

  @override
  State<ResultReportScreen> createState() => _ResultReportScreenState();
}

class _ResultReportScreenState extends State<ResultReportScreen> {
  final TextEditingController _recipientsController = TextEditingController();
  final GlobalKey _reportBoundaryKey = GlobalKey();
  final Map<int, TextEditingController> _theoryScoreControllers =
      <int, TextEditingController>{};
  final Map<int, TextEditingController> _theoryFeedbackControllers =
      <int, TextEditingController>{};

  late Future<ResultPackageData> _future;
  bool _isSending = false;
  bool _isCapturing = false;
  bool _isSavingTheoryScore = false;
  bool _sendInApp = true;
  bool _sendEmail = true;
  bool _attachScreenshot = true;
  String _screenshotUrl = '';
  String _theoryControllerSeed = '';

  @override
  void initState() {
    super.initState();
    _future = _loadResultPackage();
  }

  @override
  void dispose() {
    _recipientsController.dispose();
    for (final controller in _theoryScoreControllers.values) {
      controller.dispose();
    }
    for (final controller in _theoryFeedbackControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<ResultPackageData> _loadResultPackage() async {
    if (widget.readOnly) {
      return widget.api.getManagementResultPackage(
        token: widget.session.token,
        resultPackageId: widget.resultPackageId,
      );
    }

    return widget.api.getTeacherResultPackage(
      token: widget.session.token,
      resultPackageId: widget.resultPackageId,
    );
  }

  Future<void> _refreshResultPackage() async {
    setState(() {
      _future = _loadResultPackage();
    });
  }

  List<Map<String, dynamic>> _theoryQuestions(ResultPackageData resultPackage) {
    final questions =
        resultPackage.evidence['questions'] as List<dynamic>? ?? const [];
    return questions
        .map((item) => (item as Map<dynamic, dynamic>).cast<String, dynamic>())
        .toList(growable: false);
  }

  void _syncTheoryReviewControllers(ResultPackageData resultPackage) {
    if (resultPackage.missionType != 'THEORY') {
      return;
    }

    final questions = _theoryQuestions(resultPackage);
    final nextSeed =
        '${resultPackage.id}:${resultPackage.updatedAt ?? ''}:${questions.length}';
    if (_theoryControllerSeed == nextSeed) {
      return;
    }

    for (final controller in _theoryScoreControllers.values) {
      controller.dispose();
    }
    for (final controller in _theoryFeedbackControllers.values) {
      controller.dispose();
    }
    _theoryScoreControllers.clear();
    _theoryFeedbackControllers.clear();

    for (var index = 0; index < questions.length; index += 1) {
      final question = questions[index];
      final scoreValue = question['teacherScorePercent'];
      _theoryScoreControllers[index] = TextEditingController(
        text: scoreValue == null ? '' : scoreValue.toString(),
      );
      _theoryFeedbackControllers[index] = TextEditingController(
        text: (question['teacherFeedback'] ?? '').toString(),
      );
    }

    _theoryControllerSeed = nextSeed;
  }

  int? _parseTheoryScore(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final parsed = int.tryParse(trimmed);
    if (parsed == null || parsed < 0 || parsed > 100) {
      return null;
    }
    return parsed;
  }

  bool _allTheoryScoresValid(ResultPackageData resultPackage) {
    final questions = _theoryQuestions(resultPackage);
    if (questions.isEmpty) {
      return false;
    }
    for (var index = 0; index < questions.length; index += 1) {
      final controller = _theoryScoreControllers[index];
      if (controller == null || _parseTheoryScore(controller.text) == null) {
        return false;
      }
    }
    return true;
  }

  double _draftTheoryAverage(ResultPackageData resultPackage) {
    final questions = _theoryQuestions(resultPackage);
    if (questions.isEmpty) {
      return 0;
    }
    var total = 0;
    var count = 0;
    for (var index = 0; index < questions.length; index += 1) {
      final controller = _theoryScoreControllers[index];
      final parsed = controller == null
          ? null
          : _parseTheoryScore(controller.text);
      if (parsed == null) {
        continue;
      }
      total += parsed;
      count += 1;
    }
    if (count == 0) {
      return 0;
    }
    return total / count;
  }

  int _draftTheoryScoredCount(ResultPackageData resultPackage) {
    final questions = _theoryQuestions(resultPackage);
    if (questions.isEmpty) {
      return 0;
    }

    var count = 0;
    for (var index = 0; index < questions.length; index += 1) {
      final controller = _theoryScoreControllers[index];
      final parsed = controller == null
          ? null
          : _parseTheoryScore(controller.text);
      if (parsed != null) {
        count += 1;
      }
    }
    return count;
  }

  int _draftTheoryProjectedXp(ResultPackageData resultPackage) {
    final average = _draftTheoryAverage(resultPackage);
    final xpMax = _asIntValue(resultPackage.evidence['xpMax']);
    final safeXpMax = xpMax <= 0 ? 50 : xpMax;
    return ((average / 100) * safeXpMax).round();
  }

  Future<void> _saveTheoryScores(ResultPackageData resultPackage) async {
    if (_isSavingTheoryScore) {
      return;
    }

    final questions = _theoryQuestions(resultPackage);
    if (questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No theory questions were found to score.'),
        ),
      );
      return;
    }

    if (!_allTheoryScoresValid(resultPackage)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter a score between 0 and 100 for every theory question.',
          ),
        ),
      );
      return;
    }

    final payload = <Map<String, dynamic>>[];
    for (var index = 0; index < questions.length; index += 1) {
      final scoreController = _theoryScoreControllers[index];
      final feedbackController = _theoryFeedbackControllers[index];
      final parsedScore = scoreController == null
          ? null
          : _parseTheoryScore(scoreController.text);
      if (parsedScore == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Each theory question must have a valid score.'),
          ),
        );
        return;
      }
      payload.add({
        'questionIndex': index,
        'teacherScorePercent': parsedScore,
        'teacherFeedback': feedbackController?.text.trim() ?? '',
      });
    }

    setState(() => _isSavingTheoryScore = true);
    try {
      final updatedResultPackage = await widget.api
          .scoreTeacherTheoryResultPackage(
            token: widget.session.token,
            resultPackageId: widget.resultPackageId,
            questions: payload,
          );

      if (!mounted) {
        return;
      }

      // WHY: Resetting the controller seed forces the saved teacher scores to
      // rehydrate from the backend snapshot, which keeps local edit state aligned
      // with the audited result package after scoring or rescoring.
      _theoryControllerSeed = '';
      setState(() {
        _future = Future<ResultPackageData>.value(updatedResultPackage);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Theory score saved and XP updated.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _isSavingTheoryScore = false);
      }
    }
  }

  Widget _buildTheoryReviewPanel(ResultPackageData resultPackage) {
    final evidence = resultPackage.evidence;
    final questions = _theoryQuestions(resultPackage);
    final reviewStatus = (evidence['reviewStatus'] ?? 'pending_review')
        .toString()
        .trim();
    final xpMax = _asIntValue(evidence['xpMax']);
    final safeXpMax = xpMax <= 0 ? 50 : xpMax;
    final storedAverage = _asDoubleValue(
      evidence['averageTeacherScorePercent'],
    );
    final storedXpAwarded = _asIntValue(evidence['xpAwarded']);
    final liveAverage = _draftTheoryAverage(resultPackage);
    final scoredCount = _draftTheoryScoredCount(resultPackage);
    final totalQuestions = questions.length;
    final hasLiveScores = scoredCount > 0;
    final averageToShow = hasLiveScores ? liveAverage : storedAverage;
    final projectedXp = hasLiveScores
        ? _draftTheoryProjectedXp(resultPackage)
        : storedXpAwarded;
    final actionLabel = reviewStatus == 'scored'
        ? 'Update Theory Score'
        : 'Finalize Theory Score';
    final buttonEnabled =
        _allTheoryScoresValid(resultPackage) && !_isSavingTheoryScore;

    return SoftPanel(
      colors: const [Color(0xFFFFFBF1), Color(0xFFEAF4FF)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Theory Review', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            'Score each theory answer using /100, not /10. Theory missions keep a fixed $safeXpMax XP budget, and certification passes when the overall average is 70% or higher.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppPalette.textMuted),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.item),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(
                color: AppPalette.primaryBlue.withValues(alpha: 0.24),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Scoring guide',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  'Enter scores like 60, 75, or 100. Do not enter 6, 7, or 10. A score of 70 or above shows pass-level quality for that answer, but the final certification decision uses the average across all theory questions.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppPalette.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.compact),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _Pill(
                label:
                    'Review: ${reviewStatus == 'scored' ? 'Scored' : 'Pending review'}',
              ),
              _Pill(
                label: hasLiveScores
                    ? 'Live average: ${_formatOneDecimal(averageToShow)}%'
                    : 'Average: ${_formatOneDecimal(averageToShow)}%',
              ),
              _Pill(label: 'Scored now: $scoredCount/$totalQuestions'),
              _Pill(
                label: hasLiveScores
                    ? 'Live XP: $projectedXp/$safeXpMax'
                    : 'Projected XP: $projectedXp/$safeXpMax',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.compact),
          ...questions.asMap().entries.map((entry) {
            final index = entry.key;
            final question = entry.value;
            final minimumWordCount = _asIntValue(question['minimumWordCount']);
            final studentWordCount = _asIntValue(question['studentWordCount']);
            final meetsMinimumWords = question['meetsMinimumWords'] == true;
            final learnFirst = (question['learnFirst'] ?? '').toString().trim();
            final expectedAnswer = (question['expectedAnswer'] ?? '')
                .toString()
                .trim();
            final studentAnswer = (question['studentAnswer'] ?? '')
                .toString()
                .trim();
            final scoreController = _theoryScoreControllers[index]!;
            final feedbackController = _theoryFeedbackControllers[index]!;
            final currentScore = _parseTheoryScore(scoreController.text);
            final showsPassLevel = currentScore != null && currentScore >= 70;

            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: AppSpacing.compact),
              padding: const EdgeInsets.all(AppSpacing.item),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(
                  color: meetsMinimumWords
                      ? AppPalette.mint.withValues(alpha: 0.45)
                      : AppPalette.orange.withValues(alpha: 0.45),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Theory ${index + 1}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: meetsMinimumWords
                              ? AppPalette.mint.withValues(alpha: 0.2)
                              : AppPalette.sun.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '$studentWordCount/$minimumWordCount words',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppPalette.navy,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      if (currentScore != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: showsPassLevel
                                ? AppPalette.mint.withValues(alpha: 0.18)
                                : const Color(0xFFFFF0F0),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            showsPassLevel
                                ? '70+ pass-level answer'
                                : 'Below 70',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: showsPassLevel
                                      ? AppPalette.mint
                                      : const Color(0xFFB42318),
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    (question['questionText'] ?? '').toString(),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppPalette.navy,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (learnFirst.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Learn First',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppPalette.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      learnFirst,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppPalette.navy),
                    ),
                  ],
                  if (expectedAnswer.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Expected answer',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppPalette.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      expectedAnswer,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppPalette.mint.withValues(alpha: 0.95),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    'Student answer',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppPalette.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FBFF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      studentAnswer.isEmpty
                          ? 'No written answer recorded.'
                          : studentAnswer,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppPalette.navy),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: scoreController,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Teacher score (/100)',
                      hintText: 'Examples: 60, 75, 100',
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Guide: 70+ shows pass-level quality for this answer. Final certification still depends on the average across all theory questions.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppPalette.textMuted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: feedbackController,
                    minLines: 2,
                    maxLines: 4,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Teacher feedback (optional)',
                      hintText: 'Add short, concrete feedback for this answer.',
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 4),
          IgnorePointer(
            ignoring: !buttonEnabled,
            child: Opacity(
              opacity: buttonEnabled ? 1 : 0.5,
              child: GradientButton(
                label: _isSavingTheoryScore
                    ? 'Saving theory score...'
                    : actionLabel,
                colors: const [AppPalette.primaryBlue, AppPalette.aqua],
                onPressed: () => _saveTheoryScores(resultPackage),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FocusScaffold(
      child: FutureBuilder<ResultPackageData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.screen),
                child: SoftPanel(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Could not load result report',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.item),
                      Text(
                        snapshot.error.toString(),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.section),
                      GradientButton(
                        label: 'Back',
                        colors: AppPalette.teacherGradient,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          final resultPackage = snapshot.data!;
          _syncTheoryReviewControllers(resultPackage);
          final effectiveScreenshotUrl = _screenshotUrl.trim().isNotEmpty
              ? _screenshotUrl.trim()
              : _latestScreenshotFromLogs(resultPackage.sendLogs);
          final absoluteScreenshotUrl = widget.api.resolveApiUrl(
            effectiveScreenshotUrl,
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.screen),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: const Text('Back'),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _refreshResultPackage,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Refresh'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.compact),
                Text(
                  widget.readOnly ? 'Student Result Report' : 'Result Report',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  '${resultPackage.meta.missionTitle} · ${resultPackage.meta.studentName}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppPalette.textMuted),
                ),
                const SizedBox(height: AppSpacing.item),
                _StatusPanel(resultPackage: resultPackage),
                if (!widget.readOnly &&
                    resultPackage.missionType == 'THEORY') ...[
                  const SizedBox(height: AppSpacing.item),
                  _buildTheoryReviewPanel(resultPackage),
                ],
                const SizedBox(height: AppSpacing.item),
                RepaintBoundary(
                  key: _reportBoundaryKey,
                  child: Column(
                    children: [
                      _MetaPanel(resultPackage: resultPackage),
                      if (resultPackage.certification != null) ...[
                        const SizedBox(height: AppSpacing.item),
                        _CertificationPanel(
                          certification: resultPackage.certification!,
                          missionType: resultPackage.missionType,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.item),
                      _EvidencePanel(
                        resultPackage: resultPackage,
                        missionDraftJson: widget.mission.draftJson,
                      ),
                    ],
                  ),
                ),
                if (!widget.readOnly) ...[
                  const SizedBox(height: AppSpacing.item),
                  _buildScreenshotPanel(
                    absoluteScreenshotUrl: absoluteScreenshotUrl,
                    hasScreenshot: effectiveScreenshotUrl.trim().isNotEmpty,
                  ),
                  const SizedBox(height: AppSpacing.item),
                  _buildSendPanel(resultPackage),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildScreenshotPanel({
    required String absoluteScreenshotUrl,
    required bool hasScreenshot,
  }) {
    return SoftPanel(
      colors: const [Color(0xFFF7FBFF), Color(0xFFE8F2FF)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Screenshot Evidence',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Capture this report view and optionally attach it when sending results.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppPalette.textMuted),
          ),
          const SizedBox(height: AppSpacing.compact),
          Row(
            children: [
              Expanded(
                child: GradientButton(
                  label: _isCapturing
                      ? 'Capturing screenshot...'
                      : 'Capture Screenshot',
                  colors: const [AppPalette.primaryBlue, AppPalette.aqua],
                  onPressed: _isCapturing ? () {} : _captureAndUploadScreenshot,
                ),
              ),
            ],
          ),
          if (hasScreenshot) ...[
            const SizedBox(height: AppSpacing.compact),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Attach screenshot on send'),
              value: _attachScreenshot,
              onChanged: (value) => setState(() => _attachScreenshot = value),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              child: Image.network(
                absoluteScreenshotUrl,
                headers: {'Authorization': 'Bearer ${widget.session.token}'},
                fit: BoxFit.cover,
                height: 220,
                width: double.infinity,
                errorBuilder: (_, _, _) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.item),
                    color: Colors.white,
                    child: const Text('Screenshot preview unavailable.'),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSendPanel(ResultPackageData resultPackage) {
    return SoftPanel(
      colors: const [Color(0xFFFFFCF6), Color(0xFFFFF1DF)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Send Result', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            'Teacher email is always included. Add extra recipients if needed.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppPalette.textMuted),
          ),
          const SizedBox(height: AppSpacing.compact),
          TextField(
            controller: _recipientsController,
            decoration: const InputDecoration(
              labelText: 'Additional recipients',
              hintText: 'example@school.org, team@school.org',
            ),
          ),
          const SizedBox(height: AppSpacing.compact),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Send in-app'),
            value: _sendInApp,
            onChanged: (value) => setState(() => _sendInApp = value),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Send email'),
            value: _sendEmail,
            onChanged: (value) => setState(() => _sendEmail = value),
          ),
          const SizedBox(height: AppSpacing.compact),
          GradientButton(
            label: _isSending ? 'Sending result...' : 'Send Result',
            colors: const [AppPalette.sun, AppPalette.orange],
            onPressed: _isSending ? () {} : () => _sendResult(resultPackage),
          ),
          if (resultPackage.sendLogs.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.item),
            Text('Latest send', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            _SendLogCard(log: resultPackage.sendLogs.first),
          ],
        ],
      ),
    );
  }

  String _latestScreenshotFromLogs(List<ResultSendLog> logs) {
    for (final log in logs) {
      if (log.screenshotUrl.trim().isNotEmpty) {
        return log.screenshotUrl;
      }
    }
    return '';
  }

  Future<void> _captureAndUploadScreenshot() async {
    if (_isCapturing) {
      return;
    }

    setState(() => _isCapturing = true);
    try {
      final boundary =
          _reportBoundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) {
        throw const FocusMissionApiException(
          'Could not capture screenshot from this report view.',
        );
      }

      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw const FocusMissionApiException(
          'Screenshot capture returned empty image data.',
        );
      }
      final bytes = byteData.buffer.asUint8List();

      final uploaded = await widget.api.uploadTeacherResultScreenshot(
        token: widget.session.token,
        resultPackageId: widget.resultPackageId,
        fileBytes: bytes,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _screenshotUrl = uploaded.screenshotUrl;
        _attachScreenshot = true;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Screenshot uploaded.')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _isCapturing = false);
      }
    }
  }

  Future<void> _sendResult(ResultPackageData resultPackage) async {
    if (_isSending) {
      return;
    }

    if (!_sendInApp && !_sendEmail) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one send channel.')),
      );
      return;
    }

    final recipients = _parseRecipients(_recipientsController.text);
    final screenshotToSend = _attachScreenshot
        ? (_screenshotUrl.trim().isNotEmpty
              ? _screenshotUrl.trim()
              : _latestScreenshotFromLogs(resultPackage.sendLogs))
        : '';

    setState(() => _isSending = true);
    try {
      await widget.api.sendTeacherResultPackage(
        token: widget.session.token,
        resultPackageId: widget.resultPackageId,
        recipients: recipients,
        sendInApp: _sendInApp,
        sendEmail: _sendEmail,
        screenshotUrl: screenshotToSend,
      );

      if (!mounted) {
        return;
      }

      await _refreshResultPackage();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Result sent.')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  List<String> _parseRecipients(String raw) {
    return raw
        .split(RegExp(r'[\n,; ]+'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({required this.resultPackage});

  final ResultPackageData resultPackage;

  @override
  Widget build(BuildContext context) {
    final triesToComplete = _asIntValue(
      resultPackage.evidence['triesToComplete'] ??
          resultPackage.evidence['completionAttemptNumber'],
    );
    final isTheory = resultPackage.missionType == 'THEORY';
    final reviewStatus =
        (resultPackage.evidence['reviewStatus'] ?? 'pending_review')
            .toString()
            .trim();
    final theoryAverage = _asDoubleValue(
      resultPackage.evidence['averageTeacherScorePercent'],
    );
    final theoryXpMax = _asIntValue(resultPackage.evidence['xpMax']);
    final safeTheoryXpMax = theoryXpMax <= 0 ? 50 : theoryXpMax;
    final scoreLabel = isTheory
        ? reviewStatus == 'scored'
              ? 'Average: ${_formatOneDecimal(theoryAverage)}%'
              : 'Score: Pending review'
        : 'Score: ${resultPackage.meta.scoreCorrect}/${resultPackage.meta.scoreTotal} (${resultPackage.meta.scorePercent}%)';
    final xpLabel = isTheory
        ? reviewStatus == 'scored'
              ? 'XP: ${resultPackage.meta.xpAwarded}/$safeTheoryXpMax'
              : 'XP: Pending'
        : 'XP: ${resultPackage.meta.xpAwarded}';
    return SoftPanel(
      colors: const [Color(0xFFEFFAF5), Color(0xFFE5F4FF)],
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _Pill(label: 'Type: ${resultPackage.missionType}'),
          if (isTheory)
            _Pill(
              label:
                  'Review: ${reviewStatus == 'scored' ? 'Scored' : 'Pending review'}',
            ),
          _Pill(label: 'Send: ${resultPackage.latestSendStatus}'),
          _Pill(label: scoreLabel),
          _Pill(label: 'Tries: ${triesToComplete <= 0 ? 1 : triesToComplete}'),
          _Pill(label: xpLabel),
        ],
      ),
    );
  }
}

class _MetaPanel extends StatelessWidget {
  const _MetaPanel({required this.resultPackage});

  final ResultPackageData resultPackage;

  @override
  Widget build(BuildContext context) {
    final meta = resultPackage.meta;
    return SoftPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Meta', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.compact),
          _MetaRow(label: 'Student', value: meta.studentName),
          _MetaRow(label: 'Mission', value: meta.missionTitle),
          _MetaRow(label: 'Subject', value: meta.subject),
          _MetaRow(
            label: 'Task Codes',
            value: meta.taskCodes.isEmpty ? 'None' : meta.taskCodes.join(', '),
          ),
          _MetaRow(label: 'Assigned Date', value: meta.assignedDate),
          _MetaRow(
            label: 'Started',
            value: _formatReportDateTime(meta.startTime),
          ),
          _MetaRow(
            label: 'Submitted',
            value: _formatReportDateTime(meta.submitTime),
          ),
          _MetaRow(label: 'Duration', value: '${meta.durationSeconds}s'),
        ],
      ),
    );
  }
}

class _CertificationPanel extends StatelessWidget {
  const _CertificationPanel({
    required this.certification,
    required this.missionType,
  });

  final MissionCertificationSummary certification;
  final String missionType;

  Color get _accentColor {
    switch (certification.certificationPassStatus) {
      case 'passed':
        return AppPalette.mint;
      case 'pending_review':
        return AppPalette.sun;
      case 'not_passed':
        return const Color(0xFFFF8DA1);
      default:
        return AppPalette.primaryBlue;
    }
  }

  String get _statusLabel {
    switch (certification.certificationPassStatus) {
      case 'passed':
        return 'Passed';
      case 'pending_review':
        return 'Pending review';
      case 'not_passed':
        return 'Not passed';
      default:
        return 'Not eligible';
    }
  }

  String get _countsTowardLabel {
    if (certification.certificationCounted) {
      return 'Yes';
    }
    return certification.certificationEligible ? 'Not yet' : 'No';
  }

  @override
  Widget build(BuildContext context) {
    final reason = certification.reason.trim();
    final taskCode = certification.certificationTaskCode.trim();
    final requiredCodes = certification.requiredTaskCodes;
    final isTheoryPendingReview =
        missionType == 'THEORY' &&
        certification.certificationPassStatus == 'pending_review';

    return SoftPanel(
      colors: const [Color(0xFFF7FCFF), Color(0xFFEAF4FF)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Certification',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _accentColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _statusLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _accentColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            certification.certificationEnabled
                ? certification.certificationLabel
                : 'This subject does not currently use task-focus certification.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppPalette.textMuted),
          ),
          const SizedBox(height: AppSpacing.compact),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Pill(label: 'Counts toward certification: $_countsTowardLabel'),
              _Pill(
                label: taskCode.isEmpty
                    ? 'Task focus: None'
                    : 'Task focus: $taskCode',
              ),
              if (certification.certificationEligible)
                _Pill(
                  label:
                      'Score used: ${certification.scorePercent.toStringAsFixed(1)}%',
                ),
            ],
          ),
          if (requiredCodes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Required task focuses',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: requiredCodes
                  .map(
                    (code) => _Pill(
                      label: taskCode == code ? '$code · selected' : code,
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
          if (isTheoryPendingReview || reason.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.compact),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.item),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: _accentColor.withValues(alpha: 0.42)),
              ),
              child: Text(
                isTheoryPendingReview
                    ? 'Does not count yet until scored. ${reason.isEmpty ? '' : reason}'
                    : reason,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppPalette.navy),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EvidencePanel extends StatelessWidget {
  const _EvidencePanel({
    required this.resultPackage,
    required this.missionDraftJson,
  });

  final ResultPackageData resultPackage;
  final Map<String, dynamic>? missionDraftJson;

  @override
  Widget build(BuildContext context) {
    final evidence = resultPackage.evidence;
    final format = (evidence['format'] ?? '').toString();
    final legacyReason = (evidence['legacyBackfillReason'] ?? '').toString();

    return SoftPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Evidence', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.compact),
          if (legacyReason.trim().isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.item),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(
                  color: AppPalette.sun.withValues(alpha: 0.45),
                ),
              ),
              child: Text(
                legacyReason,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppPalette.navy),
              ),
            ),
            const SizedBox(height: AppSpacing.compact),
          ],
          if (format == 'ESSAY_BUILDER')
            _EssayEvidence(
              evidence: evidence,
              missionDraftJson: missionDraftJson,
            )
          else if (format == 'THEORY')
            _TheoryEvidence(evidence: evidence)
          else
            _QuestionEvidence(evidence: evidence),
        ],
      ),
    );
  }
}

class _TheoryEvidence extends StatelessWidget {
  const _TheoryEvidence({required this.evidence});

  final Map<String, dynamic> evidence;

  @override
  Widget build(BuildContext context) {
    final questions = evidence['questions'] as List<dynamic>? ?? const [];
    final triesToComplete = _asIntValue(
      evidence['triesToComplete'] ?? evidence['completionAttemptNumber'],
    );
    final questionsAnsweredCount = _asIntValue(
      evidence['questionsAnsweredCount'],
    );
    final completedResponsesCount = _asIntValue(
      evidence['completedResponsesCount'],
    );
    final reviewStatus = (evidence['reviewStatus'] ?? 'pending_review')
        .toString()
        .trim();
    final averageTeacherScorePercent = _asDoubleValue(
      evidence['averageTeacherScorePercent'],
    );
    final xpAwarded = _asIntValue(evidence['xpAwarded']);
    final xpMax = _asIntValue(evidence['xpMax']);
    final safeXpMax = xpMax <= 0 ? 50 : xpMax;

    if (questions.isEmpty) {
      return const Text('No theory evidence available.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.item),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFFBF1), Color(0xFFE9F4FF)],
            ),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: AppPalette.sky.withValues(alpha: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Summary', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 6),
              Text(
                'Tries to complete: ${triesToComplete <= 0 ? 1 : triesToComplete}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                'Questions answered: $questionsAnsweredCount/${questions.length}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                'Responses meeting minimum words: $completedResponsesCount/${questions.length}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                'Review status: ${reviewStatus == 'scored' ? 'Scored' : 'Pending review'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                'Average teacher score: ${reviewStatus == 'scored' ? '${_formatOneDecimal(averageTeacherScorePercent)}%' : 'Pending'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                'XP awarded: ${reviewStatus == 'scored' ? '$xpAwarded/$safeXpMax' : 'Pending'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.compact),
        ...questions.asMap().entries.map((entry) {
          final index = entry.key;
          final question = (entry.value as Map<dynamic, dynamic>)
              .cast<String, dynamic>();
          final meetsMinimumWords = question['meetsMinimumWords'] == true;
          final minimumWordCount = _asIntValue(question['minimumWordCount']);
          final studentWordCount = _asIntValue(question['studentWordCount']);
          final studentAnswer = (question['studentAnswer'] ?? '').toString();
          final learnFirst = (question['learnFirst'] ?? '').toString();
          final expectedAnswer = (question['expectedAnswer'] ?? '').toString();
          final teacherScorePercent = question['teacherScorePercent'];
          final teacherFeedback = (question['teacherFeedback'] ?? '')
              .toString()
              .trim();
          final scoredAt = (question['scoredAt'] ?? '').toString().trim();

          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.compact),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.item),
              decoration: BoxDecoration(
                color: meetsMinimumWords
                    ? const Color(0xFFF1FBF4)
                    : const Color(0xFFFFF7EF),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(
                  color: meetsMinimumWords
                      ? AppPalette.mint.withValues(alpha: 0.75)
                      : AppPalette.orange.withValues(alpha: 0.55),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Theory ${index + 1}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: meetsMinimumWords
                              ? AppPalette.mint.withValues(alpha: 0.3)
                              : AppPalette.sun.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          meetsMinimumWords
                              ? 'Minimum met'
                              : 'Needs more detail',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppPalette.navy,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '$studentWordCount / $minimumWordCount words',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppPalette.textMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    (question['questionText'] ?? '').toString(),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppPalette.navy,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (learnFirst.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Learn First',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: AppPalette.textMuted,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            learnFirst,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppPalette.navy),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (expectedAnswer.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Expected answer',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppPalette.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      expectedAnswer,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppPalette.mint.withValues(alpha: 0.95),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  if (teacherScorePercent != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppPalette.primaryBlue.withValues(
                              alpha: 0.14,
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Teacher score: ${teacherScorePercent.toString()}/100',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: AppPalette.primaryBlue,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        if (scoredAt.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Scored ${_formatReportDateTime(scoredAt)}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppPalette.textMuted),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    'Student answer',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppPalette.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      studentAnswer.trim().isEmpty
                          ? 'No written answer recorded.'
                          : studentAnswer,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppPalette.navy),
                    ),
                  ),
                  if (teacherFeedback.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Teacher feedback',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppPalette.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF2FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        teacherFeedback,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: AppPalette.navy),
                      ),
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

class _QuestionEvidence extends StatelessWidget {
  const _QuestionEvidence({required this.evidence});

  final Map<String, dynamic> evidence;

  @override
  Widget build(BuildContext context) {
    final questions = evidence['questions'] as List<dynamic>? ?? const [];
    final triesToComplete = _asIntValue(
      evidence['triesToComplete'] ?? evidence['completionAttemptNumber'],
    );
    final totalPointsEarnedRaw = _asIntValue(evidence['totalPointsEarned']);
    final totalPointsPossibleRaw = _asIntValue(evidence['totalPointsPossible']);
    final fallbackPointsEarned = questions.where((entry) {
      final question = (entry as Map<dynamic, dynamic>).cast<String, dynamic>();
      return question['correctness'] == true;
    }).length;
    final fallbackPointsPossible = questions.length;
    final totalPointsPossible = totalPointsPossibleRaw > 0
        ? totalPointsPossibleRaw
        : fallbackPointsPossible;
    final totalPointsEarned = totalPointsPossibleRaw > 0
        ? totalPointsEarnedRaw
        : fallbackPointsEarned;
    final answeredFromPayload = _asIntValue(evidence['questionsAnsweredCount']);
    final answeredFromRows = questions.where((entry) {
      final question = (entry as Map<dynamic, dynamic>).cast<String, dynamic>();
      return (question['attempted'] == true) ||
          (question['selectedAnswer'] ?? '').toString().trim().isNotEmpty;
    }).length;
    final questionsAnsweredCount = answeredFromPayload > 0
        ? answeredFromPayload
        : answeredFromRows;

    if (questions.isEmpty) {
      return const Text('No question evidence available.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.item),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFEFFAF5), Color(0xFFE9F4FF)],
            ),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: AppPalette.sky.withValues(alpha: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Summary', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 6),
              Text(
                'Tries to complete: ${triesToComplete <= 0 ? 1 : triesToComplete}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                'Questions answered: $questionsAnsweredCount/${questions.length}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                'Points: $totalPointsEarned/$totalPointsPossible',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.compact),
        ...questions.asMap().entries.map((entry) {
          final index = entry.key;
          final question = (entry.value as Map<dynamic, dynamic>)
              .cast<String, dynamic>();
          final correctness = question['correctness'] == true;
          final selectedOptionLetter = (question['selectedOptionLetter'] ?? '')
              .toString()
              .trim()
              .toUpperCase();
          final selectedAnswer = (question['selectedAnswer'] ?? '')
              .toString()
              .trim();
          final correctOptionLetter = (question['correctOptionLetter'] ?? '')
              .toString()
              .trim()
              .toUpperCase();
          final correctAnswer = (question['correctAnswer'] ?? '')
              .toString()
              .trim();
          final optionMap = _extractQuestionOptions(question);
          final hasStoredMaxPoints = _asIntValue(question['maxPoints']) > 0;
          final maxPoints = hasStoredMaxPoints
              ? _asIntValue(question['maxPoints'])
              : 1;
          final pointsEarned = hasStoredMaxPoints
              ? _asIntValue(question['pointsEarned'])
              : (correctness ? 1 : 0);
          final legacySelectionUnavailable =
              question['legacySelectionUnavailable'] == true;

          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.compact),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.item),
              decoration: BoxDecoration(
                color: correctness
                    ? const Color(0xFFF1FBF4)
                    : const Color(0xFFFFF7EF),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(
                  color: correctness
                      ? AppPalette.mint.withValues(alpha: 0.75)
                      : AppPalette.orange.withValues(alpha: 0.55),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Q${index + 1}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: correctness
                              ? AppPalette.mint.withValues(alpha: 0.3)
                              : AppPalette.sun.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          correctness ? 'Correct' : 'Incorrect',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppPalette.navy,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Points: $pointsEarned/$maxPoints',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppPalette.textMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    (question['questionText'] ?? '').toString(),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppPalette.navy,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...['A', 'B', 'C', 'D'].map((letter) {
                    final optionText = (optionMap[letter] ?? '').trim();
                    final isCorrectOption = letter == correctOptionLetter;
                    final isSelectedOption = letter == selectedOptionLetter;
                    final isSelectedWrong =
                        isSelectedOption && !isCorrectOption;
                    Color tileColor = Colors.white;
                    Color borderColor = AppPalette.sky.withValues(alpha: 0.5);
                    if (isCorrectOption) {
                      tileColor = const Color(0xFFEAF9EE);
                      borderColor = AppPalette.mint.withValues(alpha: 0.85);
                    } else if (isSelectedWrong) {
                      tileColor = const Color(0xFFFFF0E3);
                      borderColor = AppPalette.orange.withValues(alpha: 0.8);
                    } else if (isSelectedOption) {
                      tileColor = const Color(0xFFEAF2FF);
                      borderColor = AppPalette.primaryBlue.withValues(
                        alpha: 0.6,
                      );
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: tileColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$letter) ',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: AppPalette.navy,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            Expanded(
                              child: Text(
                                optionText.isEmpty ? '-' : optionText,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: AppPalette.navy),
                              ),
                            ),
                            if (isCorrectOption)
                              Icon(
                                Icons.check_circle_rounded,
                                size: 16,
                                color: AppPalette.mint.withValues(alpha: 0.95),
                              )
                            else if (isSelectedWrong)
                              Icon(
                                Icons.radio_button_checked_rounded,
                                size: 16,
                                color: AppPalette.orange,
                              )
                            else if (isSelectedOption)
                              Icon(
                                Icons.radio_button_checked_rounded,
                                size: 16,
                                color: AppPalette.primaryBlue,
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 4),
                  Text(
                    'Correct: ${correctOptionLetter.isNotEmpty ? '$correctOptionLetter) ' : ''}$correctAnswer',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppPalette.mint.withValues(alpha: 0.95),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Selected: ${selectedOptionLetter.isNotEmpty ? '$selectedOptionLetter) ' : ''}${selectedAnswer.isNotEmpty ? selectedAnswer : 'No selection recorded'}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppPalette.navy,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (legacySelectionUnavailable &&
                      selectedOptionLetter.isEmpty &&
                      selectedAnswer.isEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Original selected option was not saved in this older record.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppPalette.textMuted,
                      ),
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

class _EssayEvidence extends StatelessWidget {
  const _EssayEvidence({
    required this.evidence,
    required this.missionDraftJson,
  });

  final Map<String, dynamic> evidence;
  final Map<String, dynamic>? missionDraftJson;

  @override
  Widget build(BuildContext context) {
    final perSentence = evidence['perSentence'] as List<dynamic>? ?? const [];
    final finalEssayText = (evidence['finalEssayText'] ?? '').toString();
    final finalWordCount = (evidence['finalWordCount'] ?? 0).toString();
    final blankCompletionCount = (evidence['blankCompletionCount'] ?? 0)
        .toString();
    final blankTargetCount = (evidence['blankTargetCount'] ?? 0).toString();
    final triesToComplete = _asIntValue(
      evidence['triesToComplete'] ?? evidence['completionAttemptNumber'],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.item),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFEFFAF5), Color(0xFFE9F4FF)],
            ),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: AppPalette.sky.withValues(alpha: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Summary', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 6),
              Text(
                'Tries to complete: ${triesToComplete <= 0 ? 1 : triesToComplete}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                'Blank progress: $blankCompletionCount/$blankTargetCount',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                'Word count: $finalWordCount',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.compact),
        ...perSentence.asMap().entries.map((entry) {
          final index = entry.key;
          final sentence = (entry.value as Map<dynamic, dynamic>)
              .cast<String, dynamic>();
          final sentenceId = (sentence['sentenceId'] ?? '').toString().trim();
          final role = (sentence['role'] ?? '').toString().toLowerCase().trim();
          final bullets =
              sentence['learnFirstBullets'] as List<dynamic>? ?? const [];
          final blankSelections =
              sentence['blankSelections'] as List<dynamic>? ?? const [];
          final accentColor = role == 'topic'
              ? AppPalette.primaryBlue
              : role == 'conclusion'
              ? AppPalette.mint
              : AppPalette.sun;
          final surfaceColor = role == 'topic'
              ? const Color(0xFFEAF2FF)
              : role == 'conclusion'
              ? const Color(0xFFEFFAF5)
              : const Color(0xFFFFF7EE);

          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.compact),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.item),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: accentColor.withValues(alpha: 0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Sentence ${index + 1}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          role.isEmpty ? 'detail' : role,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppPalette.navy,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ],
                  ),
                  if (bullets.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Learn First',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: AppPalette.navy,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 6),
                          ...bullets.map(
                            (bullet) => Text(
                              '• ${bullet.toString()}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (blankSelections.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ...blankSelections.asMap().entries.map((blankEntry) {
                      final blankIndex = blankEntry.key;
                      final blank = blankEntry.value;
                      final item = (blank as Map<dynamic, dynamic>)
                          .cast<String, dynamic>();
                      final blankId = (item['blankId'] ?? '').toString().trim();
                      var hint = (item['hint'] ?? '').toString().trim();
                      var selectedLetter = (item['chosenOptionLetter'] ?? '')
                          .toString()
                          .trim()
                          .toUpperCase();
                      var selectedText = (item['chosenOptionText'] ?? '')
                          .toString()
                          .trim();
                      var correctLetter = (item['correctOptionLetter'] ?? '')
                          .toString()
                          .trim()
                          .toUpperCase();
                      var correctText = (item['correctOptionText'] ?? '')
                          .toString()
                          .trim();
                      final optionMap = _extractBlankOptions(item);
                      final draftBlank = _findEssayDraftBlank(
                        missionDraftJson: missionDraftJson,
                        sentenceId: sentenceId,
                        sentenceIndex: index,
                        blankId: blankId,
                        blankIndex: blankIndex,
                      );
                      if (draftBlank != null) {
                        if (hint.isEmpty) {
                          hint = (draftBlank['hint'] ?? '').toString().trim();
                        }
                        final draftOptions =
                            draftBlank['options'] as Map<dynamic, dynamic>? ??
                            const {};
                        for (final letter in ['A', 'B', 'C', 'D']) {
                          if ((optionMap[letter] ?? '').trim().isEmpty) {
                            optionMap[letter] = (draftOptions[letter] ?? '')
                                .toString()
                                .trim();
                          }
                        }
                        if (correctLetter.isEmpty) {
                          final draftCorrect =
                              (draftBlank['correctOption'] ?? '')
                                  .toString()
                                  .trim()
                                  .toUpperCase();
                          if (['A', 'B', 'C', 'D'].contains(draftCorrect)) {
                            correctLetter = draftCorrect;
                          }
                        }
                      }
                      if (!['A', 'B', 'C', 'D'].contains(selectedLetter)) {
                        selectedLetter = '';
                      }
                      if (!['A', 'B', 'C', 'D'].contains(correctLetter)) {
                        correctLetter = '';
                      }
                      if (selectedText.isEmpty && selectedLetter.isNotEmpty) {
                        selectedText = (optionMap[selectedLetter] ?? '').trim();
                      }
                      if (correctText.isEmpty && correctLetter.isNotEmpty) {
                        correctText = (optionMap[correctLetter] ?? '').trim();
                      }

                      return Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppPalette.sky.withValues(alpha: 0.55),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              blankId.isNotEmpty
                                  ? 'Blank ${blankIndex + 1} · $blankId'
                                  : 'Blank ${blankIndex + 1}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: AppPalette.navy,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            if (hint.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Hint: $hint',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: AppPalette.textMuted),
                              ),
                            ],
                            const SizedBox(height: 8),
                            ...['A', 'B', 'C', 'D'].map((letter) {
                              final optionText = (optionMap[letter] ?? '')
                                  .trim();
                              final isCorrect = letter == correctLetter;
                              final isSelected = letter == selectedLetter;
                              final isSelectedWrong = isSelected && !isCorrect;

                              Color tileColor = Colors.white;
                              Color borderColor = AppPalette.sky.withValues(
                                alpha: 0.5,
                              );
                              if (isCorrect) {
                                tileColor = const Color(0xFFEAF9EE);
                                borderColor = AppPalette.mint.withValues(
                                  alpha: 0.85,
                                );
                              } else if (isSelectedWrong) {
                                tileColor = const Color(0xFFFFF0E3);
                                borderColor = AppPalette.orange.withValues(
                                  alpha: 0.8,
                                );
                              } else if (isSelected) {
                                tileColor = const Color(0xFFEAF2FF);
                                borderColor = AppPalette.primaryBlue.withValues(
                                  alpha: 0.6,
                                );
                              }

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: tileColor,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: borderColor),
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        '$letter) ',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: AppPalette.navy,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          optionText.isEmpty ? '-' : optionText,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: AppPalette.navy,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                            const SizedBox(height: 4),
                            Text(
                              'Correct: ${correctLetter.isNotEmpty ? '$correctLetter) ' : ''}$correctText',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: AppPalette.mint.withValues(
                                      alpha: 0.95,
                                    ),
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            Text(
                              'Selected: ${selectedLetter.isNotEmpty ? '$selectedLetter) ' : ''}${selectedText.isNotEmpty ? selectedText : 'No selection recorded'}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: AppPalette.navy,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ] else ...[
                    const SizedBox(height: 8),
                    Text(
                      'No blank evidence available for this sentence.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppPalette.textMuted,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    (sentence['fullSentenceOutput'] ?? '').toString(),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppPalette.navy,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: AppSpacing.compact),
        Text('Final Essay', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(finalEssayText),
        const SizedBox(height: 8),
        Text(
          'Word count: $finalWordCount · Blanks: $blankCompletionCount/$blankTargetCount',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppPalette.textMuted),
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
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppPalette.textMuted),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: AppPalette.navy),
      ),
    );
  }
}

class _SendLogCard extends StatelessWidget {
  const _SendLogCard({required this.log});

  final ResultSendLog log;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.item),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sent at: ${_formatReportDateTime(log.sentAt)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 6),
          Text(
            'In-app: ${log.inAppStatus.status}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Text(
            'Email: ${log.emailStatus.status}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (log.emailStatus.failureReason.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Email note: ${log.emailStatus.failureReason}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppPalette.orange),
            ),
          ],
          if (log.emailRetry.pending) ...[
            const SizedBox(height: 4),
            Text(
              'Email pending retry (${log.emailRetry.retryCount}/${log.emailRetry.maxRetries})',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppPalette.primaryBlue),
            ),
          ],
        ],
      ),
    );
  }
}
