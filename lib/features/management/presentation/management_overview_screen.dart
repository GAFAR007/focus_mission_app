/**
 * WHAT:
 * ManagementOverviewScreen provides a dedicated management workspace after
 * management users sign in, including student roster control and result
 * review.
 * WHY:
 * Management users need their own section to monitor student delivery,
 * outcomes, and staff/student setup without being routed into mentor flows.
 * HOW:
 * Load management workspace data from the API, show management-focused summary
 * cards, allow creation of student/teacher accounts, expose active/archived
 * roster controls, and provide subject-filtered result review for students.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'package:flutter/material.dart';

import '../../../core/constants/app_palette.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/student_year_groups.dart';
import '../../../core/utils/auth_session_store.dart';
import '../../../core/utils/download_text_file.dart';
import '../../../core/utils/focus_mission_api.dart';
import '../../../shared/models/focus_mission_models.dart';
import '../../../shared/widgets/focus_scaffold.dart';
import '../../../shared/widgets/notification_panel.dart';
import '../../../shared/widgets/profile_avatar_button.dart';
import '../../../shared/widgets/profile_sheet.dart';
import '../../../shared/widgets/soft_panel.dart';
import '../../../shared/widgets/stat_chip.dart';
import '../../../shared/widgets/student_year_group_panel.dart';
import '../../../shared/widgets/weekly_timetable_calendar.dart';
import '../../auth/presentation/role_selection_screen.dart';
import 'management_day_plan_screen.dart';
import '../../teacher/presentation/result_report_screen.dart';

const _allSubjectsFilterLabel = 'All subjects';
const _allResultDatesFilterLabel = 'All dates';
const _allTargetDatesFilterLabel = 'All dates';
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

String _teacherSubjectSummaryLabel(TeacherSummary teacher) {
  final subjectNames = <String>{
    (teacher.subjectSpecialty ?? '').trim(),
    ...teacher.subjectSpecialties.map((value) => value.trim()),
  }..removeWhere((value) => value.isEmpty);

  return subjectNames.join(', ');
}

class ManagementOverviewScreen extends StatefulWidget {
  const ManagementOverviewScreen({super.key, required this.session});

  final AuthSession session;

  @override
  State<ManagementOverviewScreen> createState() =>
      _ManagementOverviewScreenState();
}

class _ManagementOverviewScreenState extends State<ManagementOverviewScreen> {
  final FocusMissionApi _api = FocusMissionApi();
  final AuthSessionStore _sessionStore = AuthSessionStore();
  final GlobalKey<FormState> _createUserFormKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _certificationLabelController =
      TextEditingController();

  late AuthSession _session;
  late Future<_ManagementScreenData> _future;
  late DateTime _selectedTimetableDate;
  String _selectedStudentId = '';
  String _selectedSubject = _allSubjectsFilterLabel;
  String _selectedResultDate = _allResultDatesFilterLabel;
  String _selectedTargetDate = _allTargetDatesFilterLabel;
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
  String _createStudentYearGroup = '';
  String _createTeacherPrimarySubject = '';
  String _selectedStudentYearGroup = '';
  NotificationInboxData? _notificationInbox;
  bool _isCreatingUser = false;
  bool _isDownloadingResults = false;
  bool _isDownloadingTargets = false;
  String _downloadingResultPackageId = '';
  String _downloadingTargetId = '';
  String _downloadingTeacherCopyMissionId = '';
  bool _isSavingCertification = false;
  bool _isSavingTimetable = false;
  bool _isArchivingStudent = false;
  bool _isSavingStudentYearGroup = false;
  String _studentStatusActionId = '';
  bool _showTimetableEditor = false;
  bool _showCertificationSetup = false;
  bool _showCreateUserPanel = false;
  bool _showCertificationProgressPanel = false;
  bool _showTeacherSubjectSetupPanel = false;
  bool _showTimetablePanel = false;
  bool _showStudentResultsPanel = false;
  bool _showStudentTargetsPanel = false;
  bool _certificationEnabled = false;
  AppUser? _lastCreatedUser;
  final Set<String> _selectedCertificationTaskCodes = <String>{};
  final Set<String> _createTeacherAdditionalSubjects = <String>{};

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    _persistSessionSnapshot();
    final now = DateTime.now();
    _selectedTimetableDate = DateTime(now.year, now.month, now.day);
    _future = _loadWorkspace();
  }

  Future<void> _persistSessionSnapshot() async {
    try {
      await _sessionStore.saveSession(_session);
    } catch (_) {}
  }

  bool get _isAnyManagementDownloadActive =>
      _isDownloadingResults ||
      _isDownloadingTargets ||
      _downloadingTargetId.isNotEmpty ||
      _downloadingResultPackageId.isNotEmpty ||
      _downloadingTeacherCopyMissionId.isNotEmpty;

  bool get _isAnyStudentStatusActionActive =>
      _isArchivingStudent || _studentStatusActionId.isNotEmpty;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _certificationLabelController.dispose();
    super.dispose();
  }

  Future<_ManagementScreenData> _loadWorkspace() async {
    final workspace = await _api.loadMentorWorkspace(
      mentorSession: _session,
      selectedStudentId: _selectedStudentId,
    );
    final responses = await Future.wait([
      _api.fetchManagementStudentResults(
        token: _session.token,
        studentId: workspace.selectedStudent.id,
      ),
      _api.fetchManagementStudentTargets(
        token: _session.token,
        studentId: workspace.selectedStudent.id,
        dateKey: _dateKeyFromDate(_selectedTimetableDate),
      ),
      _api.fetchManagementStudentCertification(
        token: _session.token,
        studentId: workspace.selectedStudent.id,
      ),
      _api.fetchManagementCertificationSubjects(token: _session.token),
      _api.fetchManagementTeachers(token: _session.token),
      _api.fetchManagementStudents(token: _session.token, status: 'archived'),
    ]);
    final recentResults = responses[0] as List<ResultHistoryItem>;
    final targetHistory = responses[1] as ManagementTargetHistory;
    final certifications = responses[2] as List<SubjectCertificationSummary>;
    final certificationSubjects =
        responses[3] as List<SubjectCertificationSettings>;
    final teachers = responses[4] as List<TeacherSummary>;
    final archivedStudents = responses[5] as List<StudentSummary>;
    final targetDateKeys = _buildWeekdayTargetDateKeysForMonth(
      _selectedTimetableDate,
    );
    final targetDateSections = _buildMonthTargetDateSections(
      dateKeys: targetDateKeys,
      targets: targetHistory.targets,
      sessionComments: targetHistory.sessionComments,
    );
    _selectedStudentId = workspace.selectedStudent.id;
    _selectedStudentYearGroup = workspace.selectedStudent.yearGroup.trim();
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
    final resultDateFilters = _buildResultDateFilters(recentResults);
    if (!resultDateFilters.contains(_selectedResultDate)) {
      _selectedResultDate = _allResultDatesFilterLabel;
    }
    final targetDateFilters = _buildTargetDateFilters(targetDateKeys);
    if (!targetDateFilters.contains(_selectedTargetDate)) {
      _selectedTargetDate = _allTargetDatesFilterLabel;
    }
    return _ManagementScreenData(
      workspace: workspace,
      recentResults: recentResults,
      targetDateKeys: targetDateKeys,
      targetDateSections: targetDateSections,
      certifications: certifications,
      certificationSubjects: certificationSubjects,
      teachers: teachers,
      archivedStudents: archivedStudents,
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
        _showCertificationSetup = false;
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

  String _dateKeyFromDate(DateTime date) {
    final normalized = _dateOnly(date);
    final year = normalized.year.toString().padLeft(4, '0');
    final month = normalized.month.toString().padLeft(2, '0');
    final day = normalized.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  List<String> _buildWeekdayTargetDateKeysForMonth(DateTime anchorDate) {
    final keys = <String>[];
    final lastDay = DateTime(anchorDate.year, anchorDate.month + 1, 0).day;

    for (var day = lastDay; day >= 1; day -= 1) {
      final date = DateTime(anchorDate.year, anchorDate.month, day);
      if (_isWeekendDate(date)) {
        continue;
      }
      keys.add(_dateKeyFromDate(date));
    }

    return keys;
  }

  String _managementWeekKeyForDateKey(String dateKey) {
    final parsed = DateTime.tryParse(dateKey.trim());
    if (parsed == null) {
      return '';
    }

    final utcDate = DateTime.utc(parsed.year, parsed.month, parsed.day);
    final adjusted = utcDate.add(Duration(days: 4 - utcDate.weekday));
    final yearStart = DateTime.utc(adjusted.year, 1, 1);
    final weekNumber = ((adjusted.difference(yearStart).inDays + 1) / 7).ceil();

    return '${adjusted.year}-W${weekNumber.toString().padLeft(2, '0')}';
  }

  List<ManagementTargetDateSection> _buildMonthTargetDateSections({
    required List<String> dateKeys,
    required List<TargetSummary> targets,
    required List<ManagementTargetSessionComment> sessionComments,
  }) {
    return dateKeys
        .map((dateKey) {
          final dateWeekKey = _managementWeekKeyForDateKey(dateKey);
          final targetsForDate = targets
              .where((target) {
                final targetType = target.targetType.trim();
                if (targetType == 'fixed_daily_mission' ||
                    targetType == 'fixed_assessment') {
                  // WHY: Fixed targets are weekly expectations, so management should
                  // see them on each teaching weekday in that week instead of only on
                  // the one date the original row was first awarded.
                  return target.weekKey.trim() == dateWeekKey;
                }
                return target.awardDateKey.trim() == dateKey;
              })
              .toList(growable: false);
          final commentsForDate = sessionComments
              .where((comment) => comment.dateKey.trim() == dateKey)
              .toList(growable: false);

          return ManagementTargetDateSection(
            dateKey: dateKey,
            targets: targetsForDate,
            sessionComments: commentsForDate,
          );
        })
        .toList(growable: false);
  }

  void _selectTimetableDate({
    required DateTime date,
    required List<TodaySchedule> timetable,
    required List<SubjectCertificationSettings> subjects,
    required List<TeacherSummary> teachers,
  }) {
    final previousMonth = _selectedTimetableDate.month;
    final previousYear = _selectedTimetableDate.year;
    final normalized = _dateOnly(date);
    // WHY: The calendar is now a direct selector for the inline editor below,
    // so the chosen date must always drive the visible day fields on-screen.
    _selectedTimetableDate = normalized;
    final monthChanged =
        previousMonth != normalized.month || previousYear != normalized.year;

    if (_isWeekendDate(normalized)) {
      if (monthChanged) {
        _future = _loadWorkspace();
      }
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
    if (monthChanged) {
      _future = _loadWorkspace();
    }
  }

  TodaySchedule? _scheduleForDate(
    List<TodaySchedule> timetable,
    DateTime date,
  ) {
    final normalized = _dateOnly(date);
    if (_isWeekendDate(normalized)) {
      return null;
    }

    final day = _weekdayLabelForDate(normalized);
    return timetable.cast<TodaySchedule?>().firstWhere(
      (item) => item?.day == day,
      orElse: () => null,
    );
  }

  void _openTimetableEditorForDate({
    required DateTime date,
    required List<TodaySchedule> timetable,
    required List<SubjectCertificationSettings> subjects,
    required List<TeacherSummary> teachers,
  }) {
    setState(() {
      _showTimetableEditor = true;
      // WHY: Management expects clicking a timetable day to open that day's
      // live editor immediately, especially when updating an existing entry.
      _selectTimetableDate(
        date: date,
        timetable: timetable,
        subjects: subjects,
        teachers: teachers,
      );
    });
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

  String _buildCertificationSetupSummary(
    SubjectCertificationSettings? selectedCertificationSettings,
  ) {
    if (selectedCertificationSettings == null) {
      return 'No certification subject is ready yet.';
    }

    final sortedTaskCodes = _selectedCertificationTaskCodes.toList(
      growable: false,
    )..sort();
    final taskCodeSummary = sortedTaskCodes.isEmpty
        ? 'No task focuses selected'
        : '${sortedTaskCodes.length} task focus${sortedTaskCodes.length == 1 ? '' : 'es'}';

    return '${selectedCertificationSettings.subjectName} · ${_certificationEnabled ? 'Enabled' : 'Off'} · $taskCodeSummary';
  }

  String _buildCreateUserSummary() {
    if (_lastCreatedUser != null) {
      return 'Last created: ${_lastCreatedUser!.name} · ${_lastCreatedUser!.role}';
    }

    return _createRole == 'student'
        ? 'Student account form is ready when needed.'
        : 'Teacher account form with a primary subject and extra teachable subjects is ready.';
  }

  String _buildTeacherSubjectSetupSummary(List<TeacherSummary> teachers) {
    if (teachers.isEmpty) {
      return 'No teacher accounts yet.';
    }

    final multiSubjectCount = teachers.where((teacher) {
      final subjectNames = <String>{
        (teacher.subjectSpecialty ?? '').trim(),
        ...teacher.subjectSpecialties.map((value) => value.trim()),
      }..removeWhere((value) => value.isEmpty);
      return subjectNames.length > 1;
    }).length;

    if (multiSubjectCount == 0) {
      return '${teachers.length} teacher${teachers.length == 1 ? '' : 's'}';
    }

    return '${teachers.length} teacher${teachers.length == 1 ? '' : 's'} · $multiSubjectCount multi-subject';
  }

  String _buildCertificationProgressSummary(
    List<SubjectCertificationSummary> certifications, {
    required String selectedSubject,
  }) {
    if (certifications.isEmpty) {
      return 'No certification progress recorded yet.';
    }

    final totalPassed = certifications.fold<int>(
      0,
      (total, item) => total + item.passedTaskCodes.length,
    );
    final totalRequired = certifications.fold<int>(
      0,
      (total, item) => total + item.requiredTaskCodes.length,
    );
    final subjectSummary =
        selectedSubject == _allCertificationSubjectsFilterLabel
        ? '${certifications.length} subject${certifications.length == 1 ? '' : 's'}'
        : selectedSubject;

    return '$subjectSummary · $totalPassed/$totalRequired task focuses passed';
  }

  String _buildTimetablePanelSummary({
    required TodaySchedule? selectedEntry,
    required DateTime selectedDate,
    required int scheduledDayCount,
  }) {
    final scheduledDayLabel =
        '$scheduledDayCount scheduled day${scheduledDayCount == 1 ? '' : 's'}';

    if (_isWeekendDate(selectedDate)) {
      return 'Weekend selected · $scheduledDayLabel';
    }

    final day = _weekdayLabelForDate(selectedDate);
    if (selectedEntry == null) {
      return '$day · No lessons assigned · $scheduledDayLabel';
    }

    final room = selectedEntry.room.trim().isEmpty
        ? 'Room pending'
        : selectedEntry.room.trim();
    return '$day · ${selectedEntry.morningMission.name} / ${selectedEntry.afternoonMission.name} · $room';
  }

  String _buildStudentResultsSummary({
    required List<ResultHistoryItem> filteredResults,
    required String selectedSubject,
    required String selectedDate,
  }) {
    final resultLabel =
        '${filteredResults.length} result${filteredResults.length == 1 ? '' : 's'}';
    final subjectLabel = selectedSubject == _allSubjectsFilterLabel
        ? 'All subjects'
        : selectedSubject;
    final dateLabel = selectedDate == _allResultDatesFilterLabel
        ? 'All dates'
        : selectedDate;

    return '$resultLabel · $subjectLabel · $dateLabel';
  }

  List<String> _buildTargetDateFilters(List<String> dateKeys) {
    final sortedDates =
        dateKeys
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList(growable: false)
          ..sort((left, right) => right.compareTo(left));
    return <String>[_allTargetDatesFilterLabel, ...sortedDates];
  }

  List<ManagementTargetDateSection> _filterTargetSections(
    List<ManagementTargetDateSection> sections, {
    required String dateKey,
  }) {
    return sections
        .where((section) {
          return dateKey == _allTargetDatesFilterLabel ||
              section.dateKey.trim() == dateKey;
        })
        .toList(growable: false);
  }

  String _buildStudentTargetsSummary({
    required List<TargetSummary> filteredTargets,
    required String selectedDate,
  }) {
    final targetLabel =
        '${filteredTargets.length} target${filteredTargets.length == 1 ? '' : 's'}';
    final dateLabel = selectedDate == _allTargetDatesFilterLabel
        ? 'All dates'
        : selectedDate;
    final awardedXp = filteredTargets.fold<int>(
      0,
      (total, target) => total + target.xpAwarded,
    );

    return '$targetLabel · $dateLabel · $awardedXp XP';
  }

  List<TargetSummary> _uniqueTargetsFromSections(
    List<ManagementTargetDateSection> sections,
  ) {
    final byId = <String, TargetSummary>{};
    for (final section in sections) {
      for (final target in section.targets) {
        final id = target.id.trim();
        if (id.isEmpty || byId.containsKey(id)) {
          continue;
        }
        byId[id] = target;
      }
    }
    return byId.values.toList(growable: false);
  }

  String _normalizeManagementLookupValue(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  bool _managementLookupContains(String haystack, String needle) {
    final normalizedHaystack = _normalizeManagementLookupValue(haystack);
    final normalizedNeedle = _normalizeManagementLookupValue(needle);
    if (normalizedHaystack.isEmpty || normalizedNeedle.isEmpty) {
      return false;
    }
    return ' $normalizedHaystack '.contains(' $normalizedNeedle ');
  }

  String _managementSessionLookupKey(String value) {
    final normalized = _normalizeManagementLookupValue(value);
    if (normalized.contains('morning')) {
      return 'morning';
    }
    if (normalized.contains('afternoon')) {
      return 'afternoon';
    }
    return normalized;
  }

  String _managementTargetIdentityKey(TargetSummary target) {
    final id = target.id.trim();
    if (id.isNotEmpty) {
      return id;
    }
    return [
      _normalizeManagementLookupValue(target.title),
      target.awardDateKey.trim(),
      target.weekKey.trim(),
    ].join('|');
  }

  String _managementSessionCommentKey(ManagementTargetSessionComment comment) {
    final id = comment.id.trim();
    if (id.isNotEmpty) {
      return id;
    }
    return [
      comment.dateKey.trim(),
      _normalizeManagementLookupValue(comment.subjectName),
      _managementSessionLookupKey(comment.sessionType),
      _normalizeManagementLookupValue(_commentActorDisplayName(comment)),
      _normalizeManagementLookupValue(comment.comment),
    ].join('|');
  }

  String _commentActorDisplayName(ManagementTargetSessionComment comment) {
    final authorName = comment.authorName.trim();
    if (authorName.isNotEmpty) {
      return authorName;
    }
    return comment.teacherName.trim();
  }

  int _managementResultMatchScore({
    required TargetSummary target,
    required ResultHistoryItem result,
    required String dateKey,
  }) {
    if (_resultDateKeyForMission(result) != dateKey) {
      return 0;
    }

    final normalizedTargetTitle = _normalizeManagementLookupValue(target.title);
    final normalizedResultTitle = _normalizeManagementLookupValue(result.title);
    if (normalizedTargetTitle.isEmpty || normalizedResultTitle.isEmpty) {
      return 0;
    }

    var score = 0;
    if (normalizedTargetTitle == normalizedResultTitle) {
      score = 120;
    } else if (normalizedTargetTitle.startsWith(normalizedResultTitle) ||
        normalizedResultTitle.startsWith(normalizedTargetTitle)) {
      score = 100;
    } else if (normalizedTargetTitle.contains(normalizedResultTitle) ||
        normalizedResultTitle.contains(normalizedTargetTitle)) {
      score = 84;
    }

    final targetWords = normalizedTargetTitle
        .split(' ')
        .where((word) => word.isNotEmpty)
        .toSet();
    final resultWords = normalizedResultTitle
        .split(' ')
        .where((word) => word.isNotEmpty)
        .toSet();
    final overlapCount = targetWords.intersection(resultWords).length;
    if (overlapCount >= 2) {
      score += overlapCount * 5;
    }

    return score;
  }

  ResultHistoryItem? _findManagementResultForTarget({
    required TargetSummary target,
    required String dateKey,
    required List<ResultHistoryItem> recentResults,
  }) {
    ResultHistoryItem? bestMatch;
    var bestScore = 0;

    for (final result in recentResults) {
      final score = _managementResultMatchScore(
        target: target,
        result: result,
        dateKey: dateKey,
      );
      if (score > bestScore) {
        bestScore = score;
        bestMatch = result;
      }
    }

    return bestScore >= 70 ? bestMatch : null;
  }

  String _resolveTeacherNameForSubject(
    String subjectName,
    List<TeacherSummary> teachers,
  ) {
    final normalizedSubject = _normalizeManagementLookupValue(subjectName);
    if (normalizedSubject.isEmpty) {
      return '';
    }

    TeacherSummary? partialMatch;
    for (final teacher in teachers) {
      final teacherSubjects = <String>{
        (teacher.subjectSpecialty ?? '').trim(),
        ...teacher.subjectSpecialties.map((value) => value.trim()),
      }..removeWhere((value) => value.isEmpty);

      for (final specialty in teacherSubjects) {
        final normalizedSpecialty = _normalizeManagementLookupValue(specialty);
        if (normalizedSpecialty.isEmpty) {
          continue;
        }
        if (normalizedSpecialty == normalizedSubject) {
          return teacher.name.trim();
        }
        if (normalizedSpecialty.contains(normalizedSubject) ||
            normalizedSubject.contains(normalizedSpecialty)) {
          partialMatch ??= teacher;
        }
      }
    }

    return partialMatch?.name.trim() ?? '';
  }

  _ManagementTargetCommentResolution _resolveManagementTargetCommentResolution({
    required TargetSummary target,
    required String dateKey,
    required List<ManagementTargetSessionComment> sessionComments,
    required List<ResultHistoryItem> recentResults,
    required List<TeacherSummary> teachers,
  }) {
    final matchedResult = _findManagementResultForTarget(
      target: target,
      dateKey: dateKey,
      recentResults: recentResults,
    );
    final inferredSubjectName = (matchedResult?.subject?.name ?? '').trim();
    final inferredSessionType = matchedResult?.sessionType.trim() ?? '';
    final normalizedInferredSubject = _normalizeManagementLookupValue(
      inferredSubjectName,
    );
    final inferredSessionKey = _managementSessionLookupKey(inferredSessionType);

    final matchedComments = sessionComments
        .where((comment) {
          final commentSubject = comment.subjectName.trim();
          final normalizedCommentSubject = _normalizeManagementLookupValue(
            commentSubject,
          );
          if (normalizedInferredSubject.isNotEmpty) {
            if (normalizedCommentSubject != normalizedInferredSubject) {
              return false;
            }
          } else if (!_managementLookupContains(target.title, commentSubject)) {
            return false;
          }

          final commentSessionKey = _managementSessionLookupKey(
            comment.sessionType,
          );
          if (inferredSessionKey.isNotEmpty &&
              commentSessionKey.isNotEmpty &&
              commentSessionKey != inferredSessionKey) {
            return false;
          }
          return true;
        })
        .toList(growable: false);

    if (matchedComments.isNotEmpty) {
      return _ManagementTargetCommentResolution(
        comments: matchedComments
            .map(
              (comment) => _ManagementResolvedTargetComment(
                subjectName: comment.subjectName.trim(),
                sessionType: comment.sessionType.trim(),
                teacherName: comment.teacherName.trim().isNotEmpty
                    ? comment.teacherName.trim()
                    : _resolveTeacherNameForSubject(
                        comment.subjectName,
                        teachers,
                      ),
                authorName: comment.authorName.trim().isNotEmpty
                    ? comment.authorName.trim()
                    : comment.teacherName.trim(),
                plannedTeacherName: comment.plannedTeacherName.trim().isNotEmpty
                    ? comment.plannedTeacherName.trim()
                    : (comment.teacherName.trim().isNotEmpty
                          ? comment.teacherName.trim()
                          : _resolveTeacherNameForSubject(
                              comment.subjectName,
                              teachers,
                            )),
                conductedByName: comment.conductedByName.trim().isNotEmpty
                    ? comment.conductedByName.trim()
                    : comment.teacherName.trim(),
                comment: comment.comment.trim(),
                isPending: false,
                createdAt: comment.createdAt,
                updatedAt: comment.updatedAt,
              ),
            )
            .toList(growable: false),
        matchedCommentKeys: matchedComments
            .map(_managementSessionCommentKey)
            .toList(growable: false),
      );
    }

    if (inferredSubjectName.isEmpty) {
      return const _ManagementTargetCommentResolution(
        comments: <_ManagementResolvedTargetComment>[],
        matchedCommentKeys: <String>[],
      );
    }

    return _ManagementTargetCommentResolution(
      comments: [
        _ManagementResolvedTargetComment(
          subjectName: inferredSubjectName,
          sessionType: inferredSessionType,
          teacherName: _resolveTeacherNameForSubject(
            inferredSubjectName,
            teachers,
          ),
          authorName: '',
          plannedTeacherName: _resolveTeacherNameForSubject(
            inferredSubjectName,
            teachers,
          ),
          conductedByName: '',
          comment: 'Pending comments from $inferredSubjectName teacher.',
          isPending: true,
          createdAt: null,
          updatedAt: null,
        ),
      ],
      matchedCommentKeys: const <String>[],
    );
  }

  Map<String, _ManagementTargetCommentResolution>
  _buildManagementTargetCommentResolutions({
    required List<TargetSummary> targets,
    required String dateKey,
    required List<ManagementTargetSessionComment> sessionComments,
    required List<ResultHistoryItem> recentResults,
    required List<TeacherSummary> teachers,
  }) {
    final resolutions = <String, _ManagementTargetCommentResolution>{};
    for (final target in targets) {
      resolutions[_managementTargetIdentityKey(
        target,
      )] = _resolveManagementTargetCommentResolution(
        target: target,
        dateKey: dateKey,
        sessionComments: sessionComments,
        recentResults: recentResults,
        teachers: teachers,
      );
    }
    return resolutions;
  }

  List<ManagementTargetSessionComment> _buildUnmatchedTargetComments({
    required List<ManagementTargetSessionComment> sessionComments,
    required Map<String, _ManagementTargetCommentResolution> resolutions,
  }) {
    final matchedCommentKeys = <String>{};
    for (final resolution in resolutions.values) {
      matchedCommentKeys.addAll(resolution.matchedCommentKeys);
    }

    return sessionComments
        .where(
          (comment) => !matchedCommentKeys.contains(
            _managementSessionCommentKey(comment),
          ),
        )
        .toList(growable: false);
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
          final resultDateFilters = _buildResultDateFilters(data.recentResults);
          final targetDateFilters = _buildTargetDateFilters(
            data.targetDateKeys,
          );
          final selectedSubject = subjectFilters.contains(_selectedSubject)
              ? _selectedSubject
              : _allSubjectsFilterLabel;
          final selectedResultDate =
              resultDateFilters.contains(_selectedResultDate)
              ? _selectedResultDate
              : _allResultDatesFilterLabel;
          final selectedTargetDate =
              targetDateFilters.contains(_selectedTargetDate)
              ? _selectedTargetDate
              : _allTargetDatesFilterLabel;
          final filteredResults = _filterResults(
            data.recentResults,
            subject: selectedSubject,
            dateKey: selectedResultDate,
          );
          final filteredTargetSections = _filterTargetSections(
            data.targetDateSections,
            dateKey: selectedTargetDate,
          );
          final filteredTargets = _uniqueTargetsFromSections(
            filteredTargetSections,
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
          final selectedTimetableEntry = _scheduleForDate(
            workspace.timetable,
            _selectedTimetableDate,
          );
          final selectedTimetableHasEntry = selectedTimetableEntry != null;
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
                      onLogout: _signOut,
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
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () =>
                            _openStudentDayPlan(workspace.selectedStudent),
                        icon: const Icon(Icons.today_rounded),
                        label: const Text('View day plan'),
                      ),
                      TextButton.icon(
                        onPressed: _isAnyStudentStatusActionActive
                            ? null
                            : () => _openStudentPicker(workspace),
                        icon: const Icon(Icons.swap_horiz_rounded),
                        label: const Text('Switch student'),
                      ),
                      TextButton.icon(
                        onPressed: _isAnyStudentStatusActionActive
                            ? null
                            : () => _openArchivedStudentsSheet(
                                data.archivedStudents,
                              ),
                        icon: const Icon(Icons.unarchive_outlined),
                        label: Text(
                          data.archivedStudents.isEmpty
                              ? 'View archived'
                              : 'View archived (${data.archivedStudents.length})',
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _isAnyStudentStatusActionActive
                            ? null
                            : () => _archiveSelectedStudent(workspace),
                        icon: Icon(
                          _isArchivingStudent
                              ? Icons.hourglass_top_rounded
                              : Icons.archive_outlined,
                        ),
                        label: Text(
                          _isArchivingStudent
                              ? 'Archiving...'
                              : 'Archive student',
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF9E4053),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.item),
                StudentYearGroupPanel(
                  title: 'Student year group',
                  subtitle:
                      'Management can keep the learner year current here so profiles, class context, and grouped Test/Exam targeting stay correct.',
                  selectedYearGroup: _selectedStudentYearGroup,
                  onChanged: (value) => setState(
                    () => _selectedStudentYearGroup = (value ?? '').trim(),
                  ),
                  onSave: () =>
                      _saveSelectedStudentYearGroup(workspace.selectedStudent),
                  isSaving: _isSavingStudentYearGroup,
                  saveLabel: 'Save year group',
                  secondaryActionLabel: _showStudentTargetsPanel
                      ? 'Hide student targets'
                      : 'Student targets',
                  secondaryActionIcon: _showStudentTargetsPanel
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.flag_rounded,
                  onSecondaryAction: () => setState(
                    () => _showStudentTargetsPanel = !_showStudentTargetsPanel,
                  ),
                ),
                const SizedBox(height: AppSpacing.item),
                SoftPanel(
                  colors: const [Color(0xFFF9FCFF), Color(0xFFEDF6FF)],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ManagementExpandableHeader(
                        title: 'Student Targets',
                        subtitle:
                            'Review daily target outcomes, switch the target date, and export target results for this learner.',
                        summary: _buildStudentTargetsSummary(
                          filteredTargets: filteredTargets,
                          selectedDate: selectedTargetDate,
                        ),
                        isExpanded: _showStudentTargetsPanel,
                        onToggle: () => setState(
                          () => _showStudentTargetsPanel =
                              !_showStudentTargetsPanel,
                        ),
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        child: !_showStudentTargetsPanel
                            ? const SizedBox.shrink()
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: AppSpacing.compact),
                                  LayoutBuilder(
                                    builder: (context, constraints) {
                                      final compact =
                                          constraints.maxWidth < 760;
                                      final dateFilter =
                                          DropdownButtonFormField<String>(
                                            initialValue: selectedTargetDate,
                                            decoration:
                                                _managementFieldDecoration(
                                                  labelText: 'Target date',
                                                ),
                                            items: targetDateFilters
                                                .map(
                                                  (dateLabel) =>
                                                      DropdownMenuItem<String>(
                                                        value: dateLabel,
                                                        child: Text(dateLabel),
                                                      ),
                                                )
                                                .toList(growable: false),
                                            onChanged: (value) {
                                              if (value == null) {
                                                return;
                                              }
                                              setState(
                                                () =>
                                                    _selectedTargetDate = value,
                                              );
                                            },
                                          );
                                      final targetCount = Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppPalette.surface.withValues(
                                            alpha: 0.96,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                          border: Border.all(
                                            color: AppPalette.sky.withValues(
                                              alpha: 0.7,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          '${filteredTargets.length} daily target${filteredTargets.length == 1 ? '' : 's'}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: AppPalette.navy,
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                      );
                                      final downloadButton = FilledButton.icon(
                                        style: _managementFilledActionStyle(
                                          context,
                                        ),
                                        onPressed:
                                            filteredTargets.isEmpty ||
                                                _isAnyManagementDownloadActive
                                            ? null
                                            : () => _downloadFilteredTargets(
                                                student:
                                                    workspace.selectedStudent,
                                                sections:
                                                    filteredTargetSections,
                                                recentResults:
                                                    data.recentResults,
                                                teachers: data.teachers,
                                              ),
                                        icon: Icon(
                                          _isDownloadingTargets
                                              ? Icons.hourglass_top_rounded
                                              : Icons.download_rounded,
                                        ),
                                        label: Text(
                                          _isDownloadingTargets
                                              ? 'Preparing target export...'
                                              : 'Download target results',
                                        ),
                                      );

                                      if (compact) {
                                        return Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            dateFilter,
                                            const SizedBox(height: 10),
                                            targetCount,
                                            const SizedBox(height: 10),
                                            Align(
                                              alignment: Alignment.centerLeft,
                                              child: downloadButton,
                                            ),
                                          ],
                                        );
                                      }

                                      return Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Expanded(child: dateFilter),
                                          const SizedBox(width: 12),
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 10,
                                            ),
                                            child: targetCount,
                                          ),
                                          const SizedBox(width: 12),
                                          downloadButton,
                                        ],
                                      );
                                    },
                                  ),
                                  const SizedBox(height: AppSpacing.item),
                                  ...filteredTargetSections.map((section) {
                                    final commentResolutions =
                                        _buildManagementTargetCommentResolutions(
                                          targets: section.targets,
                                          dateKey: section.dateKey,
                                          sessionComments:
                                              section.sessionComments,
                                          recentResults: data.recentResults,
                                          teachers: data.teachers,
                                        );
                                    final unmatchedSessionComments =
                                        _buildUnmatchedTargetComments(
                                          sessionComments:
                                              section.sessionComments,
                                          resolutions: commentResolutions,
                                        );

                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: AppSpacing.compact,
                                      ),
                                      child: Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(
                                          AppSpacing.item,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppPalette.surface.withValues(
                                            alpha: 0.96,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            AppSpacing.radiusLg,
                                          ),
                                          border: Border.all(
                                            color: AppPalette.sky.withValues(
                                              alpha: 0.68,
                                            ),
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    section.dateKey,
                                                    style: Theme.of(
                                                      context,
                                                    ).textTheme.titleSmall,
                                                  ),
                                                ),
                                                _ManagementMiniPill(
                                                  label:
                                                      '${section.targets.length} target${section.targets.length == 1 ? '' : 's'}',
                                                  backgroundColor: AppPalette
                                                      .sky
                                                      .withValues(alpha: 0.16),
                                                ),
                                              ],
                                            ),
                                            if (unmatchedSessionComments
                                                .isNotEmpty) ...[
                                              const SizedBox(
                                                height: AppSpacing.compact,
                                              ),
                                              Text(
                                                'Teacher session comments',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.copyWith(
                                                      color:
                                                          AppPalette.textMuted,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                              ),
                                              const SizedBox(height: 10),
                                              ...unmatchedSessionComments.map(
                                                (comment) => Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        bottom: 10,
                                                      ),
                                                  child:
                                                      _ManagementTargetSessionCommentCard(
                                                        comment: comment,
                                                      ),
                                                ),
                                              ),
                                            ],
                                            if (unmatchedSessionComments
                                                .isNotEmpty)
                                              const SizedBox(
                                                height: AppSpacing.compact,
                                              ),
                                            if (section.targets.isEmpty &&
                                                unmatchedSessionComments
                                                    .isEmpty)
                                              Container(
                                                width: double.infinity,
                                                padding: const EdgeInsets.all(
                                                  AppSpacing.item,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: AppPalette.surface
                                                      .withValues(alpha: 0.9),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        AppSpacing.radiusMd,
                                                      ),
                                                  border: Border.all(
                                                    color: AppPalette.sky
                                                        .withValues(
                                                          alpha: 0.58,
                                                        ),
                                                  ),
                                                ),
                                                child: Text(
                                                  'No target result was saved for this weekday yet.',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodyMedium
                                                      ?.copyWith(
                                                        color: AppPalette
                                                            .textMuted,
                                                      ),
                                                ),
                                              )
                                            else
                                              ...section.targets.map(
                                                (target) => Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        bottom:
                                                            AppSpacing.compact,
                                                      ),
                                                  child: _ManagementTargetCard(
                                                    target: target,
                                                    teacherComments:
                                                        commentResolutions[_managementTargetIdentityKey(
                                                              target,
                                                            )]
                                                            ?.comments ??
                                                        const <
                                                          _ManagementResolvedTargetComment
                                                        >[],
                                                    isDownloading:
                                                        _downloadingTargetId ==
                                                        target.id,
                                                    onDownload:
                                                        _isAnyManagementDownloadActive
                                                        ? null
                                                        : () => _downloadTargetResult(
                                                            student: workspace
                                                                .selectedStudent,
                                                            target: target,
                                                            sections: [section],
                                                            recentResults: data
                                                                .recentResults,
                                                            teachers:
                                                                data.teachers,
                                                          ),
                                                  ),
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
                    ],
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
                      _ManagementExpandableHeader(
                        title: 'Task-focus certification',
                        subtitle:
                            'Track which required task focuses this student has already passed for each subject.',
                        summary: _buildCertificationProgressSummary(
                          filteredCertifications,
                          selectedSubject: selectedCertificationSubject,
                        ),
                        isExpanded: _showCertificationProgressPanel,
                        onToggle: () => setState(
                          () => _showCertificationProgressPanel =
                              !_showCertificationProgressPanel,
                        ),
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        child: !_showCertificationProgressPanel
                            ? const SizedBox.shrink()
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: AppSpacing.compact),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: certificationFilters
                                        .map(
                                          (subject) => _SubjectFilterChip(
                                            label: subject,
                                            selected:
                                                subject ==
                                                selectedCertificationSubject,
                                            onTap: () => setState(
                                              () =>
                                                  _selectedCertificationSubject =
                                                      subject,
                                            ),
                                          ),
                                        )
                                        .toList(growable: false),
                                  ),
                                  const SizedBox(height: AppSpacing.item),
                                  if (filteredCertifications.isEmpty)
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(
                                        AppSpacing.item,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.78,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          AppSpacing.radiusMd,
                                        ),
                                      ),
                                      child: Text(
                                        'No certification templates are active for this student yet.',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodyMedium,
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
                                            for (final mission
                                                in data.recentResults)
                                              mission.latestResultPackageId
                                                      .trim():
                                                  mission,
                                          },
                                          onOpenResult: (mission) =>
                                              _openResultReport(
                                                mission: mission,
                                                student:
                                                    workspace.selectedStudent,
                                              ),
                                        ),
                                      ),
                                    ),
                                ],
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
                      _ManagementExpandableHeader(
                        title: 'Certification Setup',
                        subtitle:
                            'Choose which task focuses a student must pass to unlock the subject certificate. Changes are blocked after live evidence exists.',
                        summary: _buildCertificationSetupSummary(
                          selectedCertificationSettings,
                        ),
                        isExpanded: _showCertificationSetup,
                        onToggle: () => setState(
                          () => _showCertificationSetup =
                              !_showCertificationSetup,
                        ),
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        child: !_showCertificationSetup
                            ? const SizedBox.shrink()
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: AppSpacing.compact),
                                  if (data.certificationSubjects.isEmpty)
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(
                                        AppSpacing.item,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.78,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          AppSpacing.radiusMd,
                                        ),
                                      ),
                                      child: Text(
                                        'No subjects are available to configure yet.',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodyMedium,
                                      ),
                                    )
                                  else ...[
                                    DropdownButtonFormField<String>(
                                      initialValue:
                                          selectedCertificationSettings
                                              ?.subjectId,
                                      decoration: _managementFieldDecoration(
                                        labelText: 'Subject',
                                      ),
                                      items: data.certificationSubjects
                                          .map(
                                            (subject) =>
                                                DropdownMenuItem<String>(
                                                  value: subject.subjectId,
                                                  child: Text(
                                                    subject.subjectName,
                                                  ),
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
                                      onChanged: (value) => setState(
                                        () => _certificationEnabled = value,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    TextField(
                                      controller: _certificationLabelController,
                                      decoration: _managementFieldDecoration(
                                        labelText: 'Certificate label',
                                        hintText: 'Course Certification',
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Required task focuses',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleSmall,
                                    ),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: _certificationTaskCodeOptions
                                          .map(
                                            (taskCode) => _CreateRoleChip(
                                              label: taskCode,
                                              icon: Icons.flag_rounded,
                                              selected:
                                                  _selectedCertificationTaskCodes
                                                      .contains(taskCode),
                                              compact: true,
                                              onTap: () =>
                                                  _toggleCertificationTaskCode(
                                                    taskCode,
                                                  ),
                                            ),
                                          )
                                          .toList(growable: false),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      _selectedCertificationTaskCodes.isEmpty
                                          ? 'No task focuses selected yet.'
                                          : 'Required: ${(_selectedCertificationTaskCodes.toList(growable: false)..sort()).join(', ')}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: AppPalette.textMuted,
                                          ),
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
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.item),
                SoftPanel(
                  colors: const [Color(0xFFFFFCF6), Color(0xFFFFF3E4)],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ManagementExpandableHeader(
                        title: _createRole == 'student'
                            ? 'Add New Student'
                            : 'Add New Teacher',
                        subtitle: _createRole == 'student'
                            ? 'Create a student account and add that learner to management immediately.'
                            : 'Create a teacher account with a primary subject and extra teachable subjects.',
                        summary: _buildCreateUserSummary(),
                        isExpanded: _showCreateUserPanel,
                        onToggle: () => setState(
                          () => _showCreateUserPanel = !_showCreateUserPanel,
                        ),
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        child: !_showCreateUserPanel
                            ? const SizedBox.shrink()
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: AppSpacing.compact),
                                  Text(
                                    'Account type',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleSmall,
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _CreateRoleChip(
                                          label: 'Student',
                                          icon: Icons.school_rounded,
                                          selected: _createRole == 'student',
                                          onTap: () => setState(
                                            () => _createRole = 'student',
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: _CreateRoleChip(
                                          label: 'Teacher',
                                          icon: Icons.menu_book_rounded,
                                          selected: _createRole == 'teacher',
                                          onTap: () => setState(() {
                                            _createRole = 'teacher';
                                            _createStudentYearGroup = '';
                                          }),
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
                                          decoration:
                                              _managementFieldDecoration(
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
                                          decoration:
                                              _managementFieldDecoration(
                                                labelText: 'Email',
                                                hintText: 'name@school.org',
                                              ),
                                          validator: (value) {
                                            final email = (value ?? '').trim();
                                            if (email.isEmpty ||
                                                !email.contains('@')) {
                                              return 'Enter a valid email.';
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 12),
                                        TextFormField(
                                          controller: _passwordController,
                                          obscureText: true,
                                          decoration:
                                              _managementFieldDecoration(
                                                labelText: 'Password',
                                                hintText:
                                                    'At least 8 characters',
                                              ),
                                          validator: (value) {
                                            if ((value ?? '').length < 8) {
                                              return 'Use at least 8 characters.';
                                            }
                                            return null;
                                          },
                                        ),
                                        if (_createRole == 'student') ...[
                                          const SizedBox(height: 12),
                                          DropdownButtonFormField<String>(
                                            initialValue:
                                                _createStudentYearGroup,
                                            decoration:
                                                _managementFieldDecoration(
                                                  labelText: 'Year group',
                                                ),
                                            items: <DropdownMenuItem<String>>[
                                              const DropdownMenuItem<String>(
                                                value: '',
                                                child: Text('Not set yet'),
                                              ),
                                              ...kStudentYearGroupOptions.map(
                                                (yearGroup) =>
                                                    DropdownMenuItem<String>(
                                                      value: yearGroup,
                                                      child: Text(yearGroup),
                                                    ),
                                              ),
                                            ],
                                            onChanged: (value) {
                                              setState(
                                                () => _createStudentYearGroup =
                                                    (value ?? '').trim(),
                                              );
                                            },
                                          ),
                                        ],
                                        if (_createRole == 'teacher') ...[
                                          const SizedBox(height: 12),
                                          DropdownButtonFormField<String>(
                                            initialValue:
                                                _createTeacherPrimarySubject
                                                    .trim()
                                                    .isEmpty
                                                ? null
                                                : _createTeacherPrimarySubject,
                                            decoration: _managementFieldDecoration(
                                              labelText: 'Primary subject',
                                              helperText:
                                                  'This stays as the teacher profile display subject.',
                                            ),
                                            items: <DropdownMenuItem<String>>[
                                              const DropdownMenuItem<String>(
                                                value: '',
                                                child: Text(
                                                  'Choose primary subject',
                                                ),
                                              ),
                                              ...data.certificationSubjects.map(
                                                (subject) =>
                                                    DropdownMenuItem<String>(
                                                      value:
                                                          subject.subjectName,
                                                      child: Text(
                                                        subject.subjectName,
                                                      ),
                                                    ),
                                              ),
                                            ],
                                            validator: (value) {
                                              if (_createRole == 'teacher' &&
                                                  (value ?? '')
                                                      .trim()
                                                      .isEmpty) {
                                                return 'Choose a primary subject.';
                                              }
                                              return null;
                                            },
                                            onChanged: (value) {
                                              setState(() {
                                                _createTeacherPrimarySubject =
                                                    (value ?? '').trim();
                                                _createTeacherAdditionalSubjects
                                                    .remove(
                                                      _createTeacherPrimarySubject,
                                                    );
                                              });
                                            },
                                          ),
                                          const SizedBox(height: 12),
                                          Align(
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              'Additional teachable subjects',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.copyWith(
                                                    color: AppPalette.navy,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: data.certificationSubjects
                                                .map((subject) {
                                                  final subjectName = subject
                                                      .subjectName
                                                      .trim();
                                                  final isPrimary =
                                                      subjectName ==
                                                      _createTeacherPrimarySubject;
                                                  final isSelected =
                                                      isPrimary ||
                                                      _createTeacherAdditionalSubjects
                                                          .contains(
                                                            subjectName,
                                                          );

                                                  return FilterChip(
                                                    label: Text(subjectName),
                                                    selected: isSelected,
                                                    onSelected: isPrimary
                                                        ? null
                                                        : (selected) {
                                                            setState(() {
                                                              if (selected) {
                                                                _createTeacherAdditionalSubjects
                                                                    .add(
                                                                      subjectName,
                                                                    );
                                                              } else {
                                                                _createTeacherAdditionalSubjects
                                                                    .remove(
                                                                      subjectName,
                                                                    );
                                                              }
                                                            });
                                                          },
                                                  );
                                                })
                                                .toList(growable: false),
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
                                      icon: const Icon(
                                        Icons.person_add_alt_1_rounded,
                                      ),
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
                                      padding: const EdgeInsets.all(
                                        AppSpacing.item,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.78,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          AppSpacing.radiusMd,
                                        ),
                                      ),
                                      child: Text(
                                        'Created: ${_lastCreatedUser!.name} · ${_lastCreatedUser!.role} · ${_lastCreatedUser!.email ?? ''}',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodyMedium,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.item),
                SoftPanel(
                  colors: const [Color(0xFFF7FBFF), Color(0xFFEAF4FF)],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ManagementExpandableHeader(
                        title: 'Teacher Subject Setup',
                        subtitle:
                            'Management owns each teacher’s primary subject and full teachable subject list.',
                        summary: _buildTeacherSubjectSetupSummary(
                          data.teachers,
                        ),
                        isExpanded: _showTeacherSubjectSetupPanel,
                        onToggle: () => setState(
                          () => _showTeacherSubjectSetupPanel =
                              !_showTeacherSubjectSetupPanel,
                        ),
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        child: !_showTeacherSubjectSetupPanel
                            ? const SizedBox.shrink()
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: AppSpacing.compact),
                                  if (data.certificationSubjects.isEmpty)
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(
                                        AppSpacing.item,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.82,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          AppSpacing.radiusMd,
                                        ),
                                      ),
                                      child: Text(
                                        'Create certification subjects first so teacher subject access stays canonical.',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodyMedium,
                                      ),
                                    )
                                  else if (data.teachers.isEmpty)
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(
                                        AppSpacing.item,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.82,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          AppSpacing.radiusMd,
                                        ),
                                      ),
                                      child: Text(
                                        'No teacher accounts exist yet. Create one above, then manage their subjects here.',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodyMedium,
                                      ),
                                    )
                                  else
                                    ...data.teachers.map((teacher) {
                                      final subjectSummary =
                                          _teacherSubjectSummaryLabel(teacher);
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 10,
                                        ),
                                        child: Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(
                                            AppSpacing.item,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(
                                              alpha: 0.84,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              AppSpacing.radiusMd,
                                            ),
                                            border: Border.all(
                                              color: AppPalette.sky.withValues(
                                                alpha: 0.36,
                                              ),
                                            ),
                                          ),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      teacher.name,
                                                      style: Theme.of(
                                                        context,
                                                      ).textTheme.titleSmall,
                                                    ),
                                                    if ((teacher.email ?? '')
                                                        .trim()
                                                        .isNotEmpty) ...[
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        teacher.email!.trim(),
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .bodySmall
                                                            ?.copyWith(
                                                              color: AppPalette
                                                                  .textMuted,
                                                            ),
                                                      ),
                                                    ],
                                                    const SizedBox(height: 10),
                                                    Wrap(
                                                      spacing: 8,
                                                      runSpacing: 8,
                                                      children: [
                                                        _ManagementMiniPill(
                                                          label:
                                                              subjectSummary
                                                                  .isEmpty
                                                              ? 'No teachable subjects yet'
                                                              : subjectSummary,
                                                          backgroundColor:
                                                              subjectSummary
                                                                  .isEmpty
                                                              ? AppPalette.sun
                                                                    .withValues(
                                                                      alpha:
                                                                          0.18,
                                                                    )
                                                              : AppPalette
                                                                    .primaryBlue
                                                                    .withValues(
                                                                      alpha:
                                                                          0.12,
                                                                    ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              OutlinedButton.icon(
                                                onPressed: () =>
                                                    _openTeacherSubjectEditor(
                                                      teacher: teacher,
                                                      subjectOptions: data
                                                          .certificationSubjects,
                                                    ),
                                                icon: const Icon(
                                                  Icons.edit_rounded,
                                                ),
                                                label: const Text(
                                                  'Edit subjects',
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
                SoftPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ManagementExpandableHeader(
                        title: 'Student Timetable',
                        subtitle:
                            'Confirm lesson coverage across week and month for the selected student.',
                        summary: _buildTimetablePanelSummary(
                          selectedEntry: selectedTimetableEntry,
                          selectedDate: _selectedTimetableDate,
                          scheduledDayCount: workspace.timetable.length,
                        ),
                        isExpanded: _showTimetablePanel,
                        onToggle: () => setState(() {
                          _showTimetablePanel = !_showTimetablePanel;
                          if (!_showTimetablePanel) {
                            _showTimetableEditor = false;
                          }
                        }),
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        child: !_showTimetablePanel
                            ? const SizedBox.shrink()
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: AppSpacing.compact),
                                  WeeklyTimetableCalendar(
                                    title: 'Student Timetable',
                                    subtitle:
                                        'Confirm lesson coverage across week and month for the selected student.',
                                    entries: workspace.timetable,
                                    date: _selectedTimetableDate,
                                    showHeader: false,
                                    showPanel: false,
                                    showDateEditIcon: true,
                                    actionLabel: _showTimetableEditor
                                        ? 'Hide timetable editor'
                                        : selectedTimetableHasEntry
                                        ? 'Update teacher, subject, and room'
                                        : 'Add teacher, subject, and room',
                                    actionIcon: _showTimetableEditor
                                        ? Icons.keyboard_arrow_up_rounded
                                        : selectedTimetableHasEntry
                                        ? Icons.edit_calendar_rounded
                                        : Icons.add_circle_outline_rounded,
                                    onActionPressed: () =>
                                        _toggleTimetableEditor(data),
                                    inlineEditor: _showTimetableEditor
                                        ? _ManagementTimetableInlineEditor(
                                            selectedDate:
                                                _selectedTimetableDate,
                                            isWeekend: _isWeekendDate(
                                              _selectedTimetableDate,
                                            ),
                                            hasExistingEntry:
                                                selectedTimetableHasEntry,
                                            hasSubjects: data
                                                .certificationSubjects
                                                .isNotEmpty,
                                            subjectOptions:
                                                data.certificationSubjects,
                                            teacherOptions: data.teachers,
                                            selectedDayKey:
                                                _selectedTimetableDay,
                                            selectedMorningSubjectId:
                                                _selectedMorningSubjectId,
                                            selectedAfternoonSubjectId:
                                                _selectedAfternoonSubjectId,
                                            selectedMorningTeacherId:
                                                _selectedMorningTeacherId,
                                            selectedAfternoonTeacherId:
                                                _selectedAfternoonTeacherId,
                                            selectedMorningRoom:
                                                _selectedMorningRoom,
                                            selectedAfternoonRoom:
                                                _selectedAfternoonRoom,
                                            roomOptions: _timetableRoomOptions,
                                            isSaving: _isSavingTimetable,
                                            onMorningSubjectChanged: (value) {
                                              if (value == null) {
                                                return;
                                              }
                                              setState(
                                                () =>
                                                    _selectedMorningSubjectId =
                                                        value,
                                              );
                                            },
                                            onAfternoonSubjectChanged: (value) {
                                              if (value == null) {
                                                return;
                                              }
                                              setState(
                                                () =>
                                                    _selectedAfternoonSubjectId =
                                                        value,
                                              );
                                            },
                                            onMorningTeacherChanged: (value) =>
                                                setState(
                                                  () =>
                                                      _selectedMorningTeacherId =
                                                          value ?? '',
                                                ),
                                            onAfternoonTeacherChanged:
                                                (value) => setState(
                                                  () =>
                                                      _selectedAfternoonTeacherId =
                                                          value ?? '',
                                                ),
                                            onMorningRoomChanged: (value) {
                                              if (value == null) {
                                                return;
                                              }
                                              setState(
                                                () => _selectedMorningRoom =
                                                    value,
                                              );
                                            },
                                            onAfternoonRoomChanged: (value) {
                                              if (value == null) {
                                                return;
                                              }
                                              setState(
                                                () => _selectedAfternoonRoom =
                                                    value,
                                              );
                                            },
                                            onSave: () =>
                                                _saveTimetableEntry(data),
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
                                    onDateTap: (date) =>
                                        _openTimetableEditorForDate(
                                          date: date,
                                          timetable: workspace.timetable,
                                          subjects: data.certificationSubjects,
                                          teachers: data.teachers,
                                        ),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.item),
                SoftPanel(
                  colors: const [Color(0xFFF7FBFF), Color(0xFFEAF4FF)],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ManagementExpandableHeader(
                        title: 'Student Results',
                        subtitle:
                            'Filter by subject or result date, download the selected result set, or export each mission result or paper assessment.',
                        summary: _buildStudentResultsSummary(
                          filteredResults: filteredResults,
                          selectedSubject: selectedSubject,
                          selectedDate: selectedResultDate,
                        ),
                        isExpanded: _showStudentResultsPanel,
                        onToggle: () => setState(
                          () => _showStudentResultsPanel =
                              !_showStudentResultsPanel,
                        ),
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        child: !_showStudentResultsPanel
                            ? const SizedBox.shrink()
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: AppSpacing.compact),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: subjectFilters
                                        .map(
                                          (subject) => _SubjectFilterChip(
                                            label: subject,
                                            selected:
                                                subject == selectedSubject,
                                            onTap: () => setState(
                                              () => _selectedSubject = subject,
                                            ),
                                          ),
                                        )
                                        .toList(growable: false),
                                  ),
                                  const SizedBox(height: AppSpacing.compact),
                                  LayoutBuilder(
                                    builder: (context, constraints) {
                                      final compact =
                                          constraints.maxWidth < 760;
                                      final dateFilter =
                                          DropdownButtonFormField<String>(
                                            initialValue: selectedResultDate,
                                            decoration:
                                                _managementFieldDecoration(
                                                  labelText: 'Result date',
                                                ),
                                            items: resultDateFilters
                                                .map(
                                                  (dateLabel) =>
                                                      DropdownMenuItem<String>(
                                                        value: dateLabel,
                                                        child: Text(dateLabel),
                                                      ),
                                                )
                                                .toList(growable: false),
                                            onChanged: (value) {
                                              if (value == null) {
                                                return;
                                              }
                                              setState(
                                                () =>
                                                    _selectedResultDate = value,
                                              );
                                            },
                                          );
                                      final downloadButton = FilledButton.icon(
                                        style: _managementFilledActionStyle(
                                          context,
                                        ),
                                        onPressed:
                                            filteredResults.isEmpty ||
                                                _isAnyManagementDownloadActive
                                            ? null
                                            : () => _downloadFilteredResults(
                                                student:
                                                    workspace.selectedStudent,
                                                missions: filteredResults,
                                              ),
                                        icon: Icon(
                                          _isAnyManagementDownloadActive
                                              ? Icons.hourglass_top_rounded
                                              : Icons.download_rounded,
                                        ),
                                        label: Text(
                                          _isAnyManagementDownloadActive
                                              ? 'Preparing download...'
                                              : 'Download filtered results',
                                        ),
                                      );
                                      final resultCount = Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppPalette.surface.withValues(
                                            alpha: 0.96,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                          border: Border.all(
                                            color: AppPalette.sky.withValues(
                                              alpha: 0.7,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          '${filteredResults.length} saved result${filteredResults.length == 1 ? '' : 's'}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: AppPalette.navy,
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                      );

                                      if (compact) {
                                        return Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            dateFilter,
                                            const SizedBox(height: 10),
                                            resultCount,
                                            const SizedBox(height: 10),
                                            Align(
                                              alignment: Alignment.centerLeft,
                                              child: downloadButton,
                                            ),
                                          ],
                                        );
                                      }

                                      return Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Expanded(child: dateFilter),
                                          const SizedBox(width: 12),
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 10,
                                            ),
                                            child: resultCount,
                                          ),
                                          const SizedBox(width: 12),
                                          downloadButton,
                                        ],
                                      );
                                    },
                                  ),
                                  const SizedBox(height: AppSpacing.item),
                                  if (filteredResults.isEmpty)
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(
                                        AppSpacing.item,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppPalette.surface.withValues(
                                          alpha: 0.94,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          AppSpacing.radiusMd,
                                        ),
                                        border: Border.all(
                                          color: AppPalette.sky.withValues(
                                            alpha: 0.68,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        data.recentResults.isEmpty
                                            ? 'No saved result packages were found for this student yet.'
                                            : 'No results match this subject filter.',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodyMedium,
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
                                          downloadsLocked:
                                              _isAnyManagementDownloadActive,
                                          isDownloading:
                                              _downloadingResultPackageId ==
                                              mission.latestResultPackageId
                                                  .trim(),
                                          isDownloadingTeacherCopy:
                                              _downloadingTeacherCopyMissionId ==
                                              mission.missionId.trim(),
                                          onDownload: () =>
                                              _downloadMissionResult(
                                                student:
                                                    workspace.selectedStudent,
                                                mission: mission,
                                              ),
                                          onDownloadTeacherCopy: () =>
                                              _downloadMissionTeacherCopy(
                                                student:
                                                    workspace.selectedStudent,
                                                mission: mission,
                                              ),
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
                            'Use Switch student for the active roster and View archived when a learner needs restoring.',
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

  Future<void> _openStudentDayPlan(StudentSummary student) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ManagementDayPlanScreen(
          session: _session,
          student: student,
          initialDate: _selectedTimetableDate,
        ),
      ),
    );
  }

  void _selectStudentContext(String studentId) {
    if (!mounted || studentId.trim().isEmpty) {
      return;
    }

    setState(() {
      // WHY: Notifications and overview panels are student-specific, so
      // switching learners must reset the dependent filters before reloading.
      _selectedStudentId = studentId;
      _selectedSubject = _allSubjectsFilterLabel;
      _selectedResultDate = _allResultDatesFilterLabel;
      _selectedTargetDate = _allTargetDatesFilterLabel;
      _showTimetableEditor = false;
      _showCertificationProgressPanel = false;
      _showTimetablePanel = false;
      _showStudentTargetsPanel = false;
      _showStudentResultsPanel = false;
      _notificationInbox = null;
      _future = _loadWorkspace();
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

    _selectStudentContext(selectedStudentId);
  }

  Future<void> _openArchivedStudentsSheet(
    List<StudentSummary> archivedStudents,
  ) async {
    final selectedStudent = await showModalBottomSheet<StudentSummary>(
      context: context,
      showDragHandle: true,
      builder: (context) => _ArchivedStudentSheet(students: archivedStudents),
    );

    if (!mounted || selectedStudent == null) {
      return;
    }

    await _unarchiveStudent(selectedStudent);
  }

  Future<void> _archiveSelectedStudent(MentorWorkspaceData workspace) async {
    await _archiveStudent(
      student: workspace.selectedStudent,
      activeStudentCount: workspace.students.length,
      clearSelectedStudent: true,
    );
  }

  Future<void> _archiveStudent({
    required StudentSummary student,
    required int activeStudentCount,
    bool clearSelectedStudent = false,
  }) async {
    if (_isAnyStudentStatusActionActive) {
      return;
    }

    if (activeStudentCount <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Add another active student before archiving the final learner.',
          ),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Archive student?'),
        content: Text(
          'Archive ${student.name} and hide this learner from teacher switch lists and student quick-fill login chips. Existing evidence stays stored.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      if (clearSelectedStudent) {
        _isArchivingStudent = true;
      } else {
        _studentStatusActionId = student.id;
      }
    });
    try {
      await _api.archiveManagementStudent(
        token: _session.token,
        studentId: student.id,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        // WHY: Archive changes affect live pickers and roster sections, so the
        // management workspace must refetch after every archive state change.
        if (clearSelectedStudent) {
          _selectedStudentId = '';
          _selectedSubject = _allSubjectsFilterLabel;
          _selectedResultDate = _allResultDatesFilterLabel;
          _selectedTargetDate = _allTargetDatesFilterLabel;
          _selectedCertificationSubject = _allCertificationSubjectsFilterLabel;
          _notificationInbox = null;
          _showTimetableEditor = false;
          _showStudentTargetsPanel = false;
        }
        _future = _loadWorkspace();
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${student.name} archived.')));
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
          _isArchivingStudent = false;
          _studentStatusActionId = '';
        });
      }
    }
  }

  Future<void> _unarchiveStudent(StudentSummary student) async {
    if (_isAnyStudentStatusActionActive) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Unarchive student?'),
        content: Text(
          'Restore ${student.name} to the active roster so management and timetable teachers can work with this learner again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Unarchive'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _studentStatusActionId = student.id);
    try {
      await _api.unarchiveManagementStudent(
        token: _session.token,
        studentId: student.id,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        // WHY: Restoring a learner changes the live active roster immediately,
        // so the management dashboard must reload from the backend instead of
        // trying to merge local archived snapshots.
        _future = _loadWorkspace();
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${student.name} restored.')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _studentStatusActionId = '');
      }
    }
  }

  Future<void> _openResultReport({
    required ResultHistoryItem mission,
    required StudentSummary student,
  }) async {
    final resultPackageId = mission.resultPackageId.trim();

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
          mission: mission.toMissionContext(),
          student: student,
          resultPackageId: resultPackageId,
          api: _api,
          readOnly: true,
          useManagementAccess: true,
        ),
      ),
    );
  }

  Future<void> _saveSelectedStudentYearGroup(StudentSummary student) async {
    if (_isSavingStudentYearGroup) {
      return;
    }

    setState(() => _isSavingStudentYearGroup = true);
    try {
      await _api.updateManagementStudentYearGroup(
        token: _session.token,
        studentId: student.id,
        yearGroup: _selectedStudentYearGroup,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedStudentId = student.id;
        _future = _loadWorkspace();
      });

      final savedLabel = _selectedStudentYearGroup.trim().isEmpty
          ? 'Year group cleared.'
          : '${student.name} is now in ${_selectedStudentYearGroup.trim()}.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(savedLabel)));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _isSavingStudentYearGroup = false);
      }
    }
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
        subjectSpecialty: _createTeacherPrimarySubject.trim(),
        subjectSpecialties: _createTeacherAdditionalSubjects.toList(
          growable: false,
        ),
        yearGroup: _createRole == 'student' ? _createStudentYearGroup : '',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _lastCreatedUser = createdUser;
        _showCreateUserPanel = false;
        _nameController.clear();
        _emailController.clear();
        _passwordController.clear();
        _createStudentYearGroup = '';
        _createTeacherPrimarySubject = '';
        _createTeacherAdditionalSubjects.clear();
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
          _selectedResultDate = _allResultDatesFilterLabel;
          _selectedTargetDate = _allTargetDatesFilterLabel;
          _showTimetableEditor = false;
          _showCertificationProgressPanel = false;
          _showTimetablePanel = false;
          _showStudentTargetsPanel = false;
          _showStudentResultsPanel = false;
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

  Future<void> _openTeacherSubjectEditor({
    required TeacherSummary teacher,
    required List<SubjectCertificationSettings> subjectOptions,
  }) async {
    final canonicalSubjectNames =
        subjectOptions
            .map((subject) => subject.subjectName.trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList(growable: false)
          ..sort();
    if (canonicalSubjectNames.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Create certification subjects first so teacher subjects stay canonical.',
          ),
        ),
      );
      return;
    }

    final initialPrimary = (teacher.subjectSpecialty ?? '').trim().isNotEmpty
        ? (teacher.subjectSpecialty ?? '').trim()
        : (teacher.subjectSpecialties.isNotEmpty
              ? teacher.subjectSpecialties.first.trim()
              : '');

    final updatedTeacher = await showModalBottomSheet<TeacherSummary>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        var selectedPrimary = initialPrimary;
        final selectedAdditional =
            <String>{...teacher.subjectSpecialties.map((value) => value.trim())}
              ..removeWhere((value) => value.isEmpty)
              ..remove(initialPrimary);
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
                      'Edit teacher subjects',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${teacher.name} · ${teacher.email ?? 'No email'}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppPalette.textMuted,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.section),
                    DropdownButtonFormField<String>(
                      initialValue: selectedPrimary.isNotEmpty
                          ? selectedPrimary
                          : null,
                      decoration: _managementFieldDecoration(
                        labelText: 'Primary subject',
                        helperText:
                            'This stays the display subject for roster labels and backward-compatible teacher views.',
                      ),
                      items: canonicalSubjectNames
                          .map(
                            (subjectName) => DropdownMenuItem<String>(
                              value: subjectName,
                              child: Text(subjectName),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: isSaving
                          ? null
                          : (value) {
                              final nextPrimary = (value ?? '').trim();
                              setSheetState(() {
                                selectedPrimary = nextPrimary;
                                selectedAdditional.remove(nextPrimary);
                              });
                            },
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Additional teachable subjects',
                      style: Theme.of(
                        context,
                      ).textTheme.titleSmall?.copyWith(color: AppPalette.navy),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: canonicalSubjectNames
                          .map((subjectName) {
                            final isPrimary = subjectName == selectedPrimary;
                            final isSelected =
                                isPrimary ||
                                selectedAdditional.contains(subjectName);
                            return FilterChip(
                              label: Text(subjectName),
                              selected: isSelected,
                              onSelected: isSaving || isPrimary
                                  ? null
                                  : (selected) {
                                      setSheetState(() {
                                        if (selected) {
                                          selectedAdditional.add(subjectName);
                                        } else {
                                          selectedAdditional.remove(
                                            subjectName,
                                          );
                                        }
                                      });
                                    },
                            );
                          })
                          .toList(growable: false),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Primary: ${selectedPrimary.isEmpty ? 'Not selected yet' : selectedPrimary}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppPalette.textMuted,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.section),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: isSaving
                            ? null
                            : () async {
                                final primarySubject = selectedPrimary.trim();
                                if (primarySubject.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Choose a primary subject before saving teacher access.',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                setSheetState(() => isSaving = true);
                                try {
                                  final updated = await _api
                                      .updateManagementTeacherSubjects(
                                        token: _session.token,
                                        teacherId: teacher.id,
                                        subjectSpecialty: primarySubject,
                                        subjectSpecialties: <String>[
                                          primarySubject,
                                          ...selectedAdditional,
                                        ],
                                      );
                                  if (!mounted) {
                                    return;
                                  }
                                  if (!sheetContext.mounted) {
                                    return;
                                  }
                                  Navigator.of(sheetContext).pop(updated);
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
                                }
                              },
                        icon: Icon(
                          isSaving ? Icons.hourglass_top_rounded : Icons.save,
                        ),
                        label: Text(
                          isSaving
                              ? 'Saving subjects...'
                              : 'Save teacher subjects',
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

    if (updatedTeacher == null || !mounted) {
      return;
    }

    setState(() {
      // WHY: Teacher subject access affects timetable ownership and authoring
      // scope immediately, so management reloads the workspace from the
      // backend instead of patching partial local state.
      _future = _loadWorkspace();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${updatedTeacher.name} now teaches ${_teacherSubjectSummaryLabel(updatedTeacher)}.',
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

  List<String> _buildSubjectFilters(List<ResultHistoryItem> missions) {
    final labels = <String>{_allSubjectsFilterLabel};

    for (final mission in missions) {
      final subjectName = (mission.subject?.name ?? '').trim();
      if (subjectName.isNotEmpty) {
        labels.add(subjectName);
      }
    }

    return labels.toList(growable: false);
  }

  List<String> _buildResultDateFilters(List<ResultHistoryItem> missions) {
    final dates = <String>{};

    for (final mission in missions) {
      final dateKey = _resultDateKeyForMission(mission);
      if (dateKey != 'No date') {
        dates.add(dateKey);
      }
    }

    final sortedDates = dates.toList(growable: false)
      ..sort((left, right) => right.compareTo(left));
    return <String>[_allResultDatesFilterLabel, ...sortedDates];
  }

  List<ResultHistoryItem> _filterResults(
    List<ResultHistoryItem> missions, {
    required String subject,
    required String dateKey,
  }) {
    return missions
        .where((mission) {
          final matchesSubject =
              subject == _allSubjectsFilterLabel ||
              (mission.subject?.name ?? '').trim() == subject;
          final matchesDate =
              dateKey == _allResultDatesFilterLabel ||
              _resultDateKeyForMission(mission) == dateKey;
          return matchesSubject && matchesDate;
        })
        .toList(growable: false);
  }

  String _resultDateKeyForMission(ResultHistoryItem mission) {
    final scheduledDate = (mission.availableOnDate ?? '').trim();
    if (scheduledDate.isNotEmpty) {
      return _formatManagementMissionDate(scheduledDate);
    }

    return _formatManagementMissionDate(
      mission.publishedAt ?? mission.createdAt,
    );
  }

  Future<void> _downloadFilteredTargets({
    required StudentSummary student,
    required List<ManagementTargetDateSection> sections,
    required List<ResultHistoryItem> recentResults,
    required List<TeacherSummary> teachers,
  }) async {
    final exportTargets = _uniqueTargetsFromSections(sections);
    if (_isAnyManagementDownloadActive || exportTargets.isEmpty) {
      return;
    }

    setState(() => _isDownloadingTargets = true);
    try {
      final downloaded = await downloadTextFile(
        fileName: _buildManagementTargetsFileName(student: student),
        content: _buildManagementTargetsHtml(
          student: student,
          sections: sections,
          recentResults: recentResults,
          teachers: teachers,
        ),
        mimeType: 'text/html;charset=utf-8',
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            downloaded
                ? 'Downloaded ${exportTargets.length} target result${exportTargets.length == 1 ? '' : 's'}.'
                : 'Download is not available on this device yet.',
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
        setState(() => _isDownloadingTargets = false);
      }
    }
  }

  Future<void> _downloadTargetResult({
    required StudentSummary student,
    required TargetSummary target,
    required List<ManagementTargetDateSection> sections,
    required List<ResultHistoryItem> recentResults,
    required List<TeacherSummary> teachers,
  }) async {
    if (_isAnyManagementDownloadActive) {
      return;
    }

    setState(() => _downloadingTargetId = target.id);
    try {
      final downloaded = await downloadTextFile(
        fileName: _buildManagementTargetResultFileName(
          student: student,
          target: target,
        ),
        content: _buildManagementTargetsHtml(
          student: student,
          sections: sections,
          recentResults: recentResults,
          teachers: teachers,
        ),
        mimeType: 'text/html;charset=utf-8',
      );

      if (!mounted) {
        return;
      }

      final targetTitle = target.title.trim().isEmpty
          ? 'target'
          : target.title.trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            downloaded
                ? 'Downloaded $targetTitle result.'
                : 'Download is not available on this device yet.',
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
        setState(() => _downloadingTargetId = '');
      }
    }
  }

  Future<void> _downloadFilteredResults({
    required StudentSummary student,
    required List<ResultHistoryItem> missions,
  }) async {
    if (_isAnyManagementDownloadActive || missions.isEmpty) {
      return;
    }

    setState(() => _isDownloadingResults = true);
    try {
      final exportRows = await Future.wait(
        missions
            .where((mission) => mission.latestResultPackageId.trim().isNotEmpty)
            .map(_loadResultExportRowForMission),
      );

      if (exportRows.isEmpty) {
        throw Exception('No saved result packages were available to download.');
      }

      final downloaded = await downloadTextFile(
        fileName: _buildManagementResultsFileName(student: student),
        content: _buildManagementResultsHtml(
          student: student,
          rows: exportRows,
        ),
        mimeType: 'text/html;charset=utf-8',
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            downloaded
                ? 'Downloaded ${exportRows.length} result package${exportRows.length == 1 ? '' : 's'}.'
                : 'Download is not available on this device yet.',
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
        setState(() => _isDownloadingResults = false);
      }
    }
  }

  Future<void> _downloadMissionResult({
    required StudentSummary student,
    required ResultHistoryItem mission,
  }) async {
    final resultPackageId = mission.latestResultPackageId.trim();
    if (_isAnyManagementDownloadActive || resultPackageId.isEmpty) {
      return;
    }

    setState(() => _downloadingResultPackageId = resultPackageId);
    try {
      final exportRow = await _loadResultExportRowForMission(mission);
      final downloaded = await downloadTextFile(
        fileName: _buildManagementMissionResultFileName(
          student: student,
          mission: mission,
        ),
        content: _buildManagementResultsHtml(
          student: student,
          rows: [exportRow],
        ),
        mimeType: 'text/html;charset=utf-8',
      );

      if (!mounted) {
        return;
      }

      final missionTitle = mission.title.trim().isEmpty
          ? 'mission'
          : mission.title.trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            downloaded
                ? 'Downloaded $missionTitle result.'
                : 'Download is not available on this device yet.',
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
        setState(() => _downloadingResultPackageId = '');
      }
    }
  }

  Future<void> _downloadMissionTeacherCopy({
    required StudentSummary student,
    required ResultHistoryItem mission,
  }) async {
    final missionId = mission.missionId.trim();
    if (_isAnyManagementDownloadActive ||
        missionId.isEmpty ||
        !mission.hasTeacherCopy) {
      return;
    }

    setState(() => _downloadingTeacherCopyMissionId = missionId);
    try {
      final downloaded = await downloadTextFile(
        fileName: _buildManagementTeacherCopyFileName(
          student: student,
          mission: mission,
        ),
        content: _buildManagementTeacherCopyHtml(
          student: student,
          mission: mission,
        ),
        mimeType: 'text/html;charset=utf-8',
      );

      if (!mounted) {
        return;
      }

      final missionTitle = mission.title.trim().isEmpty
          ? 'mission'
          : mission.title.trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            downloaded
                ? 'Downloaded $missionTitle teacher copy.'
                : 'Download is not available on this device yet.',
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
        setState(() => _downloadingTeacherCopyMissionId = '');
      }
    }
  }

  Future<_ManagementResultExportRow> _loadResultExportRowForMission(
    ResultHistoryItem mission,
  ) async {
    final resultPackageId = mission.latestResultPackageId.trim();
    if (resultPackageId.isEmpty) {
      throw Exception('This mission does not have a saved result package yet.');
    }

    // WHY: Management downloads must use the immutable saved result package so
    // each export matches the auditable evidence shown in the result report.
    final resultPackage = await _api.getManagementResultPackage(
      token: _session.token,
      resultPackageId: resultPackageId,
    );
    return _ManagementResultExportRow(
      mission: mission,
      resultPackage: resultPackage,
    );
  }

  String _buildManagementTargetsFileName({required StudentSummary student}) {
    final studentSlug = _sanitizeManagementFileName(student.name);
    final dateSlug = _selectedTargetDate == _allTargetDatesFilterLabel
        ? 'all-dates'
        : _sanitizeManagementFileName(_selectedTargetDate);
    return '${studentSlug}_target-results_$dateSlug.html';
  }

  String _buildManagementTargetResultFileName({
    required StudentSummary student,
    required TargetSummary target,
  }) {
    final studentSlug = _sanitizeManagementFileName(student.name);
    final targetSlug = _sanitizeManagementFileName(target.title);
    final dateSlug = _sanitizeManagementFileName(target.awardDateKey);
    return '${studentSlug}_${dateSlug}_${targetSlug}_target-result.html';
  }

  String _buildManagementResultsFileName({required StudentSummary student}) {
    final studentSlug = _sanitizeManagementFileName(student.name);
    final subjectSlug = _selectedSubject == _allSubjectsFilterLabel
        ? 'all-subjects'
        : _sanitizeManagementFileName(_selectedSubject);
    final dateSlug = _selectedResultDate == _allResultDatesFilterLabel
        ? 'all-dates'
        : _sanitizeManagementFileName(_selectedResultDate);
    return '${studentSlug}_results_${dateSlug}_$subjectSlug.html';
  }

  String _buildManagementMissionResultFileName({
    required StudentSummary student,
    required ResultHistoryItem mission,
  }) {
    final studentSlug = _sanitizeManagementFileName(student.name);
    final missionSlug = _sanitizeManagementFileName(mission.title);
    final dateSlug = _sanitizeManagementFileName(
      _resultDateKeyForMission(mission),
    );
    return '${studentSlug}_${dateSlug}_${missionSlug}_result.html';
  }

  String _buildManagementTeacherCopyFileName({
    required StudentSummary student,
    required ResultHistoryItem mission,
  }) {
    final studentSlug = _sanitizeManagementFileName(student.name);
    final missionSlug = _sanitizeManagementFileName(mission.title);
    final subjectSlug = _sanitizeManagementFileName(
      (mission.subject?.name ?? 'subject').trim(),
    );
    final dateSlug = _sanitizeManagementFileName(
      _resultDateKeyForMission(mission),
    );
    return '${studentSlug}_${subjectSlug}_${dateSlug}_${missionSlug}_teacher-copy.html';
  }

  String _buildManagementTargetsHtml({
    required StudentSummary student,
    required List<ManagementTargetDateSection> sections,
    required List<ResultHistoryItem> recentResults,
    required List<TeacherSummary> teachers,
  }) {
    final sortedTargets = _uniqueTargetsFromSections(sections)
      ..sort((left, right) {
        final dateCompare = right.awardDateKey.compareTo(left.awardDateKey);
        if (dateCompare != 0) {
          return dateCompare;
        }
        final typeCompare = _managementTargetTypeLabel(
          left,
        ).compareTo(_managementTargetTypeLabel(right));
        if (typeCompare != 0) {
          return typeCompare;
        }
        return left.title.compareTo(right.title);
      });
    final uniqueDateCount = sections.length;
    final totalXp = sortedTargets.fold<int>(
      0,
      (total, target) => total + target.xpAwarded,
    );

    final buffer = StringBuffer()
      ..writeln('<!DOCTYPE html>')
      ..writeln('<html lang="en">')
      ..writeln('<head>')
      ..writeln('<meta charset="utf-8" />')
      ..writeln(
        '<meta name="viewport" content="width=device-width, initial-scale=1" />',
      )
      ..writeln(
        '<title>${_escapeManagementHtml(student.name)} target results</title>',
      )
      ..writeln('<style>${_buildManagementResultsStyles()}</style>')
      ..writeln('</head>')
      ..writeln('<body>')
      ..writeln('<main class="page">')
      ..writeln('<section class="hero">')
      ..writeln('<span class="copy-chip">Management Target Export</span>')
      ..writeln(
        '<h1>${_escapeManagementHtml(student.name)} target results</h1>',
      )
      ..writeln(
        '<p class="hero-summary">Daily target outcomes exported from the management workspace.</p>',
      )
      ..writeln('<div class="meta-grid">')
      ..writeln(
        _buildManagementMetaCardHtml(
          label: 'Targets',
          value: '${sortedTargets.length}',
        ),
      )
      ..writeln(
        _buildManagementMetaCardHtml(label: 'Dates', value: '$uniqueDateCount'),
      )
      ..writeln(
        _buildManagementMetaCardHtml(label: 'Target XP', value: '$totalXp XP'),
      )
      ..writeln(
        _buildManagementMetaCardHtml(
          label: 'Filter',
          value: _selectedTargetDate == _allTargetDatesFilterLabel
              ? 'All dates'
              : _selectedTargetDate,
        ),
      )
      ..writeln('</div>')
      ..writeln('</section>');

    for (final section in sections) {
      final targetsForDate = section.targets;
      final dateXp = targetsForDate.fold<int>(
        0,
        (total, target) => total + target.xpAwarded,
      );
      final commentResolutions = _buildManagementTargetCommentResolutions(
        targets: targetsForDate,
        dateKey: section.dateKey,
        sessionComments: section.sessionComments,
        recentResults: recentResults,
        teachers: teachers,
      );
      final sessionCommentsForDate = _buildUnmatchedTargetComments(
        sessionComments: section.sessionComments,
        resolutions: commentResolutions,
      );
      buffer
        ..writeln('<section class="date-group">')
        ..writeln('<h2>${_escapeManagementHtml(section.dateKey)}</h2>')
        ..writeln(
          '<p class="hero-summary">${targetsForDate.length} target${targetsForDate.length == 1 ? '' : 's'} · $dateXp XP</p>',
        );
      if (sessionCommentsForDate.isNotEmpty) {
        buffer.writeln(
          '<p class="meta-label" style="margin: 0 0 12px;">Teacher session comments</p>',
        );
        for (final comment in sessionCommentsForDate) {
          final subjectName = comment.subjectName.trim().isEmpty
              ? 'Session'
              : comment.subjectName.trim();
          final authorName = comment.authorName.trim().isNotEmpty
              ? comment.authorName.trim()
              : comment.teacherName.trim();
          final plannedTeacherName = comment.plannedTeacherName.trim();
          final conductedByName = comment.conductedByName.trim();
          final savedAtLabel = _formatManagementAuditDateTime(
            comment.updatedAt ?? comment.createdAt,
          );
          final commentLabel = authorName.isEmpty
              ? '$subjectName · ${_managementSessionTypeLabel(comment.sessionType)}'
              : '$subjectName · ${_managementSessionTypeLabel(comment.sessionType)} · $authorName';
          buffer
            ..writeln('<article class="result-card">')
            ..writeln('<div class="result-header">')
            ..writeln('<div>')
            ..writeln('<h4>${_escapeManagementHtml(subjectName)}</h4>')
            ..writeln(
              '<p class="result-subtitle">${_escapeManagementHtml(commentLabel)}</p>',
            )
            ..writeln('</div>')
            ..writeln(
              '<span class="result-pill">${_escapeManagementHtml(_managementSessionTypeLabel(comment.sessionType))}</span>',
            )
            ..writeln('</div>')
            ..writeln('<div class="result-pills">');
          if (authorName.isNotEmpty) {
            buffer.writeln(
              '<span class="result-pill">${_escapeManagementHtml('Author: $authorName')}</span>',
            );
          }
          if (plannedTeacherName.isNotEmpty) {
            buffer.writeln(
              '<span class="result-pill">${_escapeManagementHtml('Planned: $plannedTeacherName')}</span>',
            );
          }
          if (conductedByName.isNotEmpty) {
            buffer.writeln(
              '<span class="result-pill">${_escapeManagementHtml('Taught by: $conductedByName')}</span>',
            );
          }
          if (savedAtLabel.isNotEmpty) {
            buffer.writeln(
              '<span class="result-pill">${_escapeManagementHtml('Saved: $savedAtLabel')}</span>',
            );
          }
          buffer
            ..writeln('</div>')
            ..writeln('<p>${_escapeManagementHtml(comment.comment)}</p>')
            ..writeln('</article>');
        }
      }
      if (targetsForDate.isEmpty && sessionCommentsForDate.isEmpty) {
        buffer.writeln(
          '<article class="result-card"><p>No target result was saved for this weekday yet.</p></article>',
        );
      }
      for (final target in targetsForDate) {
        final description = target.description.trim();
        final resolvedComments =
            commentResolutions[_managementTargetIdentityKey(target)]
                ?.comments ??
            const <_ManagementResolvedTargetComment>[];
        buffer
          ..writeln('<article class="result-card">')
          ..writeln('<div class="result-header">')
          ..writeln('<div>')
          ..writeln('<h4>${_escapeManagementHtml(target.title)}</h4>')
          ..writeln(
            '<p class="result-subtitle">${_escapeManagementHtml(_managementTargetTypeLabel(target))} · ${_escapeManagementHtml(_managementTargetStatusLabel(target))}</p>',
          )
          ..writeln('</div>')
          ..writeln(
            '<span class="result-pill">${_escapeManagementHtml('${target.stars}/3 stars · ${target.xpAwarded} XP')}</span>',
          )
          ..writeln('</div>');
        if (description.isNotEmpty) {
          buffer.writeln(
            '<p class="meta-label">${_escapeManagementHtml(_managementTargetCommentLabel(target))}</p>',
          );
          buffer.writeln('<p>${_escapeManagementHtml(description)}</p>');
        }
        if (resolvedComments.isNotEmpty) {
          buffer.writeln(
            '<p class="meta-label" style="margin-top: 12px;">Teacher comments</p>',
          );
          for (final comment in resolvedComments) {
            buffer.writeln(_buildManagementTargetTeacherCommentHtml(comment));
          }
        }
        buffer
          ..writeln('<div class="meta-grid compact">')
          ..writeln(
            _buildManagementMetaCardHtml(
              label: 'Difficulty',
              value: _managementTitleCase(target.difficulty),
            ),
          )
          ..writeln(
            _buildManagementMetaCardHtml(
              label: 'Status',
              value: _managementTargetStatusLabel(target),
            ),
          )
          ..writeln(
            _buildManagementMetaCardHtml(
              label: 'Target type',
              value: _managementTargetTypeLabel(target),
            ),
          )
          ..writeln(
            _buildManagementMetaCardHtml(
              label: 'Award date',
              value: target.awardDateKey.trim().isEmpty
                  ? 'No date'
                  : target.awardDateKey.trim(),
            ),
          )
          ..writeln(
            _buildManagementMetaCardHtml(
              label: 'Saved at',
              value:
                  _formatManagementAuditDateTime(
                    target.updatedAt ?? target.createdAt,
                  ).isEmpty
                  ? 'Not recorded'
                  : _formatManagementAuditDateTime(
                      target.updatedAt ?? target.createdAt,
                    ),
            ),
          )
          ..writeln(
            _buildManagementMetaCardHtml(
              label: 'Saved by',
              value: target.createdByName.trim().isEmpty
                  ? 'Not recorded'
                  : target.createdByName.trim(),
            ),
          )
          ..writeln('</div>')
          ..writeln('</article>');
      }
      buffer.writeln('</section>');
    }

    buffer
      ..writeln('</main>')
      ..writeln('</body>')
      ..writeln('</html>');
    return buffer.toString();
  }

  String _buildManagementResultsHtml({
    required StudentSummary student,
    required List<_ManagementResultExportRow> rows,
  }) {
    final sortedRows = [...rows]
      ..sort((left, right) {
        final leftDate = _resultDateForExport(left);
        final rightDate = _resultDateForExport(right);
        final dateCompare = rightDate.compareTo(leftDate);
        if (dateCompare != 0) {
          return dateCompare;
        }
        final subjectCompare = _subjectNameForExport(
          left,
        ).compareTo(_subjectNameForExport(right));
        if (subjectCompare != 0) {
          return subjectCompare;
        }
        return left.resultPackage.meta.missionTitle.compareTo(
          right.resultPackage.meta.missionTitle,
        );
      });

    final groupedRows =
        <String, Map<String, List<_ManagementResultExportRow>>>{};
    for (final row in sortedRows) {
      final dateKey = _resultDateForExport(row);
      final subjectKey = _subjectNameForExport(row);
      groupedRows.putIfAbsent(
        dateKey,
        () => <String, List<_ManagementResultExportRow>>{},
      );
      groupedRows[dateKey]!.putIfAbsent(
        subjectKey,
        () => <_ManagementResultExportRow>[],
      );
      groupedRows[dateKey]![subjectKey]!.add(row);
    }

    final summaryLabel = rows.length == 1
        ? '${_resultDateForExport(rows.first)} · ${_subjectNameForExport(rows.first)}'
        : [
            _selectedResultDate == _allResultDatesFilterLabel
                ? 'All dates'
                : _selectedResultDate,
            _selectedSubject == _allSubjectsFilterLabel
                ? 'All subjects'
                : _selectedSubject,
          ].join(' · ');
    final heroTitle = rows.length == 1
        ? '${rows.first.resultPackage.meta.missionTitle} Result Export'
        : '${student.name} Result Export';
    final heroSummary = rows.length == 1
        ? rows.first.mission.isPaperAssessment
              ? 'Saved result evidence for one paper assessment from the management workspace.'
              : 'Saved result evidence for one completed mission from the management workspace.'
        : 'Grouped by result date and subject using saved result packages from the management workspace.';

    final buffer = StringBuffer()
      ..writeln('<!DOCTYPE html>')
      ..writeln('<html lang="en">')
      ..writeln('<head>')
      ..writeln('<meta charset="utf-8" />')
      ..writeln(
        '<meta name="viewport" content="width=device-width, initial-scale=1" />',
      )
      ..writeln(
        '<title>${_escapeManagementHtml('${student.name} · Result Download')}</title>',
      )
      ..writeln('<style>${_buildManagementResultsStyles()}</style>')
      ..writeln('</head>')
      ..writeln('<body>')
      ..writeln('<main class="page">')
      ..writeln('<section class="hero">')
      ..writeln('<span class="copy-chip">Management Download</span>')
      ..writeln('<h1>${_escapeManagementHtml(heroTitle)}</h1>')
      ..writeln(
        '<p class="hero-summary">${_escapeManagementHtml(heroSummary)}</p>',
      )
      ..writeln('<div class="meta-grid">')
      ..writeln(
        _buildManagementMetaCardHtml(label: 'Student', value: student.name),
      )
      ..writeln(
        _buildManagementMetaCardHtml(label: 'Filter', value: summaryLabel),
      )
      ..writeln(
        _buildManagementMetaCardHtml(
          label: 'Result packages',
          value: '${rows.length}',
        ),
      )
      ..writeln(
        _buildManagementMetaCardHtml(
          label: 'Generated',
          value: DateTime.now().toLocal().toIso8601String(),
        ),
      )
      ..writeln('</div>')
      ..writeln('</section>');

    for (final dateEntry in groupedRows.entries) {
      buffer
        ..writeln('<section class="date-group">')
        ..writeln('<h2>${_escapeManagementHtml(dateEntry.key)}</h2>');
      for (final subjectEntry in dateEntry.value.entries) {
        buffer
          ..writeln('<section class="subject-group">')
          ..writeln('<h3>${_escapeManagementHtml(subjectEntry.key)}</h3>');
        for (final row in subjectEntry.value) {
          buffer.writeln(_buildManagementResultCardHtml(row));
        }
        buffer.writeln('</section>');
      }
      buffer.writeln('</section>');
    }

    buffer
      ..writeln('</main>')
      ..writeln('</body>')
      ..writeln('</html>');
    return buffer.toString();
  }

  String _buildManagementTeacherCopyHtml({
    required StudentSummary student,
    required ResultHistoryItem mission,
  }) {
    final subjectName = (mission.subject?.name ?? 'No subject').trim();
    final taskFocusText = mission.taskCodes.isEmpty
        ? 'None selected'
        : mission.taskCodes.join(', ');
    final sourceGuidance = mission.sourceUnitText.trim();

    final buffer = StringBuffer()
      ..writeln('<!DOCTYPE html>')
      ..writeln('<html lang="en">')
      ..writeln('<head>')
      ..writeln('<meta charset="utf-8" />')
      ..writeln(
        '<meta name="viewport" content="width=device-width, initial-scale=1" />',
      )
      ..writeln(
        '<title>${_escapeManagementHtml('${mission.title} · Teacher Copy')}</title>',
      )
      ..writeln('<style>${_buildManagementTeacherCopyStyles()}</style>')
      ..writeln('</head>')
      ..writeln('<body>')
      ..writeln('<main class="page">')
      ..writeln('<section class="hero">')
      ..writeln('<div class="hero-copy">')
      ..writeln('<span class="copy-chip">Teacher Copy</span>')
      ..writeln('<h1>${_escapeManagementHtml(mission.title)}</h1>')
      ..writeln(
        '<p class="hero-summary">Teacher-ready mission copy with full question content, all options, answer keys, and guidance.</p>',
      )
      ..writeln('</div>')
      ..writeln('<div class="meta-grid">')
      ..writeln(
        _buildManagementMetaCardHtml(label: 'Student', value: student.name),
      )
      ..writeln(
        _buildManagementMetaCardHtml(label: 'Subject', value: subjectName),
      )
      ..writeln(
        _buildManagementMetaCardHtml(
          label: 'Session',
          value: mission.sessionType.toUpperCase(),
        ),
      )
      ..writeln(
        _buildManagementMetaCardHtml(
          label: 'Mission Date',
          value: _resultDateKeyForMission(mission),
        ),
      )
      ..writeln(
        _buildManagementMetaCardHtml(
          label: 'Format',
          value: _managementFormatLabel(mission),
        ),
      )
      ..writeln(
        _buildManagementMetaCardHtml(
          label: 'Difficulty',
          value: mission.difficulty.toUpperCase(),
        ),
      )
      ..writeln(
        _buildManagementMetaCardHtml(
          label: 'XP Reward',
          value: '${mission.xpReward} XP',
        ),
      )
      ..writeln(
        _buildManagementMetaCardHtml(label: 'Task Focus', value: taskFocusText),
      )
      ..writeln('</div>')
      ..writeln('</section>')
      ..writeln('<section class="section-card notice-card teacher-note">')
      ..writeln('<h2>Teacher Copy</h2>')
      ..writeln(
        '<p>Use this copy for review, oversight, and answer checking. All options and teacher guidance are included.</p>',
      )
      ..writeln('</section>');

    if (mission.teacherNote.trim().isNotEmpty) {
      buffer
        ..writeln('<section class="section-card">')
        ..writeln('<h2>Teacher Note</h2>')
        ..writeln(_buildManagementRichTextHtml(mission.teacherNote))
        ..writeln('</section>');
    }

    if (sourceGuidance.isNotEmpty) {
      buffer
        ..writeln('<section class="section-card">')
        ..writeln('<h2>Unit Text</h2>')
        ..writeln(
          '<p class="section-kicker">Reviewed unit text saved with this mission.</p>',
        )
        ..writeln(_buildManagementRichTextHtml(sourceGuidance))
        ..writeln('</section>');
    }

    buffer.writeln(
      mission.draftFormat == 'ESSAY_BUILDER'
          ? _buildManagementTeacherCopyEssayHtml(mission)
          : _buildManagementTeacherCopyQuestionHtml(mission),
    );

    buffer
      ..writeln('</main>')
      ..writeln('</body>')
      ..writeln('</html>');
    return buffer.toString();
  }

  String _buildManagementTeacherCopyQuestionHtml(ResultHistoryItem mission) {
    final questions = mission.questions;
    if (questions.isEmpty) {
      return '<section class="section-card"><h2>Questions</h2><p class="section-kicker">No question content was saved for this mission.</p></section>';
    }

    const optionLabels = ['A', 'B', 'C', 'D'];
    final buffer = StringBuffer()
      ..writeln('<section class="section-card">')
      ..writeln(
        '<h2>${_escapeManagementHtml(mission.draftFormat == 'THEORY' ? 'Theory Questions' : 'Questions')}</h2>',
      )
      ..writeln(
        '<p class="section-kicker">${_escapeManagementHtml(mission.draftFormat == 'THEORY' ? 'Teacher-ready theory prompts with expected responses and guidance.' : 'Teacher-ready question set with every option and answer key shown.')}</p>',
      );

    for (final entry in questions.asMap().entries) {
      final question = entry.value;
      buffer
        ..writeln('<article class="question-card">')
        ..writeln('<div class="question-top">')
        ..writeln(
          '<span class="question-pill">Question ${entry.key + 1}</span><span class="copy-pill">Teacher Copy</span>',
        )
        ..writeln('</div>');

      if (question.learningText.trim().isNotEmpty) {
        buffer
          ..writeln('<div class="field-label">Learn First</div>')
          ..writeln(_buildManagementRichTextHtml(question.learningText));
      }

      buffer
        ..writeln('<div class="field-label">Prompt</div>')
        ..writeln(_buildManagementRichTextHtml(question.prompt));

      if (mission.draftFormat == 'THEORY') {
        buffer.writeln(
          '<div class="pill-row"><span class="soft-pill">Minimum Words: ${_escapeManagementHtml('${question.minWordCount > 0 ? question.minWordCount : 1}')}</span></div>',
        );
        buffer
          ..writeln('<div class="answer-card">')
          ..writeln('<div class="field-label">Expected Answer</div>')
          ..writeln(
            _buildManagementRichTextHtml(
              question.expectedAnswer.trim().isEmpty
                  ? question.explanation
                  : question.expectedAnswer,
            ),
          );
        if (question.explanation.trim().isNotEmpty) {
          buffer
            ..writeln('<div class="field-label">Teacher Guidance</div>')
            ..writeln(_buildManagementRichTextHtml(question.explanation));
        }
        buffer.writeln('</div>');
        buffer.writeln('</article>');
        continue;
      }

      buffer
        ..writeln('<div class="field-label">Options</div>')
        ..writeln('<ul class="option-list">');
      for (final optionEntry in question.options.asMap().entries) {
        final optionIndex = optionEntry.key;
        final optionLabel = optionLabels[optionIndex];
        final isCorrect = question.correctIndex == optionIndex;
        buffer.writeln(
          '<li class="option-row ${isCorrect ? 'correct-option' : ''}"><span class="option-badge">$optionLabel</span><span>${_escapeManagementHtml(optionEntry.value)}</span></li>',
        );
      }
      buffer.writeln('</ul>');

      final normalizedCorrectIndex = question.correctIndex.clamp(0, 3);
      final correctLabel = optionLabels[normalizedCorrectIndex];
      final correctAnswer = question.options.length > normalizedCorrectIndex
          ? question.options[normalizedCorrectIndex]
          : '';
      buffer
        ..writeln('<div class="answer-card">')
        ..writeln(
          '<p class="answer-inline"><strong>Correct Answer:</strong> ${_escapeManagementHtml('$correctLabel) $correctAnswer')}</p>',
        );
      if (question.explanation.trim().isNotEmpty) {
        buffer
          ..writeln('<div class="field-label">Explanation</div>')
          ..writeln(_buildManagementRichTextHtml(question.explanation));
      }
      buffer.writeln('</div>');
      buffer.writeln('</article>');
    }

    buffer.writeln('</section>');
    return buffer.toString();
  }

  String _buildManagementTeacherCopyEssayHtml(ResultHistoryItem mission) {
    final draft = mission.essayBuilderDraft;
    if (draft == null) {
      return '<section class="section-card"><h2>Essay Builder</h2><p class="section-kicker">Essay builder draft is missing for this mission.</p></section>';
    }

    final buffer = StringBuffer()
      ..writeln('<section class="section-card">')
      ..writeln('<h2>Essay Builder</h2>')
      ..writeln(
        '<p class="section-kicker">Teacher-ready essay builder copy with full blank options and answer keys.</p>',
      )
      ..writeln('<div class="pill-row">')
      ..writeln(
        '<span class="soft-pill">Mode: ${_escapeManagementHtml(draft.mode)}</span>',
      )
      ..writeln(
        '<span class="soft-pill">Target Words: ${_escapeManagementHtml('${draft.targets.targetWordMin}-${draft.targets.targetWordMax}')}</span>',
      )
      ..writeln(
        '<span class="soft-pill">Target Sentences: ${_escapeManagementHtml('${draft.targets.targetSentenceCount}')}</span>',
      )
      ..writeln(
        '<span class="soft-pill">Target Blanks: ${_escapeManagementHtml('${draft.targets.targetBlankCount}')}</span>',
      )
      ..writeln('</div>');

    for (final entry in draft.sentences.asMap().entries) {
      final sentence = entry.value;
      final blankParts = sentence.parts
          .where((part) => part.isBlank)
          .toList(growable: false);
      buffer
        ..writeln('<article class="question-card">')
        ..writeln('<div class="question-top">')
        ..writeln(
          '<span class="question-pill">Sentence ${entry.key + 1}</span><span class="copy-pill">Teacher Copy</span>',
        )
        ..writeln('</div>')
        ..writeln(
          '<h3 class="sentence-role">${_escapeManagementHtml(sentence.role)}</h3>',
        );

      if (sentence.learnFirst.bullets.isNotEmpty) {
        buffer
          ..writeln('<div class="field-label">Learn First</div>')
          ..writeln('<ul class="bullet-list">');
        for (final bullet in sentence.learnFirst.bullets) {
          final trimmedBullet = bullet.trim();
          if (trimmedBullet.isEmpty) {
            continue;
          }
          buffer.writeln('<li>${_escapeManagementHtml(trimmedBullet)}</li>');
        }
        buffer.writeln('</ul>');
      }

      buffer
        ..writeln('<div class="field-label">Sentence Preview</div>')
        ..writeln(
          '<p class="sentence-preview">${_escapeManagementHtml(_managementSentencePreviewText(sentence))}</p>',
        );

      for (final blankEntry in blankParts.asMap().entries) {
        final blank = blankEntry.value;
        buffer
          ..writeln('<div class="blank-card">')
          ..writeln(
            '<div class="blank-head">Blank ${blankEntry.key + 1}</div>',
          );
        if (blank.hint.trim().isNotEmpty) {
          buffer.writeln(
            '<p class="blank-hint">${_escapeManagementHtml(blank.hint.trim())}</p>',
          );
        }
        buffer.writeln('<ul class="option-list">');
        for (final label in const ['A', 'B', 'C', 'D']) {
          final isCorrect = blank.correctOption == label;
          buffer.writeln(
            '<li class="option-row ${isCorrect ? 'correct-option' : ''}"><span class="option-badge">$label</span><span>${_escapeManagementHtml(blank.options[label] ?? '')}</span></li>',
          );
        }
        buffer
          ..writeln('</ul>')
          ..writeln(
            '<p class="answer-inline"><strong>Correct Answer:</strong> ${_escapeManagementHtml('${blank.correctOption}) ${blank.options[blank.correctOption] ?? ''}')}</p>',
          )
          ..writeln('</div>');
      }

      buffer.writeln('</article>');
    }

    buffer.writeln('</section>');
    return buffer.toString();
  }

  String _buildManagementResultCardHtml(_ManagementResultExportRow row) {
    final mission = row.mission;
    final resultPackage = row.resultPackage;
    final meta = resultPackage.meta;
    final taskCodes = meta.taskCodes.isEmpty
        ? 'None'
        : meta.taskCodes.join(', ');
    final scoreLabel = meta.scoreTotal > 0
        ? '${meta.scoreCorrect}/${meta.scoreTotal} (${meta.scorePercent}%)'
        : meta.scorePercent > 0
        ? '${meta.scorePercent}%'
        : 'Pending review';

    final buffer = StringBuffer()
      ..writeln('<article class="result-card">')
      ..writeln('<div class="result-header">')
      ..writeln('<div>')
      ..writeln('<h4>${_escapeManagementHtml(meta.missionTitle)}</h4>')
      ..writeln(
        '<p class="result-subtitle">${_escapeManagementHtml(_managementFormatLabel(mission))} · ${_escapeManagementHtml(mission.sessionType.toUpperCase())}</p>',
      )
      ..writeln('</div>')
      ..writeln(
        '<span class="result-pill">${_escapeManagementHtml(scoreLabel)} · ${meta.xpAwarded}/${mission.xpReward} XP</span>',
      )
      ..writeln('</div>')
      ..writeln('<div class="meta-grid compact">')
      ..writeln(
        _buildManagementMetaCardHtml(
          label: 'Assigned date',
          value: meta.assignedDate,
        ),
      )
      ..writeln(
        _buildManagementMetaCardHtml(
          label: 'Submitted',
          value: _formatManagementMissionDate(meta.submitTime),
        ),
      )
      ..writeln(
        _buildManagementMetaCardHtml(
          label: 'Duration',
          value: '${meta.durationSeconds}s',
        ),
      )
      ..writeln(
        _buildManagementMetaCardHtml(label: 'Task focus', value: taskCodes),
      )
      ..writeln('</div>')
      ..writeln(_buildManagementEvidenceHtml(row))
      ..writeln('</article>');

    return buffer.toString();
  }

  String _buildManagementEvidenceHtml(_ManagementResultExportRow row) {
    final evidence = row.resultPackage.evidence;
    final format = (evidence['format'] ?? row.mission.draftFormat).toString();
    if (format == 'THEORY') {
      return _buildManagementTheoryEvidenceHtml(row.resultPackage);
    }
    if (format == 'ESSAY_BUILDER') {
      return _buildManagementEssayEvidenceHtml(row.resultPackage);
    }
    return _buildManagementQuestionEvidenceHtml(row.resultPackage);
  }

  String _buildManagementQuestionEvidenceHtml(ResultPackageData resultPackage) {
    final questions =
        resultPackage.evidence['questions'] as List<dynamic>? ?? const [];
    if (questions.isEmpty) {
      return '<p class="empty-copy">No question evidence saved.</p>';
    }

    final buffer = StringBuffer()
      ..writeln('<section class="evidence-block"><h5>Question evidence</h5>');
    for (final entry in questions.asMap().entries) {
      final question = (entry.value as Map<dynamic, dynamic>)
          .cast<String, dynamic>();
      final correct = question['correctness'] == true;
      final prompt = (question['questionText'] ?? '').toString();
      final selectedLetter = (question['selectedOptionLetter'] ?? '')
          .toString()
          .trim();
      final selectedAnswer = (question['selectedAnswer'] ?? '')
          .toString()
          .trim();
      final correctLetter = (question['correctOptionLetter'] ?? '')
          .toString()
          .trim();
      final correctAnswer = (question['correctAnswer'] ?? '').toString().trim();
      final options =
          (question['options'] as Map<dynamic, dynamic>? ?? const {})
              .cast<dynamic, dynamic>();
      buffer
        ..writeln(
          '<div class="question-card ${correct ? 'success' : 'support'}">',
        )
        ..writeln('<h6>Question ${entry.key + 1}</h6>')
        ..writeln('<p>${_escapeManagementHtml(prompt)}</p>')
        ..writeln(
          _buildManagementQuestionOptionsHtml(
            options: options,
            selectedLetter: selectedLetter,
            correctLetter: correctLetter,
          ),
        )
        ..writeln(
          '<p><strong>Selected:</strong> ${_escapeManagementHtml('${selectedLetter.isEmpty ? '' : '$selectedLetter) '}${selectedAnswer.isEmpty ? 'No selection recorded' : selectedAnswer}')}</p>',
        )
        ..writeln(
          '<p><strong>Correct:</strong> ${_escapeManagementHtml('${correctLetter.isEmpty ? '' : '$correctLetter) '}$correctAnswer')}</p>',
        )
        ..writeln('</div>');
    }
    buffer.writeln('</section>');
    return buffer.toString();
  }

  String _buildManagementTheoryEvidenceHtml(ResultPackageData resultPackage) {
    final questions =
        resultPackage.evidence['questions'] as List<dynamic>? ?? const [];
    if (questions.isEmpty) {
      return '<p class="empty-copy">No theory evidence saved.</p>';
    }

    final buffer = StringBuffer()
      ..writeln('<section class="evidence-block"><h5>Theory evidence</h5>');
    for (final entry in questions.asMap().entries) {
      final question = (entry.value as Map<dynamic, dynamic>)
          .cast<String, dynamic>();
      final learnFirst = (question['learnFirst'] ?? '').toString().trim();
      final expectedAnswer = (question['expectedAnswer'] ?? '')
          .toString()
          .trim();
      final studentAnswer = (question['studentAnswer'] ?? '').toString().trim();
      final teacherFeedback = (question['teacherFeedback'] ?? '')
          .toString()
          .trim();
      final teacherScore = question['teacherScorePercent']?.toString() ?? '';
      buffer
        ..writeln('<div class="question-card theory">')
        ..writeln('<h6>Theory ${entry.key + 1}</h6>')
        ..writeln(
          '<p>${_escapeManagementHtml((question['questionText'] ?? '').toString())}</p>',
        );
      if (learnFirst.isNotEmpty) {
        buffer.writeln(
          '<p><strong>Learn First:</strong> ${_escapeManagementHtml(learnFirst)}</p>',
        );
      }
      if (expectedAnswer.isNotEmpty) {
        buffer.writeln(
          '<p><strong>Expected answer:</strong> ${_escapeManagementHtml(expectedAnswer)}</p>',
        );
      }
      buffer.writeln(
        '<p><strong>Student answer:</strong> ${_escapeManagementHtml(studentAnswer.isEmpty ? 'No written answer recorded.' : studentAnswer)}</p>',
      );
      if (teacherScore.isNotEmpty) {
        buffer.writeln(
          '<p><strong>Teacher score:</strong> ${_escapeManagementHtml('$teacherScore/100')}</p>',
        );
      }
      if (teacherFeedback.isNotEmpty) {
        buffer.writeln(
          '<p><strong>Teacher feedback:</strong> ${_escapeManagementHtml(teacherFeedback)}</p>',
        );
      }
      buffer.writeln('</div>');
    }
    buffer.writeln('</section>');
    return buffer.toString();
  }

  String _buildManagementEssayEvidenceHtml(ResultPackageData resultPackage) {
    final perSentence =
        resultPackage.evidence['perSentence'] as List<dynamic>? ?? const [];
    final finalEssayText = (resultPackage.evidence['finalEssayText'] ?? '')
        .toString()
        .trim();
    final buffer = StringBuffer()
      ..writeln('<section class="evidence-block"><h5>Essay evidence</h5>');
    for (final entry in perSentence.asMap().entries) {
      final sentence = (entry.value as Map<dynamic, dynamic>)
          .cast<String, dynamic>();
      final role = (sentence['role'] ?? 'detail').toString();
      final bullets =
          sentence['learnFirstBullets'] as List<dynamic>? ?? const [];
      final blankSelections =
          sentence['blankSelections'] as List<dynamic>? ?? const [];
      buffer
        ..writeln('<div class="question-card essay">')
        ..writeln(
          '<h6>Sentence ${entry.key + 1} · ${_escapeManagementHtml(role)}</h6>',
        );
      if (bullets.isNotEmpty) {
        buffer.writeln('<ul>');
        for (final bullet in bullets) {
          final bulletText = bullet.toString().trim();
          if (bulletText.isEmpty) {
            continue;
          }
          buffer.writeln('<li>${_escapeManagementHtml(bulletText)}</li>');
        }
        buffer.writeln('</ul>');
      }
      for (final blank in blankSelections) {
        final item = (blank as Map<dynamic, dynamic>).cast<String, dynamic>();
        final hint = (item['hint'] ?? '').toString().trim();
        final chosen = (item['chosenOptionText'] ?? '').toString().trim();
        final correct = (item['correctOptionText'] ?? '').toString().trim();
        buffer.writeln(
          '<p><strong>${_escapeManagementHtml(hint.isEmpty ? 'Blank' : hint)}:</strong> ${_escapeManagementHtml(chosen.isEmpty ? 'No selection recorded' : chosen)}${correct.isEmpty ? '' : ' <span class="muted">(Correct: ${_escapeManagementHtml(correct)})</span>'}</p>',
        );
      }
      buffer.writeln('</div>');
    }
    if (finalEssayText.isNotEmpty) {
      buffer
        ..writeln('<div class="question-card essay">')
        ..writeln('<h6>Final essay</h6>')
        ..writeln('<p>${_escapeManagementHtml(finalEssayText)}</p>')
        ..writeln('</div>');
    }
    buffer.writeln('</section>');
    return buffer.toString();
  }

  String _buildManagementQuestionOptionsHtml({
    required Map<dynamic, dynamic> options,
    required String selectedLetter,
    required String correctLetter,
  }) {
    if (options.isEmpty) {
      return '<p class="empty-copy">No option set was saved for this question.</p>';
    }

    final orderedEntries = options.entries.toList(growable: false)
      ..sort(
        (left, right) => left.key.toString().compareTo(right.key.toString()),
      );

    final buffer = StringBuffer()..writeln('<ul class="option-list">');
    for (final entry in orderedEntries) {
      final label = entry.key.toString().trim().toUpperCase();
      final value = entry.value.toString().trim();
      final isSelected = label == selectedLetter;
      final isCorrect = label == correctLetter;
      final classNames = [
        'option-row',
        if (isSelected) 'selected-option',
        if (isCorrect) 'correct-option',
      ].join(' ');

      buffer
        ..writeln('<li class="$classNames">')
        ..writeln(
          '<span class="option-badge">${_escapeManagementHtml(label)}</span>',
        )
        ..writeln(
          '<div class="option-copy"><span>${_escapeManagementHtml(value.isEmpty ? 'No option text saved.' : value)}</span>',
        );
      if (isSelected || isCorrect) {
        buffer.writeln('<div class="option-tags">');
        if (isSelected) {
          buffer.writeln('<span class="option-tag">Selected</span>');
        }
        if (isCorrect) {
          buffer.writeln('<span class="option-tag success">Correct</span>');
        }
        buffer.writeln('</div>');
      }
      buffer
        ..writeln('</div>')
        ..writeln('</li>');
    }
    buffer.writeln('</ul>');
    return buffer.toString();
  }

  String _buildManagementRichTextHtml(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return '<p class="empty-copy">No additional guidance saved.</p>';
    }

    final paragraphs = normalized
        .split(RegExp(r'\n\s*\n'))
        .map((paragraph) => paragraph.trim())
        .where((paragraph) => paragraph.isNotEmpty)
        .toList(growable: false);
    if (paragraphs.isEmpty) {
      return '<p class="empty-copy">No additional guidance saved.</p>';
    }

    return paragraphs
        .map(
          (paragraph) =>
              '<p>${_escapeManagementHtml(paragraph).replaceAll('\n', '<br />')}</p>',
        )
        .join();
  }

  String _managementSentencePreviewText(EssayBuilderSentence sentence) {
    return sentence.parts
        .map((part) => part.isBlank ? '____' : part.value)
        .join();
  }

  String _resultDateForExport(_ManagementResultExportRow row) {
    final assignedDate = row.resultPackage.meta.assignedDate.trim();
    if (assignedDate.isNotEmpty) {
      return assignedDate;
    }
    return _resultDateKeyForMission(row.mission);
  }

  String _subjectNameForExport(_ManagementResultExportRow row) {
    final subjectName = row.resultPackage.meta.subject.trim();
    if (subjectName.isNotEmpty) {
      return subjectName;
    }
    return (row.mission.subject?.name ?? 'No subject').trim();
  }

  String _managementFormatLabel(ResultHistoryItem mission) {
    if (mission.isPaperAssessment) {
      return 'Paper Assessment';
    }
    if (mission.draftFormat == 'THEORY') {
      return 'Theory';
    }
    if (mission.draftFormat == 'ESSAY_BUILDER') {
      return 'Essay Builder';
    }
    return mission.questionCount >= 10 ? 'Assessment' : 'Objective Mission';
  }

  String _buildManagementMetaCardHtml({
    required String label,
    required String value,
  }) {
    return '<div class="meta-card"><span class="meta-label">${_escapeManagementHtml(label)}</span><strong class="meta-value">${_escapeManagementHtml(value)}</strong></div>';
  }

  String _managementTargetTypeLabel(TargetSummary target) {
    switch (target.targetType.trim()) {
      case 'fixed_daily_mission':
        return 'Fixed Daily Mission';
      case 'fixed_assessment':
        return 'Fixed Assessment';
      default:
        return 'Custom';
    }
  }

  String _managementTargetStatusLabel(TargetSummary target) {
    return _managementTitleCase(target.status.replaceAll('_', ' '));
  }

  String _managementTargetCommentLabel(TargetSummary target) {
    final createdByRole = target.createdByRole.trim().toLowerCase();
    if (createdByRole == 'mentor') {
      return 'Learning mentor comment';
    }
    if (createdByRole == 'teacher') {
      return 'Teacher target note';
    }
    if (target.isFixedTarget) {
      return 'Target detail';
    }
    return 'Support note';
  }

  String _buildManagementTargetTeacherCommentHtml(
    _ManagementResolvedTargetComment comment,
  ) {
    final subjectName = comment.subjectName.trim().isEmpty
        ? 'Subject teacher'
        : comment.subjectName.trim();
    final sessionType = comment.sessionType.trim().isEmpty
        ? 'Session'
        : _managementSessionTypeLabel(comment.sessionType);
    final authorName = comment.authorName.trim().isNotEmpty
        ? comment.authorName.trim()
        : comment.teacherName.trim();
    final plannedTeacherName = comment.plannedTeacherName.trim();
    final conductedByName = comment.conductedByName.trim();
    final savedAtLabel = _formatManagementAuditDateTime(
      comment.updatedAt ?? comment.createdAt,
    );
    final pendingClass = comment.isPending ? ' pending' : '';

    final buffer = StringBuffer()
      ..writeln('<div class="teacher-comment$pendingClass">')
      ..writeln('<div class="teacher-comment-meta">')
      ..writeln('<strong>${_escapeManagementHtml(subjectName)}</strong>')
      ..writeln(
        '<span class="copy-chip">${_escapeManagementHtml(sessionType)}</span>',
      );
    if (authorName.isNotEmpty) {
      buffer.writeln(
        '<span class="result-pill">${_escapeManagementHtml('Author: $authorName')}</span>',
      );
    }
    if (plannedTeacherName.isNotEmpty) {
      buffer.writeln(
        '<span class="result-pill">${_escapeManagementHtml('Planned: $plannedTeacherName')}</span>',
      );
    }
    if (conductedByName.isNotEmpty) {
      buffer.writeln(
        '<span class="result-pill">${_escapeManagementHtml('Taught by: $conductedByName')}</span>',
      );
    }
    if (savedAtLabel.isNotEmpty) {
      buffer.writeln(
        '<span class="result-pill">${_escapeManagementHtml('Saved: $savedAtLabel')}</span>',
      );
    }
    buffer
      ..writeln('</div>')
      ..writeln('<p>${_escapeManagementHtml(comment.comment)}</p>')
      ..writeln('</div>');
    return buffer.toString();
  }

  String _formatManagementAuditDateTime(String? rawValue) {
    final parsed = rawValue == null
        ? null
        : DateTime.tryParse(rawValue)?.toLocal();
    if (parsed == null) {
      return '';
    }
    final month = parsed.month.toString().padLeft(2, '0');
    final day = parsed.day.toString().padLeft(2, '0');
    final hour = parsed.hour.toString().padLeft(2, '0');
    final minute = parsed.minute.toString().padLeft(2, '0');
    return '${parsed.year}-$month-$day $hour:$minute';
  }

  String _managementSessionTypeLabel(String value) {
    switch (value.trim().toLowerCase()) {
      case 'morning':
        return 'Morning session';
      case 'afternoon':
        return 'Afternoon session';
      default:
        return _managementTitleCase(value);
    }
  }

  String _managementTitleCase(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 'Not set';
    }

    return trimmed
        .split(RegExp(r'\s+'))
        .map((word) {
          if (word.isEmpty) {
            return word;
          }
          return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
        })
        .join(' ');
  }

  String _buildManagementResultsStyles() {
    return '''
      :root {
        color-scheme: light;
        --ink: #20304b;
        --muted: #5c6f8f;
        --line: #d7e3f7;
        --sky: #eef6ff;
        --sun: #fff4de;
        --panel: #ffffff;
        --mint: #eaf9ef;
      }
      * { box-sizing: border-box; }
      body {
        margin: 0;
        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
        background: linear-gradient(180deg, #f4f9ff 0%, #eef5ff 100%);
        color: var(--ink);
      }
      .page {
        width: min(1120px, calc(100% - 32px));
        margin: 24px auto 48px;
      }
      .hero, .date-group, .subject-group, .result-card {
        border-radius: 24px;
      }
      .hero {
        background: linear-gradient(135deg, #ffffff 0%, #eaf4ff 100%);
        border: 1px solid var(--line);
        padding: 24px;
        margin-bottom: 20px;
      }
      .copy-chip, .result-pill {
        display: inline-flex;
        align-items: center;
        border-radius: 999px;
        padding: 8px 14px;
        font-size: 12px;
        font-weight: 700;
      }
      .copy-chip {
        background: #dfeeff;
        color: #27528f;
      }
      .hero h1, .date-group h2, .subject-group h3, .result-card h4, .question-card h6 {
        margin: 0;
      }
      .hero-summary, .result-subtitle, .muted, .empty-copy {
        color: var(--muted);
      }
      .meta-grid {
        display: grid;
        grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
        gap: 12px;
        margin-top: 16px;
      }
      .meta-grid.compact {
        margin-top: 12px;
      }
      .meta-card {
        background: rgba(255, 255, 255, 0.9);
        border: 1px solid var(--line);
        border-radius: 18px;
        padding: 14px;
      }
      .meta-label {
        display: block;
        font-size: 12px;
        color: var(--muted);
        text-transform: uppercase;
        letter-spacing: 0.08em;
        margin-bottom: 6px;
      }
      .meta-value {
        font-size: 15px;
      }
      .date-group {
        margin-bottom: 18px;
        padding: 20px;
        background: rgba(255, 255, 255, 0.78);
        border: 1px solid var(--line);
      }
      .subject-group {
        margin-top: 16px;
        padding: 16px;
        background: var(--sky);
        border: 1px solid var(--line);
      }
      .result-card {
        background: var(--panel);
        border: 1px solid var(--line);
        padding: 18px;
        margin-top: 14px;
      }
      .result-header {
        display: flex;
        justify-content: space-between;
        gap: 12px;
        align-items: flex-start;
      }
      .result-pill {
        background: var(--sun);
        color: #845400;
      }
      .teacher-comment {
        margin-top: 12px;
        padding: 12px 14px;
        border-radius: 18px;
        border: 1px solid var(--line);
        background: rgba(223, 238, 255, 0.42);
      }
      .teacher-comment.pending {
        background: rgba(255, 244, 209, 0.6);
      }
      .teacher-comment-meta {
        display: flex;
        flex-wrap: wrap;
        gap: 8px;
        align-items: center;
        margin-bottom: 8px;
      }
      .teacher-comment p {
        margin: 0;
      }
      .evidence-block {
        margin-top: 16px;
      }
      .question-card {
        background: #fdfefe;
        border: 1px solid var(--line);
        border-radius: 18px;
        padding: 14px;
        margin-top: 12px;
      }
      .option-list,
      .bullet-list {
        list-style: none;
        padding: 0;
        margin: 12px 0;
      }
      .option-row,
      .blank-card {
        border: 1px solid var(--line);
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
      .option-row.selected-option {
        border-color: #9cbcff;
        box-shadow: 0 0 0 1px rgba(72, 125, 224, 0.15);
      }
      .option-row.correct-option {
        background: var(--mint);
        border-color: #cde3d4;
      }
      .option-badge,
      .option-tag {
        display: inline-flex;
        align-items: center;
        justify-content: center;
        border-radius: 999px;
        font-size: 12px;
        font-weight: 700;
      }
      .option-badge {
        min-width: 28px;
        padding: 6px 9px;
        background: #e6eefc;
        color: #32558f;
      }
      .option-copy {
        display: flex;
        flex: 1;
        gap: 8px;
        justify-content: space-between;
        align-items: flex-start;
      }
      .option-tags {
        display: flex;
        flex-wrap: wrap;
        gap: 6px;
      }
      .option-tag {
        padding: 5px 9px;
        background: #eef4ff;
        color: #315489;
      }
      .option-tag.success {
        background: #dff4e7;
        color: #2d7250;
      }
      .question-card.success { background: var(--mint); }
      .question-card.support { background: #fff8ec; }
      .question-card.theory { background: #f8fbff; }
      .question-card.essay { background: #fffdf6; }
      h5 {
        margin: 0 0 8px;
        font-size: 18px;
      }
      h6 {
        font-size: 16px;
        margin-bottom: 8px;
      }
      p, li {
        line-height: 1.55;
      }
      @media (max-width: 720px) {
        .page { width: calc(100% - 20px); }
        .hero, .date-group, .subject-group, .result-card { padding: 16px; }
        .result-header { flex-direction: column; }
      }
    ''';
  }

  String _buildManagementTeacherCopyStyles() {
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
      .blank-hint,
      .empty-copy {
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
      .soft-pill {
        padding: 7px 12px;
        background: #eef3ff;
        color: #425a8e;
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
        background: #ecf8ef;
        border-color: #d5ead8;
      }
      .option-badge {
        width: 30px;
        min-width: 30px;
        height: 30px;
        justify-content: center;
        background: #e6eefc;
        color: #355487;
      }
      .answer-card,
      .blank-card {
        margin-top: 14px;
        padding: 16px;
        background: #f7fbff;
      }
      .blank-head,
      .sentence-role {
        font-weight: 800;
        color: #253753;
      }
      .footer-card {
        margin-bottom: 0;
      }
      @media (max-width: 720px) {
        .page {
          padding: 20px 14px 32px;
        }
        .hero,
        .section-card,
        .question-card {
          padding: 18px;
        }
      }
    ''';
  }

  String _escapeManagementHtml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  String _sanitizeManagementFileName(String value) {
    final trimmed = value.trim().toLowerCase();
    if (trimmed.isEmpty) {
      return 'results';
    }
    return trimmed
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
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
  final Map<String, ResultHistoryItem> missionByResultPackageId;
  final ValueChanged<ResultHistoryItem> onOpenResult;

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
    required this.targetDateKeys,
    required this.targetDateSections,
    required this.certifications,
    required this.certificationSubjects,
    required this.teachers,
    required this.archivedStudents,
  });

  final MentorWorkspaceData workspace;
  final List<ResultHistoryItem> recentResults;
  final List<String> targetDateKeys;
  final List<ManagementTargetDateSection> targetDateSections;
  final List<SubjectCertificationSummary> certifications;
  final List<SubjectCertificationSettings> certificationSubjects;
  final List<TeacherSummary> teachers;
  final List<StudentSummary> archivedStudents;
}

class _ManagementResolvedTargetComment {
  const _ManagementResolvedTargetComment({
    required this.subjectName,
    required this.sessionType,
    required this.teacherName,
    required this.authorName,
    required this.plannedTeacherName,
    required this.conductedByName,
    required this.comment,
    required this.isPending,
    this.createdAt,
    this.updatedAt,
  });

  final String subjectName;
  final String sessionType;
  final String teacherName;
  final String authorName;
  final String plannedTeacherName;
  final String conductedByName;
  final String comment;
  final bool isPending;
  final String? createdAt;
  final String? updatedAt;
}

class _ManagementTargetCommentResolution {
  const _ManagementTargetCommentResolution({
    required this.comments,
    required this.matchedCommentKeys,
  });

  final List<_ManagementResolvedTargetComment> comments;
  final List<String> matchedCommentKeys;
}

class _ManagementResultExportRow {
  const _ManagementResultExportRow({
    required this.mission,
    required this.resultPackage,
  });

  final ResultHistoryItem mission;
  final ResultPackageData resultPackage;
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${student.name} · ${student.xp} XP · ${student.streak} day streak',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                if (student.yearGroup.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    student.yearGroup.trim(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppPalette.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
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
                            [
                              student.name,
                              '${student.xp} XP',
                              if (student.yearGroup.trim().isNotEmpty)
                                student.yearGroup.trim(),
                            ].join(' · '),
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

class _ArchivedStudentSheet extends StatelessWidget {
  const _ArchivedStudentSheet({required this.students});

  final List<StudentSummary> students;

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
              'Archived Students',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.compact),
            Text(
              'Restore an archived student to bring them back into the active management and timetable flow.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppPalette.textMuted),
            ),
            const SizedBox(height: AppSpacing.item),
            if (students.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.item),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Text(
                  'No archived students are waiting to be restored.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              )
            else
              ...students.map(
                (student) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Ink(
                    padding: const EdgeInsets.all(AppSpacing.item),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.78),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      border: Border.all(color: Colors.white),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.archive_outlined,
                          color: AppPalette.textMuted,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            [
                              student.name,
                              if (student.yearGroup.trim().isNotEmpty)
                                student.yearGroup.trim(),
                            ].join(' · '),
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: () => Navigator.of(context).pop(student),
                          icon: const Icon(Icons.unarchive_rounded),
                          label: const Text('Unarchive'),
                        ),
                      ],
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

class _ManagementExpandableHeader extends StatelessWidget {
  const _ManagementExpandableHeader({
    required this.title,
    required this.subtitle,
    required this.summary,
    required this.isExpanded,
    required this.onToggle,
  });

  final String title;
  final String subtitle;
  final String summary;
  final bool isExpanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final toggleLabel = isExpanded ? 'Hide' : 'Show';
    final toggleAffordance = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isExpanded
            ? AppPalette.primaryBlue.withValues(alpha: 0.14)
            : AppPalette.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isExpanded
              ? AppPalette.primaryBlue.withValues(alpha: 0.32)
              : AppPalette.sky.withValues(alpha: 0.7),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isExpanded
                ? Icons.keyboard_arrow_up_rounded
                : Icons.keyboard_arrow_down_rounded,
            size: 18,
            color: AppPalette.navy,
          ),
          const SizedBox(width: 6),
          Text(
            toggleLabel,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppPalette.navy,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 840;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (stacked) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        toggleAffordance,
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppPalette.textMuted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _ManagementSectionSummary(summary: summary),
                  ] else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                subtitle,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: AppPalette.textMuted),
                              ),
                              const SizedBox(height: 10),
                              _ManagementSectionSummary(summary: summary),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        toggleAffordance,
                      ],
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ManagementSectionSummary extends StatelessWidget {
  const _ManagementSectionSummary({required this.summary});

  final String summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppPalette.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppPalette.sky.withValues(alpha: 0.68)),
      ),
      child: Text(
        summary,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: AppPalette.navy),
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
    final borderRadius = BorderRadius.circular(999);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            // WHY: the selected state must stay visibly filled on pale panels.
            color: selected ? AppPalette.navy : AppPalette.surface,
            borderRadius: borderRadius,
            border: Border.all(
              color: selected
                  ? AppPalette.navy
                  : AppPalette.sky.withValues(alpha: 0.82),
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppPalette.shadow.withValues(alpha: 0.18),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: selected ? Colors.white : AppPalette.navy,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
            ),
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
    this.compact = false,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Ink(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 16,
          vertical: compact ? 10 : 14,
        ),
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
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: compact ? 16 : 18,
              color: selected ? AppPalette.orange : AppPalette.textMuted,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style:
                  (compact
                          ? Theme.of(context).textTheme.labelLarge
                          : Theme.of(context).textTheme.bodyMedium)
                      ?.copyWith(
                        color: AppPalette.navy,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
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
    required this.hasExistingEntry,
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
  final bool hasExistingEntry;
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
            hasExistingEntry
                ? 'Update teacher, subject, and room'
                : 'Add teacher, subject, and room',
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
            hasExistingEntry
                ? 'Click any weekday card below to update that saved timetable entry here in the panel.'
                : 'Click a weekday card below, then use these controls here in the timetable panel. No popup is needed.',
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
              decoration: _managementFieldDecoration(
                labelText: 'Morning subject',
              ),
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
              decoration: _managementFieldDecoration(
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
                          ? '${teacher.name} · ${_teacherSubjectSummaryLabel(teacher)}'
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
              decoration: _managementFieldDecoration(
                labelText: 'Afternoon subject',
              ),
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
              decoration: _managementFieldDecoration(
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
                          ? '${teacher.name} · ${_teacherSubjectSummaryLabel(teacher)}'
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
              decoration: _managementFieldDecoration(labelText: 'Morning room'),
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
              decoration: _managementFieldDecoration(
                labelText: 'Afternoon room',
              ),
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
                      : '${hasExistingEntry ? 'Update' : 'Save'} ${_weekdayLabelForDate(selectedDate)} timetable',
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

class _ManagementTargetCard extends StatelessWidget {
  const _ManagementTargetCard({
    required this.target,
    required this.teacherComments,
    required this.onDownload,
    this.isDownloading = false,
  });

  final TargetSummary target;
  final List<_ManagementResolvedTargetComment> teacherComments;
  final VoidCallback? onDownload;
  final bool isDownloading;

  String _formatAuditDateTime(String? rawValue) {
    final parsed = rawValue == null
        ? null
        : DateTime.tryParse(rawValue)?.toLocal();
    if (parsed == null) {
      return '';
    }
    final month = parsed.month.toString().padLeft(2, '0');
    final day = parsed.day.toString().padLeft(2, '0');
    final hour = parsed.hour.toString().padLeft(2, '0');
    final minute = parsed.minute.toString().padLeft(2, '0');
    return '${parsed.year}-$month-$day $hour:$minute';
  }

  String _targetTypeLabel() {
    switch (target.targetType.trim()) {
      case 'fixed_daily_mission':
        return 'Fixed daily mission';
      case 'fixed_assessment':
        return 'Fixed assessment';
      default:
        return 'Custom';
    }
  }

  String _statusLabel() {
    final normalized = target.status.replaceAll('_', ' ').trim();
    if (normalized.isEmpty) {
      return 'Not set';
    }
    return normalized
        .split(RegExp(r'\s+'))
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  String _commentLabel() {
    final createdByRole = target.createdByRole.trim().toLowerCase();
    if (createdByRole == 'mentor') {
      return 'Learning mentor comment';
    }
    if (createdByRole == 'teacher') {
      return 'Teacher target note';
    }
    if (target.isFixedTarget) {
      return 'Target detail';
    }
    return 'Support note';
  }

  @override
  Widget build(BuildContext context) {
    final description = target.description.trim();
    final difficulty = target.difficulty.trim().isEmpty
        ? 'Not set'
        : '${target.difficulty[0].toUpperCase()}${target.difficulty.substring(1).toLowerCase()}';
    final subjectName = target.subjectName.trim();
    final sessionType = target.sessionType.trim().toLowerCase();
    final savedAtLabel = _formatAuditDateTime(
      target.updatedAt ?? target.createdAt,
    );
    final createdByLabel = target.createdByName.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.item),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppPalette.sky.withValues(alpha: 0.52)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            target.title.trim().isEmpty
                ? 'Untitled target'
                : target.title.trim(),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ManagementMiniPill(
                label: _targetTypeLabel(),
                backgroundColor: AppPalette.sky.withValues(alpha: 0.2),
              ),
              _ManagementMiniPill(
                label: _statusLabel(),
                backgroundColor: AppPalette.sun.withValues(alpha: 0.18),
              ),
              _ManagementMiniPill(
                label: '${target.stars}/3 stars',
                backgroundColor: AppPalette.mint.withValues(alpha: 0.16),
              ),
              _ManagementMiniPill(
                label: '${target.xpAwarded} XP',
                backgroundColor: AppPalette.primaryBlue.withValues(alpha: 0.12),
              ),
              if (subjectName.isNotEmpty)
                _ManagementMiniPill(
                  label: subjectName,
                  backgroundColor: AppPalette.primaryBlue.withValues(
                    alpha: 0.12,
                  ),
                ),
              if (sessionType.isNotEmpty)
                _ManagementMiniPill(
                  label: sessionType == 'afternoon'
                      ? 'Afternoon session'
                      : 'Morning session',
                  backgroundColor: AppPalette.mint.withValues(alpha: 0.18),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            [
              'For ${target.awardDateKey.trim().isEmpty ? 'selected date' : target.awardDateKey.trim()}',
              if (savedAtLabel.isNotEmpty) 'Saved $savedAtLabel',
              if (createdByLabel.isNotEmpty) 'By $createdByLabel',
            ].join(' · '),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppPalette.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              _commentLabel(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppPalette.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppPalette.navy),
            ),
          ],
          if (teacherComments.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              teacherComments.length == 1
                  ? 'Teacher comment'
                  : 'Teacher comments',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppPalette.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            ...teacherComments.map(
              (comment) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ManagementAttachedTeacherCommentCard(comment: comment),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Difficulty · $difficulty',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppPalette.textMuted),
          ),
          const SizedBox(height: AppSpacing.compact),
          Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 220,
              child: OutlinedButton.icon(
                style: _managementOutlinedActionStyle(
                  context,
                  backgroundColor: AppPalette.surface.withValues(alpha: 0.98),
                ),
                onPressed: onDownload,
                icon: Icon(
                  isDownloading
                      ? Icons.hourglass_top_rounded
                      : Icons.download_rounded,
                ),
                label: Text(
                  isDownloading ? 'Preparing...' : 'Download target result',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ManagementAttachedTeacherCommentCard extends StatelessWidget {
  const _ManagementAttachedTeacherCommentCard({required this.comment});

  final _ManagementResolvedTargetComment comment;

  String _sessionLabel() {
    switch (comment.sessionType.trim().toLowerCase()) {
      case 'morning':
        return 'Morning session';
      case 'afternoon':
        return 'Afternoon session';
      default:
        final normalized = comment.sessionType.replaceAll('_', ' ').trim();
        if (normalized.isEmpty) {
          return 'Session';
        }
        return normalized
            .split(RegExp(r'\s+'))
            .map(
              (word) => word.isEmpty
                  ? word
                  : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
            )
            .join(' ');
    }
  }

  String _formatAuditDateTime(String? rawValue) {
    final parsed = rawValue == null
        ? null
        : DateTime.tryParse(rawValue)?.toLocal();
    if (parsed == null) {
      return '';
    }
    final month = parsed.month.toString().padLeft(2, '0');
    final day = parsed.day.toString().padLeft(2, '0');
    final hour = parsed.hour.toString().padLeft(2, '0');
    final minute = parsed.minute.toString().padLeft(2, '0');
    return '${parsed.year}-$month-$day $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final subjectName = comment.subjectName.trim().isEmpty
        ? 'Subject teacher'
        : comment.subjectName.trim();
    final authorName = comment.authorName.trim().isNotEmpty
        ? comment.authorName.trim()
        : comment.teacherName.trim();
    final plannedTeacherName = comment.plannedTeacherName.trim();
    final conductedByName = comment.conductedByName.trim();
    final savedAtLabel = _formatAuditDateTime(
      comment.updatedAt ?? comment.createdAt,
    );
    final backgroundColor = comment.isPending
        ? AppPalette.sun.withValues(alpha: 0.18)
        : AppPalette.sky.withValues(alpha: 0.08);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppPalette.sky.withValues(alpha: 0.48)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                subjectName,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppPalette.navy,
                  fontWeight: FontWeight.w800,
                ),
              ),
              _ManagementMiniPill(
                label: _sessionLabel(),
                backgroundColor: AppPalette.primaryBlue.withValues(alpha: 0.12),
              ),
              if (authorName.isNotEmpty)
                _ManagementMiniPill(
                  label: 'Author: $authorName',
                  backgroundColor: AppPalette.sun.withValues(alpha: 0.16),
                ),
              if (plannedTeacherName.isNotEmpty)
                _ManagementMiniPill(
                  label: 'Planned: $plannedTeacherName',
                  backgroundColor: AppPalette.primaryBlue.withValues(
                    alpha: 0.12,
                  ),
                ),
              if (conductedByName.isNotEmpty)
                _ManagementMiniPill(
                  label: 'Taught by: $conductedByName',
                  backgroundColor: AppPalette.mint.withValues(alpha: 0.18),
                ),
              if (comment.isPending)
                _ManagementMiniPill(
                  label: 'Pending',
                  backgroundColor: AppPalette.mint.withValues(alpha: 0.18),
                ),
            ],
          ),
          if (savedAtLabel.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Saved $savedAtLabel',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppPalette.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            comment.comment.trim(),
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppPalette.navy),
          ),
        ],
      ),
    );
  }
}

class _ManagementTargetSessionCommentCard extends StatelessWidget {
  const _ManagementTargetSessionCommentCard({required this.comment});

  final ManagementTargetSessionComment comment;

  String _sessionLabel() {
    switch (comment.sessionType.trim().toLowerCase()) {
      case 'morning':
        return 'Morning session';
      case 'afternoon':
        return 'Afternoon session';
      default:
        final normalized = comment.sessionType.replaceAll('_', ' ').trim();
        if (normalized.isEmpty) {
          return 'Session';
        }
        return normalized
            .split(RegExp(r'\s+'))
            .map(
              (word) => word.isEmpty
                  ? word
                  : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
            )
            .join(' ');
    }
  }

  String _formatAuditDateTime(String? rawValue) {
    final parsed = rawValue == null
        ? null
        : DateTime.tryParse(rawValue)?.toLocal();
    if (parsed == null) {
      return '';
    }
    final month = parsed.month.toString().padLeft(2, '0');
    final day = parsed.day.toString().padLeft(2, '0');
    final hour = parsed.hour.toString().padLeft(2, '0');
    final minute = parsed.minute.toString().padLeft(2, '0');
    return '${parsed.year}-$month-$day $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final subjectName = comment.subjectName.trim().isEmpty
        ? 'Session'
        : comment.subjectName.trim();
    final authorName = comment.authorName.trim().isNotEmpty
        ? comment.authorName.trim()
        : comment.teacherName.trim();
    final plannedTeacherName = comment.plannedTeacherName.trim();
    final conductedByName = comment.conductedByName.trim();
    final savedAtLabel = _formatAuditDateTime(
      comment.updatedAt ?? comment.createdAt,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.item),
      decoration: BoxDecoration(
        color: AppPalette.sky.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppPalette.sky.withValues(alpha: 0.58)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                subjectName,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppPalette.navy,
                  fontWeight: FontWeight.w800,
                ),
              ),
              _ManagementMiniPill(
                label: _sessionLabel(),
                backgroundColor: AppPalette.primaryBlue.withValues(alpha: 0.12),
              ),
              if (authorName.isNotEmpty)
                _ManagementMiniPill(
                  label: 'Author: $authorName',
                  backgroundColor: AppPalette.sun.withValues(alpha: 0.16),
                ),
              if (plannedTeacherName.isNotEmpty)
                _ManagementMiniPill(
                  label: 'Planned: $plannedTeacherName',
                  backgroundColor: AppPalette.primaryBlue.withValues(
                    alpha: 0.12,
                  ),
                ),
              if (conductedByName.isNotEmpty)
                _ManagementMiniPill(
                  label: 'Taught by: $conductedByName',
                  backgroundColor: AppPalette.mint.withValues(alpha: 0.18),
                ),
            ],
          ),
          if (savedAtLabel.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Saved $savedAtLabel',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppPalette.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            comment.comment.trim(),
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppPalette.navy),
          ),
        ],
      ),
    );
  }
}

class _ManagementMiniPill extends StatelessWidget {
  const _ManagementMiniPill({
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
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: AppPalette.navy),
      ),
    );
  }
}

class _ManagementResultCard extends StatelessWidget {
  const _ManagementResultCard({
    required this.mission,
    required this.downloadsLocked,
    required this.onDownload,
    required this.onDownloadTeacherCopy,
    required this.onView,
    this.isDownloading = false,
    this.isDownloadingTeacherCopy = false,
  });

  final ResultHistoryItem mission;
  final bool downloadsLocked;
  final VoidCallback onDownload;
  final VoidCallback onDownloadTeacherCopy;
  final VoidCallback onView;
  final bool isDownloading;
  final bool isDownloadingTeacherCopy;

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
    final formatLabel = mission.isPaperAssessment
        ? 'Paper assessment'
        : mission.draftFormat == 'ESSAY_BUILDER'
        ? 'Essay Builder'
        : mission.draftFormat == 'THEORY'
        ? 'Theory'
        : '${mission.questionCount} questions';

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
                  color: AppPalette.sky.withValues(alpha: 0.24),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: AppPalette.primaryBlue.withValues(alpha: 0.18),
                  ),
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
            '$formatLabel · ${mission.sessionType} · $dateLabel',
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
          LayoutBuilder(
            builder: (context, constraints) {
              final stackButtons = constraints.maxWidth < 520;
              final actionWidth = stackButtons ? double.infinity : 196.0;
              final viewButton = SizedBox(
                width: actionWidth,
                child: FilledButton.icon(
                  style: _managementFilledActionStyle(context),
                  onPressed: onView,
                  icon: const Icon(Icons.visibility_rounded),
                  label: const Text('View Result'),
                ),
              );
              final downloadButton = SizedBox(
                width: actionWidth,
                child: OutlinedButton.icon(
                  style: _managementOutlinedActionStyle(context),
                  onPressed: hasResultPackage && !downloadsLocked
                      ? onDownload
                      : null,
                  icon: Icon(
                    isDownloading
                        ? Icons.hourglass_top_rounded
                        : Icons.download_rounded,
                  ),
                  label: Text(
                    isDownloading ? 'Preparing...' : 'Download Result',
                  ),
                ),
              );
              final teacherCopyButton = SizedBox(
                width: actionWidth,
                child: OutlinedButton.icon(
                  style: _managementOutlinedActionStyle(
                    context,
                    backgroundColor: AppPalette.sky.withValues(alpha: 0.18),
                    borderColor: AppPalette.primaryBlue.withValues(alpha: 0.34),
                  ),
                  onPressed: downloadsLocked || !mission.hasTeacherCopy
                      ? null
                      : onDownloadTeacherCopy,
                  icon: Icon(
                    isDownloadingTeacherCopy
                        ? Icons.hourglass_top_rounded
                        : Icons.description_rounded,
                  ),
                  label: Text(
                    isDownloadingTeacherCopy ? 'Preparing...' : 'Teacher Copy',
                  ),
                ),
              );

              if (stackButtons) {
                return Column(
                  children: [
                    viewButton,
                    const SizedBox(height: 10),
                    downloadButton,
                    const SizedBox(height: 10),
                    teacherCopyButton,
                  ],
                );
              }

              return Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [viewButton, downloadButton, teacherCopyButton],
              );
            },
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

InputDecoration _managementFieldDecoration({
  required String labelText,
  String? hintText,
  String? helperText,
}) {
  final baseBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
    borderSide: BorderSide(color: AppPalette.sky.withValues(alpha: 0.72)),
  );
  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    helperText: helperText,
    filled: true,
    fillColor: AppPalette.surface.withValues(alpha: 0.96),
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
    border: baseBorder,
    enabledBorder: baseBorder,
    disabledBorder: baseBorder.copyWith(
      borderSide: BorderSide(color: AppPalette.sky.withValues(alpha: 0.42)),
    ),
    focusedBorder: baseBorder.copyWith(
      borderSide: const BorderSide(color: AppPalette.primaryBlue, width: 1.6),
    ),
  );
}

ButtonStyle _managementFilledActionStyle(BuildContext context) {
  return FilledButton.styleFrom(
    minimumSize: const Size(0, 46),
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    backgroundColor: AppPalette.navy,
    foregroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    textStyle: Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
  );
}

ButtonStyle _managementOutlinedActionStyle(
  BuildContext context, {
  Color? backgroundColor,
  Color? borderColor,
  Color? foregroundColor,
}) {
  return OutlinedButton.styleFrom(
    minimumSize: const Size(0, 46),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    backgroundColor:
        backgroundColor ?? AppPalette.surface.withValues(alpha: 0.96),
    foregroundColor: foregroundColor ?? AppPalette.navy,
    side: BorderSide(
      color: borderColor ?? AppPalette.sky.withValues(alpha: 0.84),
      width: 1.2,
    ),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    textStyle: Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
  );
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
