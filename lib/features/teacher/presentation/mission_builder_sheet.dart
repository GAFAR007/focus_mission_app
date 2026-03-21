/**
 * WHAT:
 * mission_builder_sheet lets the teacher generate, review, edit, and publish
 * AI-assisted mission drafts for a scheduled lesson slot.
 * WHY:
 * AI is draft-only in Focus Mission, so the teacher needs one review surface
 * where generated content can be checked and adjusted before it goes live.
 * HOW:
 * Collect the lesson text, call the draft or preview APIs, let the teacher edit
 * the mission content, then save or publish through teacher endpoints.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_palette.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/download_text_file.dart';
import '../../../core/utils/focus_mission_api.dart';
import '../../../shared/models/focus_mission_models.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../shared/widgets/soft_panel.dart';
import 'assessment_mode_screen.dart';

Future<MissionPayload?> showMissionBuilderSheet(
  BuildContext context, {
  required AuthSession session,
  required StudentSummary student,
  required SubjectSummary subject,
  required String sessionType,
  required DateTime targetDate,
  List<TodaySchedule> timetableEntries = const [],
  List<String> lockedAssessmentTaskCodes = const [],
  bool openAssessmentOnStart = false,
  FocusMissionApi? api,
  MissionPayload? initialDraft,
}) {
  return showModalBottomSheet<MissionPayload>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _MissionBuilderSheet(
      session: session,
      student: student,
      subject: subject,
      sessionType: sessionType,
      targetDate: targetDate,
      timetableEntries: timetableEntries,
      lockedAssessmentTaskCodes: lockedAssessmentTaskCodes,
      openAssessmentOnStart: openAssessmentOnStart,
      api: api ?? FocusMissionApi(),
      initialDraft: initialDraft,
    ),
  );
}

enum _DraftExportAudience { teacher, student }

enum _SourceUploadMode { aiDraft, populateDraft }

class _MissionBuilderSheet extends StatefulWidget {
  const _MissionBuilderSheet({
    required this.session,
    required this.student,
    required this.subject,
    required this.sessionType,
    required this.targetDate,
    required this.timetableEntries,
    required this.lockedAssessmentTaskCodes,
    required this.openAssessmentOnStart,
    required this.api,
    this.initialDraft,
  });

  final AuthSession session;
  final StudentSummary student;
  final SubjectSummary subject;
  final String sessionType;
  final DateTime targetDate;
  final List<TodaySchedule> timetableEntries;
  final List<String> lockedAssessmentTaskCodes;
  final bool openAssessmentOnStart;
  final FocusMissionApi api;
  final MissionPayload? initialDraft;

  @override
  State<_MissionBuilderSheet> createState() => _MissionBuilderSheetState();
}

class _MissionBuilderSheetState extends State<_MissionBuilderSheet> {
  static const int _objectiveXpReward = 30;
  static const int _assessmentQuestionCount = 10;
  static const int _assessmentXpReward = 50;
  static const int _theoryXpReward = _assessmentXpReward;
  static const int _essayXpReward = 20;
  static const int _theoryQuestionCountMin = 2;
  static const int _theoryQuestionCountMax = 5;
  static const List<String> _taskCodeOptions = [
    'P1',
    'P2',
    'P3',
    'P4',
    'P5',
    'P6',
    'M1',
    'M2',
    'D1',
    'D2',
  ];
  static const int _scheduleSearchWindowDays = 120;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  final TextEditingController _unitTextController = TextEditingController();
  final TextEditingController _teacherNoteController = TextEditingController();

  String _difficulty = 'medium';
  int _questionCount = 5;
  late String _selectedSessionType;
  late DateTime _selectedTargetDate;
  String _draftFormat = 'QUESTIONS';
  String _essayMode = 'NORMAL';
  bool _showFullRawUploadText = false;
  bool _isGenerating = false;
  bool _isExtractingSource = false;
  _SourceUploadMode? _activeSourceUploadMode;
  bool _isReextractingSource = false;
  bool _isSaving = false;
  bool _createdDraftThisSession = false;
  String? _errorMessage;
  List<String> _selectedTaskCodes = const [];
  String _rawUploadedSourceText = '';
  String _selectedSourceFileName = '';
  String _selectedSourceFileType = '';
  MissionPayload? _draftMission;
  UploadedSourceDraft? _uploadedSource;
  MissionSourceReadiness? _sourceUploadReadiness;
  List<_EditableQuestionController> _questionEditors = const [];
  bool _didAutoOpenAssessmentMode = false;
  List<SubjectCertificationSummary> _studentCertification = const [];

  bool get _hasDraft => _draftMission != null;
  bool get _isPublishedMission => _draftMission?.isPublished ?? false;
  bool get _isTargetDateInPast =>
      _resolvedTargetDate.isBefore(_dateOnly(DateTime.now()));
  bool get _isAssessmentMode => _questionCount == _assessmentQuestionCount;
  bool get _isAssessmentPublishLocked =>
      _isAssessmentMode && _selectedTaskCodes.isEmpty;
  bool get _isTheoryDraft => _draftFormat == 'THEORY';
  bool get _isCertificationQualifyingFormat =>
      _draftFormat == 'ESSAY_BUILDER' ||
      _draftFormat == 'THEORY' ||
      (_draftFormat == 'QUESTIONS' && _questionCount >= 10);
  bool get _usesScoreBasedXpReward =>
      _draftFormat == 'QUESTIONS' && _questionCount >= _assessmentQuestionCount;
  String get _effectiveDifficulty => _isAssessmentMode ? 'hard' : _difficulty;
  int get _effectiveXpReward => _resolvedXpRewardFor(
    draftFormat: _draftFormat,
    questionCount: _questionCount,
  );
  String get _xpRewardPolicySummary {
    if (_draftFormat == 'THEORY') {
      return 'Theory missions hold a fixed 50 XP reward until the teacher marks the answers.';
    }

    if (_draftFormat == 'ESSAY_BUILDER') {
      return 'Essay builder missions award a fixed 20 XP when the guided work and final response are completed.';
    }

    if (_usesScoreBasedXpReward) {
      return '10-question assessment missions award up to 50 XP based on the student score.';
    }

    return '5 and 8 question objective missions award a fixed 30 XP when the student passes.';
  }

  SubjectCertificationSummary? get _selectedSubjectCertification {
    for (final certification in _studentCertification) {
      if (certification.subjectId == widget.subject.id) {
        return certification;
      }
    }
    return null;
  }

  bool get _isUploadingForAiDraft =>
      _isExtractingSource &&
      _activeSourceUploadMode == _SourceUploadMode.aiDraft;

  bool get _isPopulatingDraftFromSource =>
      _isExtractingSource &&
      _activeSourceUploadMode == _SourceUploadMode.populateDraft;

  @override
  void initState() {
    super.initState();
    _selectedSessionType = widget.sessionType;
    _selectedTargetDate = _dateOnly(widget.targetDate);
    final slotLabel = _selectedSessionType == 'morning'
        ? 'Morning'
        : 'Afternoon';
    _titleController = TextEditingController(
      text: '${widget.subject.name} $slotLabel Mission',
    );

    if (widget.initialDraft != null) {
      _applyDraft(widget.initialDraft!);
    }

    if (widget.openAssessmentOnStart && widget.initialDraft == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _didAutoOpenAssessmentMode) {
          return;
        }
        _didAutoOpenAssessmentMode = true;
        _openAssessmentModeScreen();
      });
    }

    _loadStudentCertification();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _unitTextController.dispose();
    _teacherNoteController.dispose();
    for (final editor in _questionEditors) {
      editor.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAssessmentPublishLockedForActions =
        !_isPublishedMission && _isAssessmentPublishLocked;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.94,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: AppPalette.backgroundGradient,
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.screen),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 60,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.section),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        !_hasDraft
                            ? 'Build Mission Draft'
                            : _isPublishedMission
                            ? 'Edit Mission'
                            : 'Review Draft',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    _TopButton(icon: Icons.close_rounded, onTap: _closeSheet),
                  ],
                ),
                const SizedBox(height: AppSpacing.item),
                Text(
                  !_hasDraft
                      ? _isTheoryDraft
                            ? 'Upload a doc or scan and Groq will draft a fast-focus theory check for ${widget.student.name}. You set 2 to 5 questions, then review the draft before it goes live.'
                            : 'Paste the unit text and Groq will draft calm, SEN-friendly questions for ${widget.student.name}. You review the draft before the mission goes live.'
                      : _isPublishedMission
                      ? 'This mission is already live. Update the wording, answers, or teacher note here, then save the changes.'
                      : 'The student cannot begin this mission until you publish it. Review the draft, tune the questions, and then publish when it is ready.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppPalette.textMuted),
                ),
                const SizedBox(height: AppSpacing.section),
                SoftPanel(
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _InfoPill(label: widget.student.name),
                      _InfoPill(label: widget.subject.name),
                      _InfoPill(label: _selectedSessionType.toUpperCase()),
                      _InfoPill(label: _formatTargetDate(_resolvedTargetDate)),
                      if (_selectedTaskCodes.isNotEmpty)
                        _InfoPill(
                          label: 'Tasks: ${_selectedTaskCodes.join(', ')}',
                        ),
                      if (_hasDraft)
                        _InfoPill(
                          label: _draftMission!.isDraft
                              ? 'Draft only'
                              : 'Live mission',
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _isSaving || _isGenerating
                        ? null
                        : _openMissionDatePicker,
                    icon: const Icon(Icons.calendar_month_rounded, size: 18),
                    label: const Text('Change mission date'),
                  ),
                ),
                const SizedBox(height: AppSpacing.item),
                if (_errorMessage != null) ...[
                  SoftPanel(
                    colors: const [Color(0xFFFFF4F4), Color(0xFFFFE6E6)],
                    child: Text(
                      _errorMessage!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.item),
                ],
                if (_isTargetDateInPast) ...[
                  SoftPanel(
                    colors: const [Color(0xFFFFF4F4), Color(0xFFFFE6E6)],
                    child: Text(
                      'Teachers can only prepare missions for today or an upcoming class date. Pick a future lesson date before generating or publishing.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.item),
                ],
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(
                      bottom: AppSpacing.section + bottomPadding,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildMissionSetup(context),
                          if (_hasDraft) ...[
                            const SizedBox(height: AppSpacing.section),
                            _buildDraftPreview(context),
                          ],
                          const SizedBox(height: AppSpacing.section),
                          _buildActionSection(
                            context,
                            isAssessmentPublishLockedForActions:
                                isAssessmentPublishLockedForActions,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionSection(
    BuildContext context, {
    required bool isAssessmentPublishLockedForActions,
  }) {
    if (!_hasDraft) {
      return GradientButton(
        label: _isGenerating
            ? 'Generating Draft with Groq...'
            : 'Generate Draft with Groq',
        colors: AppPalette.teacherGradient,
        onPressed: _isGenerating || _isTargetDateInPast
            ? () {}
            : _generateDraft,
      );
    }

    final actionButtons = <Widget>[
      GradientButton(
        label: _isPublishedMission
            ? (_isSaving ? 'Saving changes...' : 'Save Changes')
            : (_isSaving ? 'Publishing...' : 'Publish Mission'),
        colors: AppPalette.progressGradient,
        onPressed:
            _isSaving ||
                _isTargetDateInPast ||
                (!_isPublishedMission && isAssessmentPublishLockedForActions)
            ? () {}
            : () => _saveDraft(true),
      ),
      if (!_isPublishedMission)
        GradientButton(
          label: _isSaving ? 'Saving...' : 'Save Draft',
          colors: AppPalette.teacherGradient,
          onPressed: _isSaving || _isTargetDateInPast
              ? () {}
              : () => _saveDraft(false),
        ),
      GradientButton(
        label: 'Download Teacher Copy',
        colors: const [AppPalette.primaryBlue, AppPalette.aqua],
        onPressed: _isSaving || _isGenerating
            ? () {}
            : () => _downloadDraft(audience: _DraftExportAudience.teacher),
      ),
      GradientButton(
        label: 'Download Student Copy',
        colors: const [AppPalette.sun, AppPalette.orange],
        onPressed: _isSaving || _isGenerating
            ? () {}
            : () => _downloadDraft(audience: _DraftExportAudience.student),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final twoColumns = constraints.maxWidth >= 640;
            if (!twoColumns) {
              return Column(
                children: List.generate(actionButtons.length, (index) {
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index == actionButtons.length - 1 ? 0 : 10,
                    ),
                    child: actionButtons[index],
                  );
                }),
              );
            }

            final rows = <Widget>[];
            for (var index = 0; index < actionButtons.length; index += 2) {
              final secondIndex = index + 1;
              rows.add(
                Padding(
                  padding: EdgeInsets.only(
                    bottom: secondIndex >= actionButtons.length ? 0 : 10,
                  ),
                  child: Row(
                    children: [
                      Expanded(child: actionButtons[index]),
                      const SizedBox(width: 10),
                      Expanded(
                        child: secondIndex < actionButtons.length
                            ? actionButtons[secondIndex]
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              );
            }
            return Column(children: rows);
          },
        ),
        if (!_isPublishedMission && isAssessmentPublishLockedForActions) ...[
          const SizedBox(height: 8),
          Text(
            'Complete Task Focus to unlock publishing.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppPalette.textMuted),
          ),
        ],
        if (!_isPublishedMission && _isAssessmentMode) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _isSaving || _isTargetDateInPast
                  ? null
                  : () => _saveDraft(false),
              icon: const Icon(Icons.auto_awesome_rounded, size: 16),
              label: const Text('Draft Super Mission'),
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 34),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMissionSetup(BuildContext context) {
    final canEditQuestionCount = !_hasDraft;
    final isAssessmentMode = _isAssessmentMode;
    final canEditDraftFormat = !_hasDraft && !_isAssessmentMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Mission title', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextFormField(
          controller: _titleController,
          decoration: const InputDecoration(
            hintText: 'English Reading Mission',
          ),
          validator: (value) {
            if ((value ?? '').trim().isEmpty) {
              return 'Enter a mission title.';
            }

            return null;
          },
        ),
        const SizedBox(height: AppSpacing.section),
        Text('Difficulty', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _ChoiceChip(
              label: 'Easy',
              selected: _effectiveDifficulty == 'easy',
              colors: AppPalette.studentGradient,
              onTap: isAssessmentMode
                  ? null
                  : () => setState(() => _difficulty = 'easy'),
            ),
            _ChoiceChip(
              label: 'Medium',
              selected: _effectiveDifficulty == 'medium',
              colors: const [AppPalette.primaryBlue, AppPalette.aqua],
              onTap: isAssessmentMode
                  ? null
                  : () => setState(() => _difficulty = 'medium'),
            ),
            _ChoiceChip(
              label: 'Hard',
              selected: _effectiveDifficulty == 'hard',
              colors: const [AppPalette.sun, AppPalette.orange],
              onTap: isAssessmentMode
                  ? null
                  : () => setState(() => _difficulty = 'hard'),
            ),
          ],
        ),
        if (isAssessmentMode) ...[
          const SizedBox(height: 8),
          Text(
            'Assessment mode locks difficulty to Hard.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppPalette.textMuted),
          ),
        ],
        const SizedBox(height: AppSpacing.section),
        Text('Draft format', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        Wrap(
          runSpacing: 10,
          children: [
            _CountChip(
              label: 'Questions',
              selected: _draftFormat == 'QUESTIONS',
              onTap: canEditDraftFormat
                  ? () => _setDraftFormat('QUESTIONS')
                  : null,
            ),
            _CountChip(
              label: 'Theory',
              selected: _draftFormat == 'THEORY',
              onTap: canEditDraftFormat
                  ? () => _setDraftFormat('THEORY')
                  : null,
            ),
            _CountChip(
              label: 'Essay (A/B/C/D)',
              selected: _draftFormat == 'ESSAY_BUILDER',
              onTap: canEditDraftFormat
                  ? () => _setDraftFormat('ESSAY_BUILDER')
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _isAssessmentMode
              ? 'Assessment mode uses questions only.'
              : _hasDraft
              ? 'Draft format locks after generation.'
              : 'Questions create objective missions with fixed 30 XP at 5 or 8 questions and score-based 50 XP at 10 questions. Theory keeps 50 XP after teacher review. Essay (A/B/C/D) awards a fixed 20 XP on completion.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppPalette.textMuted),
        ),
        if (_draftFormat == 'ESSAY_BUILDER') ...[
          const SizedBox(height: AppSpacing.item),
          Text('Essay mode', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _CountChip(
                label: 'NORMAL',
                selected: _essayMode == 'NORMAL',
                onTap: !_hasDraft
                    ? () => setState(() => _essayMode = 'NORMAL')
                    : null,
              ),
              _CountChip(
                label: 'STRETCH_15',
                selected: _essayMode == 'STRETCH_15',
                onTap: !_hasDraft
                    ? () => setState(() => _essayMode = 'STRETCH_15')
                    : null,
              ),
              _CountChip(
                label: 'STRETCH_20',
                selected: _essayMode == 'STRETCH_20',
                onTap: !_hasDraft
                    ? () => setState(() => _essayMode = 'STRETCH_20')
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _hasDraft
                ? 'Essay mode locks after generation.'
                : 'NORMAL targets around 10 sentences, STRETCH_15 around 15, and STRETCH_20 around 20.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppPalette.textMuted),
          ),
        ],
        const SizedBox(height: AppSpacing.section),
        Text('Question count', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        if (_draftFormat == 'QUESTIONS') ...[
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children:
                const [
                      (5, '5 questions · Daily'),
                      (8, '8 questions · Revision'),
                      (10, '10 questions · Assessment mode'),
                    ]
                    .map(
                      (option) => _CountChip(
                        label: option.$2,
                        selected: _questionCount == option.$1,
                        onTap: option.$1 == _assessmentQuestionCount
                            ? _openAssessmentModeScreen
                            : canEditQuestionCount
                            ? () => setState(() {
                                _questionCount = option.$1;
                                _applyAssessmentModeDefaultsIfNeeded();
                              })
                            : null,
                      ),
                    )
                    .toList(growable: false),
          ),
          const SizedBox(height: 8),
          Text(
            'Use 5 for normal daily learning, 8 for revision, and 10 only for assessment mode.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppPalette.textMuted),
          ),
          if (!canEditQuestionCount) ...[
            const SizedBox(height: 8),
            Text(
              'Question count is locked after generation so you can focus on editing the draft.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppPalette.textMuted),
            ),
          ],
        ] else if (_draftFormat == 'THEORY') ...[
          SoftPanel(
            colors: const [Color(0xFFF8FBFF), Color(0xFFE8F4FF)],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fast focus · $_questionCount question${_questionCount == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Set how many quick theory-check questions Groq should draft from the uploaded or pasted unit text.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppPalette.textMuted),
                ),
                const SizedBox(height: 12),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppPalette.primaryBlue,
                    inactiveTrackColor: Colors.white.withValues(alpha: 0.78),
                    thumbColor: AppPalette.aqua,
                    overlayColor: AppPalette.primaryBlue.withValues(
                      alpha: 0.12,
                    ),
                    valueIndicatorColor: AppPalette.primaryBlue,
                  ),
                  child: Slider(
                    min: _theoryQuestionCountMin.toDouble(),
                    max: _theoryQuestionCountMax.toDouble(),
                    divisions:
                        _theoryQuestionCountMax - _theoryQuestionCountMin,
                    value: _questionCount.toDouble(),
                    label: '$_questionCount questions',
                    onChanged: canEditQuestionCount
                        ? (value) => setState(() {
                            // WHY: Theory mode is intentionally capped at a
                            // short 2 to 5 question range for fast focus.
                            _questionCount = value.round();
                          })
                        : null,
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '2 questions',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppPalette.textMuted,
                      ),
                    ),
                    Text(
                      '5 questions',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppPalette.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            !canEditQuestionCount
                ? 'Question count is locked after generation. Use Add Question or Remove to adjust the saved theory draft within 2 to 5 questions.'
                : 'Theory keeps a fixed 50 XP reward after teacher review and uses 2 to 5 fast-focus questions from the scanned unit text.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppPalette.textMuted),
          ),
        ] else ...[
          Text(
            'Essay builder sentence and blank counts are dynamic and come from the generated draft targets.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppPalette.textMuted),
          ),
        ],
        const SizedBox(height: AppSpacing.section),
        Text('Task focus', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _taskCodeOptions
              .map(
                (taskCode) => _CountChip(
                  label: taskCode,
                  selected: _selectedTaskCodes.contains(taskCode),
                  onTap: () => _toggleTaskCode(taskCode),
                ),
              )
              .toList(growable: false),
        ),
        const SizedBox(height: 8),
        Text(
          _selectedTaskCodes.isEmpty
              ? 'Select one or more task codes (for example P1 and P2) so Groq drafts mission questions for those tasks.'
              : 'Groq will target ${_selectedTaskCodes.join(', ')} while generating and regenerating this draft.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppPalette.textMuted),
        ),
        if (_selectedSubjectCertification != null) ...[
          const SizedBox(height: AppSpacing.item),
          _buildCertificationHelperPanel(context),
        ],
        if (_rawUploadedSourceText.trim().isNotEmpty) ...[
          const SizedBox(height: AppSpacing.item),
          Text(
            'Source preview mode',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _CountChip(
                label: 'Task-specific full section',
                selected: !_showFullRawUploadText,
                onTap: () {
                  setState(() => _showFullRawUploadText = false);
                  _syncUnitTextWithPreviewMode();
                },
              ),
              _CountChip(
                label: 'Show full raw upload text',
                selected: _showFullRawUploadText,
                onTap: () {
                  setState(() => _showFullRawUploadText = true);
                  _syncUnitTextWithPreviewMode();
                },
              ),
            ],
          ),
        ],
        if (_selectedTaskCodes.isNotEmpty || _showFullRawUploadText) ...[
          const SizedBox(height: AppSpacing.item),
          SoftPanel(
            colors: const [Color(0xFFF7FCFF), Color(0xFFE9F4FF)],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _showFullRawUploadText
                      ? 'Full raw upload text'
                      : _selectedTaskCodes.length == 1
                      ? '${_selectedTaskCodes.first} draft text from source'
                      : 'Task draft text from source',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  _showFullRawUploadText
                      ? 'This is the entire text extracted from the uploaded file.'
                      : 'This is the full original extracted text for ${_selectedTaskCodes.join(', ')} from your uploaded file.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppPalette.textMuted),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 320),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.84),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: _taskSourcePreviewText.isEmpty
                      ? Text(
                          'No raw uploaded text is available yet for this draft. Upload the source file in this sheet to view the full scanned text.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppPalette.textMuted),
                        )
                      : SingleChildScrollView(
                          child: SelectableText(
                            _taskSourcePreviewText,
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(height: 1.45),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.section),
        Text('XP reward', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final value in const [10, 15, 20, 25, 30, 35, 40, 45, 50])
              _CountChip(
                label: '$value XP',
                selected: _effectiveXpReward == value,
                onTap: null,
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _xpRewardPolicySummary,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppPalette.textMuted),
        ),
        const SizedBox(height: AppSpacing.section),
        Text('Source file', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          _isTheoryDraft
              ? 'Choose how to use the uploaded file. One path sends the extracted lesson text to Groq to draft a theory check for you. The other path tries to populate the draft directly from the uploaded source.'
              : 'Choose how to use the uploaded file. One path sends the extracted lesson text to Groq to draft the mission for you. The other path tries to populate the draft directly from the uploaded source questions and unit text.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppPalette.textMuted),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final stackButtons = constraints.maxWidth < 720;
            final aiDraftButton = GradientButton(
              label: _isUploadingForAiDraft
                  ? 'Uploading for AI draft...'
                  : 'Upload file for AI draft',
              colors: AppPalette.teacherGradient,
              onPressed: _isExtractingSource || _isTargetDateInPast
                  ? () {}
                  : () => _pickAndExtractSource(_SourceUploadMode.aiDraft),
            );
            final populateButton = GradientButton(
              label: _isPopulatingDraftFromSource
                  ? 'Populating draft from file...'
                  : 'Populate draft from PDF',
              colors: const [AppPalette.primaryBlue, AppPalette.aqua],
              onPressed: _isExtractingSource || _isTargetDateInPast
                  ? () {}
                  : () =>
                        _pickAndExtractSource(_SourceUploadMode.populateDraft),
            );

            if (stackButtons) {
              return Column(
                children: [
                  aiDraftButton,
                  const SizedBox(height: 10),
                  populateButton,
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: aiDraftButton),
                const SizedBox(width: 10),
                Expanded(child: populateButton),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        Text(
          'Upload file for AI draft extracts the lesson text and asks Groq to build the draft. Populate draft from PDF copies the detected questions, unit text, and draft fields directly when the file is structured enough.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppPalette.textMuted),
        ),
        if (_hasDraft && _rawUploadedSourceText.trim().isEmpty) ...[
          const SizedBox(height: AppSpacing.item),
          GradientButton(
            label: _isReextractingSource
                ? 'Re-extracting source...'
                : 'Re-extract source for this draft',
            colors: AppPalette.mentorGradient,
            onPressed: _isReextractingSource ? () {} : _reextractSourceForDraft,
          ),
          const SizedBox(height: 8),
          Text(
            'One-click recovery for older drafts that were saved before full raw source text was persisted.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppPalette.textMuted),
          ),
        ],
        if (_hasResolvedSource || _uploadedSource != null) ...[
          const SizedBox(height: AppSpacing.item),
          _SourceSummaryCard(
            uploadedSource: _uploadedSource,
            sourceFileName: _resolvedSourceFileName,
            sourceFileType: _resolvedSourceFileType,
            xpReward: _effectiveXpReward,
            sourceUploadMode:
                _activeSourceUploadMode ?? _SourceUploadMode.aiDraft,
          ),
        ],
        if (_sourceUploadReadiness != null) ...[
          const SizedBox(height: AppSpacing.item),
          _SourceReadinessCard(
            readiness: _sourceUploadReadiness!,
            hasPrefilledMission: _uploadedSource?.prefilledMission != null,
            sourceUploadMode:
                _activeSourceUploadMode ?? _SourceUploadMode.aiDraft,
          ),
        ],
        if (_uploadedSource != null) ...[
          const SizedBox(height: AppSpacing.item),
          _UnitPlanDraftCard(
            draft: _uploadedSource!,
            appliedXpReward: _effectiveXpReward,
            sourceUploadMode:
                _activeSourceUploadMode ?? _SourceUploadMode.aiDraft,
          ),
        ],
        const SizedBox(height: AppSpacing.section),
        Text('Unit text', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          _activeSourceUploadMode == _SourceUploadMode.populateDraft
              ? _rawUploadedSourceText.trim().isEmpty
                    ? 'Populate draft reads the uploaded file directly. This Unit text box is only used if you later switch to Generate with AI.'
                    : 'Populate draft reads the uploaded file directly. This Unit text box stays separate unless you later switch to Generate with AI.'
              : _rawUploadedSourceText.trim().isEmpty
              ? 'This text is what Groq uses to generate the draft questions.'
              : 'The selected source preview (or this text) is what Groq uses to generate the draft questions.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppPalette.textMuted),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _unitTextController,
          minLines: 8,
          maxLines: 12,
          decoration: const InputDecoration(
            hintText:
                'Paste the lesson notes, reading passage, or unit content here...',
          ),
          validator: (value) {
            if ((value ?? '').trim().length < 80) {
              return 'Paste at least 80 characters of lesson text.';
            }

            return null;
          },
        ),
        if (_hasDraft) ...[
          const SizedBox(height: 10),
          Text(
            _activeSourceUploadMode == _SourceUploadMode.populateDraft
                ? _isPublishedMission
                      ? 'Upload another structured file to repopulate this draft, or paste lesson text here if you want to switch back to Generate with AI before saving changes.'
                      : 'Upload another structured file to repopulate this draft, or paste lesson text here if you want to switch back to Generate with AI.'
                : _isPublishedMission
                ? 'Paste fresh lesson text here or upload a new source file, then regenerate the question set before saving changes.'
                : 'Paste fresh lesson text here or upload a new source file, then regenerate the draft with Groq.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppPalette.textMuted),
          ),
          const SizedBox(height: 12),
          GradientButton(
            label: _isGenerating
                ? 'Refreshing with Groq...'
                : 'Regenerate with Groq',
            colors: AppPalette.teacherGradient,
            onPressed: _isGenerating || _isTargetDateInPast
                ? () {}
                : _regenerateDraft,
          ),
        ],
      ],
    );
  }

  Future<void> _loadStudentCertification() async {
    try {
      final certification = await widget.api.fetchTeacherStudentCertification(
        token: widget.session.token,
        studentId: widget.student.id,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _studentCertification = certification;
      });
    } catch (error) {
      // WHY: Certification helper copy should never block mission authoring, so
      // the builder fails soft if the secondary certification request fails.
    }
  }

  Widget _buildCertificationHelperPanel(BuildContext context) {
    final certification = _selectedSubjectCertification!;
    final selectedSingleTaskCode = _selectedTaskCodes.length == 1
        ? _selectedTaskCodes.first
        : '';
    final selectedTaskIsRequired =
        selectedSingleTaskCode.isNotEmpty &&
        certification.requiredTaskCodes.contains(selectedSingleTaskCode);
    final helperText = !_isCertificationQualifyingFormat
        ? 'This mission will not count toward certification because only essays, theory, and 10+ question missions qualify.'
        : _selectedTaskCodes.isEmpty
        ? 'To count toward certification, choose exactly one task focus.'
        : _selectedTaskCodes.length > 1
        ? 'This mission will not count toward certification because more than one task focus is selected.'
        : !selectedTaskIsRequired
        ? '$selectedSingleTaskCode is not part of this subject certification template.'
        : 'Groq will generate this draft only for $selectedSingleTaskCode. This mission can count toward certification if the student passes it.';

    return SoftPanel(
      colors: const [Color(0xFFF7FCFF), Color(0xFFEAF4FF)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Task-focus certification',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          Text(
            certification.certificationLabel,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppPalette.textMuted),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: certification.requiredTaskCodes
                .map((taskCode) {
                  final isPassed = certification.passedTaskCodes.contains(
                    taskCode,
                  );
                  final isRemaining = certification.remainingTaskCodes.contains(
                    taskCode,
                  );
                  return _CertificationFocusChip(
                    taskCode: taskCode,
                    status: isPassed
                        ? 'passed'
                        : isRemaining
                        ? 'remaining'
                        : 'required',
                  );
                })
                .toList(growable: false),
          ),
          const SizedBox(height: 10),
          Text(
            certification.remainingTaskCodes.isEmpty
                ? 'All required task focuses are already passed for this subject.'
                : 'Remaining for ${widget.student.name}: ${certification.remainingTaskCodes.join(', ')}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppPalette.textMuted),
          ),
          const SizedBox(height: 8),
          Text(
            helperText,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppPalette.navy,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDraftPreview(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SoftPanel(
          colors: const [Color(0xFFF6FCFF), Color(0xFFE8F4FF)],
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: AppPalette.teacherGradient,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.rate_review_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: AppSpacing.item),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Draft preview',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Edit the teacher note, question wording, answer options, and correct answers before you publish this mission.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppPalette.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.section),
        Text('Teacher note', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextFormField(
          controller: _teacherNoteController,
          minLines: 2,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText:
                'Add a short note for the student before the mission starts.',
          ),
        ),
        const SizedBox(height: AppSpacing.section),
        if (_draftFormat == 'ESSAY_BUILDER') ...[
          Text(
            'Essay builder preview',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'This guided essay draft will be used for A/B/C/D sentence building.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppPalette.textMuted),
          ),
          const SizedBox(height: AppSpacing.item),
          _buildEssayBuilderPreview(context),
        ] else ...[
          Text(
            _draftFormat == 'THEORY' ? 'Theory questions' : 'Draft questions',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            _draftFormat == 'THEORY'
                ? 'Edit Learn First, the written-response prompt, the expected answer, and the minimum words required per question.'
                : 'Choose the right answer for each question and tighten the wording where needed.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppPalette.textMuted),
          ),
          const SizedBox(height: AppSpacing.item),
          ...List.generate(
            _questionEditors.length,
            (index) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.item),
              child: _draftFormat == 'THEORY'
                  ? _TheoryQuestionEditorCard(
                      index: index,
                      editor: _questionEditors[index],
                      canRemove:
                          _questionEditors.length > _theoryQuestionCountMin,
                      onRemove: () => _removeTheoryQuestion(index),
                    )
                  : _QuestionEditorCard(
                      index: index,
                      editor: _questionEditors[index],
                      onCorrectIndexChanged: (value) {
                        setState(
                          () => _questionEditors[index].correctIndex = value,
                        );
                      },
                    ),
            ),
          ),
          if (_draftFormat == 'THEORY') ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Theory drafts must stay between $_theoryQuestionCountMin and $_theoryQuestionCountMax questions.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppPalette.textMuted,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                TextButton.icon(
                  onPressed: _questionEditors.length >= _theoryQuestionCountMax
                      ? null
                      : _addTheoryQuestion,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add Question'),
                ),
              ],
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildEssayBuilderPreview(BuildContext context) {
    final draft = _draftMission?.essayBuilderDraft;
    if (draft == null) {
      return SoftPanel(
        child: Text(
          'No essay builder draft is available yet. Generate the draft with Groq to see the guided sentences.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppPalette.textMuted),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SoftPanel(
          colors: const [Color(0xFFF6FCFF), Color(0xFFE8F4FF)],
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _InfoPill(label: 'Mode: ${draft.mode}'),
              _InfoPill(
                label:
                    'Words: ${draft.targets.targetWordMin}-${draft.targets.targetWordMax}',
              ),
              _InfoPill(
                label: 'Sentences: ${draft.targets.targetSentenceCount}',
              ),
              _InfoPill(label: 'Blanks: ${draft.targets.targetBlankCount}'),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ...List.generate(draft.sentences.length, (index) {
          final sentence = draft.sentences[index];
          final blankPartIndexes = <int>[];
          for (
            var partIndex = 0;
            partIndex < sentence.parts.length;
            partIndex += 1
          ) {
            if (sentence.parts[partIndex].isBlank) {
              blankPartIndexes.add(partIndex);
            }
          }
          final previewText = sentence.parts
              .map((part) => part.isBlank ? '____' : part.value)
              .join();
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.item),
            child: SoftPanel(
              colors: const [Color(0xFFF7FCFF), Color(0xFFE9F4FF)],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          'Sentence ${index + 1} · ${sentence.role}',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          _openEssayLearnFirstEditor(
                            sentenceIndex: index,
                            sentence: sentence,
                          );
                        },
                        icon: const Icon(Icons.menu_book_rounded, size: 18),
                        label: const Text('Edit Learn First'),
                      ),
                      const SizedBox(width: 4),
                      TextButton.icon(
                        onPressed: () {
                          _openEssaySentenceTextEditor(
                            sentenceIndex: index,
                            sentence: sentence,
                          );
                        },
                        icon: const Icon(Icons.edit_note_rounded, size: 18),
                        label: const Text('Edit sentence'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    sentence.learnFirst.title.isEmpty
                        ? 'LEARN FIRST'
                        : sentence.learnFirst.title,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 6),
                  ...sentence.learnFirst.bullets.map(
                    (bullet) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('• $bullet'),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(previewText),
                  const SizedBox(height: 8),
                  ...List.generate(blankPartIndexes.length, (blankIndex) {
                    final part = sentence.parts[blankPartIndexes[blankIndex]];
                    final options = <MapEntry<String, String>>[
                      MapEntry('A', part.options['A'] ?? ''),
                      MapEntry('B', part.options['B'] ?? ''),
                      MapEntry('C', part.options['C'] ?? ''),
                      MapEntry('D', part.options['D'] ?? ''),
                    ];
                    final correctOptionText =
                        part.options[part.correctOption] ?? '';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Blank ${blankIndex + 1}',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            if (part.hint.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Hint: ${part.hint}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                            const SizedBox(height: 6),
                            Text(
                              'Correct: ${part.correctOption}) $correctOptionText',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: AppPalette.primaryBlue,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            ...options.map(
                              (entry) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  '${entry.key}) ${entry.value}${entry.key == part.correctOption ? '  ✓' : ''}',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: entry.key == part.correctOption
                                            ? AppPalette.navy
                                            : AppPalette.textMuted,
                                        fontWeight:
                                            entry.key == part.correctOption
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                      ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: () {
                                  _openEssayBlankEditor(
                                    sentenceIndex: index,
                                    partIndex: blankPartIndexes[blankIndex],
                                    part: part,
                                  );
                                },
                                icon: const Icon(Icons.tune_rounded, size: 18),
                                label: const Text('Edit blank options'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Future<void> _generateDraft() async {
    if (_isTargetDateInPast) {
      setState(() {
        _errorMessage =
            'Pick today or an upcoming lesson date before generating a draft.';
      });
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isGenerating = true;
      _errorMessage = null;
    });

    try {
      // WHY: Draft generation always starts as teacher-review content so the
      // AI can assist without publishing directly to the student view.
      final mission = await widget.api.generateTeacherMission(
        token: widget.session.token,
        studentId: widget.student.id,
        subjectId: widget.subject.id,
        sessionType: _selectedSessionType,
        title: _titleController.text.trim(),
        targetDate: _dateKey(_resolvedTargetDate),
        unitText: _unitTextForGroq,
        sourceRawText: _rawUploadedSourceText.trim(),
        draftFormat: _draftFormat,
        essayMode: _draftFormat == 'ESSAY_BUILDER' ? _essayMode : '',
        missionDraftId: _draftMission?.id ?? '',
        difficulty: _effectiveDifficulty,
        questionCount: _questionCount,
        xpReward: _effectiveXpReward,
        taskCodes: _selectedTaskCodes,
        sourceFileName: _resolvedSourceFileName,
        sourceFileType: _resolvedSourceFileType,
      );

      if (!mounted) {
        return;
      }

      if (_draftFormat == 'ESSAY_BUILDER' &&
          mission.draftFormat != 'ESSAY_BUILDER') {
        setState(() {
          // WHY: Surface backend mismatch so teachers know essay drafts require the updated API.
          _errorMessage =
              'Essay draft not returned. Update/redeploy the backend and try again.';
          _isGenerating = false;
        });
        return;
      }

      if (_draftFormat == 'THEORY' && mission.draftFormat != 'THEORY') {
        setState(() {
          // WHY: Surface backend mismatch so teachers know Theory drafts need
          // the updated backend contract before they can persist this mode.
          _errorMessage =
              'Theory draft not returned. Update/redeploy the backend and try again.';
          _isGenerating = false;
        });
        return;
      }

      if (_draftFormat == 'ESSAY_BUILDER' && mission.draftJson == null) {
        setState(() {
          // WHY: Essay drafts rely on draftJson for A/B/C/D sentence building.
          _errorMessage =
              'Essay draft is missing the builder JSON. Please regenerate after the backend update.';
          _isGenerating = false;
        });
        return;
      }

      setState(() {
        _applyDraft(mission);
        _createdDraftThisSession = true;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  Future<void> _regenerateDraft() async {
    await _regenerateDraftWithCurrentSelection(showTaskFocusRefreshHint: false);
  }

  Future<void> _regenerateDraftWithCurrentSelection({
    required bool showTaskFocusRefreshHint,
  }) async {
    if (_isTargetDateInPast) {
      setState(() {
        _errorMessage =
            'Pick today or an upcoming lesson date before regenerating this draft.';
      });
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_draftMission == null) {
      setState(() {
        _errorMessage =
            'Generate a draft first before asking Groq to refresh it.';
      });
      return;
    }

    setState(() {
      _isGenerating = true;
      _errorMessage = showTaskFocusRefreshHint
          ? 'Refreshing draft for ${_selectedTaskCodes.join(', ')}...'
          : null;
    });

    try {
      final requestedQuestionCount = _isAssessmentMode
          ? _assessmentQuestionCount
          : (_questionEditors.isEmpty
                ? _questionCount
                : _questionEditors.length);

      // WHY: Regeneration uses preview mode so new AI wording can be inspected
      // before it replaces the saved draft or live mission.
      final preview = await widget.api.previewTeacherMission(
        token: widget.session.token,
        studentId: widget.student.id,
        subjectId: widget.subject.id,
        sessionType: _selectedSessionType,
        title: _titleController.text.trim(),
        targetDate: _dateKey(_resolvedTargetDate),
        unitText: _unitTextForGroq,
        sourceRawText: _rawUploadedSourceText.trim(),
        draftFormat: _draftFormat,
        essayMode: _draftFormat == 'ESSAY_BUILDER' ? _essayMode : '',
        missionDraftId: _draftMission?.id ?? '',
        difficulty: _effectiveDifficulty,
        questionCount: requestedQuestionCount,
        xpReward: _effectiveXpReward,
        taskCodes: _selectedTaskCodes,
        sourceFileName: _resolvedSourceFileName,
        sourceFileType: _resolvedSourceFileType,
      );

      if (!mounted) {
        return;
      }

      if (_draftFormat == 'ESSAY_BUILDER' &&
          preview.draftFormat != 'ESSAY_BUILDER') {
        setState(() {
          // WHY: Surface backend mismatch so teachers know essay drafts require the updated API.
          _errorMessage =
              'Essay draft not returned. Update/redeploy the backend and try again.';
          _isGenerating = false;
        });
        return;
      }

      if (_draftFormat == 'THEORY' && preview.draftFormat != 'THEORY') {
        setState(() {
          // WHY: Surface backend mismatch so teachers know Theory drafts need
          // the updated backend contract before preview regeneration can work.
          _errorMessage =
              'Theory draft not returned. Update/redeploy the backend and try again.';
          _isGenerating = false;
        });
        return;
      }

      if (_draftFormat == 'ESSAY_BUILDER' && preview.draftJson == null) {
        setState(() {
          // WHY: Essay drafts rely on draftJson for A/B/C/D sentence building.
          _errorMessage =
              'Essay draft is missing the builder JSON. Please regenerate after the backend update.';
          _isGenerating = false;
        });
        return;
      }

      setState(() {
        _applyDraft(
          _draftMission!.copyWith(
            title: preview.title,
            teacherNote: preview.teacherNote,
            sourceUnitText: _unitTextController.text.trim(),
            sourceRawText: _rawUploadedSourceText.trim(),
            draftFormat: preview.draftFormat,
            essayMode: preview.essayMode,
            draftJson: preview.draftJson,
            difficulty: _effectiveDifficulty,
            questionCount: preview.questionCount,
            questions: preview.questions,
            aiModel: preview.aiModel,
            xpReward: _effectiveXpReward,
            taskCodes: _selectedTaskCodes,
            sourceFileName: _resolvedSourceFileName,
            sourceFileType: _resolvedSourceFileType,
          ),
        );
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  Future<void> _saveDraft(bool publish) async {
    if (_isTargetDateInPast) {
      setState(() {
        _errorMessage =
            'Past class dates cannot be published or updated for student delivery.';
      });
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_draftMission == null) {
      setState(() {
        _errorMessage = 'Generate a draft first before saving or publishing.';
      });
      return;
    }

    if (publish && _isAssessmentPublishLocked) {
      setState(() {
        _errorMessage =
            'Select at least one Task Focus before publishing assessment mode.';
      });
      return;
    }

    if (_draftFormat == 'QUESTIONS' &&
        _isAssessmentMode &&
        _questionEditors.length != _assessmentQuestionCount) {
      setState(() {
        _errorMessage =
            'Assessment missions must contain exactly 10 questions. Regenerate this draft in assessment mode first.';
      });
      return;
    }

    final validationError = _validateDraftQuestions();

    if (validationError != null) {
      setState(() => _errorMessage = validationError);
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      // WHY: Publishing is explicit so the teacher stays in control of when the
      // student can access the mission for the scheduled lesson slot.
      final mission = await widget.api.updateTeacherMission(
        token: widget.session.token,
        missionId: _draftMission!.id,
        sessionType: _selectedSessionType,
        targetDate: _dateKey(_resolvedTargetDate),
        title: _titleController.text.trim(),
        teacherNote: _teacherNoteController.text.trim(),
        sourceUnitText: _unitTextController.text.trim(),
        sourceRawText: _rawUploadedSourceText.trim(),
        difficulty: _effectiveDifficulty,
        xpReward: _effectiveXpReward,
        taskCodes: _selectedTaskCodes,
        sourceFileName: _resolvedSourceFileName,
        sourceFileType: _resolvedSourceFileType,
        draftFormat: _draftFormat,
        essayMode: _draftFormat == 'ESSAY_BUILDER' ? _essayMode : null,
        draftJson: _draftFormat == 'ESSAY_BUILDER'
            ? _draftMission!.draftJson
            : null,
        status: publish ? 'published' : 'draft',
        questions: _draftFormat == 'ESSAY_BUILDER'
            ? const []
            : _questionEditors
                  .map((editor) => editor.toMissionQuestion())
                  .toList(growable: false),
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(mission);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _downloadDraft({required _DraftExportAudience audience}) async {
    if (_draftMission == null) {
      return;
    }

    final fileName = _buildDraftDownloadFileName(audience: audience);
    final htmlContent = _buildDraftDownloadHtml(audience: audience);
    final clipboardContent = _buildDraftClipboardContent(audience: audience);
    final audienceLabel = _draftExportAudienceLabel(audience);

    try {
      final downloaded = await downloadTextFile(
        fileName: fileName,
        content: htmlContent,
        mimeType: 'text/html;charset=utf-8',
      );

      if (!mounted) {
        return;
      }

      if (downloaded) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Downloaded $audienceLabel.')));
        return;
      }

      await Clipboard.setData(ClipboardData(text: clipboardContent));
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Download is not available on this device yet. $audienceLabel copied to clipboard.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not export $audienceLabel: $error')),
      );
    }
  }

  String _draftExportAudienceLabel(_DraftExportAudience audience) {
    return audience == _DraftExportAudience.teacher
        ? 'Teacher Copy'
        : 'Student Copy';
  }

  String _buildDraftDownloadFileName({required _DraftExportAudience audience}) {
    final title = _sanitizeFileNameSegment(_titleController.text.trim());
    final student = _sanitizeFileNameSegment(widget.student.name);
    final subject = _sanitizeFileNameSegment(widget.subject.name);
    final date = _dateKey(_resolvedTargetDate);
    final audienceSlug = audience == _DraftExportAudience.teacher
        ? 'teacher-copy'
        : 'student-copy';
    return '${title}_${student}_${subject}_${_selectedSessionType}_${date}_$audienceSlug.html';
  }

  String _buildDraftClipboardContent({required _DraftExportAudience audience}) {
    final includeAnswers = audience == _DraftExportAudience.teacher;
    final includeTeacherContext = audience == _DraftExportAudience.teacher;
    final draft = _draftMission;
    final unitText = includeTeacherContext
        ? _unitTextController.text.trim()
        : '';
    final buffer = StringBuffer()
      ..writeln(
        'FOCUS MISSION ${_draftExportAudienceLabel(audience).toUpperCase()}',
      )
      ..writeln('====================================')
      ..writeln('Title: ${_titleController.text.trim()}')
      ..writeln('Student: ${widget.student.name}')
      ..writeln('Subject: ${widget.subject.name}')
      ..writeln('Session: ${_selectedSessionType.toUpperCase()}')
      ..writeln('Target Date: ${_formatTargetDate(_resolvedTargetDate)}')
      ..writeln('Copy: ${_draftExportAudienceLabel(audience)}')
      ..writeln('Status: ${draft?.status ?? 'draft'}')
      ..writeln('Draft Format: $_draftFormat')
      ..writeln('Difficulty: ${_effectiveDifficulty.toUpperCase()}')
      ..writeln('XP Reward: $_effectiveXpReward');

    if (includeTeacherContext) {
      buffer.writeln(
        'Task Focus: ${_selectedTaskCodes.isEmpty ? 'None selected' : _selectedTaskCodes.join(', ')}',
      );
    }

    final teacherNote = _teacherNoteController.text.trim();
    if (includeTeacherContext && teacherNote.isNotEmpty) {
      buffer
        ..writeln('')
        ..writeln('TEACHER NOTE')
        ..writeln('------------')
        ..writeln(teacherNote);
    }

    if (unitText.isNotEmpty) {
      buffer
        ..writeln('')
        ..writeln('UNIT TEXT')
        ..writeln('---------')
        ..writeln(unitText);
    }

    if (_draftFormat == 'ESSAY_BUILDER') {
      _writeEssayBuilderDraftText(
        buffer,
        unitText: unitText,
        includeAnswers: includeAnswers,
      );
    } else {
      _writeQuestionDraftText(
        buffer,
        unitText: unitText,
        includeAnswers: includeAnswers,
      );
    }

    return buffer.toString().trimRight();
  }

  String _buildDraftDownloadHtml({required _DraftExportAudience audience}) {
    final includeAnswers = audience == _DraftExportAudience.teacher;
    final includeTeacherContext = audience == _DraftExportAudience.teacher;
    final audienceLabel = _draftExportAudienceLabel(audience);
    final title = _titleController.text.trim();
    final taskFocusText = _selectedTaskCodes.isEmpty
        ? 'None selected'
        : _selectedTaskCodes.join(', ');
    final teacherNote = _teacherNoteController.text.trim();
    final unitText = includeTeacherContext
        ? _unitTextController.text.trim()
        : '';
    final summary = includeAnswers
        ? 'Teacher copy with answers, expected responses, and review notes.'
        : 'Student copy with the mission content only. Answers and teacher-only notes are removed.';

    final buffer = StringBuffer()
      ..writeln('<!DOCTYPE html>')
      ..writeln('<html lang="en">')
      ..writeln('<head>')
      ..writeln('<meta charset="utf-8" />')
      ..writeln(
        '<meta name="viewport" content="width=device-width, initial-scale=1" />',
      )
      ..writeln('<title>${_escapeHtml('$title · $audienceLabel')}</title>')
      ..writeln('<style>${_buildDraftExportStyles()}</style>')
      ..writeln('</head>')
      ..writeln('<body>')
      ..writeln('<main class="page">')
      ..writeln('<section class="hero">')
      ..writeln('<div class="hero-copy">')
      ..writeln('<span class="copy-chip">${_escapeHtml(audienceLabel)}</span>')
      ..writeln('<h1>${_escapeHtml(title)}</h1>')
      ..writeln('<p class="hero-summary">${_escapeHtml(summary)}</p>')
      ..writeln('</div>')
      ..writeln('<div class="meta-grid">')
      ..writeln(
        _buildMetaCardHtml(label: 'Student', value: widget.student.name),
      )
      ..writeln(
        _buildMetaCardHtml(label: 'Subject', value: widget.subject.name),
      )
      ..writeln(
        _buildMetaCardHtml(
          label: 'Session',
          value: _selectedSessionType.toUpperCase(),
        ),
      )
      ..writeln(
        _buildMetaCardHtml(
          label: 'Target Date',
          value: _formatTargetDate(_resolvedTargetDate),
        ),
      )
      ..writeln(_buildMetaCardHtml(label: 'Format', value: _draftFormat))
      ..writeln(
        _buildMetaCardHtml(
          label: 'Difficulty',
          value: _effectiveDifficulty.toUpperCase(),
        ),
      )
      ..writeln(
        _buildMetaCardHtml(label: 'XP Reward', value: '$_effectiveXpReward XP'),
      );

    if (includeTeacherContext) {
      buffer.writeln(
        _buildMetaCardHtml(label: 'Task Focus', value: taskFocusText),
      );
    }

    buffer
      ..writeln('</div>')
      ..writeln('</section>')
      ..writeln(
        '<section class="section-card notice-card ${includeAnswers ? 'teacher-note' : 'student-note'}">',
      )
      ..writeln('<h2>${_escapeHtml(audienceLabel)}</h2>')
      ..writeln(
        '<p>${_escapeHtml(includeAnswers ? 'Use this version for review, marking, and answer checking.' : 'Use this version with the learner. It keeps the mission clean and answer-free.')}</p>',
      )
      ..writeln('</section>');

    if (includeTeacherContext && teacherNote.isNotEmpty) {
      buffer
        ..writeln('<section class="section-card">')
        ..writeln('<h2>Teacher Note</h2>')
        ..writeln(_buildRichTextHtml(teacherNote))
        ..writeln('</section>');
    }

    if (includeTeacherContext && unitText.isNotEmpty) {
      buffer
        ..writeln('<section class="section-card">')
        ..writeln('<h2>Unit Text</h2>')
        ..writeln(
          '<p class="section-kicker">Reviewed unit text saved with this mission.</p>',
        )
        ..writeln(_buildRichTextHtml(unitText))
        ..writeln('</section>');
    }

    if (_draftFormat == 'ESSAY_BUILDER') {
      buffer.writeln(
        _buildEssayBuilderDraftHtml(
          includeAnswers: includeAnswers,
          audienceLabel: audienceLabel,
        ),
      );
    } else {
      buffer.writeln(
        _buildQuestionDraftHtml(
          includeAnswers: includeAnswers,
          audienceLabel: audienceLabel,
        ),
      );
    }

    buffer
      ..writeln('</main>')
      ..writeln('</body>')
      ..writeln('</html>');

    return buffer.toString();
  }

  String _buildMetaCardHtml({required String label, required String value}) {
    return '<div class="meta-card"><span class="meta-label">${_escapeHtml(label)}</span><strong class="meta-value">${_escapeHtml(value)}</strong></div>';
  }

  void _writeQuestionDraftText(
    StringBuffer buffer, {
    required String unitText,
    required bool includeAnswers,
  }) {
    const optionLabels = ['A', 'B', 'C', 'D'];

    buffer
      ..writeln('')
      ..writeln(_draftFormat == 'THEORY' ? 'THEORY QUESTIONS' : 'QUESTIONS')
      ..writeln('----------------');

    for (var index = 0; index < _questionEditors.length; index += 1) {
      final editor = _questionEditors[index];
      buffer
        ..writeln('')
        ..writeln('Question ${index + 1}')
        ..writeln('Learn First: ${editor.learningTextController.text.trim()}')
        ..writeln('Prompt: ${editor.promptController.text.trim()}');

      if (unitText.isNotEmpty) {
        buffer.writeln('Unit Text: $unitText');
      }

      if (_draftFormat == 'THEORY') {
        buffer.writeln(
          'Minimum Words: ${editor.minWordCountController.text.trim()}',
        );
        if (includeAnswers) {
          buffer.writeln(
            'Expected Answer: ${editor.expectedAnswerController.text.trim()}',
          );
          final explanation = editor.explanationController.text.trim();
          if (explanation.isNotEmpty) {
            buffer.writeln('Teacher Guidance: $explanation');
          }
        }
        continue;
      }

      for (
        var optionIndex = 0;
        optionIndex < editor.optionControllers.length;
        optionIndex += 1
      ) {
        final label = optionLabels[optionIndex];
        buffer.writeln(
          '$label) ${editor.optionControllers[optionIndex].text.trim()}',
        );
      }
      if (includeAnswers) {
        final correctLabel = optionLabels[editor.correctIndex.clamp(0, 3)];
        final correctAnswer = editor
            .optionControllers[editor.correctIndex.clamp(0, 3)]
            .text
            .trim();
        buffer.writeln('Correct Answer: $correctLabel) $correctAnswer');
        final explanation = editor.explanationController.text.trim();
        if (explanation.isNotEmpty) {
          buffer.writeln('Explanation: $explanation');
        }
      }
    }
  }

  void _writeEssayBuilderDraftText(
    StringBuffer buffer, {
    required String unitText,
    required bool includeAnswers,
  }) {
    final draft = _draftMission?.essayBuilderDraft;
    if (draft == null) {
      buffer
        ..writeln('')
        ..writeln('ESSAY BUILDER')
        ..writeln('-------------')
        ..writeln('Essay builder draft is missing.');
      return;
    }

    buffer
      ..writeln('')
      ..writeln('ESSAY BUILDER')
      ..writeln('-------------')
      ..writeln('Mode: ${draft.mode}')
      ..writeln(
        'Target Words: ${draft.targets.targetWordMin}-${draft.targets.targetWordMax}',
      )
      ..writeln('Target Sentences: ${draft.targets.targetSentenceCount}')
      ..writeln('Target Blanks: ${draft.targets.targetBlankCount}');

    for (
      var sentenceIndex = 0;
      sentenceIndex < draft.sentences.length;
      sentenceIndex += 1
    ) {
      final sentence = draft.sentences[sentenceIndex];
      buffer
        ..writeln('')
        ..writeln('Sentence ${sentenceIndex + 1} · ${sentence.role}');

      if (unitText.isNotEmpty) {
        buffer.writeln('Unit Text: $unitText');
      }

      buffer.writeln(
        'Learn First Title: ${sentence.learnFirst.title.trim().isEmpty ? 'LEARN FIRST' : sentence.learnFirst.title.trim()}',
      );

      for (
        var bulletIndex = 0;
        bulletIndex < sentence.learnFirst.bullets.length;
        bulletIndex += 1
      ) {
        final bullet = sentence.learnFirst.bullets[bulletIndex].trim();
        if (bullet.isEmpty) {
          continue;
        }
        buffer.writeln('Learn First Bullet ${bulletIndex + 1}: $bullet');
      }

      buffer.writeln('Sentence Preview: ${_sentencePreviewText(sentence)}');

      final blankParts = sentence.parts
          .where((part) => part.isBlank)
          .toList(growable: false);
      for (
        var blankIndex = 0;
        blankIndex < blankParts.length;
        blankIndex += 1
      ) {
        final part = blankParts[blankIndex];
        buffer.writeln('Blank ${blankIndex + 1}:');
        if (part.hint.trim().isNotEmpty) {
          buffer.writeln('Hint: ${part.hint.trim()}');
        }
        for (final label in const ['A', 'B', 'C', 'D']) {
          buffer.writeln('$label) ${part.options[label] ?? ''}');
        }
        if (includeAnswers) {
          buffer.writeln(
            'Correct Answer: ${part.correctOption}) ${part.options[part.correctOption] ?? ''}',
          );
        }
      }
    }
  }

  String _buildQuestionDraftHtml({
    required bool includeAnswers,
    required String audienceLabel,
  }) {
    const optionLabels = ['A', 'B', 'C', 'D'];
    final buffer = StringBuffer()
      ..writeln('<section class="section-card">')
      ..writeln(
        '<h2>${_escapeHtml(_draftFormat == 'THEORY' ? 'Theory Questions' : 'Questions')}</h2>',
      )
      ..writeln(
        '<p class="section-kicker">${_escapeHtml(includeAnswers ? 'Teacher-ready answer view with guidance.' : 'Student-ready mission copy without answers.')}</p>',
      );

    for (var index = 0; index < _questionEditors.length; index += 1) {
      final editor = _questionEditors[index];
      buffer
        ..writeln('<article class="question-card">')
        ..writeln('<div class="question-top">')
        ..writeln(
          '<span class="question-pill">Question ${index + 1}</span><span class="copy-pill">${_escapeHtml(audienceLabel)}</span>',
        )
        ..writeln('</div>')
        ..writeln('<div class="field-label">Learn First</div>')
        ..writeln(_buildRichTextHtml(editor.learningTextController.text.trim()))
        ..writeln('<div class="field-label">Prompt</div>')
        ..writeln(_buildRichTextHtml(editor.promptController.text.trim()));

      if (_draftFormat == 'THEORY') {
        buffer.writeln(
          '<div class="pill-row"><span class="soft-pill">Minimum Words: ${_escapeHtml(editor.minWordCountController.text.trim())}</span></div>',
        );
        if (includeAnswers) {
          buffer
            ..writeln('<div class="answer-card">')
            ..writeln('<div class="field-label">Expected Answer</div>')
            ..writeln(
              _buildRichTextHtml(editor.expectedAnswerController.text.trim()),
            );
          final explanation = editor.explanationController.text.trim();
          if (explanation.isNotEmpty) {
            buffer
              ..writeln('<div class="field-label">Teacher Guidance</div>')
              ..writeln(_buildRichTextHtml(explanation));
          }
          buffer.writeln('</div>');
        }
        buffer.writeln('</article>');
        continue;
      }

      buffer
        ..writeln('<div class="field-label">Options</div>')
        ..writeln('<ul class="option-list">');
      for (
        var optionIndex = 0;
        optionIndex < editor.optionControllers.length;
        optionIndex += 1
      ) {
        final isCorrect = includeAnswers && editor.correctIndex == optionIndex;
        buffer.writeln(
          '<li class="option-row ${isCorrect ? 'correct-option' : ''}"><span class="option-badge">${optionLabels[optionIndex]}</span><span>${_escapeHtml(editor.optionControllers[optionIndex].text.trim())}</span></li>',
        );
      }
      buffer.writeln('</ul>');

      if (includeAnswers) {
        final correctLabel = optionLabels[editor.correctIndex.clamp(0, 3)];
        final correctAnswer = editor
            .optionControllers[editor.correctIndex.clamp(0, 3)]
            .text
            .trim();
        buffer
          ..writeln('<div class="answer-card">')
          ..writeln(
            '<p class="answer-inline"><strong>Correct Answer:</strong> ${_escapeHtml('$correctLabel) $correctAnswer')}</p>',
          );
        final explanation = editor.explanationController.text.trim();
        if (explanation.isNotEmpty) {
          buffer
            ..writeln('<div class="field-label">Explanation</div>')
            ..writeln(_buildRichTextHtml(explanation));
        }
        buffer.writeln('</div>');
      }

      buffer.writeln('</article>');
    }

    buffer.writeln('</section>');
    return buffer.toString();
  }

  String _buildEssayBuilderDraftHtml({
    required bool includeAnswers,
    required String audienceLabel,
  }) {
    final draft = _draftMission?.essayBuilderDraft;
    if (draft == null) {
      return '<section class="section-card"><h2>Essay Builder</h2><p class="section-kicker">Essay builder draft is missing.</p></section>';
    }

    final buffer = StringBuffer()
      ..writeln('<section class="section-card">')
      ..writeln('<h2>Essay Builder</h2>')
      ..writeln(
        '<p class="section-kicker">${_escapeHtml(includeAnswers ? 'Teacher-ready essay builder with answer keys for each blank.' : 'Student-ready essay builder worksheet without answer keys.')}</p>',
      )
      ..writeln('<div class="pill-row">')
      ..writeln(
        '<span class="soft-pill">Mode: ${_escapeHtml(draft.mode)}</span>',
      )
      ..writeln(
        '<span class="soft-pill">Target Words: ${_escapeHtml('${draft.targets.targetWordMin}-${draft.targets.targetWordMax}')}</span>',
      )
      ..writeln(
        '<span class="soft-pill">Target Sentences: ${_escapeHtml('${draft.targets.targetSentenceCount}')}</span>',
      )
      ..writeln(
        '<span class="soft-pill">Target Blanks: ${_escapeHtml('${draft.targets.targetBlankCount}')}</span>',
      )
      ..writeln('</div>');

    for (
      var sentenceIndex = 0;
      sentenceIndex < draft.sentences.length;
      sentenceIndex += 1
    ) {
      final sentence = draft.sentences[sentenceIndex];
      buffer
        ..writeln('<article class="question-card">')
        ..writeln('<div class="question-top">')
        ..writeln(
          '<span class="question-pill">Sentence ${sentenceIndex + 1}</span><span class="copy-pill">${_escapeHtml(audienceLabel)}</span>',
        )
        ..writeln('</div>')
        ..writeln(
          '<h3 class="sentence-role">${_escapeHtml(sentence.role)}</h3>',
        )
        ..writeln('<div class="field-label">Learn First</div>')
        ..writeln('<ul class="bullet-list">');

      for (final bullet in sentence.learnFirst.bullets) {
        final trimmedBullet = bullet.trim();
        if (trimmedBullet.isEmpty) {
          continue;
        }
        buffer.writeln('<li>${_escapeHtml(trimmedBullet)}</li>');
      }

      buffer
        ..writeln('</ul>')
        ..writeln('<div class="field-label">Sentence Preview</div>')
        ..writeln(
          '<p class="sentence-preview">${_escapeHtml(_sentencePreviewText(sentence))}</p>',
        );

      final blankParts = sentence.parts
          .where((part) => part.isBlank)
          .toList(growable: false);
      for (
        var blankIndex = 0;
        blankIndex < blankParts.length;
        blankIndex += 1
      ) {
        final part = blankParts[blankIndex];
        buffer
          ..writeln('<div class="blank-card">')
          ..writeln('<div class="blank-head">Blank ${blankIndex + 1}</div>');
        if (part.hint.trim().isNotEmpty) {
          buffer.writeln(
            '<p class="blank-hint">${_escapeHtml(part.hint.trim())}</p>',
          );
        }
        buffer.writeln('<ul class="option-list">');
        for (final label in const ['A', 'B', 'C', 'D']) {
          final isCorrect = includeAnswers && part.correctOption == label;
          buffer.writeln(
            '<li class="option-row ${isCorrect ? 'correct-option' : ''}"><span class="option-badge">$label</span><span>${_escapeHtml(part.options[label] ?? '')}</span></li>',
          );
        }
        buffer.writeln('</ul>');
        if (includeAnswers) {
          buffer.writeln(
            '<p class="answer-inline"><strong>Correct Answer:</strong> ${_escapeHtml('${part.correctOption}) ${part.options[part.correctOption] ?? ''}')}</p>',
          );
        }
        buffer.writeln('</div>');
      }

      buffer.writeln('</article>');
    }

    buffer.writeln('</section>');
    return buffer.toString();
  }

  String _buildDraftExportStyles() {
    return '''
      :root {
        color-scheme: light;
      }
      * {
        box-sizing: border-box;
      }
      body {
        margin: 0;
        font-family: "Avenir Next", "Segoe UI", Arial, sans-serif;
        background: linear-gradient(180deg, #f6fbff 0%, #eef4ff 52%, #f9f4ea 100%);
        color: #263854;
      }
      .page {
        max-width: 980px;
        margin: 0 auto;
        padding: 32px 20px 48px;
      }
      .hero,
      .section-card {
        background: rgba(255, 252, 246, 0.94);
        border: 1px solid #e8decb;
        border-radius: 28px;
        box-shadow: 0 18px 40px rgba(83, 108, 152, 0.12);
      }
      .hero {
        padding: 30px;
        margin-bottom: 18px;
      }
      .hero h1,
      .section-card h2,
      .section-card h3,
      .section-card h4 {
        margin: 0;
        color: #23334d;
      }
      .hero-summary,
      .section-kicker,
      .meta-label,
      .blank-hint {
        color: #6b7691;
      }
      .hero-summary,
      .section-kicker,
      .answer-inline,
      .sentence-preview,
      p,
      li {
        font-size: 16px;
        line-height: 1.65;
      }
      .copy-chip,
      .question-pill,
      .copy-pill,
      .soft-pill {
        display: inline-flex;
        align-items: center;
        border-radius: 999px;
        font-weight: 700;
      }
      .copy-chip {
        padding: 8px 14px;
        background: linear-gradient(135deg, #7fddeb, #6b8cff);
        color: white;
        margin-bottom: 14px;
      }
      .meta-grid {
        display: grid;
        grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
        gap: 12px;
        margin-top: 22px;
      }
      .meta-card {
        background: #fffdfa;
        border: 1px solid #ece2d2;
        border-radius: 18px;
        padding: 14px 16px;
      }
      .meta-label {
        display: block;
        font-size: 12px;
        font-weight: 700;
        letter-spacing: 0.08em;
        text-transform: uppercase;
        margin-bottom: 8px;
      }
      .meta-value {
        font-size: 17px;
        color: #243650;
      }
      .section-card {
        padding: 24px;
        margin-bottom: 18px;
      }
      .notice-card.teacher-note {
        background: linear-gradient(135deg, #eef5ff, #f5fbff);
      }
      .notice-card.student-note {
        background: linear-gradient(135deg, #fff8e8, #fffdf4);
      }
      .question-card {
        background: #fffefb;
        border: 1px solid #ede3d1;
        border-radius: 22px;
        padding: 22px;
        margin-top: 16px;
      }
      .question-top,
      .pill-row {
        display: flex;
        flex-wrap: wrap;
        gap: 10px;
        align-items: center;
      }
      .question-pill {
        padding: 7px 12px;
        background: #eaf3ff;
        color: #36507d;
      }
      .copy-pill {
        padding: 7px 12px;
        background: #fff4d5;
        color: #8d6418;
      }
      .field-label {
        margin-top: 18px;
        margin-bottom: 10px;
        font-size: 13px;
        font-weight: 800;
        letter-spacing: 0.08em;
        text-transform: uppercase;
        color: #6a7287;
      }
      .option-list,
      .bullet-list {
        margin: 0;
        padding: 0;
        list-style: none;
      }
      .bullet-list li {
        position: relative;
        padding-left: 20px;
        margin-bottom: 10px;
      }
      .bullet-list li::before {
        content: "•";
        position: absolute;
        left: 0;
        color: #5b7fd8;
      }
      .option-row,
      .blank-card {
        border: 1px solid #ece3d2;
        border-radius: 16px;
        background: #fffdfa;
      }
      .option-row {
        display: flex;
        gap: 12px;
        align-items: flex-start;
        padding: 12px 14px;
        margin-bottom: 10px;
      }
      .option-row.correct-option {
        background: #eef9ea;
        border-color: #b7ddb1;
      }
      .option-badge {
        min-width: 30px;
        height: 30px;
        display: inline-flex;
        align-items: center;
        justify-content: center;
        border-radius: 999px;
        background: #eaf1ff;
        color: #36507d;
        font-weight: 800;
      }
      .answer-card,
      .blank-card {
        margin-top: 16px;
        padding: 16px;
      }
      .answer-card {
        background: #f2f7ff;
        border-left: 4px solid #7d9cff;
      }
      .answer-inline {
        margin: 0;
      }
      .soft-pill {
        padding: 8px 12px;
        background: #f2eee1;
        color: #5b6580;
      }
      .sentence-role {
        margin-top: 14px !important;
        font-size: 22px;
      }
      .sentence-preview {
        margin: 0;
        padding: 14px 16px;
        border-radius: 16px;
        background: #f7fbff;
        border: 1px dashed #c7d8f4;
        color: #314764;
      }
      .blank-head {
        font-size: 18px;
        font-weight: 800;
        color: #243650;
        margin-bottom: 10px;
      }
      .blank-hint {
        margin-top: 0;
        margin-bottom: 12px;
      }
      .footer-card {
        margin-bottom: 0;
      }
      hr {
        border: 0;
        border-top: 1px solid #ebdfca;
        margin: 16px 0;
      }
      @media print {
        body {
          background: white;
        }
        .page {
          max-width: none;
          padding: 0;
        }
        .hero,
        .section-card,
        .question-card,
        .blank-card,
        .option-row {
          box-shadow: none;
        }
      }
    ''';
  }

  String _buildRichTextHtml(String value) {
    final normalized = value
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .trim();
    if (normalized.isEmpty) {
      return '<p class="section-kicker">Not added yet.</p>';
    }

    final buffer = StringBuffer();
    final paragraphLines = <String>[];
    var inList = false;

    void flushParagraph() {
      if (paragraphLines.isEmpty) {
        return;
      }
      buffer.writeln('<p>${_buildInlineHtml(paragraphLines.join(' '))}</p>');
      paragraphLines.clear();
    }

    void closeList() {
      if (!inList) {
        return;
      }
      buffer.writeln('</ul>');
      inList = false;
    }

    for (final rawLine in normalized.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        flushParagraph();
        closeList();
        continue;
      }

      if (line == '---') {
        flushParagraph();
        closeList();
        buffer.writeln('<hr />');
        continue;
      }

      final headingMatch = RegExp(r'^(#{1,3})\s+(.+)$').firstMatch(line);
      if (headingMatch != null) {
        flushParagraph();
        closeList();
        final level = headingMatch.group(1)!.length + 1;
        final heading = headingMatch.group(2)!.trim();
        buffer.writeln('<h$level>${_buildInlineHtml(heading)}</h$level>');
        continue;
      }

      final bulletMatch = RegExp(r'^[-*]\s+(.+)$').firstMatch(line);
      if (bulletMatch != null) {
        flushParagraph();
        if (!inList) {
          buffer.writeln('<ul class="bullet-list">');
          inList = true;
        }
        buffer.writeln(
          '<li>${_buildInlineHtml(bulletMatch.group(1)!.trim())}</li>',
        );
        continue;
      }

      closeList();
      paragraphLines.add(line);
    }

    flushParagraph();
    closeList();
    return buffer.toString();
  }

  String _buildInlineHtml(String value) {
    final escaped = _escapeHtml(value);
    return escaped.replaceAllMapped(
      RegExp(r'\*\*(.+?)\*\*'),
      (match) => '<strong>${match.group(1)}</strong>',
    );
  }

  String _escapeHtml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  String _sentencePreviewText(EssayBuilderSentence sentence) {
    return sentence.parts
        .map((part) => part.isBlank ? '____' : part.value)
        .join();
  }

  String _sanitizeFileNameSegment(String value) {
    final normalized = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    return normalized.isEmpty ? 'draft' : normalized;
  }

  String? _validateDraftQuestions() {
    if (_draftFormat == 'ESSAY_BUILDER') {
      final draft = _draftMission?.essayBuilderDraft;
      if (draft == null) {
        return 'Essay draft JSON is missing. Regenerate before saving.';
      }

      if (draft.sentences.isEmpty) {
        return 'Essay draft needs at least one sentence before saving.';
      }

      for (
        var sentenceIndex = 0;
        sentenceIndex < draft.sentences.length;
        sentenceIndex += 1
      ) {
        final sentence = draft.sentences[sentenceIndex];
        final learnFirstBullets = sentence.learnFirst.bullets
            .map((bullet) => bullet.trim())
            .where((bullet) => bullet.isNotEmpty)
            .toList(growable: false);

        if (learnFirstBullets.length < 3) {
          return 'Sentence ${sentenceIndex + 1} needs at least 3 Learn First bullets.';
        }

        final blankParts = sentence.parts
            .where((part) => part.isBlank)
            .toList(growable: false);
        if (blankParts.isEmpty) {
          return 'Sentence ${sentenceIndex + 1} must include at least one blank.';
        }

        for (
          var blankIndex = 0;
          blankIndex < blankParts.length;
          blankIndex += 1
        ) {
          final blank = blankParts[blankIndex];
          for (final label in const ['A', 'B', 'C', 'D']) {
            if ((blank.options[label] ?? '').trim().isEmpty) {
              return 'Sentence ${sentenceIndex + 1} blank ${blankIndex + 1} needs a non-empty option $label.';
            }
          }
          if (!const ['A', 'B', 'C', 'D'].contains(blank.correctOption)) {
            return 'Sentence ${sentenceIndex + 1} blank ${blankIndex + 1} has an invalid correct answer.';
          }
        }
      }

      return null;
    }

    if (_questionEditors.isEmpty) {
      return 'The draft needs at least one question before it can be saved.';
    }

    if (_draftFormat == 'THEORY' &&
        (_questionEditors.length < _theoryQuestionCountMin ||
            _questionEditors.length > _theoryQuestionCountMax)) {
      return 'Theory drafts must include between 2 and 5 questions.';
    }

    if (_draftFormat == 'QUESTIONS' &&
        !const [5, 8, 10].contains(_questionEditors.length)) {
      return 'Question drafts must include 5, 8, or 10 questions.';
    }

    for (var index = 0; index < _questionEditors.length; index += 1) {
      final question = _questionEditors[index];
      final learnFirstReviewError = question.learnFirstReviewError(
        questionNumber: index + 1,
      );
      if (learnFirstReviewError != null) {
        // WHY: Once a teacher changes Learn First, the linked prompt and answer
        // content must also be reviewed so the mission stays instructionally
        // aligned instead of mixing old questions with new teaching text.
        return learnFirstReviewError;
      }

      if (question.promptController.text.trim().isEmpty) {
        return 'Question ${index + 1} needs a prompt.';
      }

      if (question.learningTextController.text.trim().isEmpty) {
        return 'Question ${index + 1} needs a short teaching note before the question.';
      }

      if (_draftFormat == 'THEORY') {
        if (question.expectedAnswerController.text.trim().isEmpty) {
          return 'Theory question ${index + 1} needs an expected answer.';
        }

        final minWordCount = int.tryParse(
          question.minWordCountController.text.trim(),
        );
        if (minWordCount == null || minWordCount < 1 || minWordCount > 500) {
          return 'Theory question ${index + 1} needs a minimum word count between 1 and 500.';
        }
        continue;
      }

      if (question.optionControllers.any(
        (controller) => controller.text.trim().isEmpty,
      )) {
        return 'Question ${index + 1} needs four answer options.';
      }
    }

    return null;
  }

  void _addTheoryQuestion() {
    if (_questionEditors.length >= _theoryQuestionCountMax) {
      return;
    }

    setState(() {
      // WHY: Theory stays intentionally short, so add-question is capped to the
      // fixed 2 to 5 range even after the draft has been generated.
      _questionEditors = [
        ..._questionEditors,
        _EditableQuestionController.emptyTheory(),
      ];
      _questionCount = _questionEditors.length;
    });
  }

  void _removeTheoryQuestion(int index) {
    if (_questionEditors.length <= _theoryQuestionCountMin) {
      return;
    }

    final nextEditors = [..._questionEditors];
    final removed = nextEditors.removeAt(index);
    removed.dispose();

    setState(() {
      _questionEditors = nextEditors;
      _questionCount = _questionEditors.length;
    });
  }

  Future<void> _openEssayLearnFirstEditor({
    required int sentenceIndex,
    required EssayBuilderSentence sentence,
  }) async {
    final titleController = TextEditingController(
      text: sentence.learnFirst.title.trim().isEmpty
          ? 'LEARN FIRST'
          : sentence.learnFirst.title,
    );
    final initialBullets = sentence.learnFirst.bullets;
    final bulletFieldCount = initialBullets.length >= 3
        ? initialBullets.length
        : 3;
    final bulletControllers = List.generate(
      bulletFieldCount,
      (index) => TextEditingController(
        text: index < initialBullets.length ? initialBullets[index] : '',
      ),
      growable: false,
    );

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Edit Learn First · Sentence ${sentenceIndex + 1}'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 12),
                ...List.generate(
                  bulletControllers.length,
                  (index) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TextField(
                      controller: bulletControllers[index],
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Bullet ${index + 1}',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    // WHY: Draft edits should only apply when the teacher explicitly confirms.
    if (shouldSave != true) {
      titleController.dispose();
      for (final controller in bulletControllers) {
        controller.dispose();
      }
      return;
    }

    final bullets = bulletControllers
        .map((controller) => controller.text.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    if (bullets.length < 3) {
      setState(() {
        _errorMessage =
            'Sentence ${sentenceIndex + 1} Learn First needs at least 3 bullet points.';
      });
      titleController.dispose();
      for (final controller in bulletControllers) {
        controller.dispose();
      }
      return;
    }

    final draftCopy = _cloneEssayDraftJson();
    if (draftCopy == null) {
      titleController.dispose();
      for (final controller in bulletControllers) {
        controller.dispose();
      }
      return;
    }
    final sentenceMap = _essaySentenceMapAt(
      draftJson: draftCopy,
      sentenceIndex: sentenceIndex,
    );
    if (sentenceMap == null) {
      titleController.dispose();
      for (final controller in bulletControllers) {
        controller.dispose();
      }
      return;
    }

    sentenceMap['learnFirst'] = <String, dynamic>{
      'title': titleController.text.trim().isEmpty
          ? 'LEARN FIRST'
          : titleController.text.trim(),
      'bullets': bullets,
    };
    _applyEssayDraftJsonUpdate(draftCopy);

    titleController.dispose();
    for (final controller in bulletControllers) {
      controller.dispose();
    }
  }

  Future<void> _openEssaySentenceTextEditor({
    required int sentenceIndex,
    required EssayBuilderSentence sentence,
  }) async {
    final textPartIndexes = <int>[];
    final textControllers = <TextEditingController>[];
    for (var partIndex = 0; partIndex < sentence.parts.length; partIndex += 1) {
      final part = sentence.parts[partIndex];
      if (!part.isBlank) {
        textPartIndexes.add(partIndex);
        textControllers.add(TextEditingController(text: part.value));
      }
    }

    if (textPartIndexes.isEmpty) {
      setState(() {
        _errorMessage =
            'Sentence ${sentenceIndex + 1} has no editable text segments.';
      });
      return;
    }

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Edit Sentence Text · Sentence ${sentenceIndex + 1}'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(
                textControllers.length,
                (index) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TextField(
                    controller: textControllers[index],
                    minLines: 1,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Text segment ${index + 1}',
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (shouldSave != true) {
      for (final controller in textControllers) {
        controller.dispose();
      }
      return;
    }

    if (textControllers.any((controller) => controller.text.trim().isEmpty)) {
      setState(() {
        _errorMessage =
            'Sentence ${sentenceIndex + 1} text segments cannot be empty.';
      });
      for (final controller in textControllers) {
        controller.dispose();
      }
      return;
    }

    final draftCopy = _cloneEssayDraftJson();
    if (draftCopy == null) {
      for (final controller in textControllers) {
        controller.dispose();
      }
      return;
    }
    final sentenceMap = _essaySentenceMapAt(
      draftJson: draftCopy,
      sentenceIndex: sentenceIndex,
    );
    if (sentenceMap == null) {
      for (final controller in textControllers) {
        controller.dispose();
      }
      return;
    }

    final parts = _listValue(sentenceMap['parts']);
    if (parts == null) {
      for (final controller in textControllers) {
        controller.dispose();
      }
      return;
    }
    for (var index = 0; index < textPartIndexes.length; index += 1) {
      final partMap = _mapValue(parts[textPartIndexes[index]]);
      if (partMap == null) {
        continue;
      }
      partMap['value'] = textControllers[index].text;
      parts[textPartIndexes[index]] = partMap;
    }
    sentenceMap['parts'] = parts;
    _applyEssayDraftJsonUpdate(draftCopy);

    for (final controller in textControllers) {
      controller.dispose();
    }
  }

  Future<void> _openEssayBlankEditor({
    required int sentenceIndex,
    required int partIndex,
    required EssayBuilderPart part,
  }) async {
    final hintController = TextEditingController(text: part.hint);
    final optionControllers = <String, TextEditingController>{
      'A': TextEditingController(text: part.options['A'] ?? ''),
      'B': TextEditingController(text: part.options['B'] ?? ''),
      'C': TextEditingController(text: part.options['C'] ?? ''),
      'D': TextEditingController(text: part.options['D'] ?? ''),
    };
    var selectedCorrectOption = part.correctOption;

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: Text('Edit Blank · Sentence ${sentenceIndex + 1}'),
            content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: hintController,
                      decoration: const InputDecoration(labelText: 'Hint'),
                    ),
                    const SizedBox(height: 12),
                    ...const ['A', 'B', 'C', 'D'].map(
                      (label) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: TextField(
                          controller: optionControllers[label],
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: 'Option $label',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Correct answer',
                      style: Theme.of(dialogContext).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: List.generate(4, (index) {
                        const labels = ['A', 'B', 'C', 'D'];
                        final label = labels[index];
                        return _CorrectOptionChip(
                          label: label,
                          selected: selectedCorrectOption == label,
                          onTap: () {
                            setDialogState(() {
                              selectedCorrectOption = label;
                            });
                          },
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );

    if (shouldSave != true) {
      hintController.dispose();
      for (final controller in optionControllers.values) {
        controller.dispose();
      }
      return;
    }

    final hasEmptyOption = const [
      'A',
      'B',
      'C',
      'D',
    ].any((label) => optionControllers[label]!.text.trim().isEmpty);
    if (hasEmptyOption) {
      setState(() {
        _errorMessage =
            'Sentence ${sentenceIndex + 1} options A/B/C/D must all be filled.';
      });
      hintController.dispose();
      for (final controller in optionControllers.values) {
        controller.dispose();
      }
      return;
    }

    final draftCopy = _cloneEssayDraftJson();
    if (draftCopy == null) {
      hintController.dispose();
      for (final controller in optionControllers.values) {
        controller.dispose();
      }
      return;
    }
    final sentenceMap = _essaySentenceMapAt(
      draftJson: draftCopy,
      sentenceIndex: sentenceIndex,
    );
    if (sentenceMap == null) {
      hintController.dispose();
      for (final controller in optionControllers.values) {
        controller.dispose();
      }
      return;
    }
    final parts = _listValue(sentenceMap['parts']);
    if (parts == null || partIndex < 0 || partIndex >= parts.length) {
      hintController.dispose();
      for (final controller in optionControllers.values) {
        controller.dispose();
      }
      return;
    }

    final partMap = _mapValue(parts[partIndex]);
    if (partMap == null) {
      hintController.dispose();
      for (final controller in optionControllers.values) {
        controller.dispose();
      }
      return;
    }
    partMap['hint'] = hintController.text.trim();
    partMap['options'] = <String, dynamic>{
      'A': optionControllers['A']!.text.trim(),
      'B': optionControllers['B']!.text.trim(),
      'C': optionControllers['C']!.text.trim(),
      'D': optionControllers['D']!.text.trim(),
    };
    partMap['correctOption'] = selectedCorrectOption;
    parts[partIndex] = partMap;
    sentenceMap['parts'] = parts;
    _applyEssayDraftJsonUpdate(draftCopy);

    hintController.dispose();
    for (final controller in optionControllers.values) {
      controller.dispose();
    }
  }

  void _applyEssayDraftJsonUpdate(Map<String, dynamic> draftJson) {
    if (_draftMission == null) {
      return;
    }

    final sentenceCount =
        (_listValue(draftJson['sentences']) ?? const []).length;
    setState(() {
      // WHY: Saving edits back into draftJson keeps teacher-reviewed answers and
      // sentence wording as the single source of truth for publish.
      _draftMission = _draftMission!.copyWith(
        draftJson: draftJson,
        questionCount: sentenceCount > 0
            ? sentenceCount
            : _draftMission!.questionCount,
      );
      _errorMessage = null;
    });
  }

  Map<String, dynamic>? _cloneEssayDraftJson() {
    final draftJson = _draftMission?.draftJson;
    if (draftJson == null) {
      setState(() {
        _errorMessage =
            'Essay draft JSON is missing. Regenerate this draft first.';
      });
      return null;
    }
    return _deepCloneMap(draftJson);
  }

  Map<String, dynamic>? _essaySentenceMapAt({
    required Map<String, dynamic> draftJson,
    required int sentenceIndex,
  }) {
    final sentences = _listValue(draftJson['sentences']);
    if (sentences == null ||
        sentenceIndex < 0 ||
        sentenceIndex >= sentences.length) {
      setState(() {
        _errorMessage =
            'Could not find sentence ${sentenceIndex + 1} in this essay draft.';
      });
      return null;
    }
    final sentenceMap = _mapValue(sentences[sentenceIndex]);
    if (sentenceMap == null) {
      setState(() {
        _errorMessage = 'Sentence ${sentenceIndex + 1} data is malformed.';
      });
      return null;
    }
    sentences[sentenceIndex] = sentenceMap;
    draftJson['sentences'] = sentences;
    return sentenceMap;
  }

  Map<String, dynamic> _deepCloneMap(Map<String, dynamic> source) {
    final clone = <String, dynamic>{};
    source.forEach((key, value) {
      clone[key] = _deepCloneValue(value);
    });
    return clone;
  }

  dynamic _deepCloneValue(dynamic value) {
    if (value is Map<dynamic, dynamic>) {
      final next = <String, dynamic>{};
      value.forEach((key, nestedValue) {
        next[key.toString()] = _deepCloneValue(nestedValue);
      });
      return next;
    }
    if (value is List<dynamic>) {
      return value.map(_deepCloneValue).toList(growable: true);
    }
    return value;
  }

  Map<String, dynamic>? _mapValue(dynamic value) {
    if (value is Map<dynamic, dynamic>) {
      return value.cast<String, dynamic>();
    }
    return null;
  }

  List<dynamic>? _listValue(dynamic value) {
    if (value is List<dynamic>) {
      return [...value];
    }
    return null;
  }

  Future<void> _pickAndExtractSource(_SourceUploadMode mode) async {
    try {
      final hadDraftBeforeUpload = _draftMission != null;
      final result = await FilePicker.platform.pickFiles(
        withData: true,
        type: FileType.custom,
        allowedExtensions: const [
          'pdf',
          'docx',
          'txt',
          'png',
          'jpg',
          'jpeg',
          'webp',
          'bmp',
        ],
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final file = result.files.single;
      final bytes = file.bytes;

      if (bytes == null || bytes.isEmpty) {
        throw Exception(
          'The selected file could not be read. Try another file or upload it again.',
        );
      }

      setState(() {
        _isExtractingSource = true;
        _activeSourceUploadMode = mode;
        _errorMessage = null;
        _sourceUploadReadiness = null;
      });

      final extracted = await widget.api.uploadTeacherSourceDraft(
        token: widget.session.token,
        subjectId: widget.subject.id,
        studentId: widget.student.id,
        sessionType: _selectedSessionType,
        targetDate: _dateKey(_resolvedTargetDate),
        fileBytes: bytes,
        fileName: file.name,
        uploadMode: mode == _SourceUploadMode.populateDraft
            ? 'populate_draft'
            : 'ai_draft',
        title: _titleController.text.trim(),
        draftFormat: _draftFormat,
        essayMode: _draftFormat == 'ESSAY_BUILDER' ? _essayMode : '',
        difficulty: _effectiveDifficulty,
        questionCount: _questionCount,
        taskCodes: _selectedTaskCodes,
        missionDraftId: _draftMission?.id ?? '',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _uploadedSource = extracted;
        _sourceUploadReadiness = extracted.draftReadiness;
        _selectedSourceFileName = extracted.fileName;
        _selectedSourceFileType = extracted.mimeType;
        _rawUploadedSourceText = extracted.extractedText;
        final hasAppliedTaskScope = mode == _SourceUploadMode.aiDraft
            ? _applyTaskFocusedUnitTextFromSource(_selectedTaskCodes)
            : false;
        final uploadedPrefilledMission = extracted.prefilledMission;
        final prefilledMission =
            uploadedPrefilledMission != null &&
                uploadedPrefilledMission.id.isEmpty &&
                _draftMission != null
            ? _draftMission!.copyWith(
                title: uploadedPrefilledMission.title,
                teacherNote: uploadedPrefilledMission.teacherNote,
                sourceUnitText: uploadedPrefilledMission.sourceUnitText,
                sourceRawText: uploadedPrefilledMission.sourceRawText,
                sourceFileName: uploadedPrefilledMission.sourceFileName,
                sourceFileType: uploadedPrefilledMission.sourceFileType,
                draftFormat: uploadedPrefilledMission.draftFormat,
                essayMode: uploadedPrefilledMission.essayMode,
                draftJson: uploadedPrefilledMission.draftJson,
                source: uploadedPrefilledMission.source,
                status: uploadedPrefilledMission.status,
                sessionType: uploadedPrefilledMission.sessionType,
                difficulty: uploadedPrefilledMission.difficulty,
                taskCodes: uploadedPrefilledMission.taskCodes,
                xpReward: uploadedPrefilledMission.xpReward,
                questionCount: uploadedPrefilledMission.questionCount,
                aiModel: uploadedPrefilledMission.aiModel,
                availableOnDate: uploadedPrefilledMission.availableOnDate,
                availableOnDay: uploadedPrefilledMission.availableOnDay,
                subject: uploadedPrefilledMission.subject,
                questions: uploadedPrefilledMission.questions,
              )
            : uploadedPrefilledMission;

        if (mode == _SourceUploadMode.populateDraft &&
            prefilledMission != null) {
          // WHY: When the uploaded PDF already contains enough source material,
          // the sheet should drop the teacher straight into review instead of
          // forcing a second generate click.
          _applyDraft(prefilledMission);
          _createdDraftThisSession = true;
        } else {
          if (mode == _SourceUploadMode.aiDraft && !hasAppliedTaskScope) {
            _unitTextController.text = extracted.extractedText;
          }

          // WHY: The upload flow should save the teacher time by prefilling the
          // draft suggestion fields before any mission is generated.
          if (!_hasDraft && mode == _SourceUploadMode.aiDraft) {
            _titleController.text = extracted.unitPlan.suggestedMissionTitle;
            _teacherNoteController.text =
                extracted.unitPlan.suggestedTeacherNote;
            _questionCount = _normalizedQuestionCountForDraftFormat(
              extracted.unitPlan.suggestedQuestionCount,
            );
            _applyAssessmentModeDefaultsIfNeeded();
          }
        }

        _errorMessage =
            extracted.draftReadiness.needsAttention &&
                (mode != _SourceUploadMode.populateDraft ||
                    prefilledMission == null)
            ? extracted.draftReadiness.summary
            : null;
      });

      final canDraftWithAi =
          !_isTargetDateInPast && _unitTextController.text.trim().length >= 80;
      if (mode == _SourceUploadMode.aiDraft && canDraftWithAi) {
        // WHY: The AI-draft upload path should feel like one action: upload
        // once, then let Groq draft from the extracted lesson text immediately.
        if (hadDraftBeforeUpload) {
          await _regenerateDraftWithCurrentSelection(
            showTaskFocusRefreshHint: false,
          );
        } else {
          await _generateDraft();
        }
        return;
      }

      if (mode == _SourceUploadMode.aiDraft && !canDraftWithAi && mounted) {
        setState(() {
          _errorMessage =
              'The upload was saved, but there is not enough lesson text yet for Groq to draft from it. Add more source detail or use Populate draft from PDF if the file already contains the questions.';
        });
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _sourceUploadReadiness = null;
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isExtractingSource = false;
          _activeSourceUploadMode = null;
        });
      }
    }
  }

  Future<void> _reextractSourceForDraft() async {
    if (_draftMission == null) {
      return;
    }

    setState(() {
      _isReextractingSource = true;
      _errorMessage = null;
    });

    try {
      final mission = await widget.api.reextractTeacherMissionSource(
        token: widget.session.token,
        missionId: _draftMission!.id,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _applyDraft(mission);
        _errorMessage =
            'Source text recovered for this draft. You can now use Show full raw upload text.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _isReextractingSource = false);
      }
    }
  }

  void _applyDraft(MissionPayload mission) {
    for (final editor in _questionEditors) {
      editor.dispose();
    }

    _draftMission = mission;
    _selectedSessionType = mission.sessionType.isEmpty
        ? _selectedSessionType
        : mission.sessionType;
    final parsedAvailableDate = DateTime.tryParse(
      mission.availableOnDate ?? '',
    );
    if (parsedAvailableDate != null) {
      _selectedTargetDate = _dateOnly(parsedAvailableDate);
    }
    _titleController.text = mission.title;
    _teacherNoteController.text = mission.teacherNote;
    _unitTextController.text = mission.sourceUnitText;
    _rawUploadedSourceText = mission.sourceRawText.trim();
    _selectedSourceFileName = mission.sourceFileName;
    _selectedSourceFileType = mission.sourceFileType;
    _difficulty = mission.difficulty.isEmpty ? 'medium' : mission.difficulty;
    _draftFormat = mission.draftFormat.isEmpty
        ? 'QUESTIONS'
        : mission.draftFormat;
    _essayMode = mission.essayMode.trim().isNotEmpty
        ? mission.essayMode.trim().toUpperCase()
        : (mission.essayBuilderDraft?.mode.trim().isNotEmpty == true
              ? mission.essayBuilderDraft!.mode.trim().toUpperCase()
              : 'NORMAL');
    _selectedTaskCodes = mission.taskCodes
        .map((code) => code.trim().toUpperCase())
        .where((code) => code.isNotEmpty)
        .toSet()
        .toList(growable: false);
    _questionCount = mission.draftFormat == 'ESSAY_BUILDER'
        ? (mission.questionCount > 0 ? mission.questionCount : 10)
        : _normalizedQuestionCountForDraftFormat(
            mission.questions.isEmpty
                ? (mission.questionCount > 0
                      ? mission.questionCount
                      : _questionCount)
                : mission.questions.length,
            draftFormat: _draftFormat,
          );
    _applyAssessmentModeDefaultsIfNeeded();
    _questionEditors = mission.questions
        .map(_EditableQuestionController.fromMissionQuestion)
        .toList(growable: false);
  }

  int _normalizedQuestionCountForDraftFormat(
    int questionCount, {
    String? draftFormat,
  }) {
    final format = (draftFormat ?? _draftFormat).trim().toUpperCase();

    if (format == 'THEORY') {
      if (questionCount <= 0) {
        return _theoryQuestionCountMin;
      }
      final clamped = questionCount.clamp(
        _theoryQuestionCountMin,
        _theoryQuestionCountMax,
      );
      return clamped.toInt();
    }

    if (format == 'QUESTIONS') {
      return const [5, 8, 10].contains(questionCount) ? questionCount : 5;
    }

    return questionCount > 0 ? questionCount : 5;
  }

  int _resolvedXpRewardFor({
    required String draftFormat,
    required int questionCount,
  }) {
    final normalizedDraftFormat = draftFormat.trim().toUpperCase();

    if (normalizedDraftFormat == 'THEORY') {
      return _theoryXpReward;
    }

    if (normalizedDraftFormat == 'ESSAY_BUILDER') {
      return _essayXpReward;
    }

    return questionCount >= _assessmentQuestionCount
        ? _assessmentXpReward
        : _objectiveXpReward;
  }

  void _setDraftFormat(String draftFormat) {
    final normalized = draftFormat.trim().toUpperCase();

    setState(() {
      _draftFormat = normalized;
      _questionCount = _normalizedQuestionCountForDraftFormat(
        _questionCount,
        draftFormat: normalized,
      );
      _applyAssessmentModeDefaultsIfNeeded();
    });
  }

  void _applyAssessmentModeDefaultsIfNeeded() {
    if (_draftFormat == 'ESSAY_BUILDER' || _draftFormat == 'THEORY') {
      return;
    }

    if (_questionCount != _assessmentQuestionCount) {
      return;
    }

    // WHY: Assessment mode must stay standardized so difficulty and reward
    // remain consistent across teacher drafts and publishing.
    _difficulty = 'hard';
    _draftFormat = 'QUESTIONS';
  }

  void _closeSheet() {
    if (_createdDraftThisSession && _draftMission != null) {
      Navigator.of(context).pop(_draftMission);
      return;
    }

    Navigator.of(context).pop();
  }

  DateTime get _resolvedTargetDate {
    return _selectedTargetDate;
  }

  String _dateKey(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  Future<void> _openMissionDatePicker() async {
    final strictOptions = _buildAvailableDateOptions(enforceTeacherId: true);
    final options = strictOptions.isNotEmpty
        ? strictOptions
        : _buildAvailableDateOptions(enforceTeacherId: false);

    if (options.isEmpty) {
      final picked = await showDatePicker(
        context: context,
        initialDate: _resolvedTargetDate,
        firstDate: _dateOnly(DateTime.now()),
        lastDate: _dateOnly(
          DateTime.now(),
        ).add(const Duration(days: _scheduleSearchWindowDays)),
      );

      if (!mounted || picked == null) {
        return;
      }

      setState(() {
        _selectedTargetDate = _dateOnly(picked);
        _errorMessage = null;
      });
      return;
    }

    final selected = await showModalBottomSheet<_ScheduleSlotOption>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: AppPalette.backgroundGradient,
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.screen),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choose Mission Date',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  'Only timetable slots for ${widget.subject.name} are listed.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppPalette.textMuted),
                ),
                const SizedBox(height: AppSpacing.item),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: options.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.compact),
                    itemBuilder: (context, index) {
                      final option = options[index];
                      final selectedNow =
                          _isSameDate(option.date, _resolvedTargetDate) &&
                          option.sessionType == _selectedSessionType;

                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusMd,
                          ),
                          onTap: () => Navigator.of(context).pop(option),
                          child: Ink(
                            padding: const EdgeInsets.all(AppSpacing.item),
                            decoration: BoxDecoration(
                              color: selectedNow
                                  ? AppPalette.sky.withValues(alpha: 0.45)
                                  : Colors.white.withValues(alpha: 0.78),
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radiusMd,
                              ),
                              border: selectedNow
                                  ? Border.all(
                                      color: AppPalette.navy,
                                      width: 1.3,
                                    )
                                  : null,
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.event_available_rounded,
                                  color: AppPalette.navy,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    '${_formatTargetDate(option.date)} · ${option.sessionLabel}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyLarge,
                                  ),
                                ),
                                if (selectedNow)
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: AppPalette.navy,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (!mounted || selected == null) {
      return;
    }

    setState(() {
      _selectedTargetDate = _dateOnly(selected.date);
      _selectedSessionType = selected.sessionType;
      _errorMessage = null;
    });
  }

  bool get _hasResolvedSource =>
      _resolvedSourceFileName.isNotEmpty || _resolvedSourceFileType.isNotEmpty;

  String get _taskSourcePreviewText {
    final sourceText = _rawUploadedSourceText;
    if (sourceText.trim().isEmpty) {
      return '';
    }

    if (_showFullRawUploadText || _selectedTaskCodes.isEmpty) {
      return sourceText.trim();
    }

    return _extractTaskScopedTextFromSource(
      sourceText: sourceText,
      taskCodes: _selectedTaskCodes,
    ).trim();
  }

  String get _unitTextForGroq {
    if (_rawUploadedSourceText.trim().isEmpty) {
      return _unitTextController.text.trim();
    }

    final candidate = _taskSourcePreviewText.trim();
    if (candidate.length < 80) {
      return _rawUploadedSourceText.trim();
    }

    return candidate;
  }

  void _syncUnitTextWithPreviewMode() {
    if (_rawUploadedSourceText.trim().isEmpty) {
      return;
    }

    final next = _taskSourcePreviewText.trim();
    if (next.isEmpty) {
      return;
    }

    _unitTextController.text = next;
  }

  String get _resolvedSourceFileName =>
      _uploadedSource?.fileName.isNotEmpty == true
      ? _uploadedSource!.fileName
      : _selectedSourceFileName.isNotEmpty
      ? _selectedSourceFileName
      : _draftMission?.sourceFileName ?? '';

  String get _resolvedSourceFileType =>
      _uploadedSource?.mimeType.isNotEmpty == true
      ? _uploadedSource!.mimeType
      : _selectedSourceFileType.isNotEmpty
      ? _selectedSourceFileType
      : _draftMission?.sourceFileType ?? '';

  String _formatTargetDate(DateTime date) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${weekdays[date.weekday - 1]} ${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  void _toggleTaskCode(String taskCode) {
    final updated = [..._selectedTaskCodes];

    if (updated.contains(taskCode)) {
      updated.remove(taskCode);
    } else {
      if (updated.length >= 8) {
        setState(() {
          _errorMessage =
              'You can select up to 8 task codes for one mission draft.';
        });
        return;
      }
      updated.add(taskCode);
    }

    setState(() {
      _selectedTaskCodes = updated;
      _errorMessage = null;
    });

    // WHY: When teachers choose a task code (for example P1/P2), the visible
    // draft should immediately reflect that task focus from the uploaded source.
    final appliedTaskSource = _applyTaskFocusedUnitTextFromSource(updated);
    _syncUnitTextWithPreviewMode();
    final canAutoRefreshDraft =
        _hasDraft &&
        !_isGenerating &&
        !_isTargetDateInPast &&
        _unitTextController.text.trim().length >= 80;

    if (canAutoRefreshDraft) {
      _regenerateDraftWithCurrentSelection(showTaskFocusRefreshHint: true);
      return;
    }

    if (appliedTaskSource && !_hasDraft) {
      setState(() {
        _errorMessage =
            'Task focus applied from the uploaded source. Generate draft to view the P-task questions.';
      });
      return;
    }

    if (!appliedTaskSource && _selectedTaskCodes.isNotEmpty) {
      setState(() {
        _errorMessage =
            'Upload the original source file first so task text is shown exactly from that file.';
      });
    }
  }

  Future<void> _openAssessmentModeScreen() async {
    final result = await Navigator.of(context)
        .push<AssessmentModeSelectionResult>(
          MaterialPageRoute(
            builder: (_) => AssessmentModeScreen(
              studentName: widget.student.name,
              subjectName: widget.subject.name,
              sessionType: _selectedSessionType,
              targetDateLabel: _formatTargetDate(_resolvedTargetDate),
              taskCodeOptions: _taskCodeOptions,
              initialTaskCodes: _selectedTaskCodes,
              timetableEntries: widget.timetableEntries,
              initialTargetDate: _resolvedTargetDate,
              currentTeacherId: widget.session.user.id,
              authToken: widget.session.token,
              subjectId: widget.subject.id,
              api: widget.api,
              lockedTaskCodes: widget.lockedAssessmentTaskCodes,
            ),
          ),
        );

    if (!mounted || result == null) {
      return;
    }

    setState(() {
      _questionCount = _assessmentQuestionCount;
      _selectedSessionType = result.sessionType;
      _selectedTargetDate = _dateOnly(result.targetDate);
      _difficulty = 'hard';
      _selectedTaskCodes = result.taskCodes;
      _errorMessage = null;
      if (result.sourceRawText.trim().isNotEmpty) {
        _uploadedSource = null;
        _rawUploadedSourceText = result.sourceRawText.trim();
        _selectedSourceFileName = result.sourceFileName.trim();
        _selectedSourceFileType = result.sourceFileType.trim();
        final scopedText = result.taskScopedSourceText.trim();
        if (scopedText.length >= 80) {
          _unitTextController.text = scopedText;
        } else {
          _unitTextController.text = _rawUploadedSourceText;
        }
      }
    });

    // WHY: Applying assessment selection should immediately keep visible unit
    // text aligned with chosen task focus and refresh generated drafts when safe.
    final appliedTaskSource = _applyTaskFocusedUnitTextFromSource(
      _selectedTaskCodes,
    );
    final canAutoRefreshDraft =
        _hasDraft &&
        !_isGenerating &&
        !_isTargetDateInPast &&
        _unitTextController.text.trim().length >= 80;
    final canAutoGenerateDraft =
        !_hasDraft &&
        !_isGenerating &&
        !_isTargetDateInPast &&
        _unitTextController.text.trim().length >= 80;

    if (canAutoRefreshDraft) {
      await _regenerateDraftWithCurrentSelection(
        showTaskFocusRefreshHint: true,
      );
      return;
    }

    if (canAutoGenerateDraft) {
      // WHY: Assessment confirmation should behave like a direct drafting
      // action so teachers do not need an extra click after selecting tasks.
      await _generateDraft();
      return;
    }

    if (appliedTaskSource && !_hasDraft) {
      setState(() {
        _errorMessage =
            'Assessment mode is ready. Upload or keep source text with at least 80 characters so Groq can draft the 10-question assessment.';
      });
    }
  }

  bool _applyTaskFocusedUnitTextFromSource(List<String> taskCodes) {
    final sourceText = _rawUploadedSourceText;
    if (sourceText.trim().length < 80) {
      return false;
    }

    if (taskCodes.isEmpty) {
      _unitTextController.text = sourceText.trim();
      return true;
    }

    final focusedText = _extractTaskScopedTextFromSource(
      sourceText: sourceText,
      taskCodes: taskCodes,
    );

    if (focusedText.trim().length < 80) {
      return false;
    }

    _unitTextController.text = focusedText.trim();
    return true;
  }

  String _extractTaskScopedTextFromSource({
    required String sourceText,
    required List<String> taskCodes,
  }) {
    final chunks = _splitSourceChunks(sourceText);
    if (chunks.isEmpty) {
      return sourceText;
    }

    final selectedCodes = taskCodes
        .map((value) => value.trim().toUpperCase())
        .where((value) => value.isNotEmpty)
        .toSet();
    final headingIndexes = <int>[];
    for (var index = 0; index < chunks.length; index += 1) {
      final chunk = chunks[index];
      final chunkCodes = _extractTaskCodes(chunk);
      final isHeading =
          RegExp(r'\btask\b', caseSensitive: false).hasMatch(chunk) &&
          chunkCodes.isNotEmpty;
      if (isHeading) {
        headingIndexes.add(index);
      }
    }

    int start = 0;
    int end = chunks.length;
    if (headingIndexes.isNotEmpty) {
      int? matchedHeading;
      for (final headingIndex in headingIndexes) {
        final headingCodes = _extractTaskCodes(chunks[headingIndex]);
        if (headingCodes.any(selectedCodes.contains)) {
          matchedHeading = headingIndex;
          break;
        }
      }

      if (matchedHeading != null) {
        start = matchedHeading;
        final position = headingIndexes.indexOf(matchedHeading);
        if (position >= 0 && position + 1 < headingIndexes.length) {
          end = headingIndexes[position + 1];
        }
      }
    }

    final window = chunks.sublist(start, end);
    if (window.isEmpty) {
      return sourceText;
    }

    final scoped = <String>[];
    for (final chunk in window) {
      final chunkCodes = _extractTaskCodes(chunk);
      if (chunkCodes.isEmpty || chunkCodes.any(selectedCodes.contains)) {
        scoped.add(chunk);
      }
    }

    if (scoped.isEmpty) {
      return window.join('\n\n');
    }

    // WHY: P1-only should show P1 + shared instruction text; P1+P2 should
    // keep both statements exactly as they appear in the source section.
    final filteredLines = scoped
        .map(
          (chunk) => chunk
              .split('\n')
              .where((line) {
                final lineCodes = _extractTaskCodes(line);
                if (lineCodes.isEmpty) {
                  return true;
                }
                return lineCodes.any(selectedCodes.contains);
              })
              .map((line) => line.trimRight())
              .where((line) => line.trim().isNotEmpty)
              .join('\n'),
        )
        .where((chunk) => chunk.trim().isNotEmpty)
        .toList(growable: false);

    if (filteredLines.isEmpty) {
      return scoped.join('\n\n');
    }

    return filteredLines.join('\n\n');
  }

  List<String> _splitSourceChunks(String sourceText) {
    final byParagraph = sourceText
        .split(RegExp(r'\n{2,}'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);

    if (byParagraph.isNotEmpty) {
      return byParagraph;
    }

    return sourceText
        .split('\n')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
  }

  Set<String> _extractTaskCodes(String text) {
    final matches = RegExp(
      r'\b([PMD]\d+)\b',
      caseSensitive: false,
    ).allMatches(text);
    final codes = <String>{};

    for (final match in matches) {
      final code = (match.group(1) ?? '').trim().toUpperCase();
      if (code.isNotEmpty) {
        codes.add(code);
      }
    }

    return codes;
  }

  List<_ScheduleSlotOption> _buildAvailableDateOptions({
    required bool enforceTeacherId,
  }) {
    final today = _dateOnly(DateTime.now());
    final options = <_ScheduleSlotOption>[];
    final byDayName = <String, TodaySchedule>{
      for (final entry in widget.timetableEntries) _normalize(entry.day): entry,
    };
    final normalizedSubject = _normalize(widget.subject.name);

    for (var offset = 0; offset <= _scheduleSearchWindowDays; offset += 1) {
      final date = today.add(Duration(days: offset));
      final dayName = _weekdayName(date.weekday);
      final schedule = byDayName[_normalize(dayName)];
      if (schedule == null) {
        continue;
      }

      final morningMatches = _slotMatches(
        subjectName: schedule.morningMission.name,
        teacherId: schedule.morningTeacher?.id,
        normalizedSubject: normalizedSubject,
        enforceTeacherId: enforceTeacherId,
      );
      final afternoonMatches = _slotMatches(
        subjectName: schedule.afternoonMission.name,
        teacherId: schedule.afternoonTeacher?.id,
        normalizedSubject: normalizedSubject,
        enforceTeacherId: enforceTeacherId,
      );

      if (morningMatches) {
        options.add(_ScheduleSlotOption(date: date, sessionType: 'morning'));
      }
      if (afternoonMatches) {
        options.add(_ScheduleSlotOption(date: date, sessionType: 'afternoon'));
      }
    }

    return options;
  }

  bool _slotMatches({
    required String subjectName,
    required String? teacherId,
    required String normalizedSubject,
    required bool enforceTeacherId,
  }) {
    final subjectMatches = _normalize(subjectName) == normalizedSubject;
    if (!subjectMatches) {
      return false;
    }

    if (!enforceTeacherId) {
      return true;
    }

    if ((teacherId ?? '').isEmpty) {
      return true;
    }

    return teacherId == widget.session.user.id;
  }

  String _weekdayName(int weekday) {
    const names = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];

    return names[weekday - 1];
  }

  String _normalize(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  bool _isSameDate(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }
}

class _ScheduleSlotOption {
  const _ScheduleSlotOption({required this.date, required this.sessionType});

  final DateTime date;
  final String sessionType;

  String get sessionLabel => sessionType == 'morning' ? 'Morning' : 'Afternoon';
}

class _SourceReadinessCard extends StatelessWidget {
  const _SourceReadinessCard({
    required this.readiness,
    required this.hasPrefilledMission,
    required this.sourceUploadMode,
  });

  final MissionSourceReadiness readiness;
  final bool hasPrefilledMission;
  final _SourceUploadMode sourceUploadMode;

  @override
  Widget build(BuildContext context) {
    final needsAttention = readiness.needsAttention;
    final isPopulateImport =
        sourceUploadMode == _SourceUploadMode.populateDraft;

    return SoftPanel(
      colors: needsAttention
          ? const [Color(0xFFFFF7F2), Color(0xFFFFECE1)]
          : const [Color(0xFFF3FBFF), Color(0xFFE6F4FF)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: needsAttention
                      ? const Color(0xFFFFE2D5)
                      : const Color(0xFFDFF2FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  needsAttention
                      ? Icons.rule_folder_outlined
                      : Icons.verified_outlined,
                  color: needsAttention
                      ? const Color(0xFFAF5A2A)
                      : AppPalette.primaryBlue,
                ),
              ),
              const SizedBox(width: AppSpacing.item),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasPrefilledMission
                          ? 'Draft populated from upload'
                          : needsAttention
                          ? isPopulateImport
                                ? 'Import needs attention'
                                : 'Upload needs attention'
                          : isPopulateImport
                          ? 'Import is ready'
                          : 'Upload is ready',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      readiness.summary,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppPalette.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (hasPrefilledMission || readiness.detectedSignals.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.item),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (hasPrefilledMission)
                  const _InfoPill(label: 'Draft auto-filled'),
                ...readiness.detectedSignals.map(
                  (signal) => _InfoPill(label: signal),
                ),
              ],
            ),
          ],
          if (readiness.missingRequirements.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.item),
            Text(
              'Missing from the upload',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            ...readiness.missingRequirements.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.error_outline_rounded,
                        size: 18,
                        color: Color(0xFFAF5A2A),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(item)),
                  ],
                ),
              ),
            ),
          ],
          if (readiness.warningNotes.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.item),
            Text(
              'Review before publish',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            ...readiness.warningNotes.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.info_outline_rounded,
                        size: 18,
                        color: AppPalette.primaryBlue,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(item)),
                  ],
                ),
              ),
            ),
          ],
          if (needsAttention) ...[
            const SizedBox(height: 4),
            Text(
              isPopulateImport
                  ? 'Populate draft only imports fully structured files. Upload a cleaner worksheet or switch to Generate with AI if this file is lesson text only.'
                  : 'Upload a fuller PDF or add the missing detail in Unit text, then regenerate the draft.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppPalette.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

class _SourceSummaryCard extends StatelessWidget {
  const _SourceSummaryCard({
    required this.uploadedSource,
    required this.sourceFileName,
    required this.sourceFileType,
    required this.xpReward,
    required this.sourceUploadMode,
  });

  final UploadedSourceDraft? uploadedSource;
  final String sourceFileName;
  final String sourceFileType;
  final int xpReward;
  final _SourceUploadMode sourceUploadMode;

  @override
  Widget build(BuildContext context) {
    final isPopulateImport =
        sourceUploadMode == _SourceUploadMode.populateDraft;

    return SoftPanel(
      colors: const [Color(0xFFF7FCFF), Color(0xFFE9F5FF)],
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: AppPalette.teacherGradient,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.description_rounded, color: Colors.white),
          ),
          const SizedBox(width: AppSpacing.item),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sourceFileName.isEmpty ? 'Source ready' : sourceFileName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  sourceFileType.isEmpty
                      ? isPopulateImport
                            ? 'The extracted file is ready for direct draft import.'
                            : 'AI will use the extracted text as the planning source.'
                      : '$sourceFileType · ${uploadedSource?.sourceKind ?? 'text extraction'}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppPalette.textMuted),
                ),
                if (uploadedSource != null) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _InfoPill(
                        label:
                            '${uploadedSource!.extractedCharacterCount} characters',
                      ),
                      _InfoPill(label: '$xpReward XP planned'),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UnitPlanDraftCard extends StatelessWidget {
  const _UnitPlanDraftCard({
    required this.draft,
    required this.appliedXpReward,
    required this.sourceUploadMode,
  });

  final UploadedSourceDraft draft;
  final int appliedXpReward;
  final _SourceUploadMode sourceUploadMode;

  @override
  Widget build(BuildContext context) {
    final isPopulateImport =
        sourceUploadMode == _SourceUploadMode.populateDraft;

    return SoftPanel(
      colors: const [Color(0xFFFFFCF7), Color(0xFFFFF3E2)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppPalette.sun, AppPalette.orange],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  isPopulateImport
                      ? Icons.file_download_done_rounded
                      : Icons.auto_awesome_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: AppSpacing.item),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      draft.unitPlan.unitTitle.isEmpty
                          ? isPopulateImport
                                ? 'Imported file summary'
                                : 'Suggested unit plan'
                          : draft.unitPlan.unitTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      draft.unitPlan.unitSummary,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppPalette.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (draft.unitPlan.keyPoints.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.item),
            Text(
              isPopulateImport
                  ? 'What the file contained'
                  : 'Key points Groq found',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            ...draft.unitPlan.keyPoints.map(
              (point) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 7),
                      child: Icon(
                        Icons.circle,
                        size: 8,
                        color: AppPalette.primaryBlue,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        point,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.item),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _InfoPill(
                label: '${draft.unitPlan.suggestedQuestionCount} questions',
              ),
              _InfoPill(label: '$appliedXpReward XP mission policy'),
              if (!isPopulateImport &&
                  (draft.unitPlan.aiModel ?? '').isNotEmpty)
                _InfoPill(label: draft.unitPlan.aiModel!),
            ],
          ),
        ],
      ),
    );
  }
}

class _EditableQuestionController {
  _EditableQuestionController.emptyTheory()
    : answerMode = 'short_answer',
      _hasOriginalSnapshot = false,
      _originalLearningText = '',
      _originalPrompt = '',
      _originalExpectedAnswer = '',
      _originalOptions = const <String>[],
      _originalCorrectIndex = 0,
      learningTextController = TextEditingController(),
      promptController = TextEditingController(),
      explanationController = TextEditingController(),
      expectedAnswerController = TextEditingController(),
      minWordCountController = TextEditingController(text: '12'),
      optionControllers = List.generate(
        4,
        (_) => TextEditingController(),
        growable: false,
      ),
      correctIndex = 0;

  _EditableQuestionController.fromMissionQuestion(MissionQuestion question)
    : answerMode = question.answerMode.trim().isEmpty
          ? (question.isShortAnswerTheory ? 'short_answer' : 'multiple_choice')
          : question.answerMode.trim(),
      _hasOriginalSnapshot = true,
      _originalLearningText = question.learningText,
      _originalPrompt = question.prompt,
      _originalExpectedAnswer = question.expectedAnswer,
      _originalOptions = List<String>.unmodifiable(
        List<String>.generate(
          4,
          (index) =>
              index < question.options.length ? question.options[index] : '',
        ),
      ),
      _originalCorrectIndex = question.correctIndex.clamp(0, 3),
      learningTextController = TextEditingController(
        text: question.learningText,
      ),
      promptController = TextEditingController(text: question.prompt),
      explanationController = TextEditingController(text: question.explanation),
      expectedAnswerController = TextEditingController(
        text: question.expectedAnswer,
      ),
      minWordCountController = TextEditingController(
        text: '${question.minWordCount > 0 ? question.minWordCount : 12}',
      ),
      optionControllers = List.generate(
        4,
        (index) => TextEditingController(
          text: index < question.options.length ? question.options[index] : '',
        ),
        growable: false,
      ),
      correctIndex = question.correctIndex.clamp(0, 3);

  final String answerMode;
  final bool _hasOriginalSnapshot;
  final String _originalLearningText;
  final String _originalPrompt;
  final String _originalExpectedAnswer;
  final List<String> _originalOptions;
  final int _originalCorrectIndex;
  final TextEditingController learningTextController;
  final TextEditingController promptController;
  final TextEditingController explanationController;
  final TextEditingController expectedAnswerController;
  final TextEditingController minWordCountController;
  final List<TextEditingController> optionControllers;
  int correctIndex;

  bool get isTheoryShortAnswer => answerMode == 'short_answer';
  bool get hasLearnFirstChanged =>
      _hasOriginalSnapshot &&
      _normalizeDraftReviewValue(learningTextController.text) !=
          _normalizeDraftReviewValue(_originalLearningText);

  String? learnFirstReviewError({required int questionNumber}) {
    if (!_hasOriginalSnapshot || !hasLearnFirstChanged) {
      return null;
    }

    final promptChanged =
        _normalizeDraftReviewValue(promptController.text) !=
        _normalizeDraftReviewValue(_originalPrompt);
    if (!promptChanged) {
      return isTheoryShortAnswer
          ? 'Theory question $questionNumber changed Learn First, so the prompt must be updated too.'
          : 'Question $questionNumber changed Learn First, so the prompt must be updated too.';
    }

    if (isTheoryShortAnswer) {
      final expectedAnswerChanged =
          _normalizeDraftReviewValue(expectedAnswerController.text) !=
          _normalizeDraftReviewValue(_originalExpectedAnswer);
      if (!expectedAnswerChanged) {
        return 'Theory question $questionNumber changed Learn First, so the expected answer must be updated too.';
      }
      return null;
    }

    final currentOptions = optionControllers
        .map((controller) => controller.text.trim())
        .toList(growable: false);
    final optionsChanged =
        currentOptions.length != _originalOptions.length ||
        currentOptions.asMap().entries.any(
          (entry) =>
              _normalizeDraftReviewValue(entry.value) !=
              _normalizeDraftReviewValue(_originalOptions[entry.key]),
        );
    if (!optionsChanged) {
      return 'Question $questionNumber changed Learn First, so the answer options must be updated too.';
    }

    final currentCorrectAnswer = currentOptions.isEmpty
        ? ''
        : currentOptions[correctIndex.clamp(0, currentOptions.length - 1)];
    final originalCorrectAnswer = _originalOptions.isEmpty
        ? ''
        : _originalOptions[_originalCorrectIndex.clamp(
            0,
            _originalOptions.length - 1,
          )];
    final correctAnswerChanged =
        correctIndex != _originalCorrectIndex ||
        _normalizeDraftReviewValue(currentCorrectAnswer) !=
            _normalizeDraftReviewValue(originalCorrectAnswer);
    if (!correctAnswerChanged) {
      return 'Question $questionNumber changed Learn First, so the correct answer must be updated too.';
    }

    return null;
  }

  MissionQuestion toMissionQuestion() {
    final minWordCount = int.tryParse(minWordCountController.text.trim()) ?? 0;
    return MissionQuestion(
      id: '',
      answerMode: answerMode,
      learningText: learningTextController.text.trim(),
      prompt: promptController.text.trim(),
      options: isTheoryShortAnswer
          ? const []
          : optionControllers
                .map((controller) => controller.text.trim())
                .toList(growable: false),
      correctIndex: isTheoryShortAnswer ? -1 : correctIndex,
      explanation: explanationController.text.trim(),
      expectedAnswer: expectedAnswerController.text.trim(),
      minWordCount: isTheoryShortAnswer ? minWordCount : 0,
    );
  }

  void dispose() {
    learningTextController.dispose();
    promptController.dispose();
    explanationController.dispose();
    expectedAnswerController.dispose();
    minWordCountController.dispose();
    for (final controller in optionControllers) {
      controller.dispose();
    }
  }
}

class _QuestionEditorCard extends StatelessWidget {
  const _QuestionEditorCard({
    required this.index,
    required this.editor,
    required this.onCorrectIndexChanged,
  });

  final int index;
  final _EditableQuestionController editor;
  final ValueChanged<int> onCorrectIndexChanged;

  @override
  Widget build(BuildContext context) {
    const optionLabels = ['A', 'B', 'C', 'D'];
    final reviewListenable = Listenable.merge([
      editor.learningTextController,
      editor.promptController,
      ...editor.optionControllers,
    ]);

    return SoftPanel(
      colors: const [Color(0xFFFFFFFF), Color(0xFFF5FAFF)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: AppPalette.teacherGradient,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: Theme.of(
                      context,
                    ).textTheme.titleSmall?.copyWith(color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Question ${index + 1}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.item),
          TextField(
            controller: editor.learningTextController,
            minLines: 3,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText:
                  'Teach first: explain the concept and clue the question will use before the student answers.',
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              'If you rewrite Learn First, also rewrite the prompt, options, and correct answer before saving.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF65749B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          AnimatedBuilder(
            animation: reviewListenable,
            builder: (context, child) {
              final message = editor.learnFirstReviewError(
                questionNumber: index + 1,
              );
              if (message == null) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFFB93B3B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.item),
          TextField(
            controller: editor.promptController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Write the question prompt',
            ),
          ),
          const SizedBox(height: AppSpacing.item),
          ...List.generate(
            4,
            (optionIndex) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _OptionBadge(label: optionLabels[optionIndex]),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: editor.optionControllers[optionIndex],
                      decoration: InputDecoration(
                        hintText: 'Answer ${optionLabels[optionIndex]}',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text('Correct answer', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: List.generate(
              4,
              (optionIndex) => _CorrectOptionChip(
                label: optionLabels[optionIndex],
                selected: editor.correctIndex == optionIndex,
                onTap: () => onCorrectIndexChanged(optionIndex),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.item),
          TextField(
            controller: editor.explanationController,
            minLines: 2,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Explain why the correct answer is right.',
            ),
          ),
        ],
      ),
    );
  }
}

class _TheoryQuestionEditorCard extends StatelessWidget {
  const _TheoryQuestionEditorCard({
    required this.index,
    required this.editor,
    required this.canRemove,
    required this.onRemove,
  });

  final int index;
  final _EditableQuestionController editor;
  final bool canRemove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final reviewListenable = Listenable.merge([
      editor.learningTextController,
      editor.promptController,
      editor.expectedAnswerController,
    ]);

    return SoftPanel(
      colors: const [Color(0xFFFFFEFB), Color(0xFFFFF2D8)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppPalette.sun, AppPalette.orange],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: Theme.of(
                      context,
                    ).textTheme.titleSmall?.copyWith(color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Theory question ${index + 1}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              if (canRemove)
                TextButton.icon(
                  onPressed: onRemove,
                  icon: const Icon(Icons.remove_circle_outline_rounded),
                  label: const Text('Remove'),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.item),
          TextField(
            controller: editor.learningTextController,
            minLines: 4,
            maxLines: 6,
            decoration: const InputDecoration(
              hintText:
                  'LEARN FIRST: teach the idea, clue, and success criteria the student should use before writing.',
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              'If you rewrite Learn First, also rewrite the prompt and expected answer before saving.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF65749B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          AnimatedBuilder(
            animation: reviewListenable,
            builder: (context, child) {
              final message = editor.learnFirstReviewError(
                questionNumber: index + 1,
              );
              if (message == null) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFFB93B3B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.item),
          TextField(
            controller: editor.promptController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Write the short-answer theory question prompt.',
            ),
          ),
          const SizedBox(height: AppSpacing.item),
          TextField(
            controller: editor.expectedAnswerController,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText:
                  'Write the teacher expected answer or key answer points for review and reporting.',
            ),
          ),
          const SizedBox(height: AppSpacing.item),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: editor.minWordCountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    hintText: 'Minimum words',
                    labelText: 'Minimum words',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: editor.explanationController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText:
                        'Optional teacher note explaining what a strong response should include.',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _normalizeDraftReviewValue(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ');
}

class _OptionBadge extends StatelessWidget {
  const _OptionBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: AppPalette.sky.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(color: AppPalette.navy),
        ),
      ),
    );
  }
}

class _CorrectOptionChip extends StatelessWidget {
  const _CorrectOptionChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(colors: AppPalette.progressGradient)
              : LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.84),
                    Colors.white.withValues(alpha: 0.74),
                  ],
                ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: selected ? Colors.white : AppPalette.navy,
          ),
        ),
      ),
    );
  }
}

class _TopButton extends StatelessWidget {
  const _TopButton({required this.icon, required this.onTap});

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

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.84),
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

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.colors,
    this.onTap,
  });

  final String label;
  final bool selected;
  final List<Color> colors;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(colors: colors)
              : LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.82),
                    Colors.white.withValues(alpha: 0.68),
                  ],
                ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: selected ? Colors.white : AppPalette.navy,
          ),
        ),
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.label, required this.selected, this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppPalette.navy
              : Colors.white.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: selected ? Colors.white : AppPalette.navy,
          ),
        ),
      ),
    );
  }
}

class _CertificationFocusChip extends StatelessWidget {
  const _CertificationFocusChip({required this.taskCode, required this.status});

  final String taskCode;
  final String status;

  @override
  Widget build(BuildContext context) {
    final Color backgroundColor;
    final Color textColor;

    switch (status) {
      case 'passed':
        backgroundColor = const Color(0xFFE8FFF0);
        textColor = const Color(0xFF157347);
        break;
      case 'remaining':
        backgroundColor = const Color(0xFFFFF4DE);
        textColor = const Color(0xFFAF6A00);
        break;
      default:
        backgroundColor = Colors.white.withValues(alpha: 0.78);
        textColor = AppPalette.navy;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        taskCode,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
