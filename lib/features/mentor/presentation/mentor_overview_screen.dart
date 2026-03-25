/**
 * WHAT:
 * MentorOverviewScreen renders the learning mentor workspace with timetable,
 * engagement metrics, and support difficulty controls.
 * WHY:
 * Mentors need a dedicated, calm overview that helps them support the student
 * without stepping into teacher authoring or student submission flows.
 * HOW:
 * Load the mentor workspace from the API, render the support panels, and allow
 * difficulty and profile updates from the same screen.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'package:flutter/material.dart';

import '../../../core/constants/app_palette.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/auth_session_store.dart';
import '../../../core/utils/focus_mission_api.dart';
import '../../../shared/models/focus_mission_models.dart';
import '../../../shared/widgets/focus_scaffold.dart';
import '../../../shared/widgets/notification_panel.dart';
import '../../../shared/widgets/profile_avatar_button.dart';
import '../../../shared/widgets/profile_sheet.dart';
import '../../../shared/widgets/soft_panel.dart';
import '../../../shared/widgets/stat_chip.dart';
import '../../../shared/widgets/weekly_timetable_calendar.dart';
import '../../auth/presentation/role_selection_screen.dart';
import 'mentor_saved_session_screen.dart';

class MentorOverviewScreen extends StatefulWidget {
  const MentorOverviewScreen({super.key, required this.session});

  final AuthSession session;

  @override
  State<MentorOverviewScreen> createState() => _MentorOverviewScreenState();
}

class _MentorOverviewScreenState extends State<MentorOverviewScreen> {
  final FocusMissionApi _api = FocusMissionApi();
  final AuthSessionStore _sessionStore = AuthSessionStore();

  late AuthSession _session;
  late Future<MentorWorkspaceData> _future;
  late DateTime _selectedCoveredSessionDate;
  String _selectedStudentId = '';
  MentorWorkspaceData? _workspace;
  NotificationInboxData? _notificationInbox;
  Future<MentorCoveredSessionsData>? _coveredSessionsFuture;
  String _difficulty = 'Easy';
  bool _isUpdatingDifficulty = false;
  List<TargetSummary>? _targets;
  bool _isUpdatingTargets = false;
  String _savingCoveredSessionId = '';

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    final now = DateTime.now();
    _selectedCoveredSessionDate = DateTime(now.year, now.month, now.day);
    _persistSessionSnapshot();
    _future = _loadWorkspace();
  }

  Future<void> _persistSessionSnapshot() async {
    try {
      await _sessionStore.saveSession(_session);
    } catch (_) {}
  }

  Future<MentorWorkspaceData> _loadWorkspace() async {
    final workspace = await _api.loadMentorWorkspace(
      mentorSession: _session,
      selectedStudentId: _selectedStudentId,
    );
    _selectedStudentId = workspace.selectedStudent.id;
    _coveredSessionsFuture = _loadCoveredSessions(
      studentId: workspace.selectedStudent.id,
      date: _selectedCoveredSessionDate,
    );
    _workspace = workspace;
    _notificationInbox ??= workspace.notificationInbox;
    _targets ??= workspace.overview.targets;
    _difficulty = _labelDifficulty(
      workspace.overview.student.preferredDifficulty ?? 'easy',
    );
    return workspace;
  }

  @override
  Widget build(BuildContext context) {
    return FocusScaffold(
      child: FutureBuilder<MentorWorkspaceData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _LoadingState(label: 'Loading mentor overview...');
          }

          if (snapshot.hasError) {
            return _ErrorState(
              message: snapshot.error.toString(),
              onBack: () => Navigator.of(context).pop(),
            );
          }

          final workspace = snapshot.data!;
          final overview = workspace.overview;
          final targets = _targets ?? overview.targets;
          final notificationInbox =
              _notificationInbox ?? workspace.notificationInbox;
          final coveredSessionsFuture = _coveredSessionsFuture ??=
              _loadCoveredSessions(
                studentId: workspace.selectedStudent.id,
                date: _selectedCoveredSessionDate,
              );

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.screen),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _IconButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        _session.user.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    ProfileAvatarButton(
                      user: _session.user,
                      onLogout: _signOut,
                      onTap: _openProfile,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.section),
                CurrentDatePanel(
                  subtitle:
                      '${overview.student.name}\'s learning calendar is ready across the full week and month.',
                ),
                const SizedBox(height: AppSpacing.item),
                _MentorStudentPickerCard(student: workspace.selectedStudent),
                const SizedBox(height: AppSpacing.compact),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _openStudentPicker(workspace),
                    icon: const Icon(Icons.swap_horiz_rounded),
                    label: const Text('Switch student'),
                  ),
                ),
                const SizedBox(height: AppSpacing.item),
                NotificationPanel(
                  title: 'Mentor Inbox',
                  subtitle:
                      'Keep an eye on review activity and student progress alerts from one calm queue.',
                  notifications: notificationInbox.notifications,
                  unreadCount: notificationInbox.unreadCount,
                  emptyMessage:
                      'No mentor notifications yet. Learning review and submission alerts will appear here.',
                  onTapNotification: _openNotification,
                ),
                const SizedBox(height: AppSpacing.item),
                SoftPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Weekly Overview · ${overview.student.name}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.item),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          StatChip(
                            value: '${overview.metrics.averageFocusScore}%',
                            label: 'Focus score',
                            colors: AppPalette.studentGradient,
                          ),
                          StatChip(
                            value: '${overview.metrics.weeklyXp}',
                            label: 'XP this week',
                            colors: const [
                              AppPalette.primaryBlue,
                              AppPalette.aqua,
                            ],
                          ),
                          StatChip(
                            value: '${overview.metrics.completedMissions}',
                            label: 'Completed missions',
                            colors: const [
                              AppPalette.sky,
                              AppPalette.primaryBlue,
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.item),
                WeeklyTimetableCalendar(
                  title: 'Learning Mentor Calendar',
                  subtitle:
                      'Review Monday to Sunday coverage and the whole month before adjusting support.',
                  entries: workspace.timetable,
                ),
                const SizedBox(height: AppSpacing.item),
                SoftPanel(
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
                                  'Covered Teaching Sessions',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'If management assigns mentor cover, record who taught the lesson and keep the session note auditable here.',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(color: AppPalette.textMuted),
                                ),
                              ],
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _pickCoveredSessionDate(workspace),
                            icon: const Icon(Icons.edit_calendar_rounded),
                            label: const Text('Change date'),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.item),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.78),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: AppPalette.sky.withValues(alpha: 0.54),
                          ),
                        ),
                        child: Text(
                          _formatCoveredSessionDate(
                            _selectedCoveredSessionDate,
                          ),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: AppPalette.navy,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.item),
                      FutureBuilder<MentorCoveredSessionsData>(
                        future: coveredSessionsFuture,
                        builder: (context, coveredSnapshot) {
                          if (coveredSnapshot.connectionState !=
                              ConnectionState.done) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(
                                vertical: AppSpacing.compact,
                              ),
                              child: Text('Loading covered sessions...'),
                            );
                          }

                          if (coveredSnapshot.hasError) {
                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(AppSpacing.item),
                              decoration: BoxDecoration(
                                color: AppPalette.sun.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusMd,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    coveredSnapshot.error.toString(),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(color: AppPalette.navy),
                                  ),
                                  const SizedBox(height: 10),
                                  OutlinedButton.icon(
                                    onPressed: () => setState(() {
                                      _coveredSessionsFuture =
                                          _loadCoveredSessions(
                                            studentId:
                                                workspace.selectedStudent.id,
                                            date: _selectedCoveredSessionDate,
                                          );
                                    }),
                                    icon: const Icon(Icons.refresh_rounded),
                                    label: const Text('Retry'),
                                  ),
                                ],
                              ),
                            );
                          }

                          final coveredSessions = coveredSnapshot.data!;
                          if (coveredSessions.sessions.isEmpty) {
                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(AppSpacing.item),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.74),
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusMd,
                                ),
                              ),
                              child: Text(
                                'No covered sessions are assigned for ${coveredSessions.student.name} on ${coveredSessions.dateKey}.',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            );
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: coveredSessions.sessions
                                .map(
                                  (session) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _MentorCoveredSessionCard(
                                      session: session,
                                      isSaving:
                                          _savingCoveredSessionId == session.id,
                                      onEdit: () => _openCoveredSessionEditor(
                                        studentId: coveredSessions.student.id,
                                        session: session,
                                      ),
                                      onOpenSavedSession:
                                          session.sessionLog == null
                                          ? null
                                          : () => _openSavedCoveredSession(
                                              studentName:
                                                  coveredSessions.student.name,
                                              studentYearGroup:
                                                  coveredSessions
                                                      .student
                                                      .yearGroup ??
                                                  '',
                                              session: session,
                                              targets: targets,
                                            ),
                                    ),
                                  ),
                                )
                                .toList(growable: false),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.item),
                SoftPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Weekly Targets',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _isUpdatingTargets
                                ? null
                                : () => _createTarget(workspace),
                            icon: const Icon(Icons.add_circle_outline_rounded),
                            label: const Text('Create target'),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.item),
                      if (targets.isEmpty)
                        Text(
                          'No targets yet. Add one from the backend or mentor tools.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        )
                      else
                        ...targets.map(
                          (target) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _MentorTargetRow(
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
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.item),
                SoftPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Unlock World',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.72),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'Live Targets',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppPalette.navy),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.section),
                      Text(
                        'Adjust Difficulty',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppPalette.textMuted,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.compact),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _DifficultyPill(
                            label: 'Easy',
                            selected: _difficulty == 'Easy',
                            onTap: _isUpdatingDifficulty
                                ? null
                                : () => _updateDifficulty('Easy'),
                          ),
                          _DifficultyPill(
                            label: 'Medium',
                            selected: _difficulty == 'Medium',
                            onTap: _isUpdatingDifficulty
                                ? null
                                : () => _updateDifficulty('Medium'),
                          ),
                          _DifficultyPill(
                            label: 'Hard',
                            selected: _difficulty == 'Hard',
                            onTap: _isUpdatingDifficulty
                                ? null
                                : () => _updateDifficulty('Hard'),
                          ),
                        ],
                      ),
                      if (_isUpdatingDifficulty) ...[
                        const SizedBox(height: AppSpacing.item),
                        Text(
                          'Updating support level...',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _updateDifficulty(String label) async {
    final workspace = _workspace;

    if (workspace == null) {
      return;
    }

    setState(() => _isUpdatingDifficulty = true);

    try {
      // WHY: Mentor difficulty updates stay manual so support changes remain a
      // deliberate human decision instead of an automatic AI adjustment.
      await _api.updateDifficulty(
        token: workspace.session.token,
        studentId: workspace.overview.student.id,
        difficulty: label,
      );

      if (!mounted) {
        return;
      }

      setState(() => _difficulty = label);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Difficulty updated to $label.')));
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _isUpdatingDifficulty = false);
      }
    }
  }

  Future<void> _createTarget(MentorWorkspaceData workspace) async {
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
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Target title',
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
        studentId: workspace.overview.student.id,
        title: title,
        description: descriptionController.text.trim(),
        difficulty: selectedDifficulty,
        targetType: 'custom',
      );
      if (!mounted) {
        return;
      }
      setState(() {
        final next = <TargetSummary>[
          ...(_targets ?? workspace.overview.targets),
          created,
        ];
        _targets = _sortTargets(next);
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

  Future<void> _setTargetStars({
    required MentorWorkspaceData workspace,
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
      );
      if (!mounted) {
        return;
      }
      setState(() {
        final next = (_targets ?? workspace.overview.targets)
            .map((item) => item.id == updated.id ? updated : item)
            .toList(growable: false);
        _targets = _sortTargets(next);
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

  String _labelDifficulty(String raw) {
    final value = raw.toLowerCase();

    if (value.isEmpty) {
      return 'Easy';
    }

    return '${value[0].toUpperCase()}${value.substring(1)}';
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

  Future<void> _openStudentPicker(MentorWorkspaceData workspace) async {
    final selectedStudentId = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => _MentorStudentPickerSheet(
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
      // WHY: Targets and notifications are student-specific and must refresh
      // immediately when the mentor switches focus to another learner.
      _selectedStudentId = selectedStudentId;
      _notificationInbox = null;
      _targets = null;
      _coveredSessionsFuture = _loadCoveredSessions(
        studentId: selectedStudentId,
        date: _selectedCoveredSessionDate,
      );
      _future = _loadWorkspace();
    });
  }

  String _dateKeyFromDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  String _formatCoveredSessionDate(DateTime date) {
    const monthNames = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${date.day} ${monthNames[date.month - 1]} ${date.year}';
  }

  Future<MentorCoveredSessionsData> _loadCoveredSessions({
    required String studentId,
    required DateTime date,
  }) {
    return _api.fetchMentorCoveredSessions(
      token: _session.token,
      studentId: studentId,
      dateKey: _dateKeyFromDate(date),
    );
  }

  Future<void> _pickCoveredSessionDate(MentorWorkspaceData workspace) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedCoveredSessionDate,
      firstDate: DateTime(2025, 1, 1),
      lastDate: DateTime(2027, 12, 31),
    );
    if (pickedDate == null || !mounted) {
      return;
    }

    setState(() {
      _selectedCoveredSessionDate = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
      );
      _coveredSessionsFuture = _loadCoveredSessions(
        studentId: workspace.selectedStudent.id,
        date: _selectedCoveredSessionDate,
      );
    });
  }

  Future<void> _openCoveredSessionEditor({
    required String studentId,
    required MentorCoveredSession session,
  }) async {
    final focusScoreController = TextEditingController(
      text: '${session.sessionLog?.focusScore ?? 80}',
    );
    final completedQuestionsController = TextEditingController(
      text: '${session.sessionLog?.completedQuestions ?? 0}',
    );
    final xpAwardedController = TextEditingController(
      text: '${session.sessionLog?.xpAwarded ?? 0}',
    );
    final notesController = TextEditingController(
      text: session.sessionLog?.notes ?? '',
    );
    var behaviourStatus = (session.sessionLog?.behaviourStatus ?? 'steady')
        .trim()
        .toLowerCase();

    try {
      final savedSession = await showModalBottomSheet<MentorCoveredSession>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (sheetContext) {
          var isSaving = false;
          return StatefulBuilder(
            builder: (context, setSheetState) {
              return Padding(
                padding: EdgeInsets.only(
                  left: AppSpacing.screen,
                  right: AppSpacing.screen,
                  top: AppSpacing.compact,
                  bottom:
                      MediaQuery.of(sheetContext).viewInsets.bottom +
                      AppSpacing.screen,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.subject?.name.trim().isNotEmpty == true
                            ? session.subject!.name.trim()
                            : 'Covered lesson',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${_mentorSessionLabel(session.sessionType)} · ${session.dateKey}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppPalette.textMuted,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.compact),
                      if (session.plannedTeacher?.name.trim().isNotEmpty ==
                          true)
                        Text(
                          'Planned teacher: ${session.plannedTeacher!.name}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      Text(
                        'Conducted by: ${session.coverStaff?.name.trim().isNotEmpty == true ? session.coverStaff!.name : _session.user.name}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (session.reason.trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Reason: ${session.reason.trim()}',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppPalette.textMuted),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.section),
                      TextField(
                        controller: focusScoreController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Focus score (0-100)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: completedQuestionsController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Completed questions',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: behaviourStatus,
                        decoration: const InputDecoration(
                          labelText: 'Behaviour status',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'great',
                            child: Text('Great'),
                          ),
                          DropdownMenuItem(
                            value: 'steady',
                            child: Text('Steady'),
                          ),
                          DropdownMenuItem(
                            value: 'warning',
                            child: Text('Warning'),
                          ),
                          DropdownMenuItem(
                            value: 'penalty',
                            child: Text('Penalty'),
                          ),
                        ],
                        onChanged: isSaving
                            ? null
                            : (value) {
                                if (value == null) {
                                  return;
                                }
                                setSheetState(() => behaviourStatus = value);
                              },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: xpAwardedController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Target/support XP (0-50)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: notesController,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Teaching note',
                          hintText:
                              'What happened in the covered lesson? Keep it factual and audit-ready.',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.section),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: isSaving
                              ? null
                              : () async {
                                  final notes = notesController.text.trim();
                                  if (notes.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'A teaching note is required for covered sessions.',
                                        ),
                                      ),
                                    );
                                    return;
                                  }

                                  setSheetState(() => isSaving = true);
                                  setState(
                                    () => _savingCoveredSessionId = session.id,
                                  );
                                  try {
                                    final savedResponse = await _api
                                        .createMentorCoveredSessionLog(
                                          token: _session.token,
                                          studentId: studentId,
                                          dateKey: session.dateKey,
                                          sessionType: session.sessionType,
                                          focusScore:
                                              int.tryParse(
                                                focusScoreController.text
                                                    .trim(),
                                              ) ??
                                              0,
                                          completedQuestions:
                                              int.tryParse(
                                                completedQuestionsController
                                                    .text
                                                    .trim(),
                                              ) ??
                                              0,
                                          behaviourStatus: behaviourStatus,
                                          notes: notes,
                                          xpAwarded:
                                              int.tryParse(
                                                xpAwardedController.text.trim(),
                                              ) ??
                                              0,
                                        );
                                    final savedSession = savedResponse.sessions
                                        .firstWhere(
                                          (item) =>
                                              item.id.trim() ==
                                              session.id.trim(),
                                          orElse: () =>
                                              savedResponse.sessions.first,
                                        );
                                    if (!mounted) {
                                      return;
                                    }
                                    if (!sheetContext.mounted) {
                                      return;
                                    }
                                    Navigator.of(
                                      sheetContext,
                                    ).pop(savedSession);
                                    setState(() {
                                      // WHY: Covered-session notes affect the
                                      // mentor overview metrics and the saved
                                      // audited lesson record, so both the
                                      // overview and session list refresh from
                                      // the backend together.
                                      _future = _loadWorkspace();
                                    });
                                    ScaffoldMessenger.of(
                                      this.context,
                                    ).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Covered session note saved.',
                                        ),
                                      ),
                                    );
                                  } catch (error) {
                                    if (!mounted) {
                                      return;
                                    }
                                    ScaffoldMessenger.of(
                                      this.context,
                                    ).showSnackBar(
                                      SnackBar(content: Text(error.toString())),
                                    );
                                    setSheetState(() => isSaving = false);
                                  } finally {
                                    if (mounted) {
                                      setState(
                                        () => _savingCoveredSessionId = '',
                                      );
                                    }
                                  }
                                },
                          icon: Icon(
                            isSaving
                                ? Icons.hourglass_top_rounded
                                : Icons.save_rounded,
                          ),
                          label: Text(
                            isSaving
                                ? 'Saving covered note...'
                                : 'Save covered session note',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );

      if (!mounted || savedSession == null) {
        return;
      }

      final targetSnapshot = List<TargetSummary>.from(
        _targets ?? _workspace?.overview.targets ?? const <TargetSummary>[],
      );
      await _openSavedCoveredSession(
        studentName: _workspace?.selectedStudent.name.trim().isNotEmpty == true
            ? _workspace!.selectedStudent.name.trim()
            : _session.user.name,
        studentYearGroup: _workspace?.selectedStudent.yearGroup ?? '',
        session: savedSession,
        targets: targetSnapshot,
      );
    } finally {
      focusScoreController.dispose();
      completedQuestionsController.dispose();
      xpAwardedController.dispose();
      notesController.dispose();
    }
  }

  String _mentorSessionLabel(String sessionType) {
    switch (sessionType.trim().toLowerCase()) {
      case 'morning':
        return 'Morning session';
      case 'afternoon':
        return 'Afternoon session';
      default:
        return sessionType.trim().isEmpty ? 'Session' : sessionType.trim();
    }
  }

  Future<void> _openSavedCoveredSession({
    required String studentName,
    required String studentYearGroup,
    required MentorCoveredSession session,
    required List<TargetSummary> targets,
  }) async {
    if (session.sessionLog == null) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MentorSavedSessionScreen(
          studentName: studentName,
          studentYearGroup: studentYearGroup,
          session: session,
          targets: targets,
        ),
      ),
    );
  }

  Future<void> _openNotification(AppNotification notification) async {
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

      final focusTarget =
          resolvedNotification.criterionTitle ??
          resolvedNotification.studentName ??
          resolvedNotification.title;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(focusTarget)));
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

    return NotificationInboxData(
      unreadCount: updatedNotifications.where((item) => !item.isRead).length,
      notifications: updatedNotifications,
    );
  }
}

class _MentorStudentPickerCard extends StatelessWidget {
  const _MentorStudentPickerCard({required this.student});

  final StudentSummary student;

  @override
  Widget build(BuildContext context) {
    return SoftPanel(
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: AppPalette.mentorGradient),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_rounded, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${student.name} · ${student.xp} XP',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          const Icon(
            Icons.arrow_forward_ios_rounded,
            size: 14,
            color: AppPalette.textMuted,
          ),
        ],
      ),
    );
  }
}

class _MentorStudentPickerSheet extends StatelessWidget {
  const _MentorStudentPickerSheet({
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
              'Switch student to update targets, progress, and support actions.',
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
                'Could not load the mentor overview',
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

class _IconButton extends StatelessWidget {
  const _IconButton({required this.icon, this.onTap});

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

class _MentorTargetRow extends StatelessWidget {
  const _MentorTargetRow({
    required this.target,
    required this.enabled,
    required this.onSetStars,
  });

  final TargetSummary target;
  final bool enabled;
  final ValueChanged<int> onSetStars;

  @override
  Widget build(BuildContext context) {
    final typeLabel = target.targetType == 'fixed_daily_mission'
        ? 'Default daily mission'
        : target.targetType == 'fixed_assessment'
        ? 'Default assessment'
        : 'Custom';
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
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppPalette.sky.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${target.xpAwarded} XP',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppPalette.navy),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$typeLabel · ${target.status.replaceAll('_', ' ')}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppPalette.textMuted),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              ...List.generate(3, (index) {
                final starValue = index + 1;
                final selected = target.stars >= starValue;
                return IconButton(
                  onPressed: enabled ? () => onSetStars(starValue) : null,
                  iconSize: 20,
                  splashRadius: 18,
                  padding: const EdgeInsets.all(2),
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    selected ? Icons.star_rounded : Icons.star_border_rounded,
                    color: selected ? AppPalette.sun : AppPalette.textMuted,
                  ),
                );
              }),
              const SizedBox(width: 6),
              Text(
                '${target.stars}/3',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MentorCoveredSessionCard extends StatelessWidget {
  const _MentorCoveredSessionCard({
    required this.session,
    required this.isSaving,
    required this.onEdit,
    this.onOpenSavedSession,
  });

  final MentorCoveredSession session;
  final bool isSaving;
  final VoidCallback onEdit;
  final VoidCallback? onOpenSavedSession;

  String _sessionLabel() {
    switch (session.sessionType.trim().toLowerCase()) {
      case 'morning':
        return 'Morning session';
      case 'afternoon':
        return 'Afternoon session';
      default:
        return session.sessionType.trim().isEmpty
            ? 'Session'
            : session.sessionType.trim();
    }
  }

  @override
  Widget build(BuildContext context) {
    final subjectName = session.subject?.name.trim().isNotEmpty == true
        ? session.subject!.name.trim()
        : 'Covered lesson';
    final plannedTeacher = session.plannedTeacher?.name.trim() ?? '';
    final coverMentor = session.coverStaff?.name.trim() ?? '';
    final log = session.sessionLog;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.item),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppPalette.sky.withValues(alpha: 0.4)),
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
                      subjectName,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _CoveredSessionPill(
                          label: _sessionLabel(),
                          backgroundColor: AppPalette.primaryBlue.withValues(
                            alpha: 0.12,
                          ),
                        ),
                        if (plannedTeacher.isNotEmpty)
                          _CoveredSessionPill(
                            label: 'Planned: $plannedTeacher',
                            backgroundColor: AppPalette.sun.withValues(
                              alpha: 0.18,
                            ),
                          ),
                        if (coverMentor.isNotEmpty)
                          _CoveredSessionPill(
                            label: 'Cover: $coverMentor',
                            backgroundColor: AppPalette.mint.withValues(
                              alpha: 0.2,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (log != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppPalette.mint.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Saved',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppPalette.navy,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          if (session.reason.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              session.reason.trim(),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppPalette.textMuted),
            ),
          ],
          if (log != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppPalette.sky.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _CoveredSessionPill(
                        label: 'Focus ${log.focusScore}',
                        backgroundColor: AppPalette.primaryBlue.withValues(
                          alpha: 0.12,
                        ),
                      ),
                      _CoveredSessionPill(
                        label: 'Questions ${log.completedQuestions}',
                        backgroundColor: AppPalette.sky.withValues(alpha: 0.18),
                      ),
                      _CoveredSessionPill(
                        label: log.behaviourStatus.isEmpty
                            ? 'Steady'
                            : log.behaviourStatus,
                        backgroundColor: AppPalette.sun.withValues(alpha: 0.16),
                      ),
                      _CoveredSessionPill(
                        label: '${log.xpAwarded} XP',
                        backgroundColor: AppPalette.mint.withValues(
                          alpha: 0.18,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    log.notes.trim(),
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: AppPalette.navy),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Author: ${log.authorName.isEmpty ? 'Mentor' : log.authorName}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppPalette.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (log != null)
                OutlinedButton.icon(
                  onPressed: isSaving ? null : onOpenSavedSession,
                  icon: const Icon(Icons.visibility_rounded),
                  label: const Text('Saved session'),
                ),
              FilledButton.tonalIcon(
                onPressed: isSaving ? null : onEdit,
                icon: Icon(
                  isSaving
                      ? Icons.hourglass_top_rounded
                      : Icons.edit_note_rounded,
                ),
                label: Text(
                  isSaving
                      ? 'Saving...'
                      : log == null
                      ? 'Log covered session'
                      : 'Update covered session',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CoveredSessionPill extends StatelessWidget {
  const _CoveredSessionPill({
    required this.label,
    required this.backgroundColor,
  });

  final String label;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppPalette.navy,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DifficultyPill extends StatelessWidget {
  const _DifficultyPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(colors: AppPalette.mentorGradient)
              : null,
          color: selected ? null : Colors.white.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: selected ? AppPalette.navy : AppPalette.textMuted,
          ),
        ),
      ),
    );
  }
}
