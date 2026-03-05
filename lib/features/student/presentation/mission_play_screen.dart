/**
 * WHAT:
 * MissionPlayScreen runs the student mission experience from learn-first stage
 * through question answering and final completion.
 * WHY:
 * The mission flow is teach-first, so the student must read the learning note
 * before the question appears for each item.
 * HOW:
 * Track the current item, gate each question behind its learning stage, record
 * answers, and complete the session through the backend when finished.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_palette.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/focus_mission_api.dart';
import '../../../shared/models/focus_mission_models.dart';
import '../../../shared/widgets/focus_scaffold.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../shared/widgets/soft_panel.dart';
import 'celebration_sound_stub.dart'
    if (dart.library.html) 'celebration_sound_web.dart'
    as celebration_sound;

class MissionPlayScreen extends StatefulWidget {
  const MissionPlayScreen({
    super.key,
    required this.session,
    required this.startedMission,
  });

  final AuthSession session;
  final StartedMission startedMission;

  @override
  State<MissionPlayScreen> createState() => _MissionPlayScreenState();
}

class _MissionPlayScreenState extends State<MissionPlayScreen>
    with SingleTickerProviderStateMixin {
  final FocusMissionApi _api = FocusMissionApi();
  final math.Random _random = math.Random();
  static const int _essaySubmissionMinWords = 100;
  static const Map<int, int> _requiredCorrectByTotal = {
    5: 4,
    8: 6,
    10: 7,
    15: 11,
    20: 14,
  };
  final TextEditingController _essaySubmissionController =
      TextEditingController();

  int _currentIndex = 0;
  final Map<int, int> _answers = <int, int>{};
  final Map<int, int> _selectedOptions = <int, int>{};
  EssayBuilderDraft? _essayDraft;
  final Map<String, String> _essaySelections = <String, String>{};
  final List<String> _essaySentences = <String>[];
  bool _showQuestionStage = true;
  bool _isSubmitting = false;
  CompleteMissionResult? _completedResult;
  String? _errorMessage;
  Timer? _xpPulseTimer;
  bool _showXpPulse = false;
  bool _xpPulsePositive = false;
  int _xpPulseValue = 0;
  int _coachVersion = 0;
  late final AnimationController _confettiController;
  List<_ConfettiParticle> _confettiParticles = const [];
  List<_FireworkSpark> _fireworkSparks = const [];
  AudioPlayer? _celebrationPlayer;

  MissionPayload get _mission => widget.startedMission.mission;
  bool get _isEssayBuilderMission => _essayDraft != null;

  int get _essayTotalCount {
    final draft = _essayDraft;
    if (draft == null) {
      return 0;
    }
    final target = draft.targets.targetSentenceCount;
    if (target > 0) {
      return math.min(target, draft.sentences.length);
    }
    return draft.sentences.length;
  }

  String get _essayParagraph => _essaySentences.join(' ').trim();

  int get _essayTargetBlankCount {
    final draft = _essayDraft;
    if (draft == null) {
      return 0;
    }
    final target = draft.targets.targetBlankCount;
    if (target > 0) {
      return target;
    }
    return draft.sentences.fold<int>(
      0,
      (sum, sentence) =>
          sum + sentence.parts.where((part) => part.isBlank).length,
    );
  }

  int get _essayCompletedBlankCount {
    return _essaySelections.values
        .where((value) => value.trim().isNotEmpty)
        .length;
  }

  int get _essayWordCount {
    if (_essayParagraph.isEmpty) {
      return 0;
    }
    return _essayParagraph
        .split(RegExp(r'\s+'))
        .where((word) => word.trim().isNotEmpty)
        .length;
  }

  String get _essaySubmissionText => _essaySubmissionController.text.trim();

  int get _essaySubmissionWordCount {
    if (_essaySubmissionText.isEmpty) {
      return 0;
    }
    return _essaySubmissionText
        .split(RegExp(r'\s+'))
        .where((word) => word.trim().isNotEmpty)
        .length;
  }

  int _minimumCorrectForSubmit(int totalCount) {
    if (totalCount <= 0) {
      return 0;
    }
    return _requiredCorrectByTotal[totalCount] ?? 0;
  }

  @override
  void initState() {
    super.initState();
    _confettiController =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 2200),
          )
          ..addListener(() {
            if (mounted && _confettiController.isAnimating) {
              setState(() {});
            }
          })
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed && mounted) {
              setState(() {
                _confettiParticles = const [];
                _fireworkSparks = const [];
              });
            }
          });
    if (kIsWeb) {
      unawaited(celebration_sound.warmupHurraySound());
    } else {
      _celebrationPlayer = AudioPlayer();
      unawaited(_preloadCelebrationSound());
    }
    _essayDraft = _mission.essayBuilderDraft;
    if (!_isEssayBuilderMission) {
      _showQuestionStage = _shouldStartOnQuestion(
        _mission.questions.isEmpty ? null : _mission.questions.first,
      );
    }
  }

  @override
  void dispose() {
    _xpPulseTimer?.cancel();
    _confettiController.dispose();
    _celebrationPlayer?.dispose();
    _essaySubmissionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FocusScaffold(
      child: SafeArea(
        child: _completedResult != null
            ? _buildSummary(context)
            : _isEssayBuilderMission
            ? _buildEssayBuilder(context)
            : _buildQuiz(context),
      ),
    );
  }

  Widget _buildQuiz(BuildContext context) {
    if (_mission.questions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screen),
          child: SoftPanel(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'No questions are ready yet',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.item),
                Text(
                  'Ask the teacher to create an AI mission or add more question-bank content for this subject.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.section),
                GradientButton(
                  label: 'Back to Dashboard',
                  colors: AppPalette.teacherGradient,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final question = _mission.questions[_currentIndex];
    final selectedIndex = _selectedOptions[_currentIndex];
    final answerLocked = _answers.containsKey(_currentIndex);
    final wrongSelectionLocked =
        !answerLocked &&
        selectedIndex != null &&
        selectedIndex != question.correctIndex;
    final learnStageOnly = _isLearnStage(question);
    final progress = _progressFor(question);
    final coachMessage = _buildCoachMessage(
      question: question,
      answerLocked: answerLocked,
      selectedIndex: selectedIndex,
    );

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _RoundButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      _mission.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  _TagPill(
                    label: _mission.source == 'groq'
                        ? 'AI mission'
                        : 'Practice',
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.section),
              SoftPanel(
                colors: const [Color(0xFFFFF9EE), Color(0xFFFFEED8)],
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Do you want to start a daily mission instead?',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppPalette.navy,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    TextButton(
                      onPressed: _promptStartDailyMission,
                      child: const Text('Start Daily Mission'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.item),
              SoftPanel(
                colors: const [Color(0xFFF6FCFF), Color(0xFFE4F3FF)],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _StatPill(
                          label: learnStageOnly
                              ? 'Learn ${_currentIndex + 1} of ${_mission.questions.length}'
                              : 'Question ${_currentIndex + 1} of ${_mission.questions.length}',
                        ),
                        _StatPill(label: _mission.subject?.name ?? 'Mission'),
                        _StatPill(label: _mission.sessionType.toUpperCase()),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.item),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: Stack(
                        children: [
                          Container(
                            height: 12,
                            width: double.infinity,
                            color: Colors.white.withValues(alpha: 0.72),
                          ),
                          AnimatedFractionallySizedBox(
                            duration: const Duration(milliseconds: 420),
                            curve: Curves.easeOutCubic,
                            widthFactor: progress,
                            child: Container(
                              height: 12,
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: AppPalette.progressGradient,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_mission.teacherNote.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.item),
                      Text(
                        _mission.teacherNote,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppPalette.textMuted,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.item),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 320),
                      switchInCurve: Curves.easeOutBack,
                      switchOutCurve: Curves.easeInCubic,
                      child: _CoachBanner(
                        key: ValueKey<String>(
                          'coach_${_currentIndex}_$coachMessage',
                        ),
                        message: coachMessage,
                        positive: selectedIndex == question.correctIndex,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.section),
              SoftPanel(
                colors: const [Color(0xFFFFFEFB), Color(0xFFFFF2D8)],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (learnStageOnly) ...[
                      _LearningPanel(
                        text: question.learningText,
                        questionIndex: _currentIndex + 1,
                      ),
                      const SizedBox(height: AppSpacing.section),
                      SoftPanel(
                        colors: const [Color(0xFFF8FCFF), Color(0xFFEAF6FF)],
                        child: Text(
                          'Read the learning note first, then tap continue to unlock the question.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppPalette.textMuted),
                        ),
                      ),
                    ] else ...[
                      if (question.learningText.isNotEmpty) ...[
                        _LearningPanel(
                          text: question.learningText,
                          questionIndex: _currentIndex + 1,
                        ),
                        const SizedBox(height: AppSpacing.section),
                      ],
                      Text(
                        question.prompt,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: AppSpacing.section),
                      ...List.generate(
                        question.options.length,
                        (index) => Padding(
                          padding: const EdgeInsets.only(
                            bottom: AppSpacing.compact,
                          ),
                          child: _AnswerOptionCard(
                            label: question.options[index],
                            isSelected: selectedIndex == index,
                            isCorrect: question.correctIndex == index,
                            answerLocked: answerLocked || wrongSelectionLocked,
                            onTap: answerLocked || wrongSelectionLocked
                                ? null
                                : () => _pickAnswer(index),
                          ),
                        ),
                      ),
                      if (selectedIndex != null) ...[
                        const SizedBox(height: AppSpacing.item),
                        _FeedbackPanel(
                          isCorrect: selectedIndex == question.correctIndex,
                          explanation: question.explanation,
                          answerText: question.options[question.correctIndex],
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: AppSpacing.item),
                SoftPanel(
                  colors: const [Color(0xFFFFF4F4), Color(0xFFFFE0E0)],
                  child: Text(
                    _errorMessage!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
              AnimatedSlide(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutBack,
                offset: _showXpPulse ? Offset.zero : const Offset(0, 0.2),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 240),
                  opacity: _showXpPulse ? 1 : 0,
                  child: Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.item),
                    child: _XpPulsePill(
                      label: _xpPulsePositive
                          ? 'Nice! Potential +$_xpPulseValue XP'
                          : 'Keep going. Next one can add XP.',
                      positive: _xpPulsePositive,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.section),
              GradientButton(
                label: _buttonLabel(answerLocked),
                colors: _buttonColors(answerLocked),
                onPressed: _buttonAction(answerLocked),
              ),
            ],
          ),
        ),
        if (_confettiParticles.isNotEmpty)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _ConfettiBurstPainter(
                  particles: _confettiParticles,
                  sparks: _fireworkSparks,
                  progress: Curves.easeOutQuart.transform(
                    _confettiController.value,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEssayBuilder(BuildContext context) {
    final draft = _essayDraft;
    if (draft == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screen),
          child: SoftPanel(
            child: Text(
              'This essay builder draft is not ready yet. Ask your teacher to regenerate the mission.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppPalette.textMuted),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final displayedSentences = draft.sentences
        .take(_essayTotalCount > 0 ? _essayTotalCount : draft.sentences.length)
        .toList(growable: false);
    final totalSentences = _essayTotalCount;
    final targetBlankCount = _essayTargetBlankCount;
    final completedSentences = _essaySentences.length;
    final completedBlanks = _essayCompletedBlankCount;
    final targetWordMin = draft.targets.targetWordMin;
    final targetWordMax = draft.targets.targetWordMax;
    final currentWordCount = _essayWordCount;
    final hasWordMinimum =
        targetWordMin <= 0 || currentWordCount >= targetWordMin;
    final exceedsWordMaximum =
        targetWordMax > 0 && currentWordCount > targetWordMax;
    final allRequiredBlanksComplete =
        targetBlankCount > 0 && completedBlanks >= targetBlankCount;
    final isComplete =
        completedSentences >= totalSentences && totalSentences > 0;
    final isSubmissionFormUnlocked = isComplete && allRequiredBlanksComplete;
    final submissionWordCount = _essaySubmissionWordCount;
    final hasSubmissionEssayMinimum =
        submissionWordCount >= _essaySubmissionMinWords;
    final canSubmit =
        isComplete &&
        allRequiredBlanksComplete &&
        hasWordMinimum &&
        !exceedsWordMaximum &&
        hasSubmissionEssayMinimum;
    final currentSentenceIndex = math.min(
      completedSentences,
      math.max(0, displayedSentences.length - 1),
    );
    final activeSentence = displayedSentences.isNotEmpty
        ? displayedSentences[currentSentenceIndex]
        : null;
    final activePreview = activeSentence == null
        ? ''
        : _buildEssaySentencePreview(activeSentence);
    final activePreviewSpans = activeSentence == null
        ? const <InlineSpan>[]
        : _buildEssaySentencePreviewSpans(activeSentence);

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _RoundButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      _mission.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  _TagPill(
                    label: _mission.source == 'groq'
                        ? 'AI mission'
                        : 'Practice',
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.section),
              SoftPanel(
                colors: const [Color(0xFFF6FCFF), Color(0xFFE4F3FF)],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _StatPill(
                          label:
                              'Sentence ${completedSentences + 1} of $totalSentences',
                        ),
                        _StatPill(label: _mission.subject?.name ?? 'Mission'),
                        _StatPill(label: draft.mode),
                        _StatPill(label: '$currentWordCount words'),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.item),
                    Text(
                      'Target words: $targetWordMin-$targetWordMax',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppPalette.textMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Sentences completed: $completedSentences / $totalSentences',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppPalette.textMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Blanks completed: $completedBlanks / $targetBlankCount',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppPalette.textMuted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: totalSentences == 0
                            ? 0
                            : completedSentences / totalSentences,
                        minHeight: 10,
                        backgroundColor: const Color(0xFFE7EEF8),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppPalette.aqua,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.section),
              Text(
                'Build your essay',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (!hasWordMinimum && isComplete) ...[
                const SizedBox(height: 10),
                SoftPanel(
                  colors: const [Color(0xFFFFF9EE), Color(0xFFFFEED8)],
                  child: Text(
                    'Add more detail to reach at least $targetWordMin words before submitting.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppPalette.navy,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              if (exceedsWordMaximum) ...[
                const SizedBox(height: 10),
                SoftPanel(
                  colors: const [Color(0xFFFFEFEA), Color(0xFFFFE5DB)],
                  child: Text(
                    'Word count is above $targetWordMax. Submission is blocked until the essay is within range.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppPalette.orange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              ...List.generate(displayedSentences.length, (index) {
                final sentence = displayedSentences[index];
                if (index < completedSentences) {
                  return _EssaySentenceCard(
                    title: 'Sentence ${index + 1} · ${sentence.role}',
                    body: _essaySentences[index],
                    isLocked: true,
                  );
                }

                if (index == currentSentenceIndex && !isComplete) {
                  return _buildEssaySentenceEditor(
                    sentence,
                    index + 1,
                    learnFirst: sentence.learnFirst,
                  );
                }

                return _EssaySentenceCard(
                  title: 'Sentence ${index + 1} · ${sentence.role}',
                  body: 'Locked until you finish the previous sentence.',
                  isLocked: true,
                );
              }),
              const SizedBox(height: AppSpacing.section),
              Text(
                'Your essay',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              SoftPanel(
                colors: const [Color(0xFFF7FCFF), Color(0xFFE9F4FF)],
                child:
                    _essayParagraph.isEmpty &&
                        activePreview.isEmpty &&
                        activePreviewSpans.isEmpty
                    ? Text(
                        'Your essay will appear here as you complete each sentence.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_essayParagraph.isNotEmpty)
                            Text(
                              _essayParagraph,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          if (activePreviewSpans.isNotEmpty) ...[
                            if (_essayParagraph.isNotEmpty)
                              const SizedBox(height: 6),
                            RichText(
                              text: TextSpan(
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: AppPalette.navy),
                                children: activePreviewSpans,
                              ),
                            ),
                          ],
                          if (activePreviewSpans.isEmpty &&
                              activePreview.isNotEmpty &&
                              _essayParagraph.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              activePreview,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ],
                      ),
              ),
              if (isSubmissionFormUnlocked) ...[
                const SizedBox(height: AppSpacing.section),
                Text(
                  'Write an essay based on your above understanding',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                SoftPanel(
                  colors: const [Color(0xFFFFFEF8), Color(0xFFFFF5DE)],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Minimum $_essaySubmissionMinWords words',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppPalette.textMuted,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Shortcuts(
                        shortcuts: const <ShortcutActivator, Intent>{
                          SingleActivator(
                            LogicalKeyboardKey.keyV,
                            control: true,
                          ): DoNothingAndStopPropagationIntent(),
                          SingleActivator(
                            LogicalKeyboardKey.keyV,
                            meta: true,
                          ): DoNothingAndStopPropagationIntent(),
                          SingleActivator(
                            LogicalKeyboardKey.insert,
                            shift: true,
                          ): DoNothingAndStopPropagationIntent(),
                        },
                        child: TextField(
                          controller: _essaySubmissionController,
                          minLines: 6,
                          maxLines: 10,
                          enableInteractiveSelection: false,
                          onChanged: (_) {
                            setState(() {
                              _errorMessage = null;
                            });
                          },
                          decoration: InputDecoration(
                            hintText:
                                'Write your final essay response here using what you learned above.',
                            filled: true,
                            fillColor: const Color(0xFFFFFFFF),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: const BorderSide(
                                color: Color(0xFFD7E2F3),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: const BorderSide(
                                color: AppPalette.primaryBlue,
                                width: 1.4,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Final essay words: $submissionWordCount / $_essaySubmissionMinWords',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: hasSubmissionEssayMinimum
                              ? AppPalette.aqua
                              : AppPalette.orange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.section),
              GradientButton(
                label: canSubmit
                    ? (_isSubmitting
                          ? 'Saving Mission...'
                          : 'Submit Essay Mission')
                    : !isComplete
                    ? 'Complete the current sentence'
                    : !allRequiredBlanksComplete
                    ? 'Finish all blanks before submit'
                    : !hasWordMinimum
                    ? 'Reach minimum words to submit'
                    : !hasSubmissionEssayMinimum
                    ? 'Write at least 100 words to submit'
                    : 'Reduce words to submit',
                colors: canSubmit
                    ? const [AppPalette.primaryBlue, AppPalette.sun]
                    : const [Color(0xFFD7DDEA), Color(0xFFC7D2E7)],
                onPressed: canSubmit && !_isSubmitting
                    ? _completeMission
                    : () {},
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 10),
                Text(
                  _errorMessage!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppPalette.orange),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummary(BuildContext context) {
    final completedResult = _completedResult;
    if (completedResult == null) {
      return const SizedBox.shrink();
    }
    final total = _isEssayBuilderMission
        ? _essayTotalCount
        : _mission.questions.length;
    final correct = _isEssayBuilderMission
        ? _essaySentences.length
        : _correctAnswers();
    final focusScore = _isEssayBuilderMission
        ? _essayFocusScore()
        : _focusScore();
    final fallbackEarnedXp = total >= 10
        ? ((50 * focusScore) / 100).round()
        : ((30 * focusScore) / 100).round();
    final earnedXp = completedResult.sessionXpAwarded > 0
        ? completedResult.sessionXpAwarded
        : fallbackEarnedXp;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screen),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: SoftPanel(
            colors: const [Color(0xFFF6FFF8), Color(0xFFE6F8FF)],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mission Complete',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: AppSpacing.item),
                Text(
                  _mission.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.section),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _SummaryChip(
                      label: _isEssayBuilderMission ? 'Completed' : 'Correct',
                      value: '$correct / $total',
                      colors: AppPalette.studentGradient,
                    ),
                    _SummaryChip(
                      label: 'Focus',
                      value: '$focusScore%',
                      colors: const [AppPalette.primaryBlue, AppPalette.aqua],
                    ),
                    _SummaryChip(
                      label: 'XP Earned',
                      value: '+$earnedXp',
                      colors: const [AppPalette.sun, AppPalette.orange],
                    ),
                    if (completedResult.subjectCompletionBonusXp > 0)
                      _SummaryChip(
                        label: 'Subject bonus',
                        value: '+${completedResult.subjectCompletionBonusXp}',
                        colors: const [AppPalette.mint, AppPalette.aqua],
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.section),
                Text(
                  'Great work. Your answers have been saved and the dashboard will refresh your XP and recent activity.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: AppSpacing.section),
                GradientButton(
                  label: 'Return to Dashboard',
                  colors: AppPalette.progressGradient,
                  onPressed: () =>
                      Navigator.of(context).pop(completedResult.student),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _pickAnswer(int index) {
    final question = _mission.questions[_currentIndex];
    final answerLocked = _answers.containsKey(_currentIndex);
    final selectedIndex = _selectedOptions[_currentIndex];
    final wrongSelectionLocked =
        !answerLocked &&
        selectedIndex != null &&
        selectedIndex != question.correctIndex;
    if (answerLocked || wrongSelectionLocked) {
      // WHY: After a wrong tap, the learner must use Try Again so they
      // intentionally reset before attempting another option.
      return;
    }

    final isCorrect = index == question.correctIndex;
    final previewXp = _previewXpForAnswer(isCorrect);
    _xpPulseTimer?.cancel();
    if (isCorrect) {
      _triggerConfettiBurst(success: true);
    }

    setState(() {
      _selectedOptions[_currentIndex] = index;
      if (isCorrect) {
        // WHY: Lock progression only when the learner chooses the right answer,
        // so the correct option is never revealed after a wrong tap.
        _answers[_currentIndex] = index;
        _errorMessage = null;
      } else {
        // WHY: A clear retry cue reduces ambiguity after a wrong answer.
        _errorMessage = 'Not quite. Tap Retry to try again.';
      }
      _showXpPulse = true;
      _xpPulsePositive = isCorrect;
      _xpPulseValue = previewXp;
      _coachVersion += 1;
    });

    _xpPulseTimer = Timer(const Duration(milliseconds: 1300), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _showXpPulse = false;
      });
    });
  }

  Widget _buildEssaySentenceEditor(
    EssayBuilderSentence sentence,
    int displayIndex, {
    required EssaySentenceLearnFirst learnFirst,
  }) {
    final blankParts = sentence.parts.where((part) => part.isBlank).toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.item),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SoftPanel(
            colors: const [Color(0xFFFFF9EE), Color(0xFFFFEED8)],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  learnFirst.title.isEmpty ? 'Learn First' : learnFirst.title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'Read this before you complete Sentence $displayIndex.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppPalette.textMuted),
                ),
                const SizedBox(height: 8),
                ...learnFirst.bullets.map(
                  (bullet) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('• $bullet'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SoftPanel(
            colors: const [Color(0xFFF7FCFF), Color(0xFFE9F4FF)],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sentence $displayIndex · ${sentence.role}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                RichText(
                  text: TextSpan(
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppPalette.navy,
                      fontWeight: FontWeight.w600,
                    ),
                    children: _buildEssaySentencePreviewSpans(sentence),
                  ),
                ),
                const SizedBox(height: 10),
                ...blankParts.map((part) {
                  final options = [
                    'A',
                    'B',
                    'C',
                    'D',
                  ].where((key) => part.options.containsKey(key)).toList();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          part.hint.isEmpty
                              ? 'Choose the best option'
                              : part.hint,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppPalette.textMuted),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: options
                              .map(
                                (key) => _EssayOptionChip(
                                  label: '$key. ${part.options[key] ?? ''}',
                                  selected:
                                      _essaySelections[part.blankId] == key,
                                  enabled: true,
                                  onTap: () => _selectEssayOption(
                                    sentence: sentence,
                                    part: part,
                                    optionKey: key,
                                  ),
                                ),
                              )
                              .toList(growable: false),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _selectEssayOption({
    required EssayBuilderSentence sentence,
    required EssayBuilderPart part,
    required String optionKey,
  }) {
    final normalizedOption = optionKey.trim().toUpperCase();
    final expectedOption = part.correctOption.trim().toUpperCase();
    final safeExpectedOption = ['A', 'B', 'C', 'D'].contains(expectedOption)
        ? expectedOption
        : 'A';

    if (normalizedOption != safeExpectedOption) {
      setState(() {
        // WHY: EssayBuilder progression must remain teach-first and intentional.
        // Wrong picks trigger a sentence retry before unlocking the next step.
        _clearEssaySentenceSelections(sentence);
        _errorMessage =
            'Not quite. Re-read LEARN FIRST and retry this sentence.';
      });
      return;
    }

    setState(() {
      _essaySelections[part.blankId] = normalizedOption;
      _errorMessage = null;
    });

    _tryCompleteEssaySentence(sentence);
  }

  void _clearEssaySentenceSelections(EssayBuilderSentence sentence) {
    for (final part in sentence.parts) {
      if (!part.isBlank || part.blankId.trim().isEmpty) {
        continue;
      }
      _essaySelections.remove(part.blankId);
    }
  }

  void _tryCompleteEssaySentence(EssayBuilderSentence sentence) {
    final blankIds = sentence.parts
        .where((part) => part.isBlank)
        .map((part) => part.blankId)
        .where((value) => value.isNotEmpty)
        .toList();
    if (blankIds.isEmpty) {
      return;
    }

    final isComplete = blankIds.every((id) => _essaySelections.containsKey(id));
    if (!isComplete) {
      return;
    }

    final sentenceText = _buildEssaySentenceText(sentence);
    if (sentenceText.trim().isEmpty) {
      return;
    }

    setState(() {
      _essaySentences.add(sentenceText.trim());
      _errorMessage = null;
    });
  }

  String _buildEssaySentenceText(EssayBuilderSentence sentence) {
    final buffer = StringBuffer();
    for (final part in sentence.parts) {
      if (part.isBlank) {
        final selectedKey = _essaySelections[part.blankId];
        buffer.write(part.options[selectedKey] ?? '');
      } else {
        buffer.write(part.value);
      }
    }
    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _buildEssaySentencePreview(EssayBuilderSentence sentence) {
    final buffer = StringBuffer();
    for (final part in sentence.parts) {
      if (part.isBlank) {
        final selectedKey = _essaySelections[part.blankId];
        final selected = selectedKey == null
            ? '____'
            : (part.options[selectedKey] ?? '____');
        buffer.write(selected);
      } else {
        buffer.write(part.value);
      }
    }
    return buffer.toString();
  }

  List<InlineSpan> _buildEssaySentencePreviewSpans(
    EssayBuilderSentence sentence,
  ) {
    final spans = <InlineSpan>[];
    for (final part in sentence.parts) {
      if (part.isBlank) {
        final selectedKey = _essaySelections[part.blankId];
        final selectedText = selectedKey == null
            ? ''
            : (part.options[selectedKey] ?? '');
        spans.add(
          _buildEssayBlankSpan(
            text: selectedText,
            isFilled: selectedKey != null && selectedText.isNotEmpty,
          ),
        );
      } else {
        spans.add(TextSpan(text: part.value));
      }
    }
    return spans;
  }

  InlineSpan _buildEssayBlankSpan({
    required String text,
    required bool isFilled,
  }) {
    return WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: Container(
        constraints: const BoxConstraints(minWidth: 72),
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isFilled ? AppPalette.navy : AppPalette.textMuted,
              width: 2,
            ),
          ),
        ),
        child: Text(
          text.isEmpty ? ' ' : text,
          style: TextStyle(
            color: isFilled ? AppPalette.navy : AppPalette.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  String _buttonLabel(bool answerLocked) {
    final question = _mission.questions[_currentIndex];
    final selectedIndex = _selectedOptions[_currentIndex];

    if (_isLearnStage(question)) {
      return 'Continue to Question';
    }

    if (!answerLocked &&
        selectedIndex != null &&
        selectedIndex != question.correctIndex) {
      return 'Retry';
    }

    if (!answerLocked) {
      return 'Choose an Answer';
    }

    if (_currentIndex == _mission.questions.length - 1) {
      return _isSubmitting ? 'Saving Mission...' : 'Finish Mission';
    }

    return 'Next Question';
  }

  List<Color> _buttonColors(bool answerLocked) {
    final question = _mission.questions[_currentIndex];
    final selectedIndex = _selectedOptions[_currentIndex];

    if (_isLearnStage(question)) {
      return AppPalette.progressGradient;
    }

    if (!answerLocked &&
        selectedIndex != null &&
        selectedIndex != question.correctIndex) {
      return const [Color(0xFFFFD39A), Color(0xFFFFB87A)];
    }

    if (!answerLocked) {
      return const [Color(0xFFD7DDEA), Color(0xFFC7D2E7)];
    }

    return _currentIndex == _mission.questions.length - 1
        ? const [AppPalette.primaryBlue, AppPalette.sun]
        : AppPalette.progressGradient;
  }

  VoidCallback _buttonAction(bool answerLocked) {
    final question = _mission.questions[_currentIndex];
    final selectedIndex = _selectedOptions[_currentIndex];

    if (_isLearnStage(question)) {
      return () {
        setState(() {
          // WHY: Learn First must be completed before the question appears, so
          // the stage flips only when the student explicitly continues.
          _showQuestionStage = true;
          _errorMessage = null;
        });
      };
    }

    if (!answerLocked) {
      if (selectedIndex != null && selectedIndex != question.correctIndex) {
        return () {
          setState(() {
            // WHY: Try Again should restart from the first question so the
            // learner intentionally replays the mission sequence.
            _selectedOptions.clear();
            _answers.clear();
            _moveToQuestion(0);
            _showXpPulse = false;
            _xpPulsePositive = false;
            _xpPulseValue = 0;
            _errorMessage = null;
          });
        };
      }
      return () {};
    }

    if (_currentIndex == _mission.questions.length - 1) {
      return _isSubmitting ? () {} : _completeMission;
    }

    return () {
      setState(() {
        _moveToQuestion(_currentIndex + 1);
        _errorMessage = null;
      });
    };
  }

  bool _hasLearningStage(MissionQuestion? question) {
    if (question == null) {
      return false;
    }

    return question.learningText.trim().isNotEmpty;
  }

  bool _shouldStartOnQuestion(MissionQuestion? question) {
    return !_hasLearningStage(question);
  }

  bool _isLearnStage(MissionQuestion question) {
    return _hasLearningStage(question) && !_showQuestionStage;
  }

  void _moveToQuestion(int index) {
    _currentIndex = index;
    // WHY: Every new item should reopen on Learn First when teaching content
    // exists, otherwise the question would appear before the student reads it.
    _showQuestionStage = _shouldStartOnQuestion(_mission.questions[index]);
  }

  double _progressFor(MissionQuestion currentQuestion) {
    final totalStages = _mission.questions.fold<int>(
      0,
      (sum, question) => sum + (_hasLearningStage(question) ? 2 : 1),
    );
    final completedStagesBeforeCurrent = _mission.questions
        .take(_currentIndex)
        .fold<int>(
          0,
          (sum, question) => sum + (_hasLearningStage(question) ? 2 : 1),
        );
    final currentStage = _isLearnStage(currentQuestion)
        ? 1
        : (_hasLearningStage(currentQuestion) ? 2 : 1);

    return (completedStagesBeforeCurrent + currentStage) / totalStages;
  }

  int _correctAnswers() {
    var total = 0;

    for (var index = 0; index < _mission.questions.length; index += 1) {
      if (_answers[index] == _mission.questions[index].correctIndex) {
        total += 1;
      }
    }

    return total;
  }

  int _focusScore() {
    if (_mission.questions.isEmpty) {
      return 0;
    }

    return ((_correctAnswers() / _mission.questions.length) * 100).round();
  }

  int _essayFocusScore() {
    final total = _essayTotalCount;
    if (total == 0) {
      return 0;
    }
    return ((_essaySentences.length / total) * 100).round();
  }

  String _behaviourStatus() {
    final focusScore = _isEssayBuilderMission
        ? _essayFocusScore()
        : _focusScore();

    if (focusScore >= 80) {
      return 'great';
    }

    if (focusScore >= 55) {
      return 'steady';
    }

    return 'warning';
  }

  String _buildCoachMessage({
    required MissionQuestion question,
    required bool answerLocked,
    required int? selectedIndex,
  }) {
    final remaining = math.max(
      0,
      _mission.questions.length - (_currentIndex + 1),
    );
    final plural = remaining == 1 ? '' : 's';

    if (_isLearnStage(question)) {
      const learnMessages = [
        'AI Coach: Read this part first. You are building power for the next question.',
        'AI Coach: Quick read first, then you unlock the question.',
        'AI Coach: Learn mode active. Take it step by step.',
      ];
      return learnMessages[(_currentIndex + _coachVersion) %
          learnMessages.length];
    }

    if (!answerLocked) {
      if (selectedIndex != null && selectedIndex != question.correctIndex) {
        const retryMessages = [
          'Try again. You can do this.',
          'Not yet. Read and choose again.',
          'Almost there. Pick the best match.',
        ];
        return retryMessages[(_currentIndex + _coachVersion) %
            retryMessages.length];
      }
      if (remaining > 0) {
        return '$remaining more question$plural to go, you are almost there.';
      }
      return 'Final question. Finish strong and lock your score.';
    }

    if (selectedIndex == question.correctIndex) {
      const correctMessages = [
        'Great answer. XP is stacking up.',
        'Correct. Keep this rhythm going.',
        'Sharp work. You are in control.',
      ];
      return correctMessages[(_answers.length + _coachVersion) %
          correctMessages.length];
    }

    return 'Nice work. You unlocked the next step.';
  }

  int _previewXpForAnswer(bool isCorrect) {
    if (!isCorrect || _mission.questions.isEmpty) {
      return 0;
    }

    final xpPool = _mission.questions.length >= 10 ? 50 : 30;
    return math.max(1, (xpPool / _mission.questions.length).ceil());
  }

  void _triggerConfettiBurst({required bool success}) {
    const successPalette = <Color>[
      Color(0xFF00C2FF),
      Color(0xFF6A5BFF),
      Color(0xFF2CD67F),
      Color(0xFFFFC94D),
      Color(0xFFFF6B8A),
      Color(0xFF00E2C7),
    ];
    const supportPalette = <Color>[
      Color(0xFF9EC5FF),
      Color(0xFFB6C8FF),
      Color(0xFFD5E7FF),
      Color(0xFFFFDAB0),
    ];

    final palette = success ? successPalette : supportPalette;
    final particleCount = success ? 60 : 30;

    final particles = List<_ConfettiParticle>.generate(particleCount, (index) {
      final randomValue = _random.nextDouble();
      final startX = randomValue;
      final startY = -0.06 - (_random.nextDouble() * 0.18);
      final fallDistance = 0.6 + (_random.nextDouble() * 0.35);
      final horizontalDrift = (_random.nextDouble() - 0.5) * 0.2;
      final spin = (_random.nextDouble() * math.pi * 2);
      final size = success
          ? 4 + (_random.nextDouble() * 7)
          : 3 + (_random.nextDouble() * 5);

      return _ConfettiParticle(
        color: palette[index % palette.length],
        startX: startX,
        startY: startY,
        fallDistance: fallDistance,
        horizontalDrift: horizontalDrift,
        spin: spin,
        size: size,
        ribbon: index.isEven,
      );
    });

    final fireworkPalette = success ? successPalette : supportPalette;
    final sparks = List<_FireworkSpark>.generate(success ? 14 : 8, (index) {
      final step = (math.pi * 2) / (success ? 14 : 8);
      return _FireworkSpark(
        color: fireworkPalette[index % fireworkPalette.length],
        angle: (step * index) + (_random.nextDouble() * 0.15),
        length: 0.18 + (_random.nextDouble() * 0.24),
        thickness: 2 + (_random.nextDouble() * 1.8),
        delay: _random.nextDouble() * 0.25,
      );
    });

    // WHY: Firework-like sparks keep the burst feeling alive and paced slower.
    setState(() {
      _confettiParticles = particles;
      _fireworkSparks = sparks;
    });

    if (success) {
      // WHY: Tie the sound to accurate bursts so the hurray sound feels earned.
      unawaited(_playHurraySound());
    }

    _confettiController
      ..stop()
      ..reset()
      ..forward();
  }

  Future<void> _preloadCelebrationSound() async {
    final player = _celebrationPlayer;
    if (player == null) {
      return;
    }

    try {
      await player.setSourceAsset('sounds/hurray.wav');
      await player.setVolume(0.88);
    } catch (_) {
      // WHY: Failing silently keeps the UI intact if asset fails to load.
    }
  }

  Future<void> _playHurraySound() async {
    // WHY: A warm burst sound reinforces the slower firework animation.
    if (kIsWeb) {
      await celebration_sound.playHurraySound();
      return;
    }

    final player = _celebrationPlayer;
    if (player == null) {
      return;
    }

    try {
      await player.setVolume(0.88);
      if (player.state == PlayerState.playing) {
        await player.stop();
      }
      await player.play(AssetSource('sounds/hurray.wav'));
    } catch (_) {
      // WHY: Swallow playback failures to keep the UI uninterrupted.
    }
  }

  Future<void> _promptStartDailyMission() async {
    final shouldStart = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Start Daily Mission'),
          content: const Text(
            'Do you want to leave this screen and open your daily mission cards?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Stay Here'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Start Daily Mission'),
            ),
          ],
        );
      },
    );

    if (shouldStart != true || !mounted) {
      return;
    }

    await _startDailyMissionFromToday();
  }

  Future<void> _startDailyMissionFromToday() async {
    try {
      final dashboard = await _api.fetchStudentDashboard(
        token: widget.session.token,
        studentId: widget.startedMission.studentId,
      );
      final today = dashboard.today;
      if (today == null) {
        throw const FocusMissionApiException(
          'No daily mission is scheduled for today.',
        );
      }

      final requestedSessionType = widget.startedMission.sessionType
          .toLowerCase();
      final resolvedSessionType = requestedSessionType == 'afternoon'
          ? 'afternoon'
          : 'morning';
      final subjectId = resolvedSessionType == 'morning'
          ? today.morningMission.id
          : today.afternoonMission.id;

      final startedMission = await _api.startSession(
        token: widget.session.token,
        studentId: widget.startedMission.studentId,
        subjectId: subjectId,
        sessionType: resolvedSessionType,
      );

      if (!mounted) {
        return;
      }

      // WHY: Replace the current route so the student lands directly in the
      // daily mission flow without being bounced through dashboard first.
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => MissionPlayScreen(
            session: widget.session,
            startedMission: startedMission,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _completeMission() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final isEssayBuilder = _isEssayBuilderMission;
      final essayDraft = _essayDraft;
      if (isEssayBuilder && essayDraft != null) {
        if (_essaySentences.length < _essayTotalCount) {
          setState(() {
            _isSubmitting = false;
            // WHY: Essay builder missions only submit once all guided sentences
            // are completed so the student finishes the full draft.
            _errorMessage =
                'Finish all sentences before submitting your essay mission.';
          });
          return;
        }

        if (_essayCompletedBlankCount < _essayTargetBlankCount) {
          setState(() {
            _isSubmitting = false;
            // WHY: Every required blank must be completed before submission so
            // teacher evidence reflects the full guided attempt.
            _errorMessage =
                'Finish all required blanks before submitting your essay mission.';
          });
          return;
        }

        if (_essayWordCount < essayDraft.targets.targetWordMin) {
          setState(() {
            _isSubmitting = false;
            // WHY: Submit should unlock only once the minimum word target is met.
            _errorMessage =
                'Your essay needs at least ${essayDraft.targets.targetWordMin} words before submission.';
          });
          return;
        }

        if (_essayWordCount > essayDraft.targets.targetWordMax) {
          setState(() {
            _isSubmitting = false;
            // WHY: Word-cap gating keeps submissions inside the authored draft range.
            _errorMessage =
                'Your essay is above ${essayDraft.targets.targetWordMax} words. Reduce it before submitting.';
          });
          return;
        }

        if (_essaySubmissionWordCount < _essaySubmissionMinWords) {
          setState(() {
            _isSubmitting = false;
            // WHY: Final submission requires a student-authored response after
            // completing guided sentence selections.
            _errorMessage =
                'Write at least $_essaySubmissionMinWords words in the final essay response before submitting.';
          });
          return;
        }
      }

      final completedCount = isEssayBuilder
          ? _essayTotalCount
          : _mission.questions.length;
      final correctCount = isEssayBuilder
          ? _essaySentences.length
          : _correctAnswers();
      final requiredCorrect = _minimumCorrectForSubmit(completedCount);
      if (requiredCorrect > 0 && correctCount < requiredCorrect) {
        setState(() {
          _isSubmitting = false;
          // WHY: Configured mission sizes enforce explicit minimum-correct
          // thresholds; below-threshold attempts must retry.
          _errorMessage =
              'You need at least $requiredCorrect out of $completedCount correct before submitting. Please retry.';
        });
        return;
      }

      // WHY: XP and focus are awarded only after the full mission is completed,
      // which keeps progress tied to finished work instead of partial attempts.
      debugPrint(
        'Publishing ${isEssayBuilder ? 'essay builder' : 'multiple choice'} mission: ${_mission.id}',
      );
      final submitTime = DateTime.now().toUtc().toIso8601String();
      final updatedStudent = await _api.completeStudentMission(
        token: widget.session.token,
        studentId: widget.startedMission.studentId,
        subjectId: widget.startedMission.subjectId,
        sessionType: widget.startedMission.sessionType,
        missionId: _mission.id,
        focusScore: isEssayBuilder ? _essayFocusScore() : _focusScore(),
        correctAnswers: correctCount,
        completedQuestions: completedCount,
        behaviourStatus: _behaviourStatus(),
        notes: isEssayBuilder
            ? _essayParagraph
            : '${_mission.title}: ${_correctAnswers()} of ${_mission.questions.length} correct.',
        startTime: widget.startedMission.startedAt.trim().isEmpty
            ? null
            : widget.startedMission.startedAt,
        submitTime: submitTime,
        resultEvidence: _buildResultEvidence(),
      );

      if (!mounted) {
        return;
      }

      debugPrint(
        'Publish complete for ${isEssayBuilder ? 'essay builder' : 'multiple choice'} mission: ${_mission.id}',
      );
      setState(() => _completedResult = updatedStudent);
      if (updatedStudent.subjectCompletionBonusXp > 0) {
        await _showSubjectCompletionDialog(
          updatedStudent.subjectCompletionBonusXp,
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _showSubjectCompletionDialog(int bonusXp) async {
    final subjectName = _mission.subject?.name ?? 'this subject';
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(AppSpacing.screen),
          backgroundColor: Colors.transparent,
          child: SoftPanel(
            colors: const [Color(0xFFF8FFFB), Color(0xFFE8F9FF)],
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Subject Complete',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.item),
                Text(
                  'You completed all assessments for $subjectName.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 8),
                _SummaryChip(
                  label: 'Bonus XP',
                  value: '+$bonusXp',
                  colors: const [AppPalette.mint, AppPalette.aqua],
                ),
                const SizedBox(height: AppSpacing.section),
                GradientButton(
                  label: 'Awesome',
                  colors: AppPalette.progressGradient,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Map<String, dynamic> _buildResultEvidence() {
    if (_isEssayBuilderMission) {
      return {'essayBuilder': _buildEssayBuilderEvidence()};
    }

    return {'questionResponses': _buildQuestionResponsesEvidence()};
  }

  List<Map<String, dynamic>> _buildQuestionResponsesEvidence() {
    final responses = <Map<String, dynamic>>[];
    for (var index = 0; index < _mission.questions.length; index += 1) {
      final selectedIndex = _answers[index] ?? _selectedOptions[index];
      if (selectedIndex == null || selectedIndex < 0) {
        continue;
      }
      responses.add({'questionIndex': index, 'selectedIndex': selectedIndex});
    }
    return responses;
  }

  Map<String, dynamic> _buildEssayBuilderEvidence() {
    final draft = _essayDraft;
    if (draft == null) {
      return const {};
    }

    final sentences = draft.sentences
        .take(_essayTotalCount > 0 ? _essayTotalCount : draft.sentences.length)
        .toList(growable: false);
    final sentenceResponses = sentences
        .map((sentence) {
          final blankSelections = sentence.parts
              .where((part) => part.isBlank && part.blankId.trim().isNotEmpty)
              .map((part) {
                final selectedOption = _essaySelections[part.blankId] ?? '';
                return {
                  'blankId': part.blankId,
                  'selectedOption': selectedOption,
                };
              })
              .where(
                (blank) =>
                    (blank['selectedOption'] as String).trim().isNotEmpty,
              )
              .toList(growable: false);

          return {
            'sentenceId': sentence.id,
            'blankSelections': blankSelections,
          };
        })
        .toList(growable: false);

    return {
      'sentenceResponses': sentenceResponses,
      'guidedEssayText': _essayParagraph,
      'submissionEssayText': _essaySubmissionText,
      'finalEssayText': _essaySubmissionText.isNotEmpty
          ? _essaySubmissionText
          : _essayParagraph,
      'finalWordCount': _essaySubmissionText.isNotEmpty
          ? _essaySubmissionWordCount
          : _essayWordCount,
      'blankCompletedCount': _essayCompletedBlankCount,
      'blankTargetCount': _essayTargetBlankCount,
    };
  }
}

class _AnswerOptionCard extends StatelessWidget {
  const _AnswerOptionCard({
    required this.label,
    required this.isSelected,
    required this.isCorrect,
    required this.answerLocked,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final bool isCorrect;
  final bool answerLocked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = _resolveColors();
    final borderColor = answerLocked
        ? (isCorrect
              ? AppPalette.mint
              : isSelected
              ? const Color(0xFFFF9AA9)
              : Colors.white.withValues(alpha: 0.72))
        : (isSelected
              ? AppPalette.primaryBlue
              : Colors.white.withValues(alpha: 0.82));

    return AnimatedScale(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutBack,
      scale: isSelected ? 1.01 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.all(AppSpacing.item),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              border: Border.all(
                color: borderColor,
                width: isSelected || isCorrect ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.76),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    answerLocked
                        ? (isCorrect
                              ? Icons.check_rounded
                              : isSelected
                              ? Icons.close_rounded
                              : Icons.radio_button_unchecked_rounded)
                        : Icons.touch_app_rounded,
                    color: answerLocked
                        ? (isCorrect
                              ? const Color(0xFF2A9D6F)
                              : isSelected
                              ? AppPalette.primaryBlue
                              : AppPalette.textMuted)
                        : (isSelected
                              ? AppPalette.primaryBlue
                              : AppPalette.textMuted),
                  ),
                ),
                const SizedBox(width: AppSpacing.item),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(color: AppPalette.navy),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Color> _resolveColors() {
    if (!answerLocked) {
      return [
        Colors.white.withValues(alpha: 0.92),
        Colors.white.withValues(alpha: 0.72),
      ];
    }

    if (isCorrect) {
      return const [Color(0xFFE7FFF0), Color(0xFFD4F7E5)];
    }

    if (isSelected) {
      return const [Color(0xFFFFF1F1), Color(0xFFFFE3E3)];
    }

    return [
      Colors.white.withValues(alpha: 0.92),
      Colors.white.withValues(alpha: 0.72),
    ];
  }
}

class _CoachBanner extends StatelessWidget {
  const _CoachBanner({
    super.key,
    required this.message,
    required this.positive,
  });

  final String message;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    return SoftPanel(
      colors: positive
          ? const [Color(0xFFEFFFF5), Color(0xFFDDFBE9)]
          : const [Color(0xFFF5FAFF), Color(0xFFE6F3FF)],
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: AppPalette.teacherGradient,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white),
          ),
          const SizedBox(width: AppSpacing.item),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppPalette.navy),
            ),
          ),
        ],
      ),
    );
  }
}

class _XpPulsePill extends StatelessWidget {
  const _XpPulsePill({required this.label, required this.positive});

  final String label;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: positive
              ? const [Color(0xFFE8FFF2), Color(0xFFD9F8E8)]
              : const [Color(0xFFFFF8EE), Color(0xFFFFEEDC)],
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: positive ? AppPalette.mint : const Color(0xFFEFC59A),
        ),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(color: AppPalette.navy),
      ),
    );
  }
}

class _LearningPanel extends StatelessWidget {
  const _LearningPanel({required this.text, required this.questionIndex});

  final String text;
  final int questionIndex;

  @override
  Widget build(BuildContext context) {
    return SoftPanel(
      colors: const [Color(0xFFF4FBFF), Color(0xFFE6F6FF)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: AppPalette.teacherGradient,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.menu_book_rounded, color: Colors.white),
              ),
              const SizedBox(width: AppSpacing.item),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Learn First',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Read this first. When you are ready, continue to Question $questionIndex.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppPalette.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.item),
          Text(
            text,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppPalette.navy,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedbackPanel extends StatelessWidget {
  const _FeedbackPanel({
    required this.isCorrect,
    required this.explanation,
    required this.answerText,
  });

  final bool isCorrect;
  final String explanation;
  final String answerText;

  @override
  Widget build(BuildContext context) {
    return SoftPanel(
      colors: isCorrect
          ? const [Color(0xFFEFFFF4), Color(0xFFDFF9EC)]
          : const [Color(0xFFFFF7EE), Color(0xFFFFEAD3)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isCorrect ? 'Nice work' : 'Try again',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            isCorrect
                ? answerText
                : 'Try again and pick the best answer to continue.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          if (explanation.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              explanation,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppPalette.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

class _ConfettiParticle {
  const _ConfettiParticle({
    required this.color,
    required this.startX,
    required this.startY,
    required this.fallDistance,
    required this.horizontalDrift,
    required this.spin,
    required this.size,
    required this.ribbon,
  });

  final Color color;
  final double startX;
  final double startY;
  final double fallDistance;
  final double horizontalDrift;
  final double spin;
  final double size;
  final bool ribbon;
}

class _FireworkSpark {
  const _FireworkSpark({
    required this.color,
    required this.angle,
    required this.length,
    required this.thickness,
    required this.delay,
  });

  final Color color;
  final double angle;
  final double length;
  final double thickness;
  final double delay;
}

class _ConfettiBurstPainter extends CustomPainter {
  const _ConfettiBurstPainter({
    required this.particles,
    required this.sparks,
    required this.progress,
  });

  final List<_ConfettiParticle> particles;
  final List<_FireworkSpark> sparks;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final alpha = (1 - progress).clamp(0.0, 1.0);
    final wave = progress * math.pi * 2;

    for (final particle in particles) {
      final x =
          (particle.startX +
                  (math.sin(wave + particle.spin) * particle.horizontalDrift))
              .clamp(0.02, 0.98);
      final y = particle.startY + (particle.fallDistance * progress);

      final dx = x * size.width;
      final dy = y * size.height;
      final rotation = particle.spin + (progress * 8);

      canvas.save();
      canvas.translate(dx, dy);
      canvas.rotate(rotation);
      paint.color = particle.color.withValues(alpha: alpha);

      if (particle.ribbon) {
        final ribbon = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: particle.size * 0.7,
            height: particle.size * 2.1,
          ),
          Radius.circular(particle.size * 0.4),
        );
        canvas.drawRRect(ribbon, paint);
      } else {
        canvas.drawCircle(Offset.zero, particle.size * 0.5, paint);
      }

      canvas.restore();
    }

    paint.style = PaintingStyle.stroke;
    final sparkCenter = Offset(size.width * 0.5, size.height * 0.15);
    for (final spark in sparks) {
      final sparkProgress = (progress - spark.delay).clamp(0.0, 1.0);
      if (sparkProgress <= 0) {
        continue;
      }

      final sparkLength = spark.length * size.height * 0.35;
      paint
        ..color = spark.color.withValues(
          alpha: (1 - sparkProgress).clamp(0.0, 1.0),
        )
        ..strokeWidth = spark.thickness
        ..strokeCap = StrokeCap.round;

      final sparkEnd =
          sparkCenter +
          Offset(math.cos(spark.angle), math.sin(spark.angle)) *
              (sparkLength * sparkProgress);
      canvas.drawLine(sparkCenter, sparkEnd, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiBurstPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.particles != particles ||
        oldDelegate.sparks != sparks;
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.76),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Icon(icon, color: AppPalette.navy),
      ),
    );
  }
}

class _TagPill extends StatelessWidget {
  const _TagPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(color: AppPalette.navy),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
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

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.label,
    required this.value,
    required this.colors,
  });

  final String label;
  final String value;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: SoftPanel(
        colors: [
          colors.first.withValues(alpha: 0.22),
          colors.last.withValues(alpha: 0.14),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _EssaySentenceCard extends StatelessWidget {
  const _EssaySentenceCard({
    required this.title,
    required this.body,
    required this.isLocked,
  });

  final String title;
  final String body;
  final bool isLocked;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.item),
      child: SoftPanel(
        colors: isLocked
            ? const [Color(0xFFF2F4F8), Color(0xFFE9EDF5)]
            : const [Color(0xFFF7FCFF), Color(0xFFE9F4FF)],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            Text(
              body,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isLocked ? AppPalette.textMuted : AppPalette.navy,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EssayOptionChip extends StatelessWidget {
  const _EssayOptionChip({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = selected
        ? const [AppPalette.primaryBlue, AppPalette.aqua]
        : const [Color(0xFFE7ECF5), Color(0xFFD8E2F0)];
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: colors),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: selected ? Colors.white : AppPalette.navy,
            ),
          ),
        ),
      ),
    );
  }
}
