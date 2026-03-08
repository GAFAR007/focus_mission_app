/**
 * WHAT:
 * StudentDashboardScreen shows the student's daily missions, recent activity,
 * and qualification journey entry points.
 * WHY:
 * Students need one ADHD-friendly home screen where both daily practice and
 * real criterion progression are visible without hunting through menus.
 * HOW:
 * Load dashboard data plus criterion summaries, then render mission cards and
 * tappable criterion panels that open the dedicated journey flow.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_palette.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/focus_mission_api.dart';
import '../../../shared/models/focus_mission_models.dart';
import '../../../shared/widgets/focus_scaffold.dart';
import '../../../shared/widgets/mission_card.dart';
import '../../../shared/widgets/profile_avatar_button.dart';
import '../../../shared/widgets/profile_sheet.dart';
import '../../../shared/widgets/progress_hero_card.dart';
import '../../../shared/widgets/soft_panel.dart';
import '../../../shared/widgets/stat_chip.dart';
import 'criterion_journey_screen.dart';
import 'mission_play_screen.dart';
import 'student_result_report_screen.dart';
import 'student_subject_report_screen.dart';

class StudentDashboardScreen extends StatefulWidget {
  const StudentDashboardScreen({super.key, required this.session});

  final AuthSession session;

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

enum _MissionStartChoice { daily, assessment }

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  final FocusMissionApi _api = FocusMissionApi();
  static const String _shownSubjectBonusStorageKey =
      'shown_subject_bonus_keys_v1';
  final Set<String> _shownSubjectBonusKeys = <String>{};
  bool _isBonusStorageReady = false;

  late AuthSession _session;
  late Future<_StudentScreenData> _future;

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    _future = _loadData();
    _loadShownSubjectBonusKeys();
  }

  Future<_StudentScreenData> _loadData() async {
    final results = await Future.wait<dynamic>([
      _api.fetchStudentDashboard(
        token: _session.token,
        studentId: _session.user.id,
      ),
      _api.fetchStudentCriteria(
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
      criteria: (results[1] as StudentCriteriaData).criteria,
      timetable: results[2] as List<TodaySchedule>,
    );
  }

  void _refreshData() {
    setState(() {
      _future = _loadData();
    });
  }

  Future<void> _loadShownSubjectBonusKeys() async {
    List<String> storedKeys = const <String>[];
    try {
      final prefs = await SharedPreferences.getInstance();
      storedKeys =
          prefs.getStringList(_shownSubjectBonusStorageKey) ?? const <String>[];
    } catch (error) {
      // WHY: Web/plugin bootstrap can briefly miss shared_preferences during
      // hot restarts; fallback keeps the dashboard usable for testing.
      storedKeys = const <String>[];
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _shownSubjectBonusKeys
        ..clear()
        ..addAll(storedKeys);
      _isBonusStorageReady = true;
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
          _maybeShowSubjectCompletionBonus(data.dashboard.dailyXp);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.screen),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ScreenHeader(
                  title: 'Student View',
                  onBack: () => Navigator.of(context).pop(),
                  user: _session.user,
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
                ),
                const SizedBox(height: AppSpacing.item),
                _DailyXpPanel(summary: data.dashboard.dailyXp),
                const SizedBox(height: AppSpacing.section),
                Text(
                  'Today: ${today?.day ?? 'No schedule'}',
                  style: Theme.of(context).textTheme.titleLarge,
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
                    onPressed: () => _startMissionWithChoice(
                      studentId: data.dashboard.student.id,
                      subjectId: today.afternoonMission.id,
                      sessionType: 'afternoon',
                      subjectName: today.afternoonMission.name,
                    ),
                  ),
                ] else
                  const SoftPanel(
                    child: Text('No mission is assigned for today yet.'),
                  ),
                const SizedBox(height: AppSpacing.section),
                Text(
                  'This week',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.item),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    StatChip(
                      value: '${_averageFocus(data.dashboard.recentSessions)}%',
                      label: 'Focus score',
                      colors: AppPalette.studentGradient,
                    ),
                    StatChip(
                      value: '${data.dashboard.student.xp}',
                      label: 'XP total',
                      colors: const [AppPalette.primaryBlue, AppPalette.aqua],
                    ),
                    StatChip(
                      value: '${data.dashboard.recentSessions.length}',
                      label: 'Recent sessions',
                      colors: const [AppPalette.sky, AppPalette.primaryBlue],
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.section),
                Text(
                  'My Subjects',
                  style: Theme.of(context).textTheme.titleLarge,
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
                      padding: const EdgeInsets.only(bottom: AppSpacing.item),
                      child: _MySubjectCard(
                        summary: subject,
                        onTap: () => _openSubjectReport(subject),
                        onOpenLatestResult: () =>
                            _openLatestSubjectResult(subject),
                      ),
                    ),
                  ),
                const SizedBox(height: AppSpacing.section),
                Text(
                  'Qualification journey',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.item),
                if (data.criteria.isEmpty)
                  const SoftPanel(
                    child: Text(
                      'No criteria are assigned yet. Your teacher will add them soon.',
                    ),
                  )
                else
                  ...data.criteria.map(
                    (criterion) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.item),
                      child: _CriterionEntryCard(
                        criterion: criterion,
                        onTap: () => _openCriterionJourney(criterion),
                      ),
                    ),
                  ),
                const SizedBox(height: AppSpacing.section),
                Text(
                  'Recent activity',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.item),
                if (data.dashboard.recentSessions.isEmpty)
                  const SoftPanel(
                    child: Text(
                      'No completed sessions yet. Start the next mission.',
                    ),
                  )
                else
                  ...data.dashboard.recentSessions.map(
                    (session) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.item),
                      child: SoftPanel(
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
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
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
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
        .where(
          (mission) => mission.questionCount >= 5 && mission.questionCount < 10,
        )
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
                'Select any assigned daily mission (5 to 8 questions).',
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
                                      '${mission.subject?.name ?? 'Subject'} · ${mission.questionCount} questions · ${mission.sessionType}',
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

  Future<void> _startDailyMission({
    required String studentId,
    required String subjectId,
    required String sessionType,
    required String subjectName,
    String? missionId,
  }) async {
    try {
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
    );

    if (updatedUser == null || !mounted) {
      return;
    }

    setState(() {
      _session = _session.copyWith(user: updatedUser);
    });
    _refreshData();
  }

  Future<void> _openCriterionJourney(CriterionOverview criterion) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CriterionJourneyScreen(
          session: _session,
          studentId: _session.user.id,
          criterionId: criterion.criterion.id,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    _refreshData();
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
      final report = await _api.fetchStudentSubjectReport(
        token: _session.token,
        studentId: _session.user.id,
        subjectId: summary.subjectId,
      );

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
    if (!_isBonusStorageReady) {
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      showDialog<void>(
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
                    'You completed a subject and earned +$bonusXp bonus XP today.',
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
}

class _StudentScreenData {
  const _StudentScreenData({
    required this.session,
    required this.dashboard,
    required this.criteria,
    required this.timetable,
  });

  final AuthSession session;
  final StudentDashboardData dashboard;
  final List<CriterionOverview> criteria;
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
    required this.onBack,
    required this.user,
    required this.onProfileTap,
  });

  final String title;
  final VoidCallback onBack;
  final AppUser user;
  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _RoundIconButton(icon: Icons.arrow_back_ios_new_rounded, onTap: onBack),
        const SizedBox(width: 14),
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        ProfileAvatarButton(user: user, onTap: onProfileTap),
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

class _CriterionEntryCard extends StatelessWidget {
  const _CriterionEntryCard({required this.criterion, required this.onTap});

  final CriterionOverview criterion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
      child: SoftPanel(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: AppPalette.teacherGradient,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.auto_stories_rounded,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: AppSpacing.item),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    criterion.criterion.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${criterion.subject?.name ?? 'Subject'} · ${criterion.unit?.title ?? 'Unit'}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppPalette.textMuted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _MiniPill(
                        label: _criterionStateLabel(criterion.progress),
                      ),
                      _MiniPill(
                        label:
                            '${criterion.progress.wordCount}/${criterion.criterion.requiredWordCount} words',
                      ),
                      _MiniPill(
                        label:
                            '${criterion.flags.attemptsRemaining} attempts left',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.arrow_forward_ios_rounded, color: AppPalette.navy),
          ],
        ),
      ),
    );
  }

  String _criterionStateLabel(CriterionProgress progress) {
    switch (progress.criterionState) {
      case 'learning_required':
        return 'Learning';
      case 'learning_check_active':
        return progress.learningLocked ? 'Teacher reset' : 'Knowledge check';
      case 'essay_builder_unlocked':
        return 'Essay Builder';
      case 'ready_for_submission':
        return 'Ready to submit';
      case 'submitted':
        return 'Teacher review';
      case 'approved':
        return 'Approved';
      case 'revision_requested':
        return 'Revision';
      default:
        return 'Criterion';
    }
  }
}

class _DailyXpPanel extends StatelessWidget {
  const _DailyXpPanel({required this.summary});

  final DailyXpSummary summary;

  @override
  Widget build(BuildContext context) {
    return SoftPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Daily XP', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
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
              _MiniPill(label: 'Attendance ${summary.attendanceXp}/20'),
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
