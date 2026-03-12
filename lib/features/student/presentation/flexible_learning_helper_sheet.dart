/**
 * WHAT:
 * FlexibleLearningHelperSheet renders the guided student helper shown from the
 * dashboard as a playful bottom sheet.
 * WHY:
 * Students need friendly encouragement and short progress analysis without
 * exposing free-text chat or any data outside their own missions, subjects,
 * timetable, and saved results.
 * HOW:
 * Present a chip-driven helper that builds scripted responses from the current
 * dashboard payload and on-demand subject reports fetched through the existing
 * student API layer.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'package:flutter/material.dart';

import '../../../core/constants/app_palette.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../shared/models/focus_mission_models.dart';
import '../../../shared/widgets/soft_panel.dart';

typedef StudentSubjectReportLoader =
    Future<StudentSubjectReportData> Function(String subjectId);

Future<void> showFlexibleLearningHelperSheet(
  BuildContext context, {
  required AuthSession session,
  required StudentDashboardData dashboard,
  required List<TodaySchedule> timetable,
  required List<StudentSubjectReportSummary> subjects,
  required StudentSubjectReportLoader loadSubjectReport,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => FlexibleLearningHelperSheet(
      session: session,
      dashboard: dashboard,
      timetable: timetable,
      subjects: subjects,
      loadSubjectReport: loadSubjectReport,
    ),
  );
}

class FlexibleLearningHelperSheet extends StatefulWidget {
  const FlexibleLearningHelperSheet({
    super.key,
    required this.session,
    required this.dashboard,
    required this.timetable,
    required this.subjects,
    required this.loadSubjectReport,
  });

  final AuthSession session;
  final StudentDashboardData dashboard;
  final List<TodaySchedule> timetable;
  final List<StudentSubjectReportSummary> subjects;
  final StudentSubjectReportLoader loadSubjectReport;

  @override
  State<FlexibleLearningHelperSheet> createState() =>
      _FlexibleLearningHelperSheetState();
}

class _FlexibleLearningHelperSheetState
    extends State<FlexibleLearningHelperSheet> {
  final ScrollController _scrollController = ScrollController();
  final List<_HelperMessage> _messages = <_HelperMessage>[];
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _messages.add(_buildWelcomeMessage());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    return FractionallySizedBox(
      heightFactor: 0.92,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.item,
          AppSpacing.item,
          AppSpacing.item,
          AppSpacing.item + keyboard,
        ),
        child: SoftPanel(
          colors: const [Color(0xFFFFFCFF), Color(0xFFE9F7FF)],
          child: Column(
            children: [
              _HelperHeader(
                userName: widget.session.user.name,
                subjectCount: widget.subjects.length,
              ),
              const SizedBox(height: AppSpacing.item),
              Expanded(
                child: ListView.separated(
                  controller: _scrollController,
                  itemCount: _messages.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.item),
                  itemBuilder: (context, index) {
                    return _HelperBubble(message: _messages[index]);
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.item),
              _HelperActionTray(
                isBusy: _isBusy,
                subjects: widget.subjects,
                onPromptTap: _handlePrompt,
                onSubjectTap: _handleSubjectTap,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handlePrompt(_HelperPrompt prompt) async {
    if (_isBusy) {
      return;
    }

    _appendMessage(_HelperMessage.user(prompt.label));

    switch (prompt) {
      case _HelperPrompt.nextStep:
        _appendMessage(_buildNextStepMessage());
        break;
      case _HelperPrompt.todayPlan:
        _appendMessage(_buildTodayPlanMessage());
        break;
      case _HelperPrompt.weeklyPulse:
        _appendMessage(_buildWeeklyPulseMessage());
        break;
      case _HelperPrompt.readAResult:
        _appendMessage(_buildResultPromptMessage());
        break;
      case _HelperPrompt.encourageMe:
        _appendMessage(_buildEncouragementMessage());
        break;
    }
  }

  Future<void> _handleSubjectTap(StudentSubjectReportSummary subject) async {
    if (_isBusy) {
      return;
    }

    _appendMessage(_HelperMessage.user('Check ${subject.subjectName}'));
    final loadingIndex = _appendMessage(
      _HelperMessage.assistant(
        headline: 'Checking ${subject.subjectName}',
        body:
            'I am reading only your saved ${subject.subjectName} progress and result history.',
        chips: const <String>['Student-only view'],
        isLoading: true,
      ),
    );

    setState(() {
      _isBusy = true;
    });

    try {
      final report = await widget.loadSubjectReport(subject.subjectId);
      if (!mounted) {
        return;
      }
      _replaceMessage(loadingIndex, _buildSubjectMessage(subject, report));
    } catch (error) {
      if (!mounted) {
        return;
      }
      _replaceMessage(
        loadingIndex,
        _HelperMessage.assistant(
          headline: 'I could not read that subject yet',
          body:
              'I can only use your saved subject report. Please try again in a moment.',
          chips: const <String>['No extra data used'],
          footer: error.toString(),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
        _scrollToBottom();
      }
    }
  }

  _HelperMessage _buildWelcomeMessage() {
    final today = widget.dashboard.today;
    final dayLabel = today?.day ?? 'today';
    final subjectCount = widget.subjects.length;
    final intro =
        'Hey ${_firstName(widget.session.user.name)}. I only use your own timetable, subjects, XP, streak, and saved results.';
    final subjectText = subjectCount == 0
        ? 'Your teacher has not linked subjects yet, but I can still keep the mood light.'
        : 'You currently have $subjectCount ${subjectCount == 1 ? 'subject' : 'subjects'} on your board.';

    return _HelperMessage.assistant(
      headline: 'FlexibleLearning Helper',
      body: '$intro $subjectText',
      chips: <String>[
        'Today: $dayLabel',
        '${widget.dashboard.student.streak} day streak',
        '${widget.dashboard.dailyXp.totalXp}/${widget.dashboard.dailyXp.totalXpCap} XP today',
      ],
      footer:
          'Pick a quick prompt below. I will keep every answer short, friendly, and student-only.',
    );
  }

  _HelperMessage _buildNextStepMessage() {
    final today = widget.dashboard.today;
    if (today == null) {
      return _HelperMessage.assistant(
        headline: 'Your next best move',
        body:
            'Your timetable looks quiet right now. Open one of your subject cards or check back when a mission is added.',
        chips: <String>[
          '${widget.subjects.length} subjects on file',
          '${widget.dashboard.recentSessions.length} recent sessions',
        ],
        footer:
            'Tiny steps still count. You do not need to do everything at once.',
      );
    }

    final remainingXp =
        (widget.dashboard.dailyXp.totalXpCap - widget.dashboard.dailyXp.totalXp)
            .clamp(0, widget.dashboard.dailyXp.totalXpCap);
    final missionLabel = widget.dashboard.recentSessions.isEmpty
        ? 'Start your morning mission first.'
        : 'Open the next mission card that matches your timetable.';

    return _HelperMessage.assistant(
      headline: 'Your clean next step',
      body:
          '$missionLabel ${today.morningMission.name} is sitting at the top of your board for a calm start.',
      chips: <String>[
        'Morning: ${today.morningMission.name}',
        'Room: ${today.room}',
        '$remainingXp XP left today',
      ],
      footer:
          'If you want a deeper result breakdown, tap one of your subject chips below.',
    );
  }

  _HelperMessage _buildTodayPlanMessage() {
    final today = widget.dashboard.today;
    if (today == null) {
      return _HelperMessage.assistant(
        headline: 'Today plan',
        body:
            'I cannot see a timetable entry for today yet. Your board will update as soon as a lesson is assigned.',
        chips: const <String>['No lesson assigned yet'],
        footer: 'You can still use me for encouragement or subject summaries.',
      );
    }

    final morningTeacher = today.morningTeacher?.name ?? 'Teacher pending';
    final afternoonTeacher = today.afternoonTeacher?.name ?? 'Teacher pending';

    return _HelperMessage.assistant(
      headline: 'Your plan for ${today.day}',
      body:
          'Morning is ${today.morningMission.name} with $morningTeacher. Afternoon is ${today.afternoonMission.name} with $afternoonTeacher.',
      chips: <String>[
        'Morning: ${today.morningMission.name}',
        'Afternoon: ${today.afternoonMission.name}',
        today.room,
      ],
      footer:
          'That is the full student view I can see for today. No hidden extras, no other-user data.',
    );
  }

  _HelperMessage _buildWeeklyPulseMessage() {
    final sessions = widget.dashboard.recentSessions;
    final focusAverage = _averageFocus(sessions);
    final assessmentSubjects = widget.dashboard.subjectProgress
        .where((subject) => subject.completedAssessments > 0)
        .length;
    final certificateReady = widget.dashboard.subjectCertification
        .where((subject) => subject.certificateUnlocked)
        .length;
    final tone = switch (focusAverage) {
      >= 85 => 'You are in a really steady groove.',
      >= 65 => 'Your focus is building nicely.',
      _ => 'A quiet reset and one mission can change the feel of the day.',
    };

    return _HelperMessage.assistant(
      headline: 'Weekly pulse',
      body:
          '$tone I can see ${sessions.length} recent ${sessions.length == 1 ? 'session' : 'sessions'} and a ${widget.dashboard.student.streak}-day streak.',
      chips: <String>[
        'Focus avg $focusAverage%',
        'XP ${widget.dashboard.student.xp}',
        '$assessmentSubjects subjects with completed assessments',
        '$certificateReady certificates unlocked',
      ],
      footer:
          'I only measure what your own dashboard has saved, so this stays simple and fair.',
    );
  }

  _HelperMessage _buildResultPromptMessage() {
    if (widget.subjects.isEmpty) {
      return _HelperMessage.assistant(
        headline: 'Result reading',
        body:
            'I need at least one linked subject before I can read a saved result. Your teacher can add that through the timetable.',
        chips: const <String>['No linked subjects yet'],
      );
    }

    return _HelperMessage.assistant(
      headline: 'Pick a subject',
      body:
          'Tap one subject chip below and I will read only that saved report, including your assessment progress, latest score, and remaining task focuses.',
      chips: <String>[
        '${widget.subjects.length} subjects ready',
        'Student-only analysis',
      ],
      footer:
          'I do not answer general questions outside your own subjects and results.',
    );
  }

  _HelperMessage _buildEncouragementMessage() {
    final xpToday = widget.dashboard.dailyXp.totalXp;
    final streak = widget.dashboard.student.streak;
    final body = switch ((xpToday, streak)) {
      (>= 150, >= 3) =>
        'You have already built real momentum. Keep it gentle and protect the streak.',
      (>= 60, _) =>
        'You are already moving. One more small mission is enough to keep the day feeling alive.',
      (_, >= 3) =>
        'That streak is proof that small steps work. You do not need a giant session to keep going.',
      _ =>
        'Fresh boards are not bad boards. Start tiny, get one win, and let the rest follow.',
    };

    return _HelperMessage.assistant(
      headline: 'Pep talk',
      body: body,
      chips: <String>[
        '$xpToday XP today',
        '$streak day streak',
        '${widget.dashboard.recentSessions.length} recent sessions',
      ],
      footer:
          'I am here for encouragement, mission direction, and your own saved progress only.',
    );
  }

  _HelperMessage _buildSubjectMessage(
    StudentSubjectReportSummary subject,
    StudentSubjectReportData report,
  ) {
    final latestResult = report.missionHistory.isEmpty
        ? null
        : report.missionHistory.first;
    final assessment = report.assessmentProgress;
    final certification = report.certification;
    final assessmentLabel = assessment == null
        ? 'No assessment score saved yet'
        : '${assessment.completionPercentage}% assessment completion · ${assessment.averageScore}% average';
    final certificateLabel = certification.certificationEnabled
        ? '${certification.completionPercentage}% certification complete'
        : 'Certification not active';
    final latestLabel = latestResult == null
        ? 'No completed result saved yet'
        : 'Latest result ${latestResult.scorePercent}% · +${latestResult.xpAwarded} XP';

    final footer = latestResult == null
        ? 'Start the next ${subject.subjectName} mission and I will have more real evidence to read.'
        : latestResult.taskCodes.isEmpty
        ? latestResult.statusLabel
        : 'Task focuses: ${latestResult.taskCodes.join(', ')}';

    return _HelperMessage.assistant(
      headline: '${subject.subjectName} snapshot',
      body: '$assessmentLabel. $certificateLabel. $latestLabel.',
      chips: <String>[
        subject.subjectName,
        if (latestResult != null) latestResult.title,
        if (certification.remainingTaskCodes.isNotEmpty)
          'Still needed: ${certification.remainingTaskCodes.take(3).join(', ')}',
      ],
      footer: footer,
    );
  }

  int _appendMessage(_HelperMessage message) {
    final index = _messages.length;
    setState(() {
      _messages.add(message);
    });
    _scrollToBottom();
    return index;
  }

  void _replaceMessage(int index, _HelperMessage message) {
    setState(() {
      _messages[index] = message;
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  int _averageFocus(List<SessionSummary> sessions) {
    if (sessions.isEmpty) {
      return 0;
    }
    final total = sessions.fold<int>(0, (sum, item) => sum + item.focusScore);
    return (total / sessions.length).round();
  }

  String _firstName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return 'friend';
    }
    return trimmed.split(RegExp(r'\s+')).first;
  }
}

enum _HelperPrompt {
  nextStep('What should I do next?', Icons.flag_circle_rounded),
  todayPlan('What is my plan today?', Icons.event_note_rounded),
  weeklyPulse('How am I doing?', Icons.insights_rounded),
  readAResult('Help me read a result', Icons.article_rounded),
  encourageMe('Give me a boost', Icons.favorite_rounded);

  const _HelperPrompt(this.label, this.icon);

  final String label;
  final IconData icon;
}

class _HelperHeader extends StatelessWidget {
  const _HelperHeader({required this.userName, required this.subjectCount});

  final String userName;
  final int subjectCount;

  @override
  Widget build(BuildContext context) {
    return SoftPanel(
      padding: const EdgeInsets.all(AppSpacing.item),
      colors: const [Color(0xFFEFFAFF), Color(0xFFFFF9F2)],
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppPalette.aqua, AppPalette.sun],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: AppSpacing.item),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FlexibleLearning Helper',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  'Hi $userName. I can only talk about your own $subjectCount subjects, timetable, XP, and saved results.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppPalette.textMuted),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Close helper',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

class _HelperActionTray extends StatelessWidget {
  const _HelperActionTray({
    required this.isBusy,
    required this.subjects,
    required this.onPromptTap,
    required this.onSubjectTap,
  });

  final bool isBusy;
  final List<StudentSubjectReportSummary> subjects;
  final ValueChanged<_HelperPrompt> onPromptTap;
  final ValueChanged<StudentSubjectReportSummary> onSubjectTap;

  @override
  Widget build(BuildContext context) {
    return SoftPanel(
      padding: const EdgeInsets.all(AppSpacing.item),
      colors: const [Color(0xFFF8FCFF), Color(0xFFFDF8FF)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quick prompts', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.compact),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _HelperPrompt.values
                .map(
                  (prompt) => ActionChip(
                    avatar: Icon(prompt.icon, size: 18, color: AppPalette.navy),
                    label: Text(prompt.label),
                    onPressed: isBusy ? null : () => onPromptTap(prompt),
                    backgroundColor: Colors.white.withValues(alpha: 0.88),
                    side: BorderSide(
                      color: AppPalette.primaryBlue.withValues(alpha: 0.18),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: AppSpacing.item),
          Text('Subject check', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            'Choose one subject if you want a results snapshot.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppPalette.textMuted),
          ),
          const SizedBox(height: AppSpacing.compact),
          if (subjects.isEmpty)
            const Text('No linked subjects yet.')
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: subjects
                  .map(
                    (subject) => FilterChip(
                      label: Text(subject.subjectName),
                      selected: false,
                      onSelected: isBusy ? null : (_) => onSubjectTap(subject),
                      avatar: Icon(
                        _subjectIcon(subject.subjectName, subject.subjectIcon),
                        size: 18,
                        color: Colors.white,
                      ),
                      backgroundColor: _subjectColor(
                        subject.subjectColor,
                      ).withValues(alpha: 0.12),
                      side: BorderSide(
                        color: _subjectColor(
                          subject.subjectColor,
                        ).withValues(alpha: 0.22),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
        ],
      ),
    );
  }
}

class _HelperBubble extends StatelessWidget {
  const _HelperBubble({required this.message});

  final _HelperMessage message;

  @override
  Widget build(BuildContext context) {
    final alignment = message.isUser
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;
    final colors = message.isUser
        ? const [Color(0xFFEDEBFF), Color(0xFFDFF5FF)]
        : const [Colors.white, Color(0xFFF8FCFF)];

    return Column(
      crossAxisAlignment: alignment,
      children: [
        SoftPanel(
          padding: const EdgeInsets.all(AppSpacing.item),
          colors: colors,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message.headline != null) ...[
                  Text(
                    message.headline!,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!message.isUser) ...[
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppPalette.aqua, AppPalette.sun],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.sentiment_satisfied_alt_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Text(
                        message.body,
                        style: Theme.of(
                          context,
                        ).textTheme.bodyLarge?.copyWith(color: AppPalette.navy),
                      ),
                    ),
                    if (message.isLoading) ...[
                      const SizedBox(width: 10),
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      ),
                    ],
                  ],
                ),
                if (message.chips.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.compact),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: message.chips
                        .map(
                          (chip) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.72),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              chip,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppPalette.navy),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ],
                if ((message.footer ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.compact),
                  Text(
                    message.footer!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppPalette.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HelperMessage {
  const _HelperMessage({
    required this.isUser,
    required this.body,
    this.headline,
    this.footer,
    this.chips = const <String>[],
    this.isLoading = false,
  });

  final bool isUser;
  final String body;
  final String? headline;
  final String? footer;
  final List<String> chips;
  final bool isLoading;

  factory _HelperMessage.user(String body) {
    return _HelperMessage(isUser: true, body: body);
  }

  factory _HelperMessage.assistant({
    required String body,
    String? headline,
    String? footer,
    List<String> chips = const <String>[],
    bool isLoading = false,
  }) {
    return _HelperMessage(
      isUser: false,
      body: body,
      headline: headline,
      footer: footer,
      chips: chips,
      isLoading: isLoading,
    );
  }
}

Color _subjectColor(String value) {
  final normalized = value.trim().replaceFirst('#', '');
  if (normalized.length != 6) {
    return AppPalette.primaryBlue;
  }
  final parsed = int.tryParse(normalized, radix: 16);
  if (parsed == null) {
    return AppPalette.primaryBlue;
  }
  return Color(0xFF000000 | parsed);
}

IconData _subjectIcon(String subjectName, String rawIcon) {
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
  if (source.contains('life')) {
    return Icons.self_improvement_rounded;
  }
  return Icons.school_rounded;
}
