/**
 * WHAT:
 * ManagementOverviewScreen provides a dedicated management workspace after
 * management users sign in, including user creation and result review.
 * WHY:
 * Management users need their own section to monitor student delivery,
 * outcomes, and staff/student setup without being routed into mentor flows.
 * HOW:
 * Load mentor-compatible workspace data from the API, show management-focused
 * summary cards, allow creation of student/teacher accounts, and expose
 * subject-filtered result review for assigned students.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'package:flutter/material.dart';

import '../../../core/constants/app_palette.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/focus_mission_api.dart';
import '../../../shared/models/focus_mission_models.dart';
import '../../../shared/widgets/focus_scaffold.dart';
import '../../../shared/widgets/notification_panel.dart';
import '../../../shared/widgets/profile_avatar_button.dart';
import '../../../shared/widgets/profile_sheet.dart';
import '../../../shared/widgets/soft_panel.dart';
import '../../../shared/widgets/stat_chip.dart';
import '../../../shared/widgets/weekly_timetable_calendar.dart';
import '../../teacher/presentation/result_report_screen.dart';

const _allSubjectsFilterLabel = 'All subjects';
const _allCertificationSubjectsFilterLabel = 'All certification subjects';
const List<String> _managementWeekdayOptions = <String>[
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
];
const List<String> _timetableRoomOptions = <String>[
  'Room 1',
  'Room 2',
  'Room 3',
  'Room 4',
  'Room 5',
  'Room 6',
  'Room 7',
  'Room 8',
];
const List<String> _certificationTaskCodeOptions = [
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

class ManagementOverviewScreen extends StatefulWidget {
  const ManagementOverviewScreen({super.key, required this.session});

  final AuthSession session;

  @override
  State<ManagementOverviewScreen> createState() =>
      _ManagementOverviewScreenState();
}

class _ManagementOverviewScreenState extends State<ManagementOverviewScreen> {
  final FocusMissionApi _api = FocusMissionApi();
  final GlobalKey<FormState> _createUserFormKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _subjectSpecialtyController =
      TextEditingController();
  final TextEditingController _certificationLabelController =
      TextEditingController();

  late AuthSession _session;
  late Future<_ManagementScreenData> _future;
  late DateTime _selectedTimetableDate;
  String _selectedStudentId = '';
  String _selectedSubject = _allSubjectsFilterLabel;
  String _selectedCertificationSubject = _allCertificationSubjectsFilterLabel;
  String _selectedCertificationEditorSubjectId = '';
  String _selectedTimetableDay = _managementWeekdayOptions.first;
  String _selectedMorningSubjectId = '';
  String _selectedAfternoonSubjectId = '';
  String _selectedMorningTeacherId = '';
  String _selectedAfternoonTeacherId = '';
  String _selectedMorningRoom = _timetableRoomOptions.first;
  String _selectedAfternoonRoom = _timetableRoomOptions.first;
  String _createRole = 'student';
  NotificationInboxData? _notificationInbox;
  bool _isCreatingUser = false;
  bool _isSavingCertification = false;
  bool _isSavingTimetable = false;
  bool _showTimetableEditor = false;
  bool _certificationEnabled = false;
  AppUser? _lastCreatedUser;
  final Set<String> _selectedCertificationTaskCodes = <String>{};

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    final now = DateTime.now();
    _selectedTimetableDate = DateTime(now.year, now.month, now.day);
    _future = _loadWorkspace();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _subjectSpecialtyController.dispose();
    _certificationLabelController.dispose();
    super.dispose();
  }

  Future<_ManagementScreenData> _loadWorkspace() async {
    final workspace = await _api.loadMentorWorkspace(
      mentorSession: _session,
      selectedStudentId: _selectedStudentId,
    );
    final recentResults = await _api.fetchManagementStudentResults(
      token: _session.token,
      studentId: workspace.selectedStudent.id,
    );
    final certifications = await _api.fetchManagementStudentCertification(
      token: _session.token,
      studentId: workspace.selectedStudent.id,
    );
    final responses = await Future.wait([
      _api.fetchManagementCertificationSubjects(token: _session.token),
      _api.fetchManagementTeachers(token: _session.token),
    ]);
    final certificationSubjects =
        responses[0] as List<SubjectCertificationSettings>;
    final teachers = responses[1] as List<TeacherSummary>;
    _selectedStudentId = workspace.selectedStudent.id;
    _notificationInbox ??= workspace.notificationInbox;
    _syncCertificationEditor(certificationSubjects);
    _syncTimetableEditor(
      timetable: workspace.timetable,
      subjects: certificationSubjects,
      teachers: teachers,
    );
    final certificationFilters = _buildCertificationFilters(certifications);
    if (!certificationFilters.contains(_selectedCertificationSubject)) {
      _selectedCertificationSubject = _allCertificationSubjectsFilterLabel;
    }
    return _ManagementScreenData(
      workspace: workspace,
      recentResults: recentResults,
      certifications: certifications,
      certificationSubjects: certificationSubjects,
      teachers: teachers,
    );
  }

  void _syncCertificationEditor(List<SubjectCertificationSettings> subjects) {
    if (subjects.isEmpty) {
      _selectedCertificationEditorSubjectId = '';
      _certificationEnabled = false;
      _selectedCertificationTaskCodes.clear();
      _certificationLabelController.text = 'Course Certification';
      return;
    }

    final selected = subjects.firstWhere(
      (subject) => subject.subjectId == _selectedCertificationEditorSubjectId,
      orElse: () => subjects.first,
    );

    _selectedCertificationEditorSubjectId = selected.subjectId;
    _certificationEnabled = selected.certificationEnabled;
    _selectedCertificationTaskCodes
      ..clear()
      ..addAll(selected.requiredCertificationTaskCodes);
    _certificationLabelController.text = selected.certificationLabel;
  }

  void _selectCertificationEditorSubject(
    String subjectId,
    List<SubjectCertificationSettings> subjects,
  ) {
    final selected = subjects.firstWhere(
      (subject) => subject.subjectId == subjectId,
      orElse: () => subjects.first,
    );

    setState(() {
      _selectedCertificationEditorSubjectId = selected.subjectId;
      _certificationEnabled = selected.certificationEnabled;
      _selectedCertificationTaskCodes
        ..clear()
        ..addAll(selected.requiredCertificationTaskCodes);
      _certificationLabelController.text = selected.certificationLabel;
    });
  }

  void _toggleCertificationTaskCode(String taskCode) {
    setState(() {
      if (_selectedCertificationTaskCodes.contains(taskCode)) {
        _selectedCertificationTaskCodes.remove(taskCode);
      } else {
        _selectedCertificationTaskCodes.add(taskCode);
      }
    });
  }

  Future<void> _saveCertificationTemplate() async {
    if (_selectedCertificationEditorSubjectId.trim().isEmpty ||
        _isSavingCertification) {
      return;
    }

    if (_certificationEnabled && _selectedCertificationTaskCodes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Pick at least one required task focus before enabling certification.',
          ),
        ),
      );
      return;
    }

    setState(() => _isSavingCertification = true);
    try {
      final updated = await _api.updateManagementSubjectCertification(
        token: _session.token,
        subjectId: _selectedCertificationEditorSubjectId,
        certificationEnabled: _certificationEnabled,
        requiredCertificationTaskCodes: _selectedCertificationTaskCodes.toList(
          growable: false,
        )..sort(),
        certificationLabel: _certificationLabelController.text.trim().isEmpty
            ? 'Course Certification'
            : _certificationLabelController.text.trim(),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedCertificationEditorSubjectId = updated.subjectId;
        _certificationEnabled = updated.certificationEnabled;
        _selectedCertificationTaskCodes
          ..clear()
          ..addAll(updated.requiredCertificationTaskCodes);
        _certificationLabelController.text = updated.certificationLabel;
        _future = _loadWorkspace();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Certification settings saved.')),
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
        setState(() => _isSavingCertification = false);
      }
    }
  }

  void _syncTimetableEditor({
    required List<TodaySchedule> timetable,
    required List<SubjectCertificationSettings> subjects,
    required List<TeacherSummary> teachers,
  }) {
    final fallbackDate = _dateOnly(_selectedTimetableDate);
    final nextDate = _isWeekendDate(_selectedTimetableDate)
        ? fallbackDate
        : _dateOnly(_selectedTimetableDate);
    final fallbackDay = timetable.isNotEmpty
        ? timetable.first.day
        : _managementWeekdayOptions.first;
    final nextDay = !_isWeekendDate(nextDate)
        ? _weekdayLabelForDate(nextDate)
        : (_managementWeekdayOptions.contains(_selectedTimetableDay)
              ? _selectedTimetableDay
              : fallbackDay);

    _selectedTimetableDate = nextDate;
    _selectedTimetableDay = nextDay;
    _applyTimetableDaySelection(
      day: nextDay,
      timetable: timetable,
      subjects: subjects,
      teachers: teachers,
    );
  }

  void _applyTimetableDaySelection({
    required String day,
    required List<TodaySchedule> timetable,
    required List<SubjectCertificationSettings> subjects,
    required List<TeacherSummary> teachers,
  }) {
    final entry = timetable.cast<TodaySchedule?>().firstWhere(
      (item) => item?.day == day,
      orElse: () => null,
    );
    final firstSubjectId = subjects.isNotEmpty ? subjects.first.subjectId : '';

    final morningSubjectId =
        _resolveSubjectId(
          subjects: subjects,
          currentSubjectId: entry?.morningMission.id ?? '',
          fallbackSubjectId: _selectedMorningSubjectId.isNotEmpty
              ? _selectedMorningSubjectId
              : firstSubjectId,
        ) ??
        '';
    final afternoonSubjectId =
        _resolveSubjectId(
          subjects: subjects,
          currentSubjectId: entry?.afternoonMission.id ?? '',
          fallbackSubjectId: _selectedAfternoonSubjectId.isNotEmpty
              ? _selectedAfternoonSubjectId
              : firstSubjectId,
        ) ??
        '';

    // WHY: Keep the editor aligned with the saved timetable entry for the
    // selected day so management edits the real live slot, not stale form data.
    _selectedMorningSubjectId = morningSubjectId;
    _selectedAfternoonSubjectId = afternoonSubjectId;
    _selectedMorningTeacherId = _resolveTeacherId(
      teachers: teachers,
      currentTeacherId: entry?.morningTeacher?.id ?? '',
      fallbackTeacherId: _selectedMorningTeacherId,
    );
    _selectedAfternoonTeacherId = _resolveTeacherId(
      teachers: teachers,
      currentTeacherId: entry?.afternoonTeacher?.id ?? '',
      fallbackTeacherId: _selectedAfternoonTeacherId,
    );
    final roomSelection = _parseTimetableRooms(
      entry?.room ?? '',
      morningFallback: _selectedMorningRoom,
      afternoonFallback: _selectedAfternoonRoom,
    );
    _selectedMorningRoom = roomSelection.morningRoom;
    _selectedAfternoonRoom = roomSelection.afternoonRoom;
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  void _selectTimetableDate({
    required DateTime date,
    required List<TodaySchedule> timetable,
    required List<SubjectCertificationSettings> subjects,
    required List<TeacherSummary> teachers,
  }) {
    final normalized = _dateOnly(date);
    // WHY: The calendar is now a direct selector for the inline editor below,
    // so the chosen date must always drive the visible day fields on-screen.
    _selectedTimetableDate = normalized;

    if (_isWeekendDate(normalized)) {
      return;
    }

    final day = _weekdayLabelForDate(normalized);
    _selectedTimetableDay = day;
    _applyTimetableDaySelection(
      day: day,
      timetable: timetable,
      subjects: subjects,
      teachers: teachers,
    );
  }

  String? _resolveSubjectId({
    required List<SubjectCertificationSettings> subjects,
    required String currentSubjectId,
    required String fallbackSubjectId,
  }) {
    if (subjects.any((subject) => subject.subjectId == currentSubjectId)) {
      return currentSubjectId;
    }
    if (subjects.any((subject) => subject.subjectId == fallbackSubjectId)) {
      return fallbackSubjectId;
    }
    return subjects.isNotEmpty ? subjects.first.subjectId : null;
  }

  String _resolveTeacherId({
    required List<TeacherSummary> teachers,
    required String currentTeacherId,
    required String fallbackTeacherId,
  }) {
    if (teachers.any((teacher) => teacher.id == currentTeacherId)) {
      return currentTeacherId;
    }
    if (teachers.any((teacher) => teacher.id == fallbackTeacherId)) {
      return fallbackTeacherId;
    }
    return '';
  }

  _TimetableRoomSelection _parseTimetableRooms(
    String value, {
    required String morningFallback,
    required String afternoonFallback,
  }) {
    final parts = value
        .split('/')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList(growable: false);

    final resolvedMorning = _resolveRoomOption(
      parts.isNotEmpty ? parts.first : '',
      fallback: morningFallback,
    );
    final resolvedAfternoon = _resolveRoomOption(
      parts.length > 1 ? parts[1] : '',
      fallback: afternoonFallback,
    );

    return _TimetableRoomSelection(
      morningRoom: resolvedMorning,
      afternoonRoom: resolvedAfternoon,
    );
  }

  String _resolveRoomOption(String currentRoom, {required String fallback}) {
    if (_timetableRoomOptions.contains(currentRoom)) {
      return currentRoom;
    }
    if (_timetableRoomOptions.contains(fallback)) {
      return fallback;
    }
    return _timetableRoomOptions.first;
  }

  String _composeTimetableRooms({
    required String morningRoom,
    required String afternoonRoom,
  }) {
    // WHY: The backend timetable contract stores one room string for the day,
    // so the UI composes the two selected slot rooms into the existing format.
    return '$morningRoom / $afternoonRoom';
  }

  bool _isWeekendDate(DateTime date) =>
      date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;

  String _weekdayLabelForDate(DateTime date) {
    return _managementWeekdayOptions[date.weekday - 1];
  }

  Future<bool> _persistTimetableEntry({
    required _ManagementScreenData data,
    required String day,
    required String room,
    required String morningSubjectId,
    required String afternoonSubjectId,
    required String morningTeacherId,
    required String afternoonTeacherId,
  }) async {
    if (morningSubjectId.trim().isEmpty || afternoonSubjectId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose a morning and afternoon subject first.'),
        ),
      );
      return false;
    }

    if (room.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a morning and afternoon room.')),
      );
      return false;
    }

    try {
      await _api.saveManagementStudentTimetableEntry(
        token: _session.token,
        studentId: data.workspace.selectedStudent.id,
        day: day,
        room: room.trim(),
        morningSubjectId: morningSubjectId,
        afternoonSubjectId: afternoonSubjectId,
        morningTeacherId: morningTeacherId,
        afternoonTeacherId: afternoonTeacherId,
      );

      if (!mounted) {
        return true;
      }

      setState(() {
        _selectedTimetableDay = day;
        _selectedMorningSubjectId = morningSubjectId;
        _selectedAfternoonSubjectId = afternoonSubjectId;
        _selectedMorningTeacherId = morningTeacherId;
        _selectedAfternoonTeacherId = afternoonTeacherId;
        final roomSelection = _parseTimetableRooms(
          room.trim(),
          morningFallback: _selectedMorningRoom,
          afternoonFallback: _selectedAfternoonRoom,
        );
        _selectedMorningRoom = roomSelection.morningRoom;
        _selectedAfternoonRoom = roomSelection.afternoonRoom;
        // WHY: Reloading the full workspace keeps the planner calendar, the
        // student dashboard summary, and the form state in sync after a save.
        _future = _loadWorkspace();
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Timetable saved for $day.')));
      return true;
    } catch (error) {
      if (!mounted) {
        return false;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
      return false;
    }
  }

  Future<void> _saveTimetableEntry(_ManagementScreenData data) async {
    if (_isSavingTimetable) {
      return;
    }

    setState(() => _isSavingTimetable = true);
    try {
      await _persistTimetableEntry(
        data: data,
        day: _selectedTimetableDay,
        room: _composeTimetableRooms(
          morningRoom: _selectedMorningRoom,
          afternoonRoom: _selectedAfternoonRoom,
        ),
        morningSubjectId: _selectedMorningSubjectId,
        afternoonSubjectId: _selectedAfternoonSubjectId,
        morningTeacherId: _selectedMorningTeacherId,
        afternoonTeacherId: _selectedAfternoonTeacherId,
      );
    } finally {
      if (mounted) {
        setState(() => _isSavingTimetable = false);
      }
    }
  }

  void _toggleTimetableEditor(_ManagementScreenData data) {
    setState(() {
      _showTimetableEditor = !_showTimetableEditor;
      if (_showTimetableEditor) {
        // WHY: When management opens the editor it must be synced to the
        // selected calendar day so teacher, subject, and room edits land on the
        // visible timetable slot.
        _selectTimetableDate(
          date: _selectedTimetableDate,
          timetable: data.workspace.timetable,
          subjects: data.certificationSubjects,
          teachers: data.teachers,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return FocusScaffold(
      child: FutureBuilder<_ManagementScreenData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _LoadingState(label: 'Loading management section...');
          }

          if (snapshot.hasError) {
            return _ErrorState(
              message: snapshot.error.toString(),
              onBack: () => Navigator.of(context).pop(),
            );
          }

          final data = snapshot.data!;
          final workspace = data.workspace;
          final overview = workspace.overview;
          final inbox = _notificationInbox ?? workspace.notificationInbox;
          final subjectFilters = _buildSubjectFilters(data.recentResults);
          final selectedSubject = subjectFilters.contains(_selectedSubject)
              ? _selectedSubject
              : _allSubjectsFilterLabel;
          final filteredResults = _filterResults(
            data.recentResults,
            selectedSubject,
          );
          final certificationFilters = _buildCertificationFilters(
            data.certifications,
          );
          final selectedCertificationSubject =
              certificationFilters.contains(_selectedCertificationSubject)
              ? _selectedCertificationSubject
              : _allCertificationSubjectsFilterLabel;
          final filteredCertifications = _filterCertifications(
            data.certifications,
            selectedCertificationSubject,
          );
          final selectedCertificationSettings =
              data.certificationSubjects.isEmpty
              ? null
              : data.certificationSubjects.firstWhere(
                  (subject) =>
                      subject.subjectId ==
                      _selectedCertificationEditorSubjectId,
                  orElse: () => data.certificationSubjects.first,
                );

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.screen),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _TopIconButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Management Section',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _session.user.name,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: AppPalette.textMuted),
                          ),
                        ],
                      ),
                    ),
                    ProfileAvatarButton(
                      user: _session.user,
                      onTap: _openProfile,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.section),
                CurrentDatePanel(
                  title: 'Management Dashboard',
                  subtitle:
                      'Monitor delivery quality, student outcomes, and support activity from one place.',
                ),
                const SizedBox(height: AppSpacing.item),
                _SelectedStudentCard(student: workspace.selectedStudent),
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
                SoftPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Delivery Snapshot',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.item),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          StatChip(
                            value: '${workspace.students.length}',
                            label: 'Assigned students',
                            colors: const [
                              AppPalette.primaryBlue,
                              AppPalette.aqua,
                            ],
                          ),
                          StatChip(
                            value: '${overview.metrics.weeklyXp}',
                            label: '${workspace.selectedStudent.name} XP',
                            colors: const [AppPalette.sun, AppPalette.orange],
                          ),
                          StatChip(
                            value: '${overview.metrics.completedMissions}',
                            label: 'Completed missions',
                            colors: const [
                              AppPalette.primaryBlue,
                              AppPalette.aqua,
                            ],
                          ),
                          StatChip(
                            value: '${inbox.unreadCount}',
                            label: 'Unread alerts',
                            colors: const [AppPalette.sun, AppPalette.orange],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SoftPanel(
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
                        'Track which required task focuses this student has already passed for each subject.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppPalette.textMuted,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.compact),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: certificationFilters
                            .map(
                              (subject) => _SubjectFilterChip(
                                label: subject,
                                selected:
                                    subject == selectedCertificationSubject,
                                onTap: () => setState(
                                  () => _selectedCertificationSubject = subject,
                                ),
                              ),
                            )
                            .toList(growable: false),
                      ),
                      const SizedBox(height: AppSpacing.item),
                      if (filteredCertifications.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppSpacing.item),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.78),
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusMd,
                            ),
                          ),
                          child: Text(
                            'No certification templates are active for this student yet.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        )
                      else
                        ...filteredCertifications.map(
                          (certification) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.compact,
                            ),
                            child: _ManagementCertificationCard(
                              certification: certification,
                              missionByResultPackageId: {
                                for (final mission in data.recentResults)
                                  mission.latestResultPackageId.trim(): mission,
                              },
                              onOpenResult: (mission) => _openResultReport(
                                mission: mission,
                                student: workspace.selectedStudent,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.item),
                SoftPanel(
                  colors: const [Color(0xFFFFFCF6), Color(0xFFFFF3E4)],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Certification Setup',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Choose which task focuses a student must pass to unlock the subject certificate. Changes are blocked after live evidence exists.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppPalette.textMuted,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.compact),
                      if (data.certificationSubjects.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppSpacing.item),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.78),
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusMd,
                            ),
                          ),
                          child: Text(
                            'No subjects are available to configure yet.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        )
                      else ...[
                        DropdownButtonFormField<String>(
                          initialValue:
                              selectedCertificationSettings?.subjectId,
                          decoration: const InputDecoration(
                            labelText: 'Subject',
                          ),
                          items: data.certificationSubjects
                              .map(
                                (subject) => DropdownMenuItem<String>(
                                  value: subject.subjectId,
                                  child: Text(subject.subjectName),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }
                            _selectCertificationEditorSubject(
                              value,
                              data.certificationSubjects,
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile.adaptive(
                          value: _certificationEnabled,
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Enable certification'),
                          subtitle: const Text(
                            'Use task-focus passes to unlock a subject certificate.',
                          ),
                          onChanged: (value) =>
                              setState(() => _certificationEnabled = value),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _certificationLabelController,
                          decoration: const InputDecoration(
                            labelText: 'Certificate label',
                            hintText: 'Course Certification',
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Required task focuses',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: _certificationTaskCodeOptions
                              .map(
                                (taskCode) => _CreateRoleChip(
                                  label: taskCode,
                                  icon: Icons.flag_rounded,
                                  selected: _selectedCertificationTaskCodes
                                      .contains(taskCode),
                                  onTap: () =>
                                      _toggleCertificationTaskCode(taskCode),
                                ),
                              )
                              .toList(growable: false),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _selectedCertificationTaskCodes.isEmpty
                              ? 'No task focuses selected yet.'
                              : 'Required: ${(_selectedCertificationTaskCodes.toList(growable: false)..sort()).join(', ')}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppPalette.textMuted),
                        ),
                        const SizedBox(height: AppSpacing.compact),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _isSavingCertification
                                ? null
                                : _saveCertificationTemplate,
                            icon: const Icon(Icons.save_rounded),
                            label: Text(
                              _isSavingCertification
                                  ? 'Saving certification...'
                                  : 'Save Certification Setup',
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.item),
                SoftPanel(
                  colors: const [Color(0xFFFFFCF6), Color(0xFFFFF3E4)],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _createRole == 'student'
                            ? 'Add New Student'
                            : 'Add New Teacher',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _createRole == 'student'
                            ? 'Create a student account and add that learner to management immediately.'
                            : 'Create a teacher account with a subject specialty.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppPalette.textMuted,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.compact),
                      Text(
                        'Account type',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _CreateRoleChip(
                              label: 'Student',
                              icon: Icons.school_rounded,
                              selected: _createRole == 'student',
                              onTap: () =>
                                  setState(() => _createRole = 'student'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _CreateRoleChip(
                              label: 'Teacher',
                              icon: Icons.menu_book_rounded,
                              selected: _createRole == 'teacher',
                              onTap: () =>
                                  setState(() => _createRole = 'teacher'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.compact),
                      Form(
                        key: _createUserFormKey,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                labelText: 'Full name',
                                hintText: 'Enter full name',
                              ),
                              validator: (value) {
                                if ((value ?? '').trim().isEmpty) {
                                  return 'Enter a name.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _emailController,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                hintText: 'name@school.org',
                              ),
                              validator: (value) {
                                final email = (value ?? '').trim();
                                if (email.isEmpty || !email.contains('@')) {
                                  return 'Enter a valid email.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'Password',
                                hintText: 'At least 8 characters',
                              ),
                              validator: (value) {
                                if ((value ?? '').length < 8) {
                                  return 'Use at least 8 characters.';
                                }
                                return null;
                              },
                            ),
                            if (_createRole == 'teacher') ...[
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _subjectSpecialtyController,
                                decoration: const InputDecoration(
                                  labelText: 'Subject specialty',
                                  hintText: 'English, Science, Business',
                                ),
                                validator: (value) {
                                  if (_createRole == 'teacher' &&
                                      (value ?? '').trim().isEmpty) {
                                    return 'Enter a subject specialty.';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.compact),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _isCreatingUser
                              ? null
                              : _createManagedUser,
                          icon: const Icon(Icons.person_add_alt_1_rounded),
                          label: Text(
                            _isCreatingUser
                                ? 'Creating account...'
                                : 'Create ${_createRole == 'student' ? 'Student' : 'Teacher'}',
                          ),
                        ),
                      ),
                      if (_lastCreatedUser != null) ...[
                        const SizedBox(height: AppSpacing.compact),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppSpacing.item),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.78),
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusMd,
                            ),
                          ),
                          child: Text(
                            'Created: ${_lastCreatedUser!.name} · ${_lastCreatedUser!.role} · ${_lastCreatedUser!.email ?? ''}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.item),
                NotificationPanel(
                  title: 'Management Inbox',
                  subtitle:
                      'Track review-required and submitted activity before sharing outcomes.',
                  notifications: inbox.notifications,
                  unreadCount: inbox.unreadCount,
                  emptyMessage:
                      'No management notifications yet. New workflow alerts will appear here.',
                  onTapNotification: _openNotification,
                ),
                const SizedBox(height: AppSpacing.item),
                WeeklyTimetableCalendar(
                  title: 'Student Timetable',
                  subtitle:
                      'Confirm lesson coverage across week and month for the selected student.',
                  entries: workspace.timetable,
                  date: _selectedTimetableDate,
                  actionLabel: _showTimetableEditor
                      ? 'Hide timetable editor'
                      : 'Add teacher, subject, and room',
                  actionIcon: _showTimetableEditor
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.add_circle_outline_rounded,
                  onActionPressed: () => _toggleTimetableEditor(data),
                  inlineEditor: _showTimetableEditor
                      ? _ManagementTimetableInlineEditor(
                          selectedDate: _selectedTimetableDate,
                          isWeekend: _isWeekendDate(_selectedTimetableDate),
                          hasSubjects: data.certificationSubjects.isNotEmpty,
                          subjectOptions: data.certificationSubjects,
                          teacherOptions: data.teachers,
                          selectedDayKey: _selectedTimetableDay,
                          selectedMorningSubjectId: _selectedMorningSubjectId,
                          selectedAfternoonSubjectId:
                              _selectedAfternoonSubjectId,
                          selectedMorningTeacherId: _selectedMorningTeacherId,
                          selectedAfternoonTeacherId:
                              _selectedAfternoonTeacherId,
                          selectedMorningRoom: _selectedMorningRoom,
                          selectedAfternoonRoom: _selectedAfternoonRoom,
                          roomOptions: _timetableRoomOptions,
                          isSaving: _isSavingTimetable,
                          onMorningSubjectChanged: (value) {
                            if (value == null) {
                              return;
                            }
                            setState(() => _selectedMorningSubjectId = value);
                          },
                          onAfternoonSubjectChanged: (value) {
                            if (value == null) {
                              return;
                            }
                            setState(() => _selectedAfternoonSubjectId = value);
                          },
                          onMorningTeacherChanged: (value) => setState(
                            () => _selectedMorningTeacherId = value ?? '',
                          ),
                          onAfternoonTeacherChanged: (value) => setState(
                            () => _selectedAfternoonTeacherId = value ?? '',
                          ),
                          onMorningRoomChanged: (value) {
                            if (value == null) {
                              return;
                            }
                            setState(() => _selectedMorningRoom = value);
                          },
                          onAfternoonRoomChanged: (value) {
                            if (value == null) {
                              return;
                            }
                            setState(() => _selectedAfternoonRoom = value);
                          },
                          onSave: () => _saveTimetableEntry(data),
                        )
                      : null,
                  onDateChanged: (date) => setState(
                    () => _selectTimetableDate(
                      date: date,
                      timetable: workspace.timetable,
                      subjects: data.certificationSubjects,
                      teachers: data.teachers,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.item),
                SoftPanel(
                  colors: const [Color(0xFFF7FBFF), Color(0xFFEAF4FF)],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Student Results',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Filter by subject and open a full read-only result report for any completed mission.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppPalette.textMuted,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.compact),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: subjectFilters
                            .map(
                              (subject) => _SubjectFilterChip(
                                label: subject,
                                selected: subject == selectedSubject,
                                onTap: () =>
                                    setState(() => _selectedSubject = subject),
                              ),
                            )
                            .toList(growable: false),
                      ),
                      const SizedBox(height: AppSpacing.item),
                      if (filteredResults.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppSpacing.item),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.78),
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusMd,
                            ),
                          ),
                          child: Text(
                            data.recentResults.isEmpty
                                ? 'No saved result packages were found for this student yet.'
                                : 'No results match this subject filter.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        )
                      else
                        ...filteredResults.map(
                          (mission) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.compact,
                            ),
                            child: _ManagementResultCard(
                              mission: mission,
                              onView: () => _openResultReport(
                                mission: mission,
                                student: workspace.selectedStudent,
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
                      Text(
                        'Management Notes',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      _noteRow(
                        context,
                        icon: Icons.check_circle_outline_rounded,
                        text:
                            'Use this section to review outcomes before external reporting.',
                      ),
                      const SizedBox(height: 8),
                      _noteRow(
                        context,
                        icon: Icons.mark_email_read_outlined,
                        text:
                            'Open any unread alert to mark it read and keep the inbox clean.',
                      ),
                      const SizedBox(height: 8),
                      _noteRow(
                        context,
                        icon: Icons.people_alt_outlined,
                        text:
                            'Switch student to verify each learner has complete mission evidence.',
                      ),
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

  Widget _noteRow(
    BuildContext context, {
    required IconData icon,
    required String text,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppPalette.primaryBlue),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppPalette.textMuted),
          ),
        ),
      ],
    );
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

  Future<void> _openStudentPicker(MentorWorkspaceData workspace) async {
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
      // WHY: Notifications and selected overview are student-specific, so
      // the screen refreshes immediately after switching student context.
      _selectedStudentId = selectedStudentId;
      _selectedSubject = _allSubjectsFilterLabel;
      _notificationInbox = null;
      _future = _loadWorkspace();
    });
  }

  Future<void> _openResultReport({
    required MissionPayload mission,
    required StudentSummary student,
  }) async {
    final resultPackageId = mission.latestResultPackageId.trim();

    if (resultPackageId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This mission does not have a saved result package yet.',
          ),
        ),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ResultReportScreen(
          session: _session,
          mission: mission,
          student: student,
          resultPackageId: resultPackageId,
          api: _api,
          readOnly: true,
        ),
      ),
    );
  }

  Future<void> _createManagedUser() async {
    if (!_createUserFormKey.currentState!.validate() || _isCreatingUser) {
      return;
    }

    setState(() => _isCreatingUser = true);
    try {
      final createdUser = await _api.createManagementUser(
        token: _session.token,
        role: _createRole,
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        subjectSpecialty: _subjectSpecialtyController.text.trim(),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _lastCreatedUser = createdUser;
        _nameController.clear();
        _emailController.clear();
        _passwordController.clear();
        _subjectSpecialtyController.clear();
        if (createdUser.role == 'student') {
          final nextAssignedStudents = {
            ..._session.user.assignedStudents,
            createdUser.id,
          }.toList(growable: false);
          // WHY: Newly created students should appear immediately in the
          // management workspace without forcing a logout/login cycle.
          _session = _session.copyWith(
            user: _session.user.copyWith(
              assignedStudents: nextAssignedStudents,
            ),
          );
          _selectedStudentId = createdUser.id;
          _selectedSubject = _allSubjectsFilterLabel;
          _notificationInbox = null;
          _future = _loadWorkspace();
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${createdUser.role == 'student' ? 'Student' : 'Teacher'} account created.',
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
        setState(() => _isCreatingUser = false);
      }
    }
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

  List<String> _buildSubjectFilters(List<MissionPayload> missions) {
    final labels = <String>{_allSubjectsFilterLabel};

    for (final mission in missions) {
      final subjectName = (mission.subject?.name ?? '').trim();
      if (subjectName.isNotEmpty) {
        labels.add(subjectName);
      }
    }

    return labels.toList(growable: false);
  }

  List<MissionPayload> _filterResults(
    List<MissionPayload> missions,
    String subject,
  ) {
    if (subject == _allSubjectsFilterLabel) {
      return missions;
    }

    return missions
        .where((mission) => (mission.subject?.name ?? '').trim() == subject)
        .toList(growable: false);
  }

  List<String> _buildCertificationFilters(
    List<SubjectCertificationSummary> certifications,
  ) {
    final labels = <String>{_allCertificationSubjectsFilterLabel};

    for (final certification in certifications) {
      final subjectName = certification.subjectName.trim();
      if (subjectName.isNotEmpty) {
        labels.add(subjectName);
      }
    }

    return labels.toList(growable: false);
  }

  List<SubjectCertificationSummary> _filterCertifications(
    List<SubjectCertificationSummary> certifications,
    String subject,
  ) {
    if (subject == _allCertificationSubjectsFilterLabel) {
      return certifications;
    }

    return certifications
        .where((certification) => certification.subjectName.trim() == subject)
        .toList(growable: false);
  }
}

class _ManagementCertificationCard extends StatelessWidget {
  const _ManagementCertificationCard({
    required this.certification,
    required this.missionByResultPackageId,
    required this.onOpenResult,
  });

  final SubjectCertificationSummary certification;
  final Map<String, MissionPayload> missionByResultPackageId;
  final ValueChanged<MissionPayload> onOpenResult;

  @override
  Widget build(BuildContext context) {
    final isUnlocked = certification.certificateUnlocked;

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
                      certification.subjectName,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      certification.certificationLabel,
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
                  color: (isUnlocked ? AppPalette.mint : AppPalette.sun)
                      .withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  isUnlocked
                      ? 'Certificate unlocked'
                      : '${certification.passedTaskCodes.length}/${certification.requiredTaskCodes.length} passed',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isUnlocked ? AppPalette.mint : AppPalette.orange,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            certification.remainingTaskCodes.isEmpty
                ? 'All required task focuses are complete.'
                : 'Still needed: ${certification.remainingTaskCodes.join(', ')}',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppPalette.textMuted),
          ),
          const SizedBox(height: 6),
          Text(
            '${certification.completionPercentage}% complete · Average on passed focuses ${certification.averagePassedScorePercent.toStringAsFixed(1)}%',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          ...certification.requiredTaskCodes.map((taskCode) {
            final evidence = certification.evidenceRows.firstWhere(
              (row) => row.taskCode == taskCode,
              orElse: () => CertificationEvidenceRow(
                taskCode: taskCode,
                status: 'not_started',
                bestScorePercent: 0,
                bestMissionId: '',
                bestResultPackageId: '',
                missionType: '',
                completedAt: null,
                reason: '',
              ),
            );
            final linkedMission =
                missionByResultPackageId[evidence.bestResultPackageId.trim()];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ManagementCertificationEvidenceRow(
                evidence: evidence,
                onOpenResult: linkedMission == null
                    ? null
                    : () => onOpenResult(linkedMission),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _ManagementCertificationEvidenceRow extends StatelessWidget {
  const _ManagementCertificationEvidenceRow({
    required this.evidence,
    required this.onOpenResult,
  });

  final CertificationEvidenceRow evidence;
  final VoidCallback? onOpenResult;

  @override
  Widget build(BuildContext context) {
    late final Color badgeColor;
    late final Color textColor;
    late final String statusLabel;

    switch (evidence.status) {
      case 'passed':
        badgeColor = const Color(0xFFE8FFF0);
        textColor = const Color(0xFF157347);
        statusLabel = 'Passed';
        break;
      case 'pending_review':
        badgeColor = const Color(0xFFFFF7E5);
        textColor = const Color(0xFFB27300);
        statusLabel = 'Pending review';
        break;
      case 'not_passed':
        badgeColor = const Color(0xFFFFF0F0);
        textColor = const Color(0xFFB42318);
        statusLabel = 'Not passed';
        break;
      default:
        badgeColor = const Color(0xFFF5F8FF);
        textColor = AppPalette.navy;
        statusLabel = 'Not started';
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.compact),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FBFF),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: const Color(0xFFD9E7FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                evidence.taskCode,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              if (evidence.bestScorePercent > 0)
                Text(
                  '${evidence.bestScorePercent.toStringAsFixed(1)}%',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(color: AppPalette.navy),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            evidence.reason.trim().isEmpty
                ? evidence.status == 'passed'
                      ? 'Best evidence: ${evidence.missionType} mission'
                      : 'No linked result evidence yet.'
                : evidence.reason,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppPalette.textMuted),
          ),
          if (onOpenResult != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onOpenResult,
                icon: const Icon(Icons.visibility_rounded),
                label: const Text('Open evidence'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ManagementScreenData {
  const _ManagementScreenData({
    required this.workspace,
    required this.recentResults,
    required this.certifications,
    required this.certificationSubjects,
    required this.teachers,
  });

  final MentorWorkspaceData workspace;
  final List<MissionPayload> recentResults;
  final List<SubjectCertificationSummary> certifications;
  final List<SubjectCertificationSettings> certificationSubjects;
  final List<TeacherSummary> teachers;
}

class _SelectedStudentCard extends StatelessWidget {
  const _SelectedStudentCard({required this.student});

  final StudentSummary student;

  @override
  Widget build(BuildContext context) {
    return SoftPanel(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppPalette.primaryBlue, AppPalette.aqua],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_rounded, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${student.name} · ${student.xp} XP · ${student.streak} day streak',
              style: Theme.of(context).textTheme.titleSmall,
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
              'Select a student to refresh management metrics and alerts.',
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

class _TopIconButton extends StatelessWidget {
  const _TopIconButton({required this.icon, this.onTap});

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

class _SubjectFilterChip extends StatelessWidget {
  const _SubjectFilterChip({
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
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  colors: [AppPalette.primaryBlue, AppPalette.aqua],
                )
              : null,
          color: selected ? null : Colors.white.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: selected ? Colors.white : AppPalette.navy,
          ),
        ),
      ),
    );
  }
}

class _CreateRoleChip extends StatelessWidget {
  const _CreateRoleChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFFFE2B8)
              : Colors.white.withValues(alpha: 0.86),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppPalette.orange : AppPalette.sky,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? AppPalette.orange : AppPalette.textMuted,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppPalette.navy,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManagementTimetableInlineEditor extends StatelessWidget {
  const _ManagementTimetableInlineEditor({
    required this.selectedDate,
    required this.isWeekend,
    required this.hasSubjects,
    required this.subjectOptions,
    required this.teacherOptions,
    required this.selectedDayKey,
    required this.selectedMorningSubjectId,
    required this.selectedAfternoonSubjectId,
    required this.selectedMorningTeacherId,
    required this.selectedAfternoonTeacherId,
    required this.selectedMorningRoom,
    required this.selectedAfternoonRoom,
    required this.roomOptions,
    required this.isSaving,
    required this.onMorningSubjectChanged,
    required this.onAfternoonSubjectChanged,
    required this.onMorningTeacherChanged,
    required this.onAfternoonTeacherChanged,
    required this.onMorningRoomChanged,
    required this.onAfternoonRoomChanged,
    required this.onSave,
  });

  final DateTime selectedDate;
  final bool isWeekend;
  final bool hasSubjects;
  final List<SubjectCertificationSettings> subjectOptions;
  final List<TeacherSummary> teacherOptions;
  final String selectedDayKey;
  final String selectedMorningSubjectId;
  final String selectedAfternoonSubjectId;
  final String selectedMorningTeacherId;
  final String selectedAfternoonTeacherId;
  final String selectedMorningRoom;
  final String selectedAfternoonRoom;
  final List<String> roomOptions;
  final bool isSaving;
  final ValueChanged<String?> onMorningSubjectChanged;
  final ValueChanged<String?> onAfternoonSubjectChanged;
  final ValueChanged<String?> onMorningTeacherChanged;
  final ValueChanged<String?> onAfternoonTeacherChanged;
  final ValueChanged<String?> onMorningRoomChanged;
  final ValueChanged<String?> onAfternoonRoomChanged;
  final VoidCallback onSave;

  String _formatEditorDate(DateTime date) {
    const monthNames = <String>[
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
    return '${_weekdayLabelForDate(date)} ${date.day} ${monthNames[date.month - 1]} ${date.year}';
  }

  String _weekdayLabelForDate(DateTime date) {
    const labels = <String>[
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return labels[date.weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.item),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add teacher, subject, and room',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Editing ${_formatEditorDate(selectedDate)}',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: AppPalette.navy),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Click a weekday card below, then use these controls here in the timetable panel. No popup is needed.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppPalette.textMuted),
          ),
          const SizedBox(height: AppSpacing.compact),
          if (isWeekend)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.item),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Text(
                'Weekend dates stay as rest days with no subject.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          else if (!hasSubjects)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.item),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Text(
                'No subjects are available yet. Create subjects first, then return here to build the timetable.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          else ...[
            DropdownButtonFormField<String>(
              key: ValueKey('management-inline-$selectedDayKey-morning'),
              initialValue: selectedMorningSubjectId.isNotEmpty
                  ? selectedMorningSubjectId
                  : null,
              decoration: const InputDecoration(labelText: 'Morning subject'),
              items: subjectOptions
                  .map(
                    (subject) => DropdownMenuItem<String>(
                      value: subject.subjectId,
                      child: Text(subject.subjectName),
                    ),
                  )
                  .toList(growable: false),
              onChanged: onMorningSubjectChanged,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey(
                'management-inline-$selectedDayKey-morning-teacher',
              ),
              initialValue: selectedMorningTeacherId,
              decoration: const InputDecoration(
                labelText: 'Morning teacher',
                helperText: 'Optional, but helps mission ownership stay clear.',
              ),
              items: <DropdownMenuItem<String>>[
                const DropdownMenuItem<String>(
                  value: '',
                  child: Text('No teacher yet'),
                ),
                ...teacherOptions.map(
                  (teacher) => DropdownMenuItem<String>(
                    value: teacher.id,
                    child: Text(
                      teacher.subjectSpecialty?.trim().isNotEmpty == true
                          ? '${teacher.name} · ${teacher.subjectSpecialty}'
                          : teacher.name,
                    ),
                  ),
                ),
              ].toList(growable: false),
              onChanged: onMorningTeacherChanged,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey('management-inline-$selectedDayKey-afternoon'),
              initialValue: selectedAfternoonSubjectId.isNotEmpty
                  ? selectedAfternoonSubjectId
                  : null,
              decoration: const InputDecoration(labelText: 'Afternoon subject'),
              items: subjectOptions
                  .map(
                    (subject) => DropdownMenuItem<String>(
                      value: subject.subjectId,
                      child: Text(subject.subjectName),
                    ),
                  )
                  .toList(growable: false),
              onChanged: onAfternoonSubjectChanged,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey(
                'management-inline-$selectedDayKey-afternoon-teacher',
              ),
              initialValue: selectedAfternoonTeacherId,
              decoration: const InputDecoration(
                labelText: 'Afternoon teacher',
                helperText:
                    'Optional, but helps afternoon missions route to the correct teacher.',
              ),
              items: <DropdownMenuItem<String>>[
                const DropdownMenuItem<String>(
                  value: '',
                  child: Text('No teacher yet'),
                ),
                ...teacherOptions.map(
                  (teacher) => DropdownMenuItem<String>(
                    value: teacher.id,
                    child: Text(
                      teacher.subjectSpecialty?.trim().isNotEmpty == true
                          ? '${teacher.name} · ${teacher.subjectSpecialty}'
                          : teacher.name,
                    ),
                  ),
                ),
              ].toList(growable: false),
              onChanged: onAfternoonTeacherChanged,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey('management-inline-$selectedDayKey-morning-room'),
              initialValue: selectedMorningRoom,
              decoration: const InputDecoration(labelText: 'Morning room'),
              items: roomOptions
                  .map(
                    (room) => DropdownMenuItem<String>(
                      value: room,
                      child: Text(room),
                    ),
                  )
                  .toList(growable: false),
              onChanged: onMorningRoomChanged,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey('management-inline-$selectedDayKey-afternoon-room'),
              initialValue: selectedAfternoonRoom,
              decoration: const InputDecoration(labelText: 'Afternoon room'),
              items: roomOptions
                  .map(
                    (room) => DropdownMenuItem<String>(
                      value: room,
                      child: Text(room),
                    ),
                  )
                  .toList(growable: false),
              onChanged: onAfternoonRoomChanged,
            ),
            const SizedBox(height: 10),
            Text(
              'Saving this entry updates the selected weekday in the timetable shown below.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppPalette.textMuted),
            ),
            const SizedBox(height: AppSpacing.compact),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isSaving ? null : onSave,
                icon: const Icon(Icons.save_rounded),
                label: Text(
                  isSaving
                      ? 'Saving timetable...'
                      : 'Save ${_weekdayLabelForDate(selectedDate)} timetable',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TimetableRoomSelection {
  const _TimetableRoomSelection({
    required this.morningRoom,
    required this.afternoonRoom,
  });

  final String morningRoom;
  final String afternoonRoom;
}

class _ManagementResultCard extends StatelessWidget {
  const _ManagementResultCard({required this.mission, required this.onView});

  final MissionPayload mission;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final subjectName = (mission.subject?.name ?? '').trim().isEmpty
        ? 'No subject'
        : mission.subject!.name.trim();
    final scoreTotal = mission.scoreTotal > 0
        ? mission.scoreTotal
        : mission.questionCount;
    final hasResultPackage = mission.latestResultPackageId.trim().isNotEmpty;
    final earnedXp = mission.xpEarned < 0
        ? 0
        : (mission.xpEarned > mission.xpReward
              ? mission.xpReward
              : mission.xpEarned);
    final scoreLabel =
        '${mission.scoreCorrect}/$scoreTotal (${mission.scorePercent}%)';
    final theorySummary = mission.draftFormat == 'THEORY'
        ? hasResultPackage && earnedXp == 0 && mission.scoreTotal <= 0
              ? 'Pending review · XP pending'
              : hasResultPackage
              ? '${mission.scorePercent}% scored · $earnedXp/${mission.xpReward} XP'
              : 'Awaiting submission · $earnedXp/${mission.xpReward} XP'
        : '$scoreLabel score · $earnedXp/${mission.xpReward} XP';
    final dateLabel = _formatManagementMissionDate(
      mission.availableOnDate ?? mission.publishedAt ?? mission.createdAt,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.item),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  mission.title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppPalette.sky.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  subjectName,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppPalette.navy),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            theorySummary,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppPalette.navy),
          ),
          const SizedBox(height: 4),
          Text(
            '${mission.draftFormat == 'ESSAY_BUILDER' ? 'Essay Builder' : '${mission.questionCount} questions'} · ${mission.sessionType} · $dateLabel',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppPalette.textMuted),
          ),
          if (mission.taskCodes.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Tasks: ${mission.taskCodes.join(', ')}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppPalette.textMuted),
            ),
          ],
          const SizedBox(height: AppSpacing.compact),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onView,
              icon: const Icon(Icons.visibility_rounded),
              label: const Text('View Result'),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatManagementMissionDate(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'No date';
  }
  final parsed = DateTime.tryParse(value)?.toLocal();
  if (parsed == null) {
    return value;
  }
  return '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
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
                'Could not load the management section',
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
