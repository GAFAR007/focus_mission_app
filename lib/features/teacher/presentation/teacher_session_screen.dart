/**
 * WHAT:
 * TeacherSessionScreen lets a teacher review the timetable, prepare AI mission
 * drafts, publish missions, and save lesson session outcomes.
 * WHY:
 * Teachers need a date-aware authoring surface that respects timetable
 * ownership, lesson-slot boundaries, and review-before-publish rules.
 * HOW:
 * Load the selected student's timetable and derive the active lesson slot from
 * the selected date plus the current teacher's ownership of that slot.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'package:flutter/material.dart';

import '../../../core/constants/app_palette.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/focus_mission_api.dart';
import '../../../shared/models/focus_mission_models.dart';
import '../../../shared/widgets/focus_scaffold.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../shared/widgets/notification_panel.dart';
import '../../../shared/widgets/profile_avatar_button.dart';
import '../../../shared/widgets/profile_sheet.dart';
import '../../../shared/widgets/soft_panel.dart';
import '../../../shared/widgets/weekly_timetable_calendar.dart';
import 'criterion_review_sheet.dart';
import 'mission_builder_sheet.dart';
import 'result_report_screen.dart';
import 'teacher_analytics_screen.dart';

const List<String> _availableCertificationTaskCodes = <String>[
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

class TeacherSessionScreen extends StatefulWidget {
  const TeacherSessionScreen({super.key, required this.session});

  final AuthSession session;

  @override
  State<TeacherSessionScreen> createState() => _TeacherSessionScreenState();
}

class _TeacherSessionScreenState extends State<TeacherSessionScreen> {
  final FocusMissionApi _api = FocusMissionApi();
  final TextEditingController _notesController = TextEditingController();

  late AuthSession _session;
  late Future<TeacherWorkspaceData> _future;
  String _selectedStudentId = '';

  String _selectedLesson = 'Morning';
  String _selectedBehaviour = 'No Issues';
  late DateTime _selectedLessonDate;
  bool _isSaving = false;
  List<MissionPayload>? _draftMissions;
  List<MissionPayload>? _recentMissions;
  List<CriterionOverview>? _criteria;
  NotificationInboxData? _notificationInbox;
  List<TargetSummary>? _targets;
  bool _isUpdatingTargets = false;
  bool _isSelectingDraftMissions = false;
  bool _isDeletingDraftMissions = false;
  final Set<String> _selectedDraftMissionIds = <String>{};
  final Set<String> _sendingResultMissionIds = <String>{};

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    final now = DateTime.now();
    _selectedLessonDate = DateTime(now.year, now.month, now.day);
    _future = _loadWorkspace();
  }

  Future<TeacherWorkspaceData> _loadWorkspace() async {
    final workspace = await _api.loadTeacherWorkspace(
      session: _session,
      selectedStudentId: _selectedStudentId,
    );
    _selectedStudentId = workspace.selectedStudent.id;
    _notificationInbox ??= workspace.notificationInbox;
    _targets ??= workspace.targets;
    return workspace;
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FocusScaffold(
      child: FutureBuilder<TeacherWorkspaceData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _LoadingState(label: 'Loading teacher workspace...');
          }

          if (snapshot.hasError) {
            return _ErrorState(
              message: snapshot.error.toString(),
              onBack: () => Navigator.of(context).pop(),
            );
          }

          final workspace = snapshot.data!;
          final criteria = _criteria ?? workspace.criteria;
          final draftMissions = _draftMissions ?? workspace.draftMissions;
          final assessmentDraftMissions = draftMissions
              .where(_isAssessmentDraft)
              .toList(growable: false);
          final dailyDraftMissions = draftMissions
              .where((mission) => !_isAssessmentDraft(mission))
              .toList(growable: false);
          final recentMissions = _recentMissions ?? workspace.recentMissions;
          final targets = _targets ?? workspace.targets;
          final studentCertification =
              workspace.selectedDashboard.subjectCertification;
          final teacherCertificationSubjects =
              _teacherOwnedCertificationSubjects(
                timetable: workspace.timetable,
                certifications: studentCertification,
              );
          final notificationInbox =
              _notificationInbox ?? workspace.notificationInbox;
          final teacherCriteria = criteria
              .where(
                (criterion) =>
                    _normalizeLessonValue(criterion.subject?.name) ==
                    _normalizeLessonValue(_session.user.subjectSpecialty),
              )
              .toList(growable: false);
          final schedule = _scheduleForDate(
            workspace.timetable,
            _selectedLessonDate,
          );
          final activeLesson = _resolvedLessonForTeacher(schedule);
          final selectedSubject = activeLesson == 'Morning'
              ? schedule?.morningMission
              : schedule?.afternoonMission;
          final selectedTeacher = activeLesson == 'Morning'
              ? schedule?.morningTeacher
              : schedule?.afternoonTeacher;
          final teacherOwnsSelectedSlot = _teacherMatchesLessonSlot(
            subject: selectedSubject,
            teacher: selectedTeacher,
          );
          final selectedDateIsToday = _isSameDateOnly(
            _selectedLessonDate,
            DateTime.now(),
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.screen),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(
                  onBack: () => Navigator.of(context).pop(),
                  title: _session.user.name,
                  user: _session.user,
                  onProfileTap: _openProfile,
                ),
                const SizedBox(height: AppSpacing.section),
                CurrentDatePanel(
                  title: 'Selected Lesson Date',
                  date: _selectedLessonDate,
                  subtitle:
                      '${workspace.selectedStudent.name}\'s timetable now spans the full week and month. Pick the class date you want to prepare.',
                ),
                const SizedBox(height: AppSpacing.item),
                _StudentPickerCard(student: workspace.selectedStudent),
                const SizedBox(height: AppSpacing.compact),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _openStudentPicker(workspace),
                    icon: const Icon(Icons.swap_horiz_rounded),
                    label: const Text('Switch student'),
                  ),
                ),
                const SizedBox(height: AppSpacing.compact),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _openTeacherAnalytics(workspace),
                    icon: const Icon(Icons.insights_rounded),
                    label: const Text('Open analytics'),
                  ),
                ),
                const SizedBox(height: AppSpacing.item),
                _TeacherCertificationPanel(
                  workspace: workspace,
                  subjects: teacherCertificationSubjects,
                  certifications: studentCertification,
                  studentName: workspace.selectedStudent.name,
                  onEditPlan: _openCertificationPlanEditor,
                ),
                const SizedBox(height: AppSpacing.item),
                _TeacherCriterionPanel(
                  criteria: teacherCriteria,
                  onTap: (criterion) =>
                      _openCriterionReview(workspace, criterion),
                ),
                const SizedBox(height: AppSpacing.item),
                NotificationPanel(
                  title: 'Teacher Inbox',
                  subtitle:
                      'Review submission alerts and locked learning checks without leaving this screen.',
                  notifications: notificationInbox.notifications,
                  unreadCount: notificationInbox.unreadCount,
                  emptyMessage:
                      'No review alerts right now. New criterion submissions and lock reviews will appear here.',
                  onTapNotification: (notification) =>
                      _openNotification(workspace, notification),
                ),
                const SizedBox(height: AppSpacing.item),
                WeeklyTimetableCalendar(
                  title: 'Teacher Timetable',
                  subtitle:
                      '${workspace.selectedStudent.name}\'s Monday to Sunday planner with a full month view.',
                  entries: workspace.timetable,
                  date: _selectedLessonDate,
                  onDateChanged: (date) =>
                      setState(() => _selectedLessonDate = date),
                ),
                const SizedBox(height: AppSpacing.item),
                _DraftMissionsPanel(
                  missions: dailyDraftMissions,
                  dailyDraftCount: dailyDraftMissions.length,
                  assessmentDraftCount: assessmentDraftMissions.length,
                  isSelectingDrafts: _isSelectingDraftMissions,
                  isDeletingDrafts: _isDeletingDraftMissions,
                  selectedDraftMissionIds: _selectedDraftMissionIds,
                  onOpenDailyDrafts: () => _openDailyDraftsList(
                    workspace,
                    dailyDraftMissions,
                    selectedSubject: selectedSubject,
                    lessonLabel: activeLesson,
                  ),
                  onOpenAssessmentDrafts: () => _openAssessmentDraftsList(
                    workspace,
                    assessmentDraftMissions,
                    selectedSubject: selectedSubject,
                    lessonLabel: activeLesson,
                  ),
                  onToggleDraftSelectionMode: () =>
                      _toggleDraftSelectionMode(dailyDraftMissions),
                  onCancelDraftSelection: _clearDraftSelection,
                  onToggleDraftSelection: _toggleDraftSelection,
                  onDeleteSelectedDrafts: () =>
                      _deleteSelectedDraftMissions(workspace),
                  onEdit: (mission) => _openMissionBuilder(
                    workspace: workspace,
                    subject: SubjectSummary(
                      id: mission.subject?.id ?? selectedSubject?.id ?? '',
                      name:
                          mission.subject?.name ??
                          selectedSubject?.name ??
                          'Mission',
                    ),
                    lessonLabel: mission.sessionType == 'afternoon'
                        ? 'Afternoon'
                        : 'Morning',
                    initialDraft: mission,
                  ),
                ),
                const SizedBox(height: AppSpacing.item),
                _LatestAssignedMissionsPanel(
                  missions: recentMissions,
                  sendingResultMissionIds: _sendingResultMissionIds,
                  onEdit: (mission) => _openMissionBuilder(
                    workspace: workspace,
                    subject: SubjectSummary(
                      id: mission.subject?.id ?? '',
                      name: mission.subject?.name ?? 'Mission',
                    ),
                    lessonLabel: mission.sessionType == 'afternoon'
                        ? 'Afternoon'
                        : 'Morning',
                    initialDraft: mission,
                  ),
                  onMoveBackToDraft: (mission) =>
                      _moveMissionBackToDraft(workspace, mission),
                  onSendResult: (mission) =>
                      _sendMissionResult(workspace, mission),
                  onViewResult: (mission) =>
                      _openResultReport(workspace, mission),
                ),
                const SizedBox(height: AppSpacing.item),
                SoftPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lesson',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${selectedDateIsToday ? 'Today\'s session' : 'Selected session'} · ${_selectedDateSummary(schedule)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppPalette.textMuted,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.compact),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _ChoicePill(
                            label: 'Morning',
                            selected: activeLesson == 'Morning',
                            colors: AppPalette.studentGradient,
                            onTap: () =>
                                setState(() => _selectedLesson = 'Morning'),
                          ),
                          _ChoicePill(
                            label: 'Afternoon',
                            selected: activeLesson == 'Afternoon',
                            colors: const [
                              AppPalette.primaryBlue,
                              AppPalette.aqua,
                            ],
                            onTap: () =>
                                setState(() => _selectedLesson = 'Afternoon'),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.section),
                      Text(
                        'Subject',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppPalette.textMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.item),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusMd,
                          ),
                        ),
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
                              child: Icon(
                                activeLesson == 'Morning'
                                    ? Icons.wb_sunny_rounded
                                    : Icons.nights_stay_rounded,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                selectedSubject == null
                                    ? 'No subject assigned'
                                    : '${selectedSubject.name} · ${schedule?.room ?? 'Room'} · ${selectedTeacher?.name ?? 'Teacher not set'}',
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(color: AppPalette.navy),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.section),
                      Text(
                        'Targets Met',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.compact),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Default + custom weekly targets',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppPalette.textMuted),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _isUpdatingTargets
                                ? null
                                : () => _createTarget(workspace),
                            icon: const Icon(Icons.add_circle_outline_rounded),
                            label: const Text('Create new target'),
                          ),
                        ],
                      ),
                      if (targets.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(bottom: AppSpacing.compact),
                          child: Text('No targets available yet.'),
                        )
                      else
                        ...targets.map(
                          (target) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.compact,
                            ),
                            child: _TargetStarsRow(
                              target: target,
                              enabled: !_isUpdatingTargets,
                              onSetStars: (stars) => _setTargetStars(
                                workspace: workspace,
                                target: target,
                                stars: stars,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: AppSpacing.compact),
                      TextField(
                        controller: _notesController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: 'Enter comment...',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.section),
                      Text(
                        'Behaviour',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.compact),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _ChoicePill(
                            label: 'No Issues',
                            selected: _selectedBehaviour == 'No Issues',
                            colors: AppPalette.studentGradient,
                            onTap: () => setState(
                              () => _selectedBehaviour = 'No Issues',
                            ),
                          ),
                          _ChoicePill(
                            label: 'Warning',
                            selected: _selectedBehaviour == 'Warning',
                            colors: const [AppPalette.sun, AppPalette.orange],
                            onTap: () =>
                                setState(() => _selectedBehaviour = 'Warning'),
                          ),
                          _ChoicePill(
                            label: 'Penalty',
                            selected: _selectedBehaviour == 'Penalty',
                            colors: const [
                              Color(0xFFFF8DA1),
                              Color(0xFFFFC2A0),
                            ],
                            onTap: () =>
                                setState(() => _selectedBehaviour = 'Penalty'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.section),
                GradientButton(
                  label: _isSaving ? 'Saving...' : 'Save Session',
                  colors: AppPalette.progressGradient,
                  onPressed:
                      selectedSubject == null ||
                          _isSaving ||
                          !selectedDateIsToday ||
                          !teacherOwnsSelectedSlot
                      ? () {}
                      : () => _saveSession(workspace, selectedSubject),
                ),
                if (!selectedDateIsToday || !teacherOwnsSelectedSlot) ...[
                  const SizedBox(height: AppSpacing.compact),
                  Text(
                    !selectedDateIsToday
                        ? 'Session logs can only be saved on the actual lesson day. You can still prepare missions for this selected future class.'
                        : 'Only the teacher assigned to this lesson can save the session log for this slot.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppPalette.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _saveSession(
    TeacherWorkspaceData workspace,
    SubjectSummary selectedSubject,
  ) async {
    final schedule = _scheduleForDate(workspace.timetable, _selectedLessonDate);
    final lessonLabel = _resolvedLessonForTeacher(schedule);
    final publishedMission = _publishedMissionForLesson(
      _recentMissions ?? workspace.recentMissions,
      lessonLabel: lessonLabel,
      subjectId: selectedSubject.id,
    );
    final xpReward = publishedMission?.xpReward ?? 20;

    setState(() => _isSaving = true);

    try {
      await _api.createSessionLog(
        token: workspace.session.token,
        studentId: workspace.selectedStudent.id,
        subjectId: selectedSubject.id,
        sessionType: lessonLabel.toLowerCase(),
        focusScore: _focusScoreForBehaviour(),
        completedQuestions: 5,
        behaviourStatus: _behaviourStatusForApi(),
        notes: _notesController.text.trim(),
        xpAwarded: xpReward,
      );

      _notesController.clear();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${workspace.selectedStudent.name}\'s $lessonLabel session saved for $xpReward XP.',
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
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _createTarget(TeacherWorkspaceData workspace) async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    String selectedDifficulty = 'medium';

    final shouldCreate = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Create New Target'),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Target title',
                        hintText: 'e.g. Stay focused for 20 minutes',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.compact),
                    TextField(
                      controller: descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description (optional)',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.compact),
                    DropdownButtonFormField<String>(
                      initialValue: selectedDifficulty,
                      items: const [
                        DropdownMenuItem(value: 'easy', child: Text('Easy')),
                        DropdownMenuItem(
                          value: 'medium',
                          child: Text('Medium'),
                        ),
                        DropdownMenuItem(value: 'hard', child: Text('Hard')),
                      ],
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setDialogState(() => selectedDifficulty = value);
                      },
                      decoration: const InputDecoration(
                        labelText: 'Difficulty',
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );

    if (!mounted) {
      return;
    }

    if (shouldCreate != true) {
      return;
    }

    final title = titleController.text.trim();
    final description = descriptionController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Target title is required.')),
      );
      return;
    }

    setState(() => _isUpdatingTargets = true);
    try {
      final created = await _api.createTarget(
        token: workspace.session.token,
        studentId: workspace.selectedStudent.id,
        title: title,
        description: description,
        difficulty: selectedDifficulty,
        targetType: 'custom',
        stars: 0,
        awardDateKey: _dateKey(_selectedLessonDate),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        final nextTargets = <TargetSummary>[
          ...(_targets ?? workspace.targets),
          created,
        ];
        _targets = _sortTargets(nextTargets);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Target created: ${created.title}')),
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
        setState(() => _isUpdatingTargets = false);
      }
    }
  }

  Future<void> _setTargetStars({
    required TeacherWorkspaceData workspace,
    required TargetSummary target,
    required int stars,
  }) async {
    final nextStars = target.stars == stars ? 0 : stars;
    setState(() => _isUpdatingTargets = true);
    try {
      final updated = await _api.updateTarget(
        token: workspace.session.token,
        targetId: target.id,
        stars: nextStars,
        awardDateKey: _dateKey(_selectedLessonDate),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        final nextTargets = (_targets ?? workspace.targets)
            .map((item) => item.id == updated.id ? updated : item)
            .toList(growable: false);
        _targets = _sortTargets(nextTargets);
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _isUpdatingTargets = false);
      }
    }
  }

  List<TargetSummary> _sortTargets(List<TargetSummary> targets) {
    final nextTargets = [...targets];
    nextTargets.sort((left, right) {
      final leftFixed = left.isFixedTarget ? 0 : 1;
      final rightFixed = right.isFixedTarget ? 0 : 1;
      if (leftFixed != rightFixed) {
        return leftFixed.compareTo(rightFixed);
      }
      return left.title.toLowerCase().compareTo(right.title.toLowerCase());
    });
    return nextTargets;
  }

  int _focusScoreForBehaviour() {
    switch (_selectedBehaviour) {
      case 'No Issues':
        return 88;
      case 'Warning':
        return 58;
      case 'Penalty':
        return 30;
      default:
        return 78;
    }
  }

  Future<void> _openTeacherAnalytics(TeacherWorkspaceData workspace) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => TeacherAnalyticsScreen(
          session: workspace.session,
          student: workspace.selectedStudent,
        ),
      ),
    );
  }

  String _behaviourStatusForApi() {
    switch (_selectedBehaviour) {
      case 'No Issues':
        return 'great';
      case 'Warning':
        return 'warning';
      case 'Penalty':
        return 'penalty';
      default:
        return 'steady';
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
  }

  Future<void> _openStudentPicker(TeacherWorkspaceData workspace) async {
    final selectedStudentId = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => _StudentPickerSheet(
        students: workspace.students,
        selectedStudentId: workspace.selectedStudent.id,
      ),
    );

    if (!mounted ||
        selectedStudentId == null ||
        selectedStudentId == workspace.selectedStudent.id) {
      return;
    }

    setState(() {
      // WHY: Student switching must refresh all learner-specific sections so
      // mission assignment and session saving always target the chosen student.
      _selectedStudentId = selectedStudentId;
      _draftMissions = null;
      _recentMissions = null;
      _criteria = null;
      _targets = null;
      _notificationInbox = null;
      _isSelectingDraftMissions = false;
      _isDeletingDraftMissions = false;
      _selectedDraftMissionIds.clear();
      _future = _loadWorkspace();
    });
  }

  Future<void> _openMissionBuilder({
    required TeacherWorkspaceData workspace,
    required SubjectSummary subject,
    required String lessonLabel,
    List<String> lockedAssessmentTaskCodes = const [],
    bool openAssessmentOnStart = false,
    MissionPayload? initialDraft,
  }) async {
    final mission = await showMissionBuilderSheet(
      context,
      session: _session,
      student: workspace.selectedStudent,
      subject: subject,
      sessionType: initialDraft?.sessionType ?? lessonLabel.toLowerCase(),
      targetDate: _selectedLessonDate,
      timetableEntries: workspace.timetable,
      lockedAssessmentTaskCodes: lockedAssessmentTaskCodes,
      openAssessmentOnStart: openAssessmentOnStart,
      api: _api,
      initialDraft: initialDraft,
    );

    if (mission == null || !mounted) {
      return;
    }

    setState(() {
      final nextDrafts = [...(_draftMissions ?? workspace.draftMissions)];
      final nextRecent = [...(_recentMissions ?? workspace.recentMissions)];

      nextDrafts.removeWhere((item) => item.id == mission.id);
      nextRecent.removeWhere((item) => item.id == mission.id);

      if (mission.isDraft) {
        nextDrafts.insert(0, mission);
      } else {
        nextRecent.insert(0, mission);
      }

      _draftMissions = nextDrafts.take(5).toList(growable: false);
      // WHY: Assigned mission history should stay visible after edits/publish
      // so teachers can open older result reports and resend outcomes.
      _recentMissions = nextRecent.toList(growable: false);
      _pruneSelectedDraftMissions();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          mission.isPublished
              ? '${mission.title} is now live for ${workspace.selectedStudent.name}.'
              : '${mission.title} was saved as a draft.',
        ),
      ),
    );
  }

  Future<void> _moveMissionBackToDraft(
    TeacherWorkspaceData workspace,
    MissionPayload mission,
  ) async {
    try {
      final updatedMission = await _api.updateTeacherMissionStatus(
        token: workspace.session.token,
        missionId: mission.id,
        status: 'draft',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        final nextDrafts = [...(_draftMissions ?? workspace.draftMissions)];
        final nextRecent = [...(_recentMissions ?? workspace.recentMissions)];

        nextDrafts.removeWhere((item) => item.id == updatedMission.id);
        nextRecent.removeWhere((item) => item.id == updatedMission.id);
        nextDrafts.insert(0, updatedMission);

        _draftMissions = nextDrafts.take(5).toList(growable: false);
        _recentMissions = nextRecent.toList(growable: false);
        _pruneSelectedDraftMissions();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${updatedMission.title} moved back to drafts.'),
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

  Future<void> _openResultReport(
    TeacherWorkspaceData workspace,
    MissionPayload mission,
  ) async {
    final resultPackageId = mission.latestResultPackageId.trim();
    if (resultPackageId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No result package is available yet for this mission.'),
        ),
      );
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ResultReportScreen(
          session: _session,
          mission: mission,
          student: workspace.selectedStudent,
          resultPackageId: resultPackageId,
          api: _api,
        ),
      ),
    );
  }

  Future<void> _sendMissionResult(
    TeacherWorkspaceData workspace,
    MissionPayload mission,
  ) async {
    final resultPackageId = mission.latestResultPackageId.trim();
    if (resultPackageId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No result package is available yet for this mission.'),
        ),
      );
      return;
    }

    if (_sendingResultMissionIds.contains(mission.id)) {
      return;
    }

    setState(() {
      _sendingResultMissionIds.add(mission.id);
    });

    try {
      // WHY: One-tap send from the mission list reduces friction for teachers
      // when they need to deliver many completed results quickly.
      await _api.sendTeacherResultPackage(
        token: workspace.session.token,
        resultPackageId: resultPackageId,
        recipients: const [],
        sendInApp: true,
        sendEmail: true,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Result sent for "${mission.title}".')),
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
        setState(() {
          _sendingResultMissionIds.remove(mission.id);
        });
      }
    }
  }

  void _toggleDraftSelectionMode(List<MissionPayload> visibleDraftMissions) {
    if (visibleDraftMissions.isEmpty || _isDeletingDraftMissions) {
      return;
    }

    setState(() {
      if (_isSelectingDraftMissions) {
        _isSelectingDraftMissions = false;
        _selectedDraftMissionIds.clear();
        return;
      }

      _isSelectingDraftMissions = true;
      _selectedDraftMissionIds.clear();
    });
  }

  void _toggleDraftSelection(MissionPayload mission) {
    if (_isDeletingDraftMissions) {
      return;
    }

    setState(() {
      _isSelectingDraftMissions = true;
      if (_selectedDraftMissionIds.contains(mission.id)) {
        _selectedDraftMissionIds.remove(mission.id);
      } else {
        _selectedDraftMissionIds.add(mission.id);
      }
    });
  }

  void _clearDraftSelection() {
    if (!_isSelectingDraftMissions && _selectedDraftMissionIds.isEmpty) {
      return;
    }

    setState(() {
      _isSelectingDraftMissions = false;
      _selectedDraftMissionIds.clear();
    });
  }

  void _pruneSelectedDraftMissions() {
    final visibleDraftIds = (_draftMissions ?? const <MissionPayload>[])
        .map((mission) => mission.id)
        .toSet();
    _selectedDraftMissionIds.removeWhere((id) => !visibleDraftIds.contains(id));
    if (_selectedDraftMissionIds.isEmpty) {
      _isSelectingDraftMissions = false;
    }
  }

  Future<void> _deleteSelectedDraftMissions(
    TeacherWorkspaceData workspace,
  ) async {
    if (_isDeletingDraftMissions) {
      return;
    }

    final visibleDrafts = _draftMissions ?? workspace.draftMissions;
    final selectedDrafts = visibleDrafts
        .where((mission) => _selectedDraftMissionIds.contains(mission.id))
        .toList(growable: false);

    if (selectedDrafts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one draft to delete.')),
      );
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final count = selectedDrafts.length;
        return AlertDialog(
          title: const Text('Delete selected drafts?'),
          content: Text(
            count == 1
                ? 'This draft will be permanently deleted.'
                : '$count drafts will be permanently deleted.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFB3261E),
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true || !mounted) {
      return;
    }

    setState(() {
      _isDeletingDraftMissions = true;
    });

    try {
      for (final mission in selectedDrafts) {
        // WHY: Deleting one mission at a time keeps per-draft auth checks and
        // error messages explicit at the same API boundary used by editing.
        await _api.deleteTeacherMission(
          token: workspace.session.token,
          missionId: mission.id,
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _isDeletingDraftMissions = false;
        _isSelectingDraftMissions = false;
        _selectedDraftMissionIds.clear();
        _draftMissions = null;
        _future = _loadWorkspace();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            selectedDrafts.length == 1
                ? 'Draft deleted.'
                : '${selectedDrafts.length} drafts deleted.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isDeletingDraftMissions = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _openAssessmentDraftsList(
    TeacherWorkspaceData workspace,
    List<MissionPayload> missions, {
    SubjectSummary? selectedSubject,
    required String lessonLabel,
  }) async {
    final result = await Navigator.of(context).push<_AssessmentDraftListResult>(
      MaterialPageRoute(
        builder: (_) => _AssessmentDraftListScreen(
          studentName: workspace.selectedStudent.name,
          studentXp: workspace.selectedStudent.xp,
          missions: missions,
          lockedTaskCodes: missions
              .expand((mission) => mission.taskCodes)
              .map((code) => code.trim().toUpperCase())
              .where((code) => code.isNotEmpty)
              .toSet()
              .toList(growable: false),
        ),
      ),
    );

    if (!mounted || result == null) {
      return;
    }

    if (result.createNew) {
      final fallbackSubject =
          selectedSubject ??
          (missions.isNotEmpty && missions.first.subject != null
              ? SubjectSummary(
                  id: missions.first.subject!.id,
                  name: missions.first.subject!.name,
                )
              : null);
      if (fallbackSubject == null || fallbackSubject.id.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Select a timetable subject slot first, then create the new assessment draft.',
            ),
          ),
        );
        return;
      }

      await _openMissionBuilder(
        workspace: workspace,
        subject: fallbackSubject,
        lessonLabel: lessonLabel,
        openAssessmentOnStart: true,
        lockedAssessmentTaskCodes: result.lockedTaskCodes,
      );
      return;
    }

    final selected = result.mission;
    if (selected == null) {
      return;
    }

    await _openMissionBuilder(
      workspace: workspace,
      subject: SubjectSummary(
        id: selected.subject?.id ?? '',
        name: selected.subject?.name ?? 'Mission',
      ),
      lessonLabel: selected.sessionType == 'afternoon'
          ? 'Afternoon'
          : 'Morning',
      initialDraft: selected,
    );
  }

  Future<void> _openDailyDraftsList(
    TeacherWorkspaceData workspace,
    List<MissionPayload> missions, {
    SubjectSummary? selectedSubject,
    required String lessonLabel,
  }) async {
    final result = await Navigator.of(context).push<_DailyDraftListResult>(
      MaterialPageRoute(
        builder: (_) => _DailyDraftListScreen(
          studentName: workspace.selectedStudent.name,
          missions: missions,
        ),
      ),
    );

    if (!mounted || result == null) {
      return;
    }

    if (result.createNew) {
      final fallbackSubject =
          selectedSubject ??
          (missions.isNotEmpty && missions.first.subject != null
              ? SubjectSummary(
                  id: missions.first.subject!.id,
                  name: missions.first.subject!.name,
                )
              : null);
      if (fallbackSubject == null || fallbackSubject.id.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Select a timetable subject slot first, then create a daily draft.',
            ),
          ),
        );
        return;
      }

      await _openMissionBuilder(
        workspace: workspace,
        subject: fallbackSubject,
        lessonLabel: lessonLabel,
      );
      return;
    }

    final selected = result.mission;
    if (selected == null) {
      return;
    }

    await _openMissionBuilder(
      workspace: workspace,
      subject: SubjectSummary(
        id: selected.subject?.id ?? '',
        name: selected.subject?.name ?? 'Mission',
      ),
      lessonLabel: selected.sessionType == 'afternoon'
          ? 'Afternoon'
          : 'Morning',
      initialDraft: selected,
    );
  }

  bool _isAssessmentDraft(MissionPayload mission) {
    return mission.isDraft &&
        mission.draftFormat != 'ESSAY_BUILDER' &&
        (mission.questionCount == 10 || mission.questions.length == 10);
  }

  Future<void> _openCriterionReview(
    TeacherWorkspaceData workspace,
    CriterionOverview criterion,
  ) {
    final schedule = _scheduleForDate(workspace.timetable, _selectedLessonDate);
    final resolvedLesson = _resolvedLessonForTeacher(schedule);
    final selectedSubject = resolvedLesson == 'Morning'
        ? schedule?.morningMission
        : schedule?.afternoonMission;
    final selectedTeacher = resolvedLesson == 'Morning'
        ? schedule?.morningTeacher
        : schedule?.afternoonTeacher;
    final matchesSelectedLesson =
        selectedSubject != null &&
        (criterion.subject?.id ?? '') == selectedSubject.id;
    final teacherOwnsSlot = _teacherMatchesLessonSlot(
      subject: selectedSubject,
      teacher: selectedTeacher,
    );
    final selectedDateIsPast = _selectedLessonDate.isBefore(
      _dateOnly(DateTime.now()),
    );
    final hasMissionForSlot = _hasMissionForSlot(
      subjectId: selectedSubject?.id ?? '',
      lessonLabel: resolvedLesson,
      drafts: _draftMissions ?? workspace.draftMissions,
      published: _recentMissions ?? workspace.recentMissions,
    );
    final shouldOfferDailyDraft =
        matchesSelectedLesson &&
        teacherOwnsSlot &&
        !selectedDateIsPast &&
        !hasMissionForSlot;

    return _openCriterionReviewByIds(
      workspace,
      workspace.selectedStudent.id,
      criterion.criterion.id,
      onDraftDailyMission: shouldOfferDailyDraft
          ? () => _openMissionBuilder(
              workspace: workspace,
              subject: selectedSubject,
              lessonLabel: resolvedLesson,
            )
          : null,
    );
  }

  Future<void> _openCriterionReviewByIds(
    TeacherWorkspaceData workspace,
    String studentId,
    String criterionId, {
    VoidCallback? onDraftDailyMission,
  }) async {
    final shouldRefresh = await showCriterionReviewSheet(
      context,
      session: _session,
      studentId: studentId,
      criterionId: criterionId,
      api: _api,
      onDraftDailyMission: onDraftDailyMission,
    );

    if (shouldRefresh != true || !mounted) {
      return;
    }

    if (studentId != workspace.selectedStudent.id) {
      return;
    }

    final refreshed = await _api.fetchStudentCriteria(
      token: _session.token,
      studentId: studentId,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _criteria = refreshed.criteria;
    });
  }

  Future<void> _openNotification(
    TeacherWorkspaceData workspace,
    AppNotification notification,
  ) async {
    try {
      final resolvedNotification = notification.isRead
          ? notification
          : await _api.markNotificationRead(
              token: _session.token,
              notificationId: notification.id,
            );

      if (!mounted) {
        return;
      }

      setState(() {
        _notificationInbox = _markNotificationLocally(resolvedNotification);
      });

      final studentId = resolvedNotification.studentId ?? '';
      final criterionId = resolvedNotification.criterionId ?? '';

      // WHY: Review notifications should take the teacher directly to the
      // criterion action sheet so the inbox becomes a working queue, not a
      // passive message list that requires more hunting through the UI.
      if (studentId.isNotEmpty && criterionId.isNotEmpty) {
        await _openCriterionReviewByIds(workspace, studentId, criterionId);
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(resolvedNotification.title)));
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  NotificationInboxData _markNotificationLocally(AppNotification notification) {
    final current = _notificationInbox;
    final notifications = [
      ...(current?.notifications ?? const <AppNotification>[]),
    ];

    final updatedNotifications = notifications
        .map(
          (item) => item.id == notification.id
              ? item.copyWith(
                  isRead: notification.isRead,
                  readAt: notification.readAt,
                )
              : item,
        )
        .toList(growable: false);

    final unreadCount = updatedNotifications
        .where((item) => !item.isRead)
        .length;

    return NotificationInboxData(
      unreadCount: unreadCount,
      notifications: updatedNotifications,
    );
  }

  MissionPayload? _publishedMissionForLesson(
    List<MissionPayload> missions, {
    required String lessonLabel,
    required String subjectId,
  }) {
    final lessonKey = lessonLabel.toLowerCase();
    final selectedDateKey = _dateKey(_selectedLessonDate);

    for (final mission in missions) {
      // WHY: Session XP should come from the authored mission for this exact
      // date and slot so the rewarded value matches what the teacher planned.
      if (mission.sessionType == lessonKey &&
          (mission.availableOnDate ?? '') == selectedDateKey &&
          (mission.subject?.id ?? '') == subjectId) {
        return mission;
      }
    }

    return null;
  }

  String _resolvedLessonForTeacher(TodaySchedule? schedule) {
    if (schedule == null) {
      return _selectedLesson;
    }

    final ownsMorning = _teacherMatchesLessonSlot(
      subject: schedule.morningMission,
      teacher: schedule.morningTeacher,
    );
    final ownsAfternoon = _teacherMatchesLessonSlot(
      subject: schedule.afternoonMission,
      teacher: schedule.afternoonTeacher,
    );

    if (ownsMorning && !ownsAfternoon) {
      return 'Morning';
    }

    if (ownsAfternoon && !ownsMorning) {
      return 'Afternoon';
    }

    return _selectedLesson;
  }

  bool _teacherMatchesLessonSlot({
    required SubjectSummary? subject,
    required TeacherSummary? teacher,
  }) {
    if (teacher?.id == _session.user.id) {
      return true;
    }

    final subjectName = _normalizeLessonValue(subject?.name);
    final teacherSpecialty = _normalizeLessonValue(
      _session.user.subjectSpecialty,
    );

    // WHY: The UI should still resolve to the teacher's own subject slot if a
    // stale timetable payload temporarily omits the expected teacher id. The
    // backend remains authoritative and will reject invalid generation attempts.
    return subjectName.isNotEmpty &&
        teacherSpecialty.isNotEmpty &&
        subjectName == teacherSpecialty;
  }

  String _normalizeLessonValue(String? value) {
    return (value ?? '').trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  TodaySchedule? _scheduleForDate(
    List<TodaySchedule> timetable,
    DateTime date,
  ) {
    const weekdayNames = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final weekdayName = weekdayNames[date.weekday - 1];

    for (final entry in timetable) {
      if (entry.day == weekdayName) {
        return entry;
      }
    }

    return null;
  }

  bool _isSameDateOnly(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  bool _hasMissionForSlot({
    required String subjectId,
    required String lessonLabel,
    required List<MissionPayload> drafts,
    required List<MissionPayload> published,
  }) {
    if (subjectId.isEmpty) {
      return false;
    }

    final lessonKey = lessonLabel.toLowerCase();
    final selectedDateKey = _dateKey(_selectedLessonDate);

    bool matchesSlot(MissionPayload mission) {
      return mission.sessionType == lessonKey &&
          (mission.availableOnDate ?? '') == selectedDateKey &&
          (mission.subject?.id ?? '') == subjectId;
    }

    return drafts.any(matchesSlot) || published.any(matchesSlot);
  }

  String _dateKey(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  String _selectedDateSummary(TodaySchedule? schedule) {
    if (_selectedLessonDate.weekday == DateTime.saturday ||
        _selectedLessonDate.weekday == DateTime.sunday) {
      return 'Weekend view';
    }

    return schedule?.day ?? 'No lesson scheduled';
  }

  List<_TeacherCertificationSubjectOption> _teacherOwnedCertificationSubjects({
    required List<TodaySchedule> timetable,
    required List<SubjectCertificationSummary> certifications,
  }) {
    final ordered = <_TeacherCertificationSubjectOption>[];
    final seenSubjectIds = <String>{};

    void addSubject(SubjectSummary? subject) {
      final subjectId = subject?.id ?? '';
      if (subjectId.isEmpty || seenSubjectIds.contains(subjectId)) {
        return;
      }
      seenSubjectIds.add(subjectId);
      ordered.add(
        _TeacherCertificationSubjectOption(
          subjectId: subjectId,
          subjectName: subject?.name ?? '',
          subjectIcon: subject?.icon,
          subjectColor: subject?.color,
        ),
      );
    }

    for (final entry in timetable) {
      if (_teacherMatchesLessonSlot(
        subject: entry.morningMission,
        teacher: entry.morningTeacher,
      )) {
        addSubject(entry.morningMission);
      }
      if (_teacherMatchesLessonSlot(
        subject: entry.afternoonMission,
        teacher: entry.afternoonTeacher,
      )) {
        addSubject(entry.afternoonMission);
      }
    }

    for (final certification in certifications) {
      if (seenSubjectIds.contains(certification.subjectId)) {
        continue;
      }
      // WHY: Existing certification plans must stay visible even if the current
      // timetable payload no longer exposes the subject in this week's slots.
      seenSubjectIds.add(certification.subjectId);
      ordered.add(
        _TeacherCertificationSubjectOption(
          subjectId: certification.subjectId,
          subjectName: certification.subjectName,
          subjectIcon: certification.subjectIcon.isEmpty
              ? null
              : certification.subjectIcon,
          subjectColor: certification.subjectColor.isEmpty
              ? null
              : certification.subjectColor,
        ),
      );
    }

    return ordered;
  }

  Future<void> _openCertificationPlanEditor({
    required TeacherWorkspaceData workspace,
    required _TeacherCertificationSubjectOption subject,
    SubjectCertificationSummary? initialCertification,
  }) async {
    final labelController = TextEditingController(
      text: initialCertification?.certificationLabel.isNotEmpty == true
          ? initialCertification!.certificationLabel
          : '${subject.subjectName} Certification',
    );
    final reasonController = TextEditingController();
    final selectedTaskCodes = <String>{
      ...?initialCertification?.requiredTaskCodes,
    };
    bool isSaving = false;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                initialCertification == null
                    ? 'Set certification objectives'
                    : 'Update certification objectives',
              ),
              content: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subject.subjectName,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Choose every task focus this student must pass for this subject. Qualifying missions will target one objective at a time.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppPalette.textMuted,
                        ),
                      ),
                      if (initialCertification != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Current plan: v${initialCertification.planVersion ?? 1} · ${initialCertification.planSource == 'teacher_plan' ? 'Teacher-owned plan' : 'Legacy subject template'}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppPalette.textMuted),
                        ),
                        if ((initialCertification.planChangeReason ?? '')
                            .isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Last change reason: ${initialCertification.planChangeReason}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppPalette.textMuted),
                            ),
                          ),
                      ],
                      const SizedBox(height: AppSpacing.compact),
                      TextField(
                        controller: labelController,
                        decoration: const InputDecoration(
                          labelText: 'Certification label',
                          hintText: 'e.g. English Course Certification',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.compact),
                      TextField(
                        controller: reasonController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Change reason',
                          hintText:
                              'Why are you setting or updating this plan?',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.compact),
                      Text(
                        'Required task focuses',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _availableCertificationTaskCodes
                            .map((taskCode) {
                              final isSelected = selectedTaskCodes.contains(
                                taskCode,
                              );
                              return FilterChip(
                                selected: isSelected,
                                label: Text(taskCode),
                                onSelected: (selected) {
                                  setDialogState(() {
                                    if (selected) {
                                      selectedTaskCodes.add(taskCode);
                                    } else {
                                      selectedTaskCodes.remove(taskCode);
                                    }
                                  });
                                },
                              );
                            })
                            .toList(growable: false),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'To count toward certification, a qualifying mission must target exactly one of these task focuses.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppPalette.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final certificationLabel = labelController.text
                              .trim();
                          final changeReason = reasonController.text.trim();

                          // WHY: Certification plans become the audit source for
                          // future mission evidence, so blank objectives or no
                          // change reason would make later progress impossible to
                          // defend.
                          if (selectedTaskCodes.isEmpty) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Select at least one required task focus.',
                                ),
                              ),
                            );
                            return;
                          }
                          if (changeReason.length < 3) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Add a short change reason so the plan stays auditable.',
                                ),
                              ),
                            );
                            return;
                          }

                          setDialogState(() => isSaving = true);
                          try {
                            await _api.updateTeacherStudentCertificationPlan(
                              token: workspace.session.token,
                              studentId: workspace.selectedStudent.id,
                              subjectId: subject.subjectId,
                              requiredTaskCodes: selectedTaskCodes.toList()
                                ..sort(),
                              certificationLabel: certificationLabel,
                              changeReason: changeReason,
                            );
                            if (!mounted) {
                              return;
                            }
                            setState(() {
                              _future = _loadWorkspace();
                            });
                            if (context.mounted) {
                              Navigator.of(dialogContext).pop(true);
                            }
                          } catch (error) {
                            if (dialogContext.mounted) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                SnackBar(content: Text(error.toString())),
                              );
                              setDialogState(() => isSaving = false);
                            }
                          }
                        },
                  child: Text(
                    initialCertification == null
                        ? 'Save objectives'
                        : 'Create new version',
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted || saved != true) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          initialCertification == null
              ? '${subject.subjectName} certification objectives saved.'
              : '${subject.subjectName} certification plan updated.',
        ),
      ),
    );
  }
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
                'Could not load the teacher workspace',
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

class _Header extends StatelessWidget {
  const _Header({
    required this.onBack,
    required this.title,
    required this.user,
    required this.onProfileTap,
  });

  final VoidCallback onBack;
  final String title;
  final AppUser user;
  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _HeaderButton(icon: Icons.arrow_back_ios_new_rounded, onTap: onBack),
        const SizedBox(width: 14),
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        ProfileAvatarButton(user: user, onTap: onProfileTap),
      ],
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({required this.icon, this.onTap});

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

class _StudentPickerCard extends StatelessWidget {
  const _StudentPickerCard({required this.student});

  final StudentSummary student;

  @override
  Widget build(BuildContext context) {
    return SoftPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                child: const Icon(Icons.group_rounded, color: Colors.white),
              ),
              const SizedBox(width: AppSpacing.item),
              Expanded(
                child: Text(
                  'Selected Student',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Icon(
                Icons.assignment_ind_rounded,
                color: AppPalette.textMuted.withValues(alpha: 0.8),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.item),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.item,
              vertical: AppSpacing.compact,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.74),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: AppPalette.studentGradient,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${student.name} · ${student.xp} XP',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(color: AppPalette.navy),
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: AppPalette.textMuted,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentPickerSheet extends StatelessWidget {
  const _StudentPickerSheet({
    required this.students,
    required this.selectedStudentId,
  });

  final List<StudentSummary> students;
  final String selectedStudentId;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen,
          AppSpacing.item,
          AppSpacing.screen,
          AppSpacing.section,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose Student',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.compact),
            Text(
              'Switch student before assigning missions or saving lesson sessions.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppPalette.textMuted),
            ),
            const SizedBox(height: AppSpacing.item),
            ...students.map(
              (student) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  onTap: () => Navigator.of(context).pop(student.id),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  child: Ink(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.item,
                      vertical: AppSpacing.compact,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.78),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      border: Border.all(
                        color: student.id == selectedStudentId
                            ? AppPalette.primaryBlue
                            : Colors.white,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.person_rounded,
                          color: AppPalette.textMuted,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${student.name} · ${student.xp} XP',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ),
                        if (student.id == selectedStudentId)
                          const Icon(
                            Icons.check_circle_rounded,
                            color: AppPalette.primaryBlue,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeacherCriterionPanel extends StatelessWidget {
  const _TeacherCriterionPanel({required this.criteria, required this.onTap});

  final List<CriterionOverview> criteria;
  final ValueChanged<CriterionOverview> onTap;

  @override
  Widget build(BuildContext context) {
    return SoftPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                  Icons.fact_check_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: AppSpacing.item),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Qualification Review',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Reset locked knowledge checks and review submitted criteria for your own subject only.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppPalette.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.section),
          if (criteria.isEmpty)
            const SoftPanel(
              padding: EdgeInsets.all(AppSpacing.item),
              child: Text('No criteria match this teacher\'s subject yet.'),
            )
          else
            ...criteria.map(
              (criterion) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.item),
                child: InkWell(
                  onTap: () => onTap(criterion),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  child: Ink(
                    padding: const EdgeInsets.all(AppSpacing.item),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                criterion.criterion.title,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${criterion.subject?.name ?? 'Subject'} · ${criterion.unit?.title ?? 'Unit'}',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: AppPalette.textMuted),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _StatusPill(
                                    label: _criterionStateLabel(
                                      criterion.progress,
                                    ),
                                  ),
                                  _StatusPill(
                                    label:
                                        '${criterion.progress.wordCount}/${criterion.criterion.requiredWordCount} words',
                                  ),
                                  _StatusPill(
                                    label:
                                        '${criterion.flags.attemptsRemaining} attempts left',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: AppPalette.navy,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _criterionStateLabel(CriterionProgress progress) {
    switch (progress.criterionState) {
      case 'learning_required':
        return 'Learning';
      case 'learning_check_active':
        return progress.learningLocked ? 'Reset needed' : 'Knowledge check';
      case 'essay_builder_unlocked':
        return 'Essay Builder';
      case 'ready_for_submission':
        return 'Ready to submit';
      case 'submitted':
        return 'Review now';
      case 'approved':
        return 'Approved';
      case 'revision_requested':
        return 'Revision';
      default:
        return 'Criterion';
    }
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

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

class _DraftMissionsPanel extends StatelessWidget {
  const _DraftMissionsPanel({
    required this.missions,
    required this.dailyDraftCount,
    required this.assessmentDraftCount,
    required this.isSelectingDrafts,
    required this.isDeletingDrafts,
    required this.selectedDraftMissionIds,
    required this.onOpenDailyDrafts,
    required this.onOpenAssessmentDrafts,
    required this.onToggleDraftSelectionMode,
    required this.onCancelDraftSelection,
    required this.onToggleDraftSelection,
    required this.onDeleteSelectedDrafts,
    required this.onEdit,
  });

  final List<MissionPayload> missions;
  final int dailyDraftCount;
  final int assessmentDraftCount;
  final bool isSelectingDrafts;
  final bool isDeletingDrafts;
  final Set<String> selectedDraftMissionIds;
  final VoidCallback onOpenDailyDrafts;
  final VoidCallback onOpenAssessmentDrafts;
  final VoidCallback onToggleDraftSelectionMode;
  final VoidCallback onCancelDraftSelection;
  final ValueChanged<MissionPayload> onToggleDraftSelection;
  final VoidCallback onDeleteSelectedDrafts;
  final ValueChanged<MissionPayload> onEdit;

  @override
  Widget build(BuildContext context) {
    return SoftPanel(
      colors: const [Color(0xFFF7FBFF), Color(0xFFE6F3FF)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                child: const Icon(Icons.edit_note_rounded, color: Colors.white),
              ),
              const SizedBox(width: AppSpacing.item),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Draft Missions',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Review and edit these drafts before the student can begin.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppPalette.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: onOpenDailyDrafts,
                icon: const Icon(Icons.list_alt_rounded, size: 18),
                label: Text(
                  dailyDraftCount <= 0
                      ? 'Daily drafts'
                      : 'Daily drafts ($dailyDraftCount)',
                ),
              ),
              TextButton.icon(
                onPressed: onOpenAssessmentDrafts,
                icon: const Icon(Icons.assignment_rounded, size: 18),
                label: Text(
                  assessmentDraftCount <= 0
                      ? 'Assessment drafts'
                      : 'Assessment drafts ($assessmentDraftCount)',
                ),
              ),
            ],
          ),
          if (missions.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.compact),
            if (!isSelectingDrafts)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onToggleDraftSelectionMode,
                  icon: const Icon(Icons.checklist_rtl_rounded, size: 18),
                  label: const Text('Select drafts'),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.item,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      selectedDraftMissionIds.isEmpty
                          ? 'Selection mode active'
                          : '${selectedDraftMissionIds.length} selected',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppPalette.navy,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextButton(
                      onPressed: isDeletingDrafts
                          ? null
                          : onCancelDraftSelection,
                      child: const Text('Cancel'),
                    ),
                    TextButton.icon(
                      onPressed:
                          isDeletingDrafts || selectedDraftMissionIds.isEmpty
                          ? null
                          : onDeleteSelectedDrafts,
                      icon: isDeletingDrafts
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.delete_outline_rounded, size: 18),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFB3261E),
                      ),
                      label: Text(
                        isDeletingDrafts
                            ? 'Deleting...'
                            : selectedDraftMissionIds.isEmpty
                            ? 'Delete selected'
                            : 'Delete selected (${selectedDraftMissionIds.length})',
                      ),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: AppSpacing.item),
          if (missions.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.item),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.76),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Text(
                'No draft missions yet. Generate one above, review it, and publish when ready.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          else
            ...missions.map((mission) {
              final isSelected = selectedDraftMissionIds.contains(mission.id);
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.compact),
                child: _MissionCard(
                  mission: mission,
                  badgeLabel: 'Draft',
                  dateLabel: _formatMissionDate(
                    mission.availableOnDate ?? mission.createdAt,
                  ),
                  actionLabel: isSelectingDrafts
                      ? (isSelected ? 'Selected for delete' : 'Tap to select')
                      : 'Edit draft',
                  showSelectionControl: isSelectingDrafts,
                  isSelected: isSelected,
                  onSelectionTap: () => onToggleDraftSelection(mission),
                  onTap: isSelectingDrafts
                      ? () => onToggleDraftSelection(mission)
                      : () => onEdit(mission),
                ),
              );
            }),
        ],
      ),
    );
  }

  String _formatMissionDate(String? value) {
    if (value == null || value.isEmpty) {
      return 'Just now';
    }

    final parsed = DateTime.tryParse(value)?.toLocal();

    if (parsed == null) {
      return 'Just now';
    }

    return '${_month(parsed.month)} ${parsed.day}';
  }

  String _month(int month) {
    const labels = [
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

    return labels[month - 1];
  }
}

class _LatestAssignedMissionsPanel extends StatelessWidget {
  const _LatestAssignedMissionsPanel({
    required this.missions,
    required this.sendingResultMissionIds,
    required this.onEdit,
    required this.onMoveBackToDraft,
    required this.onSendResult,
    required this.onViewResult,
  });

  final List<MissionPayload> missions;
  final Set<String> sendingResultMissionIds;
  final ValueChanged<MissionPayload> onEdit;
  final ValueChanged<MissionPayload> onMoveBackToDraft;
  final ValueChanged<MissionPayload> onSendResult;
  final ValueChanged<MissionPayload> onViewResult;

  @override
  Widget build(BuildContext context) {
    final totalAssignedXp = missions.fold<int>(
      0,
      (total, mission) => total + (mission.xpReward < 0 ? 0 : mission.xpReward),
    );
    final totalEarnedXp = missions.fold<int>(0, (total, mission) {
      final reward = mission.xpReward < 0 ? 0 : mission.xpReward;
      final earned = mission.xpEarned < 0
          ? 0
          : (mission.xpEarned > reward ? reward : mission.xpEarned);
      return total + earned;
    });
    final assignedProgressRatio = totalAssignedXp <= 0
        ? 0.0
        : totalEarnedXp / totalAssignedXp;

    return SoftPanel(
      colors: const [Color(0xFFFFFCF6), Color(0xFFFFF0D8)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppPalette.sun, AppPalette.orange],
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.library_books_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: AppSpacing.item),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Assigned Missions',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Published missions become available on their scheduled lesson date.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppPalette.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.compact),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.item),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.76),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Assigned mission XP progress',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  '$totalEarnedXp / $totalAssignedXp XP filled',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppPalette.textMuted),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Stack(
                        children: [
                          Container(
                            height: 12,
                            width: double.infinity,
                            color: Colors.white.withValues(alpha: 0.78),
                          ),
                          Container(
                            height: 12,
                            width: constraints.maxWidth * assignedProgressRatio,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: AppPalette.progressGradient,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  totalAssignedXp == 0
                      ? 'No assigned mission XP yet.'
                      : 'Total assigned mission XP: $totalAssignedXp',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppPalette.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.item),
          if (missions.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.item),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.76),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Text(
                'No assigned AI missions yet. Generate one from the panel above.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          else
            ...missions.asMap().entries.map((entry) {
              final mission = entry.value;
              final scoreTotal = mission.scoreTotal > 0
                  ? mission.scoreTotal
                  : mission.questionCount;
              final scoreCorrect = mission.scoreCorrect < 0
                  ? 0
                  : (mission.scoreCorrect > scoreTotal
                        ? scoreTotal
                        : mission.scoreCorrect);
              final scoreRatio = scoreTotal <= 0
                  ? 0.0
                  : scoreCorrect / scoreTotal;
              final rewardXp = mission.xpReward < 0 ? 0 : mission.xpReward;
              final earnedXp = mission.xpEarned < 0
                  ? 0
                  : (mission.xpEarned > rewardXp ? rewardXp : mission.xpEarned);
              final hasResultPackage = mission.latestResultPackageId
                  .trim()
                  .isNotEmpty;
              final isTheoryPendingReview =
                  mission.draftFormat == 'THEORY' &&
                  hasResultPackage &&
                  earnedXp == 0 &&
                  mission.scoreTotal <= 0;
              final topProgressRatio = isTheoryPendingReview
                  ? 0.0
                  : mission.draftFormat == 'THEORY' && hasResultPackage
                  ? (mission.scorePercent.clamp(0, 100) / 100)
                  : scoreRatio;
              final topProgressLabel = isTheoryPendingReview
                  ? 'Pending review · XP pending'
                  : mission.draftFormat == 'THEORY' && hasResultPackage
                  ? '${mission.scorePercent}% scored · $earnedXp/$rewardXp XP'
                  : mission.draftFormat == 'THEORY'
                  ? 'Awaiting submission · $earnedXp/$rewardXp XP'
                  : '$scoreCorrect/$scoreTotal score · $earnedXp/$rewardXp XP';
              final isSendingResult = sendingResultMissionIds.contains(
                mission.id,
              );
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.compact),
                child: _MissionCard(
                  mission: mission,
                  badgeLabel: mission.source == 'groq' ? 'Groq' : 'Bank',
                  dateLabel: _formatMissionDate(
                    mission.availableOnDate ??
                        mission.publishedAt ??
                        mission.createdAt,
                  ),
                  actionLabel: 'Edit mission',
                  topProgressRatio: topProgressRatio,
                  topProgressLabel: topProgressLabel,
                  secondaryActionLabel: isSendingResult
                      ? 'Sending result...'
                      : 'Send result',
                  onSecondaryTap: hasResultPackage && !isSendingResult
                      ? () => onSendResult(mission)
                      : null,
                  tertiaryActionLabel: 'View result',
                  onTertiaryTap: hasResultPackage
                      ? () => onViewResult(mission)
                      : null,
                  quaternaryActionLabel: 'Move back to draft',
                  onQuaternaryTap: () => onMoveBackToDraft(mission),
                  onTap: () => onEdit(mission),
                ),
              );
            }),
        ],
      ),
    );
  }

  String _formatMissionDate(String? value) {
    if (value == null || value.isEmpty) {
      return 'Just now';
    }

    final parsed = DateTime.tryParse(value)?.toLocal();

    if (parsed == null) {
      return 'Just now';
    }

    return '${_month(parsed.month)} ${parsed.day}';
  }

  String _month(int month) {
    const labels = [
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

    return labels[month - 1];
  }
}

class _AssessmentDraftListResult {
  const _AssessmentDraftListResult._({
    required this.createNew,
    required this.mission,
    required this.lockedTaskCodes,
  });

  factory _AssessmentDraftListResult.open(MissionPayload mission) {
    return _AssessmentDraftListResult._(
      createNew: false,
      mission: mission,
      lockedTaskCodes: const [],
    );
  }

  factory _AssessmentDraftListResult.createNew(List<String> lockedTaskCodes) {
    return _AssessmentDraftListResult._(
      createNew: true,
      mission: null,
      lockedTaskCodes: lockedTaskCodes,
    );
  }

  final bool createNew;
  final MissionPayload? mission;
  final List<String> lockedTaskCodes;
}

class _DailyDraftListResult {
  const _DailyDraftListResult._({
    required this.createNew,
    required this.mission,
  });

  factory _DailyDraftListResult.open(MissionPayload mission) {
    return _DailyDraftListResult._(createNew: false, mission: mission);
  }

  factory _DailyDraftListResult.createNew() {
    return const _DailyDraftListResult._(createNew: true, mission: null);
  }

  final bool createNew;
  final MissionPayload? mission;
}

class _DailyDraftListScreen extends StatelessWidget {
  const _DailyDraftListScreen({
    required this.studentName,
    required this.missions,
  });

  final String studentName;
  final List<MissionPayload> missions;

  @override
  Widget build(BuildContext context) {
    return FocusScaffold(
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _HeaderButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Daily Draft Missions',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => Navigator.of(
                      context,
                    ).pop(_DailyDraftListResult.createNew()),
                    icon: const Icon(
                      Icons.add_circle_outline_rounded,
                      size: 18,
                    ),
                    label: const Text('Create new daily mission draft'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.compact),
              Text(
                'Only daily draft missions for $studentName are shown here. Assessment drafts are in their own page.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppPalette.textMuted),
              ),
              const SizedBox(height: AppSpacing.section),
              SoftPanel(
                colors: const [Color(0xFFF7FBFF), Color(0xFFE6F3FF)],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (missions.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.item),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.76),
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusMd,
                          ),
                        ),
                        child: Text(
                          'No daily drafts yet. Create one from the lesson panel.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      )
                    else
                      ...missions.map(
                        (mission) => Padding(
                          padding: const EdgeInsets.only(
                            bottom: AppSpacing.compact,
                          ),
                          child: _MissionCard(
                            mission: mission,
                            badgeLabel: 'Daily Draft',
                            dateLabel: _formatMissionDate(
                              mission.availableOnDate ?? mission.createdAt,
                            ),
                            actionLabel: 'Open daily draft',
                            onTap: () => Navigator.of(
                              context,
                            ).pop(_DailyDraftListResult.open(mission)),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatMissionDate(String? value) {
    if (value == null || value.isEmpty) {
      return 'Just now';
    }

    final parsed = DateTime.tryParse(value)?.toLocal();
    if (parsed == null) {
      return 'Just now';
    }

    return '${_month(parsed.month)} ${parsed.day}';
  }

  String _month(int month) {
    const labels = [
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

    return labels[month - 1];
  }
}

class _AssessmentDraftListScreen extends StatelessWidget {
  const _AssessmentDraftListScreen({
    required this.studentName,
    required this.studentXp,
    required this.missions,
    required this.lockedTaskCodes,
  });

  final String studentName;
  final int studentXp;
  final List<MissionPayload> missions;
  final List<String> lockedTaskCodes;

  @override
  Widget build(BuildContext context) {
    final totalAvailableXp = missions.fold<int>(
      0,
      (total, mission) => total + (mission.xpReward < 0 ? 0 : mission.xpReward),
    );
    final safeStudentXp = studentXp < 0 ? 0 : studentXp;
    final cappedStudentXp = totalAvailableXp <= 0
        ? 0
        : (safeStudentXp > totalAvailableXp ? totalAvailableXp : safeStudentXp);
    final progressRatio = totalAvailableXp <= 0
        ? 0.0
        : cappedStudentXp / totalAvailableXp;
    final missionProgress = <_MissionDraftProgress>[];
    var remainingMissionXp = cappedStudentXp;
    for (final mission in missions) {
      final rewardXp = mission.xpReward < 0 ? 0 : mission.xpReward;
      final filledXp = rewardXp <= 0
          ? 0
          : (remainingMissionXp >= rewardXp ? rewardXp : remainingMissionXp);
      if (remainingMissionXp > 0) {
        remainingMissionXp -= filledXp;
      }
      missionProgress.add(
        _MissionDraftProgress(
          totalXp: rewardXp,
          filledXp: filledXp,
          ratio: rewardXp <= 0 ? 0 : filledXp / rewardXp,
        ),
      );
    }

    return FocusScaffold(
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _HeaderButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Assessment Draft Missions',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).pop(
                      _AssessmentDraftListResult.createNew(lockedTaskCodes),
                    ),
                    icon: const Icon(
                      Icons.add_circle_outline_rounded,
                      size: 18,
                    ),
                    label: const Text('Create new assessment draft'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.compact),
              Text(
                'Only assessment drafts for $studentName are shown here. Daily drafts stay in the main Draft Missions section.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppPalette.textMuted),
              ),
              const SizedBox(height: AppSpacing.compact),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.item),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.76),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'XP progress from assessment drafts',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$cappedStudentXp / $totalAvailableXp XP filled',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppPalette.textMuted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return Stack(
                            children: [
                              Container(
                                height: 12,
                                width: double.infinity,
                                color: Colors.white.withValues(alpha: 0.78),
                              ),
                              Container(
                                height: 12,
                                width: constraints.maxWidth * progressRatio,
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: AppPalette.progressGradient,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      totalAvailableXp == 0
                          ? 'Create assessment drafts to build available XP for this student.'
                          : 'Available XP is the sum of XP reward across current assessment drafts.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppPalette.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (lockedTaskCodes.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Locked task focus codes from existing drafts: ${lockedTaskCodes.join(', ')}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppPalette.textMuted),
                ),
              ],
              const SizedBox(height: AppSpacing.section),
              SoftPanel(
                colors: const [Color(0xFFF7FBFF), Color(0xFFE6F3FF)],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (missions.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.item),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.76),
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusMd,
                          ),
                        ),
                        child: Text(
                          'No assessment drafts yet. Build one from 10-question assessment mode.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      )
                    else
                      ...missions.asMap().entries.map((entry) {
                        final mission = entry.value;
                        final xpProgress = missionProgress[entry.key];
                        return Padding(
                          padding: const EdgeInsets.only(
                            bottom: AppSpacing.compact,
                          ),
                          child: _MissionCard(
                            mission: mission,
                            badgeLabel: 'Assessment Draft',
                            dateLabel: _formatMissionDate(
                              mission.availableOnDate ?? mission.createdAt,
                            ),
                            actionLabel: 'Open assessment draft',
                            topProgressRatio: xpProgress.ratio,
                            topProgressLabel:
                                '${xpProgress.filledXp}/${xpProgress.totalXp} XP filled',
                            onTap: () => Navigator.of(
                              context,
                            ).pop(_AssessmentDraftListResult.open(mission)),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatMissionDate(String? value) {
    if (value == null || value.isEmpty) {
      return 'Just now';
    }

    final parsed = DateTime.tryParse(value)?.toLocal();
    if (parsed == null) {
      return 'Just now';
    }

    return '${_month(parsed.month)} ${parsed.day}';
  }

  String _month(int month) {
    const labels = [
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

    return labels[month - 1];
  }
}

class _MissionDraftProgress {
  const _MissionDraftProgress({
    required this.totalXp,
    required this.filledXp,
    required this.ratio,
  });

  final int totalXp;
  final int filledXp;
  final double ratio;
}

typedef _EditTeacherCertificationPlan =
    Future<void> Function({
      required TeacherWorkspaceData workspace,
      required _TeacherCertificationSubjectOption subject,
      SubjectCertificationSummary? initialCertification,
    });

class _TeacherCertificationSubjectOption {
  const _TeacherCertificationSubjectOption({
    required this.subjectId,
    required this.subjectName,
    this.subjectIcon,
    this.subjectColor,
  });

  final String subjectId;
  final String subjectName;
  final String? subjectIcon;
  final String? subjectColor;
}

class _TeacherCertificationPanel extends StatelessWidget {
  const _TeacherCertificationPanel({
    required this.workspace,
    required this.subjects,
    required this.certifications,
    required this.studentName,
    required this.onEditPlan,
  });

  final TeacherWorkspaceData workspace;
  final List<_TeacherCertificationSubjectOption> subjects;
  final List<SubjectCertificationSummary> certifications;
  final String studentName;
  final _EditTeacherCertificationPlan onEditPlan;

  @override
  Widget build(BuildContext context) {
    final certificationsBySubject = <String, SubjectCertificationSummary>{
      for (final certification in certifications)
        certification.subjectId: certification,
    };

    return SoftPanel(
      colors: const [Color(0xFFF7FCFF), Color(0xFFEAF4FF)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Task-focus certification',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Set the certification objectives for each subject you teach, then target one task focus per qualifying mission so progress stays auditable.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppPalette.textMuted),
          ),
          const SizedBox(height: AppSpacing.compact),
          if (subjects.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.item),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Text(
                'No timetable subjects are assigned to this teacher for $studentName yet.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          else
            ...subjects.map((subject) {
              final certification = certificationsBySubject[subject.subjectId];
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.compact),
                child: _TeacherCertificationCard(
                  subject: subject,
                  certification: certification,
                  onEditPlan: () => onEditPlan(
                    workspace: workspace,
                    subject: subject,
                    initialCertification: certification,
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _TeacherCertificationCard extends StatelessWidget {
  const _TeacherCertificationCard({
    required this.subject,
    required this.certification,
    required this.onEditPlan,
  });

  final _TeacherCertificationSubjectOption subject;
  final SubjectCertificationSummary? certification;
  final VoidCallback onEditPlan;

  CertificationEvidenceRow? _evidenceForTaskCode(String taskCode) {
    final rows =
        certification?.evidenceRows ?? const <CertificationEvidenceRow>[];
    for (final row in rows) {
      if (row.taskCode == taskCode) {
        return row;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final hasPlan = certification != null;
    final isUnlocked = certification?.certificateUnlocked == true;
    final requiredTaskCodes =
        certification?.requiredTaskCodes ?? const <String>[];
    final passedTaskCodes = certification?.passedTaskCodes ?? const <String>[];
    final remainingTaskCodes =
        certification?.remainingTaskCodes ?? const <String>[];
    final summaryText = hasPlan
        ? remainingTaskCodes.isEmpty
              ? 'All required task focuses are complete.'
              : 'Still needed: ${remainingTaskCodes.join(', ')}'
        : 'No certification objectives set yet. Pick the task focuses this student must pass for ${subject.subjectName}.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.item),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
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
                      subject.subjectName,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasPlan
                          ? certification!.certificationLabel
                          : 'Set the live certification plan for this student and subject.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppPalette.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: hasPlan
                      ? (isUnlocked ? AppPalette.mint : AppPalette.sun)
                            .withValues(alpha: 0.14)
                      : AppPalette.sky.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  !hasPlan
                      ? 'Needs setup'
                      : isUnlocked
                      ? 'Certificate unlocked'
                      : '${passedTaskCodes.length}/${requiredTaskCodes.length} passed',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: !hasPlan
                        ? AppPalette.sky
                        : isUnlocked
                        ? AppPalette.mint
                        : AppPalette.orange,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            summaryText,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppPalette.textMuted),
          ),
          if (hasPlan) ...[
            const SizedBox(height: 6),
            Text(
              '${certification!.completionPercentage}% complete · Average on passed focuses ${certification!.averagePassedScorePercent.toStringAsFixed(1)}%',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if ((certification!.planVersion ?? 0) > 0) ...[
              const SizedBox(height: 6),
              Text(
                'Plan v${certification!.planVersion} · ${certification!.planSource == 'teacher_plan' ? 'Teacher-owned plan' : 'Legacy template'}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppPalette.textMuted),
              ),
            ],
            if ((certification!.planChangeReason ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Last change: ${certification!.planChangeReason}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppPalette.textMuted),
                ),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: requiredTaskCodes
                  .map((taskCode) {
                    final evidence = _evidenceForTaskCode(taskCode);
                    return _TeacherCertificationChip(
                      taskCode: taskCode,
                      status: evidence?.status ?? 'not_started',
                      scorePercent: evidence?.bestScorePercent ?? 0,
                    );
                  })
                  .toList(growable: false),
            ),
          ],
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: onEditPlan,
              icon: Icon(
                hasPlan ? Icons.edit_note_rounded : Icons.playlist_add_rounded,
              ),
              label: Text(hasPlan ? 'Update objectives' : 'Set objectives'),
            ),
          ),
        ],
      ),
    );
  }
}

class _TeacherCertificationChip extends StatelessWidget {
  const _TeacherCertificationChip({
    required this.taskCode,
    required this.status,
    required this.scorePercent,
  });

  final String taskCode;
  final String status;
  final double scorePercent;

  @override
  Widget build(BuildContext context) {
    late final Color backgroundColor;
    late final Color borderColor;
    late final Color textColor;

    switch (status) {
      case 'passed':
        backgroundColor = const Color(0xFFE8FFF0);
        borderColor = const Color(0xFF8DDBAC);
        textColor = const Color(0xFF157347);
        break;
      case 'pending_review':
        backgroundColor = const Color(0xFFFFF7E5);
        borderColor = const Color(0xFFF4CD79);
        textColor = const Color(0xFFB27300);
        break;
      case 'not_passed':
        backgroundColor = const Color(0xFFFFF0F0);
        borderColor = const Color(0xFFFFB3B3);
        textColor = const Color(0xFFB42318);
        break;
      default:
        backgroundColor = const Color(0xFFF5F8FF);
        borderColor = const Color(0xFFD5E6FF);
        textColor = AppPalette.navy;
        break;
    }

    final label = status == 'passed'
        ? '$taskCode · ${scorePercent.toStringAsFixed(0)}%'
        : status == 'pending_review'
        ? '$taskCode · Pending'
        : taskCode;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MissionCard extends StatelessWidget {
  const _MissionCard({
    required this.mission,
    required this.badgeLabel,
    required this.dateLabel,
    required this.actionLabel,
    required this.onTap,
    this.topProgressRatio,
    this.topProgressLabel,
    this.secondaryActionLabel,
    this.onSecondaryTap,
    this.tertiaryActionLabel,
    this.onTertiaryTap,
    this.quaternaryActionLabel,
    this.onQuaternaryTap,
    this.showSelectionControl = false,
    this.isSelected = false,
    this.onSelectionTap,
  });

  final MissionPayload mission;
  final String badgeLabel;
  final String dateLabel;
  final String actionLabel;
  final VoidCallback onTap;
  final double? topProgressRatio;
  final String? topProgressLabel;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryTap;
  final String? tertiaryActionLabel;
  final VoidCallback? onTertiaryTap;
  final String? quaternaryActionLabel;
  final VoidCallback? onQuaternaryTap;
  final bool showSelectionControl;
  final bool isSelected;
  final VoidCallback? onSelectionTap;

  @override
  Widget build(BuildContext context) {
    final handleSelectionTap = onSelectionTap ?? onTap;
    final showProminentResultActions =
        secondaryActionLabel != null || tertiaryActionLabel != null;
    final hasDisabledResultAction =
        (secondaryActionLabel != null && onSecondaryTap == null) ||
        (tertiaryActionLabel != null && onTertiaryTap == null);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: showSelectionControl ? handleSelectionTap : onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.item),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: showSelectionControl && isSelected
                ? Border.all(
                    color: AppPalette.primaryBlue.withValues(alpha: 0.65),
                    width: 1.5,
                  )
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (topProgressRatio != null && topProgressLabel != null) ...[
                Text(
                  topProgressLabel!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppPalette.textMuted),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final ratio = topProgressRatio!
                          .clamp(0.0, 1.0)
                          .toDouble();
                      return Stack(
                        children: [
                          Container(
                            height: 8,
                            width: double.infinity,
                            color: Colors.white.withValues(alpha: 0.78),
                          ),
                          Container(
                            height: 8,
                            width: constraints.maxWidth * ratio,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: AppPalette.progressGradient,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.item),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: AppPalette.teacherGradient,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      mission.sessionType == 'morning'
                          ? Icons.wb_sunny_rounded
                          : Icons.nights_stay_rounded,
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
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${mission.subject?.name ?? 'Mission'} · ${mission.draftFormat == 'ESSAY_BUILDER' ? '${mission.questionCount} sentences' : '${mission.questionCount} questions'} · ${mission.sessionType}',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppPalette.textMuted),
                        ),
                        if (mission.taskCodes.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Tasks: ${mission.taskCodes.join(', ')}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: AppPalette.primaryBlue,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                        if ((mission.availableOnDate ?? '').isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Scheduled for ${mission.availableOnDate}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppPalette.primaryBlue),
                          ),
                        ],
                        if (mission.teacherNote.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            mission.teacherNote,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                        if (showProminentResultActions) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppPalette.sky.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Result actions',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: AppPalette.navy,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    if (secondaryActionLabel != null)
                                      _MissionActionButton(
                                        label: secondaryActionLabel!,
                                        icon: Icons.send_rounded,
                                        onTap: onSecondaryTap,
                                        colors: const [
                                          AppPalette.sun,
                                          AppPalette.orange,
                                        ],
                                      ),
                                    if (tertiaryActionLabel != null)
                                      _MissionActionButton(
                                        label: tertiaryActionLabel!,
                                        icon: Icons.visibility_rounded,
                                        onTap: onTertiaryTap,
                                        colors: const [
                                          AppPalette.primaryBlue,
                                          AppPalette.aqua,
                                        ],
                                      ),
                                  ],
                                ),
                                if (hasDisabledResultAction) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    'Buttons unlock after this mission has a saved result package.',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(color: AppPalette.textMuted),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Text(
                          actionLabel,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppPalette.primaryBlue,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        if (quaternaryActionLabel != null &&
                            onQuaternaryTap != null) ...[
                          const SizedBox(height: 6),
                          TextButton(
                            onPressed: onQuaternaryTap,
                            style: TextButton.styleFrom(
                              minimumSize: const Size(0, 0),
                              padding: EdgeInsets.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              alignment: Alignment.centerLeft,
                            ),
                            child: Text(
                              quaternaryActionLabel!,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: AppPalette.navy,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.compact),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _MissionMiniPill(label: badgeLabel),
                      const SizedBox(height: 8),
                      Text(
                        dateLabel,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppPalette.textMuted,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (showSelectionControl)
                        InkWell(
                          onTap: handleSelectionTap,
                          borderRadius: BorderRadius.circular(999),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppPalette.primaryBlue
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: isSelected
                                    ? AppPalette.primaryBlue
                                    : AppPalette.textMuted.withValues(
                                        alpha: 0.45,
                                      ),
                              ),
                            ),
                            child: isSelected
                                ? const Icon(
                                    Icons.check_rounded,
                                    size: 14,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                        )
                      else
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: AppPalette.textMuted,
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MissionMiniPill extends StatelessWidget {
  const _MissionMiniPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppPalette.sky.withValues(alpha: 0.28),
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

class _MissionActionButton extends StatelessWidget {
  const _MissionActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.colors,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onTap != null;
    return Opacity(
      opacity: isEnabled ? 1 : 0.58,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            gradient: isEnabled ? LinearGradient(colors: colors) : null,
            color: isEnabled ? null : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppPalette.textMuted.withValues(alpha: 0.35),
            ),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 140),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 16,
                      color: isEnabled ? Colors.white : AppPalette.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isEnabled ? Colors.white : AppPalette.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TargetStarsRow extends StatelessWidget {
  const _TargetStarsRow({
    required this.target,
    required this.enabled,
    required this.onSetStars,
  });

  final TargetSummary target;
  final bool enabled;
  final ValueChanged<int> onSetStars;

  @override
  Widget build(BuildContext context) {
    final statusLabel = target.status.replaceAll('_', ' ');
    final typeLabel = target.targetType == 'fixed_daily_mission'
        ? 'Default · Daily mission'
        : target.targetType == 'fixed_assessment'
        ? 'Default · Assessment'
        : 'Custom target';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.item),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  target.title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              _MissionMiniPill(label: '${target.xpAwarded} XP'),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$typeLabel · $statusLabel',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppPalette.textMuted),
          ),
          if (target.description.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              target.description.trim(),
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Stars',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppPalette.textMuted),
              ),
              const SizedBox(width: 8),
              ...List.generate(3, (index) {
                final starValue = index + 1;
                final selected = target.stars >= starValue;
                return IconButton(
                  onPressed: enabled ? () => onSetStars(starValue) : null,
                  iconSize: 20,
                  visualDensity: VisualDensity.compact,
                  splashRadius: 18,
                  padding: const EdgeInsets.all(2),
                  icon: Icon(
                    selected ? Icons.star_rounded : Icons.star_border_rounded,
                    color: selected ? AppPalette.sun : AppPalette.textMuted,
                  ),
                );
              }),
              const SizedBox(width: 4),
              Text(
                '${target.stars}/3',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppPalette.navy),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChoicePill extends StatelessWidget {
  const _ChoicePill({
    required this.label,
    required this.selected,
    required this.colors,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final List<Color> colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: selected ? LinearGradient(colors: colors) : null,
          color: selected ? null : Colors.white.withValues(alpha: 0.68),
          borderRadius: BorderRadius.circular(999),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: colors.first.withValues(alpha: 0.18),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: selected ? Colors.white : AppPalette.navy,
          ),
        ),
      ),
    );
  }
}
