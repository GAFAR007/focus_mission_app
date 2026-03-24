/**
 * WHAT:
 * StudentDashboardScreen shows the student's daily missions, recent activity,
 * subject-level progress, and the guided FlexibleLearning Helper entry point.
 * WHY:
 * Students need one ADHD-friendly home screen where daily practice and
 * certification progress are visible without sending them into legacy
 * criterion flows that are no longer the main progress story, while still
 * feeling playful and supportive.
 * HOW:
 * Load dashboard data plus timetable context, render more rewarding student
 * cards, and layer guided helper and encouragement popups on top of the
 * existing student-only API data.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_palette.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/auth_session_store.dart';
import '../../../core/utils/focus_mission_api.dart';
import '../../../shared/models/focus_mission_models.dart';
import '../../../shared/widgets/focus_scaffold.dart';
import '../../../shared/widgets/mission_card.dart';
import '../../../shared/widgets/profile_avatar_button.dart';
import '../../../shared/widgets/profile_sheet.dart';
import '../../../shared/widgets/progress_hero_card.dart';
import '../../../shared/widgets/soft_panel.dart';
import '../../../shared/widgets/stat_chip.dart';
import '../../auth/presentation/role_selection_screen.dart';
import 'flexible_learning_helper_sheet.dart';
import 'mission_play_screen.dart';
import 'standalone_paper_play_screen.dart';
import 'student_result_report_screen.dart';
import 'student_subject_report_screen.dart';

class StudentDashboardScreen extends StatefulWidget {
  const StudentDashboardScreen({super.key, required this.session});

  final AuthSession session;

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

enum _MissionStartChoice { daily, assessment }

enum _DailyWelcomeAction { helper, missions, close }

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  final FocusMissionApi _api = FocusMissionApi();
  final AuthSessionStore _sessionStore = AuthSessionStore();
  static const String _shownSubjectBonusStorageKey =
      'shown_subject_bonus_keys_v1';
  static const String _shownDailyWelcomeStorageKey =
      'shown_student_dashboard_welcome_keys_v1';
  final Set<String> _shownSubjectBonusKeys = <String>{};
  final Set<String> _shownDailyWelcomeKeys = <String>{};
  final List<Future<void> Function()> _popupQueue = <Future<void> Function()>[];
  final Map<String, StudentSubjectReportData> _subjectReportCache =
      <String, StudentSubjectReportData>{};
  final Map<String, Future<StudentSubjectReportData>> _subjectReportRequests =
      <String, Future<StudentSubjectReportData>>{};
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _todaySectionKey = GlobalKey();
  bool _isPopupStorageReady = false;
  bool _isPopupVisible = false;
  bool _hasQueuedDailyLoginBonus = false;

  late AuthSession _session;
  late Future<_StudentScreenData> _future;

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    _persistSessionSnapshot();
    _future = _loadData();
    _loadShownPopupKeys();
  }

  Future<void> _persistSessionSnapshot() async {
    try {
      await _sessionStore.saveSession(_session);
    } catch (_) {}
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<_StudentScreenData> _loadData() async {
    final results = await Future.wait<dynamic>([
      _api.fetchStudentDashboard(
        token: _session.token,
        studentId: _session.user.id,
      ),
      _api.fetchStudentTimetable(
        token: _session.token,
        studentId: _session.user.id,
      ),
    ]);

    return _StudentScreenData(
      session: _session,
      dashboard: results[0] as StudentDashboardData,
      timetable: results[1] as List<TodaySchedule>,
    );
  }

  void _refreshData() {
    setState(() {
      _subjectReportCache.clear();
      _subjectReportRequests.clear();
      _future = _loadData();
    });
  }

  Future<void> _loadShownPopupKeys() async {
    List<String> storedKeys = const <String>[];
    List<String> welcomeKeys = const <String>[];
    try {
      final prefs = await SharedPreferences.getInstance();
      storedKeys =
          prefs.getStringList(_shownSubjectBonusStorageKey) ?? const <String>[];
      welcomeKeys =
          prefs.getStringList(_shownDailyWelcomeStorageKey) ?? const <String>[];
    } catch (error) {
      // WHY: Web/plugin bootstrap can briefly miss shared_preferences during
      // hot restarts; fallback keeps the dashboard usable for testing.
      storedKeys = const <String>[];
      welcomeKeys = const <String>[];
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _shownSubjectBonusKeys
        ..clear()
        ..addAll(storedKeys);
      _shownDailyWelcomeKeys
        ..clear()
        ..addAll(welcomeKeys);
      _isPopupStorageReady = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FocusScaffold(
      child: FutureBuilder<_StudentScreenData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return _LoadingState(
              label: 'Loading ${_session.user.name}\'s missions...',
            );
          }

          if (snapshot.hasError) {
            return _ErrorState(
              message: snapshot.error.toString(),
              onBack: () => Navigator.of(context).pop(),
            );
          }

          final data = snapshot.data!;
          final today = data.dashboard.today;
          final mySubjects = _buildSubjectSummaries(data);
          _maybeShowDailyLoginBonus(data.dashboard.dailyXp);
          _maybeShowSubjectCompletionBonus(data.dashboard.dailyXp);
          _maybeShowDailyWelcome(data, mySubjects);

          return Stack(
            children: [
              SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screen,
                  AppSpacing.screen,
                  AppSpacing.screen,
                  120,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ScreenHeader(
                      title: 'Student View',
                      subtitle: 'Tiny wins, clear missions, calm progress.',
                      onBack: () => Navigator.of(context).pop(),
                      user: _session.user,
                      onLogout: _signOut,
                      onProfileTap: _openProfile,
                    ),
                    const SizedBox(height: AppSpacing.section),
                    ProgressHeroCard(
                      name: _session.user.name,
                      streakLabel: _journeyLabel(data.dashboard.student),
                      currentXp: data.dashboard.student.xp,
                      goalXp: 200,
                      trailingIcon: Icons.emoji_events_rounded,
                      avatarUrl: _session.user.avatar,
                      titleBadge: _heroTitleBadge(today),
                      highlightMessage: _heroHighlightMessage(data, today),
                      statBadges: <String>[
                        '${mySubjects.length} subjects',
                        '${data.dashboard.dailyXp.totalXp}/${data.dashboard.dailyXp.totalXpCap} XP today',
                        '${_averageFocus(data.dashboard.recentSessions)}% focus average',
                      ],
                    ),
                    const SizedBox(height: AppSpacing.item),
                    _DailyXpPanel(summary: data.dashboard.dailyXp),
                    const SizedBox(height: AppSpacing.section),
                    KeyedSubtree(
                      key: _todaySectionKey,
                      child: _SectionLead(
                        title: 'Today: ${today?.day ?? 'No schedule yet'}',
                        subtitle:
                            'Pick one mission, keep it simple, and let the helper do the cheering.',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.item),
                    if (today != null) ...[
                      MissionCard(
                        title: 'Morning Mission',
                        subtitle: _missionSubtitle(
                          today.morningMission.name,
                          today.room,
                          today.morningTeacher?.name,
                        ),
                        actionLabel: 'Start Mission',
                        icon: Icons.computer_rounded,
                        colors: AppPalette.studentGradient,
                        eyebrow: 'Warm-up mode',
                        toneMessage:
                            'Start light, build rhythm, keep your brain comfy.',
                        featurePills: <String>[
                          today.morningMission.name,
                          today.room,
                        ],
                        onPressed: () => _startMissionWithChoice(
                          studentId: data.dashboard.student.id,
                          subjectId: today.morningMission.id,
                          sessionType: 'morning',
                          subjectName: today.morningMission.name,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.item),
                      MissionCard(
                        title: 'Afternoon Mission',
                        subtitle: _missionSubtitle(
                          today.afternoonMission.name,
                          today.room,
                          today.afternoonTeacher?.name,
                        ),
                        actionLabel: 'Start Mission',
                        icon: Icons.account_balance_rounded,
                        colors: const [AppPalette.primaryBlue, AppPalette.sun],
                        eyebrow: 'Round two',
                        toneMessage:
                            'Steady beats speedy. One focused run is enough.',
                        featurePills: <String>[
                          today.afternoonMission.name,
                          today.room,
                        ],
                        onPressed: () => _startMissionWithChoice(
                          studentId: data.dashboard.student.id,
                          subjectId: today.afternoonMission.id,
                          sessionType: 'afternoon',
                          subjectName: today.afternoonMission.name,
                        ),
                      ),
                    ] else
                      const SoftPanel(
                        child: Text(
                          'No mission is assigned for today yet. Your board will wake up as soon as one is added.',
                        ),
                      ),
                    if (data.dashboard.todayStandalonePapers.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.section),
                      const _SectionLead(
                        title: 'Today Tests And Exams',
                        subtitle:
                            'These stay separate from missions and open in their own timed paper runner.',
                      ),
                      const SizedBox(height: AppSpacing.item),
                      ...data.dashboard.todayStandalonePapers.map(
                        (paper) => Padding(
                          padding: const EdgeInsets.only(
                            bottom: AppSpacing.item,
                          ),
                          child: MissionCard(
                            title: paper.title,
                            subtitle:
                                '${paper.subject?.name ?? 'Subject'} · ${_standaloneSessionLabel(paper.sessionType)} · ${paper.durationMinutes <= 0 ? 'No timer' : '${paper.durationMinutes} min'}',
                            actionLabel: _standaloneActionLabel(paper),
                            icon: paper.isExam
                                ? Icons.fact_check_rounded
                                : Icons.quiz_rounded,
                            colors: paper.isExam
                                ? const [Color(0xFFF0B45D), Color(0xFFE58E3F)]
                                : const [
                                    AppPalette.primaryBlue,
                                    AppPalette.aqua,
                                  ],
                            eyebrow: paper.isExam ? 'Exam mode' : 'Test mode',
                            toneMessage: paper.latestSession?.isActive == true
                                ? 'Pick up where you left off. Your timer keeps running.'
                                : paper.latestSession?.isLocked == true
                                ? 'This paper is locked right now. Open it to see what happened.'
                                : 'One question at a time, with your progress saved as you go.',
                            featurePills: <String>[
                              _standaloneStatusLabel(
                                paper.latestSession?.status ?? 'ready',
                              ),
                              if ((paper.latestSession?.warningCount ?? 0) > 0)
                                'Warnings ${paper.latestSession!.warningCount}',
                            ],
                            onPressed: () => _openStandalonePaper(paper),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.section),
                    const _SectionLead(
                      title: 'This week',
                      subtitle:
                          'Quick signals only. No giant dashboard maze today.',
                    ),
                    const SizedBox(height: AppSpacing.item),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        StatChip(
                          value:
                              '${_averageFocus(data.dashboard.recentSessions)}%',
                          label: 'Focus score',
                          colors: AppPalette.studentGradient,
                        ),
                        StatChip(
                          value: '${data.dashboard.student.xp}',
                          label: 'XP total',
                          colors: const [
                            AppPalette.primaryBlue,
                            AppPalette.aqua,
                          ],
                        ),
                        StatChip(
                          value: '${data.dashboard.recentSessions.length}',
                          label: 'Recent sessions',
                          colors: const [
                            AppPalette.sky,
                            AppPalette.primaryBlue,
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.section),
                    const _SectionLead(
                      title: 'My Subjects',
                      subtitle:
                          'Open a subject when you want a calm, read-only progress check.',
                    ),
                    const SizedBox(height: AppSpacing.item),
                    if (mySubjects.isEmpty)
                      const SoftPanel(
                        child: Text(
                          'No subjects are linked to your timetable yet. Your teacher will add them soon.',
                        ),
                      )
                    else
                      ...mySubjects.map(
                        (subject) => Padding(
                          padding: const EdgeInsets.only(
                            bottom: AppSpacing.item,
                          ),
                          child: _MySubjectCard(
                            summary: subject,
                            onTap: () => _openSubjectReport(subject),
                            onOpenLatestResult: () =>
                                _openLatestSubjectResult(subject),
                          ),
                        ),
                      ),
                    const SizedBox(height: AppSpacing.section),
                    const _SectionLead(
                      title: 'Recent activity',
                      subtitle:
                          'These are your latest wins, kept short and easy to scan.',
                    ),
                    const SizedBox(height: AppSpacing.item),
                    if (data.dashboard.recentSessions.isEmpty)
                      const SoftPanel(
                        child: Text(
                          'No completed sessions yet. Start the next mission and the board will start telling your story.',
                        ),
                      )
                    else
                      ...data.dashboard.recentSessions.map(
                        (session) => Padding(
                          padding: const EdgeInsets.only(
                            bottom: AppSpacing.item,
                          ),
                          child: SoftPanel(
                            colors: [
                              Colors.white.withValues(alpha: 0.92),
                              AppPalette.teacherGradient.last.withValues(
                                alpha: 0.18,
                              ),
                            ],
                            child: Row(
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
                                    Icons.check_rounded,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.item),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        session.subjectName,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${session.sessionType} · ${session.completedQuestions} questions · ${session.focusScore}% focus',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodyMedium,
                                      ),
                                    ],
                                  ),
                                ),
                                const _MiniPill(label: 'Nice work'),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Positioned(
                right: AppSpacing.screen,
                bottom: AppSpacing.screen,
                child: _HelperBubbleButton(
                  onTap: () => _openHelper(data, mySubjects),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _startMissionWithChoice({
    required String studentId,
    required String subjectId,
    required String sessionType,
    required String subjectName,
  }) async {
    final choice = await showDialog<_MissionStartChoice>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Start Mission'),
          content: const Text(
            'Choose which mission type you want to start now.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(_MissionStartChoice.assessment),
              child: const Text('Assessment Mission'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(_MissionStartChoice.daily),
              child: const Text('Daily Mission'),
            ),
          ],
        );
      },
    );

    if (choice == null || !mounted) {
      return;
    }

    if (choice == _MissionStartChoice.assessment) {
      final mission = await _pickAssessmentMission(
        studentId: studentId,
        subjectId: subjectId,
        sessionType: sessionType,
      );
      if (!mounted) {
        return;
      }
      if (mission == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No assessment missions are assigned for this subject yet.',
            ),
          ),
        );
        return;
      }
      await _startDailyMission(
        studentId: studentId,
        subjectId: subjectId,
        sessionType: sessionType,
        subjectName: subjectName,
        missionId: mission.id,
      );
      return;
    }

    final dailyMission = await _pickDailyMission(
      studentId: studentId,
      subjectId: subjectId,
      sessionType: sessionType,
    );
    if (!mounted) {
      return;
    }
    if (dailyMission == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No daily missions are assigned for this subject yet.'),
        ),
      );
      return;
    }
    await _startDailyMission(
      studentId: studentId,
      subjectId: subjectId,
      sessionType: sessionType,
      subjectName: subjectName,
      missionId: dailyMission.id,
    );
  }

  Future<MissionPayload?> _pickAssessmentMission({
    required String studentId,
    required String subjectId,
    required String sessionType,
  }) async {
    final assignedMissions = await _api.fetchStudentAssignedMissions(
      token: _session.token,
      studentId: studentId,
      subjectId: subjectId,
      sessionType: sessionType,
    );
    final assessmentMissions = assignedMissions
        .where((mission) => mission.questionCount >= 10)
        .toList(growable: false);

    if (assessmentMissions.isEmpty) {
      return null;
    }
    if (!mounted) {
      return null;
    }

    return showModalBottomSheet<MissionPayload>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(AppSpacing.screen),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose Assessment Mission',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.compact),
              Text(
                'Select any assigned assessment mission to start now.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppPalette.textMuted),
              ),
              const SizedBox(height: AppSpacing.item),
              Expanded(
                child: ListView.separated(
                  itemCount: assessmentMissions.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.compact),
                  itemBuilder: (context, index) {
                    final mission = assessmentMissions[index];
                    return SoftPanel(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusLg,
                        ),
                        onTap: () => Navigator.of(context).pop(mission),
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.item),
                          child: Row(
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
                                child: const Icon(
                                  Icons.menu_book_rounded,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.item),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      mission.title,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${mission.subject?.name ?? 'Subject'} · ${mission.sessionType}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: AppPalette.textMuted,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right_rounded),
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
        );
      },
    );
  }

  Future<MissionPayload?> _pickDailyMission({
    required String studentId,
    required String subjectId,
    required String sessionType,
  }) async {
    final assignedMissions = await _api.fetchStudentAssignedMissions(
      token: _session.token,
      studentId: studentId,
      subjectId: subjectId,
      sessionType: sessionType,
    );
    final dailyMissions = assignedMissions
        // WHY: Daily launchers must include the newer THEORY and ESSAY mission
        // formats as well as legacy 5/8-question missions. Restricting this to
        // 5-8 questions hides valid teacher-assigned daily work like 2-question
        // theory missions from the student.
        .where((mission) => !_isAssessmentMission(mission))
        .toList(growable: false);

    if (dailyMissions.isEmpty) {
      return null;
    }
    if (!mounted) {
      return null;
    }

    return showModalBottomSheet<MissionPayload>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(AppSpacing.screen),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose Daily Mission',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.compact),
              Text(
                'Select any assigned daily mission for this lesson.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppPalette.textMuted),
              ),
              const SizedBox(height: AppSpacing.item),
              Expanded(
                child: ListView.separated(
                  itemCount: dailyMissions.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.compact),
                  itemBuilder: (context, index) {
                    final mission = dailyMissions[index];
                    return SoftPanel(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusLg,
                        ),
                        onTap: () => Navigator.of(context).pop(mission),
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.item),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: AppPalette.studentGradient,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.bolt_rounded,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.item),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      mission.title,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${mission.subject?.name ?? 'Subject'} · ${_dailyMissionLabel(mission)} · ${mission.sessionType}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: AppPalette.textMuted,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right_rounded),
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
        );
      },
    );
  }

  bool _isAssessmentMission(MissionPayload mission) {
    return mission.questionCount >= 10;
  }

  String _dailyMissionLabel(MissionPayload mission) {
    switch (mission.draftFormat.trim().toUpperCase()) {
      case 'THEORY':
        return '${mission.questionCount} theory ${mission.questionCount == 1 ? 'question' : 'questions'}';
      case 'ESSAY_BUILDER':
        return 'essay builder';
      default:
        return '${mission.questionCount} questions';
    }
  }

  Future<void> _startDailyMission({
    required String studentId,
    required String subjectId,
    required String sessionType,
    required String subjectName,
    String? missionId,
  }) async {
    try {
      final previousStudent = _session.user;
      final startedMission = await _api.startSession(
        token: _session.token,
        studentId: studentId,
        subjectId: subjectId,
        sessionType: sessionType,
        missionId: missionId,
      );

      if (!mounted) {
        return;
      }

      final updatedStudent = await Navigator.of(context).push<AppUser>(
        MaterialPageRoute(
          builder: (_) => MissionPlayScreen(
            session: _session,
            startedMission: startedMission,
          ),
        ),
      );

      if (!mounted) {
        return;
      }

      if (updatedStudent != null) {
        setState(() {
          _session = _session.copyWith(
            user: _session.user.copyWith(
              xp: updatedStudent.xp,
              streak: updatedStudent.streak,
              streakBadgeUnlocked: updatedStudent.streakBadgeUnlocked,
              firstLoginAt: updatedStudent.firstLoginAt,
              lastLoginAt: updatedStudent.lastLoginAt,
              loginDayCount: updatedStudent.loginDayCount,
              daysSinceFirstLogin: updatedStudent.daysSinceFirstLogin,
            ),
          );
        });
        _refreshData();
        _queueMissionMomentumPopup(
          previousStudent: previousStudent,
          updatedStudent: updatedStudent,
          subjectName: subjectName,
          sessionType: sessionType,
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$subjectName $sessionType mission opened.')),
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

  Future<void> _openProfile() async {
    final updatedUser = await showProfileSheet(
      context,
      session: _session,
      api: _api,
      onSignOut: _signOut,
    );

    if (updatedUser == null || !mounted) {
      return;
    }

    final nextSession = _session.copyWith(user: updatedUser);
    await _sessionStore.saveSession(nextSession);
    setState(() {
      _session = nextSession;
    });
    _refreshData();
  }

  Future<void> _signOut() async {
    await _sessionStore.clearSession();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const RoleSelectionScreen()),
      (_) => false,
    );
  }

  Future<void> _openSubjectReport(StudentSubjectReportSummary summary) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => StudentSubjectReportScreen(
          session: _session,
          subjectId: summary.subjectId,
          api: _api,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    _refreshData();
  }

  Future<void> _openLatestSubjectResult(
    StudentSubjectReportSummary summary,
  ) async {
    try {
      final report = await _loadSubjectReport(summary.subjectId);

      if (!mounted) {
        return;
      }

      // WHY: The dashboard shortcut should open the newest completed result
      // quickly, but it must fail calmly when a subject has no saved evidence.
      if (report.missionHistory.isEmpty ||
          report.missionHistory.first.resultPackageId.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No completed results are saved for ${summary.subjectName} yet.',
            ),
          ),
        );
        return;
      }

      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => StudentResultReportScreen(
            session: _session,
            resultPackageId: report.missionHistory.first.resultPackageId,
            api: _api,
          ),
        ),
      );

      if (!mounted) {
        return;
      }

      _refreshData();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _openStandalonePaper(StandalonePaperAvailability paper) async {
    final latestSession = paper.latestSession;
    if (latestSession != null &&
        latestSession.isSubmitted &&
        latestSession.resultPackageId.trim().isNotEmpty) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => StudentResultReportScreen(
            session: _session,
            resultPackageId: latestSession.resultPackageId,
            api: _api,
          ),
        ),
      );
    } else {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => StandalonePaperPlayScreen(
            session: _session,
            paperId: paper.id,
            initialAvailability: paper,
            api: _api,
          ),
        ),
      );
    }

    if (!mounted) {
      return;
    }
    _refreshData();
  }

  List<StudentSubjectReportSummary> _buildSubjectSummaries(
    _StudentScreenData data,
  ) {
    final progressById = <String, SubjectProgressSummary>{
      for (final progress in data.dashboard.subjectProgress)
        progress.subjectId: progress,
    };
    final certificationById = <String, SubjectCertificationSummary>{
      for (final certification in data.dashboard.subjectCertification)
        certification.subjectId: certification,
    };
    final subjectSeeds = <String, _DashboardSubjectSeed>{};
    final timetableOrder = <String, int>{};
    var nextTimetableOrder = 0;

    void mergeSubject({
      required String subjectId,
      required String subjectName,
      String? subjectIcon,
      String? subjectColor,
      bool fromTimetable = false,
    }) {
      final id = subjectId.trim();
      final name = subjectName.trim();
      if (id.isEmpty || name.isEmpty) {
        return;
      }

      final existing = subjectSeeds[id];
      if (existing == null) {
        subjectSeeds[id] = _DashboardSubjectSeed(
          subjectId: id,
          subjectName: name,
          subjectIcon: subjectIcon?.trim() ?? '',
          subjectColor: subjectColor?.trim() ?? '',
        );
      } else {
        if (existing.subjectIcon.isEmpty &&
            (subjectIcon ?? '').trim().isNotEmpty) {
          existing.subjectIcon = subjectIcon!.trim();
        }
        if (existing.subjectColor.isEmpty &&
            (subjectColor ?? '').trim().isNotEmpty) {
          existing.subjectColor = subjectColor!.trim();
        }
      }

      if (fromTimetable) {
        timetableOrder.putIfAbsent(id, () => nextTimetableOrder++);
      }
    }

    // WHY: Students should first see subjects they are actually taught this
    // week, then keep any evidence-only subjects so existing progress is never
    // hidden just because the timetable payload changes later.
    for (final day in data.timetable) {
      mergeSubject(
        subjectId: day.morningMission.id,
        subjectName: day.morningMission.name,
        subjectIcon: day.morningMission.icon,
        subjectColor: day.morningMission.color,
        fromTimetable: true,
      );
      mergeSubject(
        subjectId: day.afternoonMission.id,
        subjectName: day.afternoonMission.name,
        subjectIcon: day.afternoonMission.icon,
        subjectColor: day.afternoonMission.color,
        fromTimetable: true,
      );
    }

    for (final progress in data.dashboard.subjectProgress) {
      mergeSubject(
        subjectId: progress.subjectId,
        subjectName: progress.subjectName,
        subjectIcon: progress.subjectIcon,
        subjectColor: progress.subjectColor,
      );
    }

    for (final certification in data.dashboard.subjectCertification) {
      mergeSubject(
        subjectId: certification.subjectId,
        subjectName: certification.subjectName,
        subjectIcon: certification.subjectIcon,
        subjectColor: certification.subjectColor,
      );
    }

    final summaries = subjectSeeds.values.toList(growable: false)
      ..sort((left, right) {
        final leftOrder = timetableOrder[left.subjectId];
        final rightOrder = timetableOrder[right.subjectId];
        if (leftOrder != null && rightOrder != null) {
          return leftOrder.compareTo(rightOrder);
        }
        if (leftOrder != null) {
          return -1;
        }
        if (rightOrder != null) {
          return 1;
        }
        return left.subjectName.toLowerCase().compareTo(
          right.subjectName.toLowerCase(),
        );
      });

    return summaries
        .map((seed) {
          final progress = progressById[seed.subjectId];
          final certification = certificationById[seed.subjectId];
          return StudentSubjectReportSummary(
            subjectId: seed.subjectId,
            subjectName: seed.subjectName,
            subjectIcon: seed.subjectIcon,
            subjectColor: seed.subjectColor,
            assessmentCompletionPercentage: progress?.completionPercentage ?? 0,
            assessmentAverageScore: progress?.averageScore ?? 0,
            certificationEnabled: certification?.certificationEnabled ?? false,
            certificationCompletionPercentage:
                certification?.completionPercentage ?? 0,
            passedTaskFocusCount: certification?.passedTaskCodes.length ?? 0,
            requiredTaskFocusCount:
                certification?.requiredTaskCodes.length ?? 0,
            remainingTaskCodes: certification?.remainingTaskCodes ?? const [],
            certificateUnlocked: certification?.certificateUnlocked ?? false,
          );
        })
        .toList(growable: false);
  }

  int _averageFocus(List<SessionSummary> sessions) {
    if (sessions.isEmpty) {
      return 0;
    }

    final total = sessions.fold<int>(0, (sum, item) => sum + item.focusScore);
    return (total / sessions.length).round();
  }

  String _missionSubtitle(String subject, String room, String? teacher) {
    final teacherPart = teacher == null || teacher.isEmpty ? '' : ' · $teacher';
    return '$subject · $room$teacherPart';
  }

  String _journeyLabel(AppUser student) {
    final dayNumber = student.daysSinceFirstLogin > 0
        ? student.daysSinceFirstLogin
        : 1;
    final streak = student.streak > 0 ? student.streak : 1;

    return 'Day $dayNumber journey · $streak day streak';
  }

  void _maybeShowSubjectCompletionBonus(DailyXpSummary summary) {
    if (!_isPopupStorageReady) {
      return;
    }

    final bonusXp = summary.subjectCompletionBonusXp;
    if (bonusXp <= 0) {
      return;
    }

    final key = '${_session.user.id}:${summary.dateKey}:$bonusXp';
    if (_shownSubjectBonusKeys.contains(key)) {
      return;
    }

    _shownSubjectBonusKeys.add(key);
    () async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList(
          _shownSubjectBonusStorageKey,
          _shownSubjectBonusKeys.toList(growable: false),
        );
      } catch (error) {
        // WHY: Bonus modal suppression should not block student flow if local
        // persistence is temporarily unavailable.
      }
    }();

    _enqueuePopup(() async {
      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
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
                    'Subject Bonus Awarded',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.item),
                  Text(
                    'You completed a subject and earned +$bonusXp bonus XP today. Tiny confetti moment unlocked.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: AppSpacing.section),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Great'),
                  ),
                ],
              ),
            ),
          );
        },
      );
    });
  }

  void _maybeShowDailyLoginBonus(DailyXpSummary summary) {
    if (_hasQueuedDailyLoginBonus) {
      return;
    }

    if (!_session.loginMeta.dailyLoginRewardGranted ||
        _session.loginMeta.dailyLoginXpAwarded <= 0) {
      return;
    }

    _hasQueuedDailyLoginBonus = true;
    _enqueuePopup(() async {
      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (context) {
          return Dialog(
            insetPadding: const EdgeInsets.all(AppSpacing.screen),
            backgroundColor: Colors.transparent,
            child: SoftPanel(
              colors: const [Color(0xFFFFFCF4), Color(0xFFE8F7FF)],
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppPalette.sun, AppPalette.primaryBlue],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.bolt_rounded,
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
                              'Daily bonus unlocked',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Nice one, ${_firstName(_session.user.name)}. You picked up +${_session.loginMeta.dailyLoginXpAwarded} XP for showing up today.',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppPalette.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.item),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _MiniPill(
                        label:
                            '+${_session.loginMeta.dailyLoginXpAwarded} XP today',
                      ),
                      _MiniPill(
                        label:
                            '${summary.totalXp}/${summary.totalXpCap} XP on the board',
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.section),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.rocket_launch_rounded),
                      label: const Text('Keep going'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    });
  }

  void _maybeShowDailyWelcome(
    _StudentScreenData data,
    List<StudentSubjectReportSummary> subjects,
  ) {
    if (!_isPopupStorageReady) {
      return;
    }

    final dateKey = data.dashboard.dailyXp.dateKey.trim().isEmpty
        ? DateTime.now().toIso8601String().split('T').first
        : data.dashboard.dailyXp.dateKey.trim();
    final storageKey = '${_session.user.id}:$dateKey';
    if (_shownDailyWelcomeKeys.contains(storageKey)) {
      return;
    }

    _shownDailyWelcomeKeys.add(storageKey);
    () async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList(
          _shownDailyWelcomeStorageKey,
          _shownDailyWelcomeKeys.toList(growable: false),
        );
      } catch (error) {
        // WHY: The welcome popup is supportive polish; if storage misses, the
        // dashboard still needs to stay usable.
      }
    }();

    final today = data.dashboard.today;
    final moodCopy = today == null
        ? 'Fresh board, soft landing. I can cheer you on while your next mission is being added.'
        : 'Your board is ready with ${today.morningMission.name} and ${today.afternoonMission.name}. Pick one calm win.';

    _enqueuePopup(() async {
      if (!mounted) {
        return;
      }

      final action = await showDialog<_DailyWelcomeAction>(
        context: context,
        builder: (context) {
          return Dialog(
            insetPadding: const EdgeInsets.all(AppSpacing.screen),
            backgroundColor: Colors.transparent,
            child: SoftPanel(
              colors: const [Color(0xFFFFFCF4), Color(0xFFE9F8FF)],
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppPalette.sun, AppPalette.aqua],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.waving_hand_rounded,
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
                              'Morning, ${_firstName(_session.user.name)}',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              moodCopy,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppPalette.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.item),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _MiniPill(
                        label:
                            '${data.dashboard.dailyXp.totalXp}/${data.dashboard.dailyXp.totalXpCap} XP today',
                      ),
                      _MiniPill(
                        label: '${data.dashboard.student.streak} day streak',
                      ),
                      _MiniPill(label: '${subjects.length} subjects'),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.section),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        onPressed: () => Navigator.of(
                          context,
                        ).pop(_DailyWelcomeAction.helper),
                        icon: const Icon(Icons.chat_bubble_rounded),
                        label: const Text('Ask helper'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: today == null
                            ? null
                            : () => Navigator.of(
                                context,
                              ).pop(_DailyWelcomeAction.missions),
                        icon: const Icon(Icons.rocket_launch_rounded),
                        label: Text(
                          today == null
                              ? 'Waiting for mission'
                              : 'Show mission',
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(
                          context,
                        ).pop(_DailyWelcomeAction.close),
                        child: const Text('Later'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );

      if (!mounted) {
        return;
      }

      switch (action) {
        case _DailyWelcomeAction.helper:
          await _openHelper(data, subjects);
          break;
        case _DailyWelcomeAction.missions:
          await _scrollToTodaySection();
          break;
        case _DailyWelcomeAction.close:
        case null:
          break;
      }
    });
  }

  Future<StudentSubjectReportData> _loadSubjectReport(String subjectId) {
    final cached = _subjectReportCache[subjectId];
    if (cached != null) {
      return Future<StudentSubjectReportData>.value(cached);
    }

    final inFlight = _subjectReportRequests[subjectId];
    if (inFlight != null) {
      return inFlight;
    }

    final request = _api
        .fetchStudentSubjectReport(
          token: _session.token,
          studentId: _session.user.id,
          subjectId: subjectId,
        )
        .then((report) {
          _subjectReportCache[subjectId] = report;
          _subjectReportRequests.remove(subjectId);
          return report;
        })
        .catchError((error) {
          _subjectReportRequests.remove(subjectId);
          throw error;
        });

    _subjectReportRequests[subjectId] = request;
    return request;
  }

  Future<void> _openHelper(
    _StudentScreenData data,
    List<StudentSubjectReportSummary> subjects,
  ) {
    return showFlexibleLearningHelperSheet(
      context,
      session: _session,
      dashboard: data.dashboard,
      timetable: data.timetable,
      subjects: subjects,
      loadSubjectReport: _loadSubjectReport,
    );
  }

  Future<void> _scrollToTodaySection() async {
    final targetContext = _todaySectionKey.currentContext;
    if (targetContext == null) {
      return;
    }

    await Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
      alignment: 0.06,
    );
  }

  void _queueMissionMomentumPopup({
    required AppUser previousStudent,
    required AppUser updatedStudent,
    required String subjectName,
    required String sessionType,
  }) {
    final gainedXp = updatedStudent.xp - previousStudent.xp;
    final streakGrew = updatedStudent.streak > previousStudent.streak;
    final xpMilestoneCrossed =
        previousStudent.xp ~/ 100 != updatedStudent.xp ~/ 100;

    if (gainedXp <= 0 && !streakGrew && !xpMilestoneCrossed) {
      return;
    }

    _enqueuePopup(() async {
      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (context) {
          return Dialog(
            insetPadding: const EdgeInsets.all(AppSpacing.screen),
            backgroundColor: Colors.transparent,
            child: SoftPanel(
              colors: const [Color(0xFFF8FFFB), Color(0xFFFFF8EF)],
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    xpMilestoneCrossed
                        ? 'XP Milestone Hit'
                        : streakGrew
                        ? 'Streak Growing'
                        : 'Mission Win',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.item),
                  Text(
                    'Your $sessionType $subjectName mission pushed the board forward.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: AppSpacing.compact),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (gainedXp > 0) _MiniPill(label: '+$gainedXp XP'),
                      if (streakGrew)
                        _MiniPill(label: '${updatedStudent.streak} day streak'),
                      if (xpMilestoneCrossed)
                        _MiniPill(label: '${updatedStudent.xp} XP total'),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.section),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Nice'),
                  ),
                ],
              ),
            ),
          );
        },
      );
    });
  }

  String _heroTitleBadge(TodaySchedule? today) {
    if (today == null) {
      return 'Helper mode';
    }
    return '${today.morningMission.name} + ${today.afternoonMission.name} day';
  }

  String _heroHighlightMessage(_StudentScreenData data, TodaySchedule? today) {
    final remainingXp =
        (data.dashboard.dailyXp.totalXpCap - data.dashboard.dailyXp.totalXp)
            .clamp(0, data.dashboard.dailyXp.totalXpCap);
    if (today == null) {
      return 'Your board is calm right now. The helper can still cheer you on while lessons are being lined up.';
    }
    return 'You have $remainingXp XP left in today\'s target and ${today.morningMission.name} is ready whenever you are.';
  }

  void _enqueuePopup(Future<void> Function() popup) {
    _popupQueue.add(popup);
    _drainPopupQueue();
  }

  Future<void> _drainPopupQueue() async {
    if (_isPopupVisible || _popupQueue.isEmpty || !mounted) {
      return;
    }

    _isPopupVisible = true;
    final popup = _popupQueue.removeAt(0);
    try {
      await popup();
    } finally {
      _isPopupVisible = false;
      if (mounted && _popupQueue.isNotEmpty) {
        _drainPopupQueue();
      }
    }
  }

  String _firstName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return 'friend';
    }
    return trimmed.split(RegExp(r'\s+')).first;
  }
}

class _StudentScreenData {
  const _StudentScreenData({
    required this.session,
    required this.dashboard,
    required this.timetable,
  });

  final AuthSession session;
  final StudentDashboardData dashboard;
  final List<TodaySchedule> timetable;
}

class _LoadingState extends StatelessWidget {
  const _LoadingState({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.screen),
        child: SoftPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: AppSpacing.item),
              Text(label, style: Theme.of(context).textTheme.bodyLarge),
            ],
          ),
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
        child: SoftPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Could not load the dashboard',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.item),
              Text(message, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: AppSpacing.section),
              FilledButton(onPressed: onBack, child: const Text('Go Back')),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScreenHeader extends StatelessWidget {
  const _ScreenHeader({
    required this.title,
    required this.subtitle,
    required this.onBack,
    required this.user,
    required this.onLogout,
    required this.onProfileTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;
  final AppUser user;
  final VoidCallback onLogout;
  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _RoundIconButton(icon: Icons.arrow_back_ios_new_rounded, onTap: onBack),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppPalette.textMuted),
              ),
            ],
          ),
        ),
        ProfileAvatarButton(
          user: user,
          onLogout: onLogout,
          onTap: onProfileTap,
        ),
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.74),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Icon(icon, color: AppPalette.navy, size: 20),
      ),
    );
  }
}

class _DailyXpPanel extends StatelessWidget {
  const _DailyXpPanel({required this.summary});

  final DailyXpSummary summary;

  @override
  Widget build(BuildContext context) {
    return SoftPanel(
      colors: const [Color(0xFFFFFCFF), Color(0xFFEAF9FF)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Daily XP rocket',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const _MiniPill(label: 'Keep it light'),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Every little point counts. You do not need a perfect day to make progress.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppPalette.textMuted),
          ),
          const SizedBox(height: 10),
          Text(
            '${summary.totalXp} / ${summary.totalXpCap} XP',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            minHeight: 10,
            value: summary.totalXpCap == 0
                ? 0
                : (summary.totalXp / summary.totalXpCap).clamp(0, 1),
            borderRadius: BorderRadius.circular(999),
            backgroundColor: Colors.white.withValues(alpha: 0.66),
            valueColor: const AlwaysStoppedAnimation<Color>(
              AppPalette.primaryBlue,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniPill(
                label:
                    'Performance ${summary.performanceXp}/${summary.performanceXpCap}',
              ),
              _MiniPill(label: 'Daily bonus ${summary.dailyLoginXp}/20'),
              _MiniPill(label: 'Challenge ${summary.challengeXp}/30'),
              _MiniPill(label: 'Assessment ${summary.assessmentXp}/50'),
              _MiniPill(
                label: 'Targets ${summary.targetXp}/${summary.targetXpCap}',
              ),
              _MiniPill(
                label:
                    'Weekly targets ${summary.weeklyTargetXp}/${summary.weeklyTargetXpCap}',
              ),
              if (summary.subjectCompletionBonusXp > 0)
                _MiniPill(
                  label: 'Subject bonus +${summary.subjectCompletionBonusXp}',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionLead extends StatelessWidget {
  const _SectionLead({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
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
    );
  }
}

class _MiniPill extends StatelessWidget {
  const _MiniPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.68),
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

class _MySubjectCard extends StatelessWidget {
  const _MySubjectCard({
    required this.summary,
    required this.onTap,
    required this.onOpenLatestResult,
  });

  final StudentSubjectReportSummary summary;
  final VoidCallback onTap;
  final VoidCallback onOpenLatestResult;

  @override
  Widget build(BuildContext context) {
    final subjectColor = _mySubjectColor(summary.subjectColor);
    final remainingLabel = summary.remainingTaskCodes.isEmpty
        ? summary.certificateUnlocked
              ? 'Certificate unlocked'
              : summary.certificationEnabled
              ? 'Teacher review may still be pending'
              : 'Certification is not active for this subject yet'
        : 'Still needed: ${summary.remainingTaskCodes.join(', ')}';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
      child: SoftPanel(
        colors: [
          subjectColor.withValues(alpha: 0.16),
          Colors.white.withValues(alpha: 0.84),
        ],
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: subjectColor,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                _mySubjectIcon(summary.subjectName, summary.subjectIcon),
                color: Colors.white,
              ),
            ),
            const SizedBox(width: AppSpacing.item),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          summary.subjectName,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      if (summary.certificateUnlocked)
                        const _MiniPill(label: 'Certificate unlocked'),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Assessment ${summary.assessmentCompletionPercentage}% · ${summary.assessmentAverageScore}% average',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppPalette.textMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    summary.certificationEnabled
                        ? '${summary.passedTaskFocusCount}/${summary.requiredTaskFocusCount} task focuses passed'
                        : 'No active certification template',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppPalette.navy,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    remainingLabel,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppPalette.textMuted,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.item),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: onTap,
                        icon: const Icon(Icons.visibility_rounded),
                        label: const Text('View subject report'),
                      ),
                      OutlinedButton.icon(
                        onPressed: onOpenLatestResult,
                        icon: const Icon(Icons.article_rounded),
                        label: const Text('Open latest result'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HelperBubbleButton extends StatelessWidget {
  const _HelperBubbleButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 760;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 16 : 18,
            vertical: isCompact ? 16 : 14,
          ),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppPalette.aqua, AppPalette.primaryBlue],
            ),
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: AppPalette.primaryBlue.withValues(alpha: 0.28),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.chat_bubble_rounded,
                color: Colors.white,
                size: 22,
              ),
              if (!isCompact) ...[
                const SizedBox(width: 10),
                Text(
                  'Helper',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: Colors.white),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

Color _mySubjectColor(String value) {
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

String _standaloneSessionLabel(String value) {
  return value.trim().toLowerCase() == 'afternoon' ? 'Afternoon' : 'Morning';
}

String _standaloneStatusLabel(String value) {
  switch (value.trim().toLowerCase()) {
    case 'active':
      return 'In progress';
    case 'locked':
      return 'Locked';
    case 'submitted':
      return 'Submitted';
    case 'time_expired':
      return 'Time up';
    default:
      return 'Ready';
  }
}

String _standaloneActionLabel(StandalonePaperAvailability paper) {
  final latestSession = paper.latestSession;
  if (latestSession != null &&
      latestSession.isSubmitted &&
      latestSession.resultPackageId.trim().isNotEmpty) {
    return 'View result';
  }
  if (latestSession?.isActive == true) {
    return 'Resume ${paper.isExam ? 'Exam' : 'Test'}';
  }
  if (latestSession?.isLocked == true) {
    return 'Open ${paper.isExam ? 'Exam' : 'Test'}';
  }
  return 'Start ${paper.isExam ? 'Exam' : 'Test'}';
}

IconData _mySubjectIcon(String subjectName, String rawIcon) {
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

class _DashboardSubjectSeed {
  _DashboardSubjectSeed({
    required this.subjectId,
    required this.subjectName,
    required this.subjectIcon,
    required this.subjectColor,
  });

  final String subjectId;
  final String subjectName;
  String subjectIcon;
  String subjectColor;
}
