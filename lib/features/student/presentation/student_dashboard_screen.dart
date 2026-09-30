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
 * Load existing dashboard and timetable data, render compact progress and
 * responsive subject cards, and keep both session containers visible even
 * without a schedule. Existing actions, helper and encouragement flows remain.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import '../../../shared/widgets/xp_leaderboard_sheet.dart';
import 'package:flutter/material.dart';
import 'pong_home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_palette.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/auth_session_store.dart';
import '../../../core/utils/focus_mission_api.dart';
import '../../../shared/models/focus_mission_models.dart';
import '../../../shared/models/xp_journey.dart';
import '../../../shared/widgets/focus_scaffold.dart';
import '../../../shared/widgets/mission_card.dart';
import '../../../shared/widgets/profile_avatar_button.dart';
import '../../../shared/widgets/profile_sheet.dart';
import '../../../shared/widgets/progress_hero_card.dart';
import '../../../shared/widgets/soft_panel.dart';
import '../../auth/presentation/role_selection_screen.dart';
import 'flexible_learning_helper_sheet.dart';
import 'mission_play_screen.dart';
import 'standalone_paper_play_screen.dart';
import 'student_result_report_screen.dart';
import 'student_subject_report_screen.dart';

class StudentDashboardScreen extends StatefulWidget {
  const StudentDashboardScreen({super.key, required this.session, this.api});

  final AuthSession session;
  final FocusMissionApi? api;

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

enum _DailyWelcomeAction { helper, missions, close }

enum _StudentMissionType {
  objective('Objective'),
  theory('Theory'),
  essay('Essay'),
  assessmentA('Assessment A'),
  assessmentB('Assessment B'),
  unknown('Type unavailable');

  const _StudentMissionType(this.label);

  final String label;
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  late final FocusMissionApi _api;
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
    _api = widget.api ?? FocusMissionApi();
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
                      onProfileTap: () => _openProfile(
                        data.dashboard.student.xp,
                        data.dashboard.xpAchievements,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.section),
                    ProgressHeroCard(
                      name: _session.user.name,
                      streakLabel: _journeyLabel(data.dashboard.student),
                      currentXp: data.dashboard.student.xp,
                      goalXp: XpJourney.goalXp,
                      showXpJourney: true,
                      xpAchievements: data.dashboard.xpAchievements,
                      onLeaderboard: () => showXpLeaderboard(
                        context,
                        api: _api,
                        token: _session.token,
                      ),
                      trailingIcon: Icons.emoji_events_rounded,
                      avatarUrl: _session.user.avatar,
                      titleBadge:
                          data.dashboard.assignedMissions.any(
                            (m) => !m.isAssignmentLocked,
                          )
                          ? 'Work ready'
                          : _heroTitleBadge(today),
                      highlightMessage: _heroHighlightMessage(data, today),
                      statBadges: <String>[
                        '${mySubjects.length} subjects',
                        '${data.dashboard.dailyXp.totalXp}/${data.dashboard.dailyXp.totalXpCap} XP today',
                        '${_averageFocus(data.dashboard.recentSessions)}% focus average',
                      ],
                    ),
                    const SizedBox(height: AppSpacing.item),
                    _DailyXpPanel(summary: data.dashboard.dailyXp),
                    const SizedBox(height: AppSpacing.item),
                    PongDashboardCard(token: _session.token),
                    const SizedBox(height: AppSpacing.section),
                    KeyedSubtree(
                      key: _todaySectionKey,
                      child: _SectionLead(
                        title: "Today's lessons",
                        subtitle: today == null
                            ? 'No lessons scheduled today. Your available missions stay below.'
                            : '${today.day} · Your scheduled morning and afternoon lessons.',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.item),
                    // WHY: Empty session slots are still part of the day. Keep
                    // both visible; scheduled lessons retain their existing picker.
                    _StudentCardGrid(
                      maxColumns: 2,
                      minCardWidth: 350,
                      children: [
                        if (today != null)
                          MissionCard(
                            title: 'Morning session',
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
                              lessonDate: data.dashboard.dailyXp.dateKey,
                              studentId: data.dashboard.student.id,
                              subjectId: today.morningMission.id,
                              sessionType: 'morning',
                              subjectName: today.morningMission.name,
                            ),
                          )
                        else
                          const _EmptySessionCard(
                            title: 'Morning session',
                            icon: Icons.wb_sunny_outlined,
                          ),
                        if (today != null)
                          MissionCard(
                            title: 'Afternoon session',
                            subtitle: _missionSubtitle(
                              today.afternoonMission.name,
                              today.room,
                              today.afternoonTeacher?.name,
                            ),
                            actionLabel: 'Start Mission',
                            icon: Icons.account_balance_rounded,
                            colors: const [
                              AppPalette.primaryBlue,
                              AppPalette.sun,
                            ],
                            eyebrow: 'Round two',
                            toneMessage:
                                'Steady beats speedy. One focused run is enough.',
                            featurePills: <String>[
                              today.afternoonMission.name,
                              today.room,
                            ],
                            onPressed: () => _startMissionWithChoice(
                              lessonDate: data.dashboard.dailyXp.dateKey,
                              studentId: data.dashboard.student.id,
                              subjectId: today.afternoonMission.id,
                              sessionType: 'afternoon',
                              subjectName: today.afternoonMission.name,
                            ),
                          )
                        else
                          const _EmptySessionCard(
                            title: 'Afternoon session',
                            icon: Icons.wb_twilight_rounded,
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.section),
                    _SectionLead(
                      title: 'Available Missions',
                      subtitle:
                          '${data.dashboard.assignedMissions.where((m) => !m.isAssignmentLocked).length} remaining · Available every day until completed.',
                    ),
                    const SizedBox(height: AppSpacing.item),
                    _AvailableMissionSummary(
                      missions: data.dashboard.assignedMissions,
                      onOpenSubject: (subjectId) {
                        final missions = data.dashboard.assignedMissions
                            .where(
                              (m) =>
                                  !m.isAssignmentLocked &&
                                  (subjectId == null ||
                                      m.subject?.id == subjectId),
                            )
                            .toList();
                        _openMissionPanel(
                          subjectId == null
                              ? 'Available Missions'
                              : '${missions.first.subject?.name ?? 'Subject'} · Available missions',
                          missions,
                        );
                      },
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
                      subtitle: 'Your focus, XP and recent sessions.',
                    ),
                    const SizedBox(height: AppSpacing.item),
                    SoftPanel(
                      solid: true,
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 4,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _WeeklyStat(
                            value:
                                '${_averageFocus(data.dashboard.recentSessions)}%',
                            label: 'Focus score',
                          ),
                          _WeeklyStat(
                            value: '${data.dashboard.student.xp}',
                            label: 'XP total',
                          ),
                          _WeeklyStat(
                            value: '${data.dashboard.recentSessions.length}',
                            label: 'Recent sessions',
                            divider: false,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.section),
                    const _SectionLead(
                      title: 'My Subjects',
                      subtitle:
                          'Choose a task focus for assigned work, or open your progress report.',
                    ),
                    const SizedBox(height: AppSpacing.item),
                    if (mySubjects.isEmpty)
                      const SoftPanel(
                        child: Text(
                          'No subjects are linked to your timetable yet. Your teacher will add them soon.',
                        ),
                      )
                    else
                      _StudentCardGrid(
                        maxColumns: 3,
                        minCardWidth: 330,
                        children: mySubjects
                            .map(
                              (subject) => _MySubjectCard(
                                summary: subject,
                                missions: data.dashboard.assignedMissions
                                    .where(
                                      (m) => m.subject?.id == subject.subjectId,
                                    )
                                    .toList(),
                                onTaskFocus: (taskCode) => _openTaskFocus(
                                  subject,
                                  taskCode,
                                  data.dashboard.assignedMissions,
                                ),
                                onTap: () => _openSubjectReport(subject),
                                onOpenLatestResult: () =>
                                    _openLatestSubjectResult(subject),
                              ),
                            )
                            .toList(growable: false),
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
                        solid: true,
                        padding: EdgeInsets.all(AppSpacing.item),
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
                            solid: true,
                            padding: const EdgeInsets.all(AppSpacing.item),
                            colors: [
                              Colors.white.withValues(alpha: 0.92),
                              AppPalette.teacherGradient.last.withValues(
                                alpha: 0.18,
                              ),
                            ],
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF218579),
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

  Future<void> _openAssignedMission(MissionPayload mission) async {
    if (mission.isAssignmentLocked) {
      if (mission.latestResultPackageId.isEmpty) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => StudentResultReportScreen(
            session: _session,
            resultPackageId: mission.latestResultPackageId,
            api: _api,
          ),
        ),
      );
      return;
    }
    await _startDailyMission(
      studentId: _session.user.id,
      subjectId: mission.subject!.id,
      sessionType: mission.sessionType,
      subjectName: mission.subject!.name,
      missionId: mission.id,
    );
  }

  Future<void> _openTaskFocus(
    StudentSubjectReportSummary subject,
    String? taskCode,
    List<MissionPayload> assignments,
  ) async {
    final missions = assignments
        .where(
          (m) =>
              m.subject?.id == subject.subjectId &&
              (taskCode == null || m.taskCodes.contains(taskCode)),
        )
        .toList();
    await _openMissionPanel(
      '${subject.subjectName} · ${taskCode ?? 'All task focuses'}',
      missions,
    );
  }

  Future<void> _openMissionPanel(
    String title,
    List<MissionPayload> missions,
  ) async {
    final chosen = await showModalBottomSheet<MissionPayload>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 720),
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: 0.8,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.item),
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              '${missions.where((m) => !m.isAssignmentLocked).length} available missions',
            ),
            const SizedBox(height: 16),
            for (final group in [
              'In progress',
              'Redo requested',
              'Available',
              'Completed',
            ]) ...[
              if (missions.any((m) => _missionPanelGroup(m) == group)) ...[
                Text(group, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ...missions
                    .where((m) => _missionPanelGroup(m) == group)
                    .map(
                      (mission) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _AssignedWorkRow(
                          mission: mission,
                          onAction: () =>
                              Navigator.of(sheetContext).pop(mission),
                        ),
                      ),
                    ),
              ],
            ],
          ],
        ),
      ),
    );
    if (chosen != null && mounted) await _openAssignedMission(chosen);
  }

  Future<void> _startMissionWithChoice({
    required String studentId,
    required String subjectId,
    required String sessionType,
    required String subjectName,
    required String lessonDate,
  }) async {
    final allMissions = await _api.fetchStudentAssignedMissions(
      token: _session.token,
      studentId: studentId,
      subjectId: subjectId,
      sessionType: sessionType,
    );
    final assignedMissions = allMissions
        .where(
          (mission) =>
              !mission.isAssignmentLocked &&
              mission.availableOnDate == lessonDate,
        )
        .toList();
    if (!mounted) {
      return;
    }
    if (assignedMissions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No unfinished missions for this lesson today. Check Available Missions for earlier work.',
          ),
        ),
      );
      return;
    }

    final mission = await showModalBottomSheet<MissionPayload>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 720),
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.9,
          child: StudentMissionPickerSheet(missions: assignedMissions),
        );
      },
    );

    if (mission == null || !mounted) {
      return;
    }
    await _startDailyMission(
      studentId: studentId,
      subjectId: subjectId,
      sessionType: sessionType,
      subjectName: subjectName,
      missionId: mission.id,
    );
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

      _refreshData();
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

  Future<void> _openProfile(
    int currentXp,
    List<XpAchievement> achievements,
  ) async {
    final updatedUser = await showProfileSheet(
      context,
      xpAchievements: achievements,
      // Use the same server balance as the hero rather than the login snapshot.
      session: _session.copyWith(user: _session.user.copyWith(xp: currentXp)),
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

    // A timetable change must not hide an older, unfinished assignment.
    for (final mission in data.dashboard.assignedMissions) {
      final subject = mission.subject;
      if (subject != null) {
        mergeSubject(
          subjectId: subject.id,
          subjectName: subject.name,
          subjectIcon: subject.icon,
          subjectColor: subject.color,
        );
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
    final remaining = data.dashboard.assignedMissions
        .where((m) => !m.isAssignmentLocked)
        .length;
    if (remaining > 0) {
      return '$remaining ${remaining == 1 ? 'mission is' : 'missions are'} ready whenever you are. Choose one from Available Missions.';
    }
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

/**
 * WHAT:
 * StudentMissionPickerSheet presents assigned missions as a compact, filtered
 * list grouped by the learner's task focus and mission format.
 * WHY:
 * Students need to distinguish P/M/D task focuses and Objective, Theory,
 * Essay, and Assessment work without scanning large repetitive cards.
 * HOW:
 * Derive only the filters present in the supplied missions, keep those controls
 * above a separately scrolling list, and return the selected mission.
 */
class StudentMissionPickerSheet extends StatefulWidget {
  const StudentMissionPickerSheet({super.key, required this.missions});

  final List<MissionPayload> missions;

  @override
  State<StudentMissionPickerSheet> createState() =>
      _StudentMissionPickerSheetState();
}

class _StudentMissionPickerSheetState extends State<StudentMissionPickerSheet> {
  String? _taskCode;
  _StudentMissionType? _missionType;

  List<String> get _taskCodes {
    final codes = widget.missions
        .expand((mission) => mission.taskCodes)
        .map((code) => code.trim().toUpperCase())
        .where((code) => code.isNotEmpty)
        .toSet()
        .toList(growable: false);
    codes.sort(_compareTaskCodes);
    return codes;
  }

  List<_StudentMissionType> get _missionTypes {
    final presentTypes = widget.missions.map(_studentMissionType).toSet();
    return _StudentMissionType.values
        .where(presentTypes.contains)
        .toList(growable: false);
  }

  List<MissionPayload> get _visibleMissions {
    final missions = widget.missions
        .where((mission) {
          final normalizedCodes = mission.taskCodes
              .map((code) => code.trim().toUpperCase())
              .toSet();
          final matchesTask =
              _taskCode == null || normalizedCodes.contains(_taskCode);
          final matchesType =
              _missionType == null ||
              _studentMissionType(mission) == _missionType;
          return matchesTask && matchesType;
        })
        .toList(growable: false);

    // WHY: A stable task-focus order makes P1, P2, P3, M1, and D1 work easy
    // to scan even before the learner applies a filter.
    missions.sort((left, right) {
      final taskComparison = _compareTaskCodes(
        _primaryTaskCode(left),
        _primaryTaskCode(right),
      );
      if (taskComparison != 0) {
        return taskComparison;
      }
      final typeComparison = _studentMissionType(
        left,
      ).index.compareTo(_studentMissionType(right).index);
      if (typeComparison != 0) {
        return typeComparison;
      }
      return left.displayTitle.toLowerCase().compareTo(
        right.displayTitle.toLowerCase(),
      );
    });
    return missions;
  }

  @override
  Widget build(BuildContext context) {
    final taskCodes = _taskCodes;
    final missionTypes = _missionTypes;
    final visibleMissions = _visibleMissions;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        0,
        AppSpacing.screen,
        AppSpacing.compact,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Choose Mission',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Filter by task focus or mission type.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppPalette.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Close mission chooser',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.compact),
          if (taskCodes.isNotEmpty) ...[
            _MissionFilterLabel(label: 'Task focus'),
            const SizedBox(height: 6),
            Wrap(
              key: const Key('student-mission-task-filters'),
              spacing: 8,
              runSpacing: 6,
              children: [
                _MissionFilterChip(
                  label: 'All',
                  selected: _taskCode == null,
                  onSelected: () => setState(() => _taskCode = null),
                ),
                ...taskCodes.map(
                  (code) => _MissionFilterChip(
                    label: code,
                    selected: _taskCode == code,
                    onSelected: () => setState(() => _taskCode = code),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.compact),
          ],
          _MissionFilterLabel(label: 'Mission type'),
          const SizedBox(height: 6),
          Wrap(
            key: const Key('student-mission-type-filters'),
            spacing: 8,
            runSpacing: 6,
            children: [
              _MissionFilterChip(
                label: 'All',
                selected: _missionType == null,
                onSelected: () => setState(() => _missionType = null),
              ),
              ...missionTypes.map(
                (type) => _MissionFilterChip(
                  label: type.label,
                  selected: _missionType == type,
                  onSelected: () => setState(() => _missionType = type),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.compact),
          Text(
            '${visibleMissions.length} ${visibleMissions.length == 1 ? 'mission' : 'missions'}',
            key: const Key('student-mission-result-count'),
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: AppPalette.textMuted),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: visibleMissions.isEmpty
                ? Center(
                    child: Text(
                      'No missions match both filters.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppPalette.textMuted,
                      ),
                    ),
                  )
                : ListView.separated(
                    key: const Key('student-mission-list'),
                    padding: const EdgeInsets.only(bottom: AppSpacing.compact),
                    itemCount: visibleMissions.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final mission = visibleMissions[index];
                      return _SlimMissionRow(
                        key: ValueKey('student-mission-${mission.id}'),
                        mission: mission,
                        onTap: () => Navigator.of(context).pop(mission),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _MissionFilterLabel extends StatelessWidget {
  const _MissionFilterLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(
        context,
      ).textTheme.labelLarge?.copyWith(color: AppPalette.navy),
    );
  }
}

class _MissionFilterChip extends StatelessWidget {
  const _MissionFilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      visualDensity: const VisualDensity(horizontal: -1, vertical: -1),
      onSelected: (_) => onSelected(),
    );
  }
}

class _SlimMissionRow extends StatelessWidget {
  const _SlimMissionRow({
    super.key,
    required this.mission,
    required this.onTap,
  });

  final MissionPayload mission;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final type = _studentMissionType(mission);
    final taskLabel = mission.taskCodes
        .map((code) => code.trim().toUpperCase())
        .where((code) => code.isNotEmpty)
        .join(' + ');
    final accent = _studentMissionAccent(type);

    return Material(
      color: Colors.white.withValues(alpha: 0.88),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        side: BorderSide(color: accent.withValues(alpha: 0.28)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_studentMissionIcon(type), color: accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      mission.displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppPalette.navy,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${taskLabel.isEmpty ? 'No task focus' : taskLabel} · ${type.label} · ${mission.subject?.name ?? 'Subject'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppPalette.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppPalette.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

_StudentMissionType _studentMissionType(MissionPayload mission) {
  final format = (mission.namingDraftFormat ?? mission.draftFormat)
      .trim()
      .toUpperCase();
  if (format == 'THEORY') {
    return _StudentMissionType.theory;
  }
  if (format == 'ESSAY_BUILDER') {
    return _StudentMissionType.essay;
  }

  final sequences = mission.assessmentSequenceByTaskCode.values
      .map((value) => value.trim().toUpperCase())
      .where((value) => value == 'A' || value == 'B')
      .toSet();
  if (sequences.contains('B') && !sequences.contains('A')) {
    return _StudentMissionType.assessmentB;
  }
  if (sequences.contains('A')) {
    // Classification uses stored assessment metadata, never question count.
    return _StudentMissionType.assessmentA;
  }
  return format == 'QUESTIONS'
      ? _StudentMissionType.objective
      : _StudentMissionType.unknown;
}

String _primaryTaskCode(MissionPayload mission) {
  final codes = mission.taskCodes
      .map((code) => code.trim().toUpperCase())
      .where((code) => code.isNotEmpty)
      .toList(growable: false);
  if (codes.isEmpty) {
    return '';
  }
  codes.sort(_compareTaskCodes);
  return codes.first;
}

int _compareTaskCodes(String left, String right) {
  final leftParts = _taskCodeParts(left);
  final rightParts = _taskCodeParts(right);
  final prefixComparison = leftParts.$1.compareTo(rightParts.$1);
  if (prefixComparison != 0) {
    return prefixComparison;
  }
  final numberComparison = leftParts.$2.compareTo(rightParts.$2);
  if (numberComparison != 0) {
    return numberComparison;
  }
  return left.compareTo(right);
}

(int, int) _taskCodeParts(String code) {
  final normalized = code.trim().toUpperCase();
  final match = RegExp(r'^([PMD])(\d+)$').firstMatch(normalized);
  if (match == null) {
    return (3, 999);
  }
  final prefixOrder = switch (match.group(1)) {
    'P' => 0,
    'M' => 1,
    'D' => 2,
    _ => 3,
  };
  return (prefixOrder, int.tryParse(match.group(2) ?? '') ?? 999);
}

IconData _studentMissionIcon(_StudentMissionType type) {
  return switch (type) {
    _StudentMissionType.unknown => Icons.help_outline_rounded,
    _StudentMissionType.objective => Icons.bolt_rounded,
    _StudentMissionType.theory => Icons.lightbulb_rounded,
    _StudentMissionType.essay => Icons.edit_note_rounded,
    _StudentMissionType.assessmentA ||
    _StudentMissionType.assessmentB => Icons.fact_check_rounded,
  };
}

Color _studentMissionAccent(_StudentMissionType type) {
  return switch (type) {
    _StudentMissionType.unknown => AppPalette.textMuted,
    _StudentMissionType.objective => const Color(0xFF4AB8A8),
    _StudentMissionType.theory => const Color(0xFF6586D9),
    _StudentMissionType.essay => const Color(0xFFB678D3),
    _StudentMissionType.assessmentA ||
    _StudentMissionType.assessmentB => const Color(0xFFE19445),
  };
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

class _StudentCardGrid extends StatelessWidget {
  const _StudentCardGrid({
    required this.children,
    required this.maxColumns,
    required this.minCardWidth,
  });
  final List<Widget> children;
  final int maxColumns;
  final double minCardWidth;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      // WHY: Keep mobile single-column and let longer copy grow naturally instead
      // of imposing tile heights that could hide buttons or certification states.
      final columns =
          ((constraints.maxWidth + AppSpacing.item) /
                  (minCardWidth + AppSpacing.item))
              .floor()
              .clamp(1, maxColumns);
      final width =
          (constraints.maxWidth - AppSpacing.item * (columns - 1)) / columns;
      return Wrap(
        spacing: AppSpacing.item,
        runSpacing: AppSpacing.item,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}

class _EmptySessionCard extends StatelessWidget {
  const _EmptySessionCard({required this.title, required this.icon});
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) => SoftPanel(
    solid: true,
    padding: const EdgeInsets.all(AppSpacing.item),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppPalette.navy,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'No mission assigned yet',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'Waiting for your teacher',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );
}

class _WeeklyStat extends StatelessWidget {
  const _WeeklyStat({
    required this.value,
    required this.label,
    this.divider = true,
  });
  final String value;
  final String label;
  final bool divider;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        border: divider
            ? Border(
                right: BorderSide(
                  color: AppPalette.navy.withValues(alpha: 0.14),
                ),
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    ),
  );
}

class _DailyXpPanel extends StatelessWidget {
  const _DailyXpPanel({required this.summary});

  final DailyXpSummary summary;

  @override
  Widget build(BuildContext context) {
    return SoftPanel(
      solid: true,
      padding: const EdgeInsets.all(AppSpacing.item),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Daily XP',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                '${summary.totalXp} / ${summary.totalXpCap} XP',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            minHeight: 8,
            value: summary.totalXpCap == 0
                ? 0
                : (summary.totalXp / summary.totalXpCap).clamp(0, 1),
            borderRadius: BorderRadius.circular(999),
            backgroundColor: AppPalette.navy.withValues(alpha: 0.08),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF218579)),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppPalette.navy.withValues(alpha: 0.06),
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
    required this.missions,
    required this.onTaskFocus,
  });

  final List<MissionPayload> missions;
  final ValueChanged<String?> onTaskFocus;
  final StudentSubjectReportSummary summary;
  final VoidCallback onTap;
  final VoidCallback onOpenLatestResult;

  @override
  Widget build(BuildContext context) {
    final availableCount = missions.where((m) => !m.isAssignmentLocked).length;
    final inProgressCount = missions
        .where(
          (m) => !m.isAssignmentLocked && m.assignmentStatus == 'in_progress',
        )
        .length;
    // Prioritise unfinished focuses while retaining completed work in the panel.
    final taskCodes = [
      ...missions.where((m) => !m.isAssignmentLocked),
      ...missions.where((m) => m.isAssignmentLocked),
    ].expand((m) => m.taskCodes).toSet().toList();
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
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: SoftPanel(
        solid: true,
        padding: const EdgeInsets.all(AppSpacing.item),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: subjectColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _mySubjectIcon(summary.subjectName, summary.subjectIcon),
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    summary.subjectName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Assessment ${summary.assessmentCompletionPercentage}% · ${summary.assessmentAverageScore}% average',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Text('Certification', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(
              summary.certificationEnabled
                  ? '${summary.passedTaskFocusCount}/${summary.requiredTaskFocusCount} task focuses passed'
                  : 'Not active',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppPalette.navy,
                fontWeight: FontWeight.w700,
              ),
            ),
            // WHY: Suppress only the duplicate inactive explanation. Unlocked,
            // pending-review and outstanding task-code states remain distinct.
            if (summary.certificationEnabled ||
                summary.certificateUnlocked ||
                summary.remainingTaskCodes.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                remainingLabel,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (missions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                availableCount == 0
                    ? 'All assigned work completed'
                    : '$availableCount ${availableCount == 1 ? 'mission' : 'missions'} available${inProgressCount > 0 ? ' · $inProgressCount in progress' : ''}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final code in taskCodes.take(6))
                    _TaskFocusChip(
                      code: code,
                      missions: missions
                          .where((m) => m.taskCodes.contains(code))
                          .toList(),
                      onTap: () => onTaskFocus(code),
                    ),
                  if (taskCodes.length > 6 ||
                      missions.any((m) => m.taskCodes.isEmpty))
                    ActionChip(
                      label: Text(
                        taskCodes.isEmpty
                            ? 'Assigned work'
                            : taskCodes.length > 6
                            ? '+${taskCodes.length - 6} more'
                            : 'All work',
                      ),
                      onPressed: () => onTaskFocus(null),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFEAF0F8),
                    foregroundColor: AppPalette.navy,
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: onTap,
                  icon: const Icon(Icons.visibility_rounded, size: 18),
                  label: const Text('View subject report'),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppPalette.navy,
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    side: BorderSide(
                      color: AppPalette.navy.withValues(alpha: 0.25),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: onOpenLatestResult,
                  icon: const Icon(Icons.article_rounded, size: 18),
                  label: const Text('Open latest result'),
                ),
              ],
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF187F79),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppPalette.primaryBlue.withValues(alpha: 0.28),
                blurRadius: 12,
                offset: const Offset(0, 4),
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
              ...[
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

// Both dashboard surfaces reference the same mission IDs and result links.
class _TaskFocusChip extends StatelessWidget {
  const _TaskFocusChip({
    required this.code,
    required this.missions,
    required this.onTap,
  });
  final String code;
  final List<MissionPayload> missions;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final availableCount = missions.where((m) => !m.isAssignmentLocked).length;
    final inProgress = missions.any(
      (m) => !m.isAssignmentLocked && m.assignmentStatus == 'in_progress',
    );
    final redo = missions.any((m) => m.isRedoRequested);
    final available = availableCount > 0;
    final label = inProgress
        ? 'In progress'
        : redo
        ? 'Redo requested'
        : available
        ? 'Available'
        : 'Completed and locked';
    final color = inProgress
        ? AppPalette.primaryBlue
        : redo
        ? const Color(0xFF9A6415)
        : available
        ? AppPalette.primaryBlue
        : const Color(0xFF227A68);
    final count = available ? availableCount : missions.length;
    return Tooltip(
      message:
          '$code · $label · $availableCount available · ${missions.length} total',
      child: ActionChip(
        avatar: Icon(
          inProgress
              ? Icons.play_arrow_rounded
              : redo
              ? Icons.replay_rounded
              : available
              ? Icons.circle
              : Icons.lock_outline,
          size: 16,
          color: color,
        ),
        label: Text(count > 1 ? '$code $count' : code),
        onPressed: onTap,
        backgroundColor: color.withValues(alpha: 0.08),
      ),
    );
  }
}

class _AssignedWorkRow extends StatelessWidget {
  const _AssignedWorkRow({required this.mission, required this.onAction});
  final MissionPayload mission;
  final VoidCallback onAction;
  @override
  Widget build(BuildContext context) {
    final locked = mission.isAssignmentLocked;
    final action = locked
        ? 'View result'
        : mission.assignmentStatus == 'in_progress'
        ? 'Continue'
        : mission.isRedoRequested
        ? 'Start again'
        : 'Start mission';
    return SoftPanel(
      solid: true,
      padding: const EdgeInsets.all(AppSpacing.item),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${mission.subject?.name ?? 'Subject'}${mission.taskCodes.isEmpty ? '' : ' · ${mission.taskCodes.join(', ')}'}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Text(
            mission.displayTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            '${mission.assignmentLabel} · Attempt ${mission.assignmentAttempt}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Text(
            'Assigned ${mission.availableOnDate ?? ''} · Original lesson: ${mission.availableOnDay ?? ''} ${mission.sessionType}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (mission.teacherNote.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              mission.teacherNote,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (locked && mission.completedAt != null)
            Text(
              'Completed ${mission.completedAt!.split('T').first}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: locked && mission.latestResultPackageId.isEmpty
                ? null
                : onAction,
            icon: Icon(
              locked
                  ? Icons.lock_outline
                  : mission.isRedoRequested
                  ? Icons.replay_rounded
                  : Icons.play_arrow_rounded,
              size: 18,
            ),
            label: Text(action),
          ),
        ],
      ),
    );
  }
}

String _missionPanelGroup(MissionPayload mission) {
  if (mission.isAssignmentLocked) return 'Completed';
  if (mission.assignmentStatus == 'in_progress') return 'In progress';
  if (mission.isRedoRequested) return 'Redo requested';
  return 'Available';
}

// The dashboard indexes subjects; individual assignment rows live only in the
// existing mission panel. Grouping here never creates or changes assignments.
class _AvailableMissionSummary extends StatelessWidget {
  const _AvailableMissionSummary({
    required this.missions,
    required this.onOpenSubject,
  });
  final List<MissionPayload> missions;
  final ValueChanged<String?> onOpenSubject;

  @override
  Widget build(BuildContext context) {
    final available = missions.where((m) => !m.isAssignmentLocked).toList();
    final bySubject = <String?, List<MissionPayload>>{};
    for (final mission in available) {
      bySubject.putIfAbsent(mission.subject?.id, () => []).add(mission);
    }
    final inProgress = available
        .where((m) => m.assignmentStatus == 'in_progress')
        .length;
    return SoftPanel(
      solid: true,
      padding: const EdgeInsets.all(AppSpacing.item),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (available.isEmpty)
            const Text('All caught up. New assignments will appear here.')
          else ...[
            if (inProgress > 0) ...[
              Text(
                '$inProgress in progress · Choose a subject to continue.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
            ],
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final entry in bySubject.entries)
                  Tooltip(
                    message:
                        '${entry.value.first.subject?.name ?? 'Subject'} · ${entry.value.length} available · ${entry.value.where((m) => m.assignmentStatus == 'in_progress').length} in progress',
                    child: ActionChip(
                      key: ValueKey('available_subject_${entry.key}'),
                      avatar: Icon(
                        entry.value.any(
                              (m) => m.assignmentStatus == 'in_progress',
                            )
                            ? Icons.play_arrow_rounded
                            : Icons.menu_book_outlined,
                        size: 18,
                        color: AppPalette.primaryBlue,
                      ),
                      label: Text(
                        '${entry.value.first.subject?.name ?? 'Subject'} ${entry.value.length}',
                      ),
                      onPressed: () => onOpenSubject(entry.key),
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: () => onOpenSubject(null),
                  icon: const Icon(Icons.list_alt_rounded, size: 18),
                  label: const Text('View all missions'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
