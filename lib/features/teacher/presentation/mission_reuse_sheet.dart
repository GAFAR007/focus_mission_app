/**
 * WHAT:
 * mission_reuse_sheet lets a teacher create a new mission draft for another
 * authorised student from an existing reviewed draft.
 * WHY:
 * Reuse should save preparation time without sharing student-specific schedule
 * state, changing the source draft, or weakening timetable permissions.
 * HOW:
 * Filter the authorised roster, load the chosen student's timetable, offer
 * only matching teacher-owned subject slots, and submit explicit shuffle
 * choices to the server-owned cloning endpoint.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'package:flutter/material.dart';

import '../../../core/constants/app_palette.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/focus_mission_api.dart';
import '../../../shared/models/focus_mission_models.dart';
import '../../../shared/widgets/student_year_group_filter.dart';

const int _reuseScheduleSearchDays = 120;

class MissionReuseSlot {
  const MissionReuseSlot({required this.date, required this.sessionType});

  final DateTime date;
  final String sessionType;

  String get dateKey {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  String get key => '$dateKey:$sessionType';
}

List<MissionReuseSlot> buildMissionReuseSlots({
  required List<TodaySchedule> timetable,
  required String subjectId,
  required String teacherId,
  DateTime? now,
  int searchDays = _reuseScheduleSearchDays,
}) {
  final startValue = now ?? DateTime.now();
  final start = DateTime(startValue.year, startValue.month, startValue.day);
  final schedulesByDay = <String, TodaySchedule>{
    for (final schedule in timetable)
      schedule.day.trim().toLowerCase(): schedule,
  };
  final slots = <MissionReuseSlot>[];

  for (var offset = 0; offset <= searchDays; offset += 1) {
    final date = start.add(Duration(days: offset));
    final schedule = schedulesByDay[_weekdayName(date.weekday).toLowerCase()];
    if (schedule == null) {
      continue;
    }

    if (_isOwnedSubjectSlot(
      subjectId: schedule.morningMission.id,
      scheduledTeacherId: schedule.morningTeacher?.id ?? '',
      requiredSubjectId: subjectId,
      requiredTeacherId: teacherId,
    )) {
      slots.add(MissionReuseSlot(date: date, sessionType: 'morning'));
    }
    if (_isOwnedSubjectSlot(
      subjectId: schedule.afternoonMission.id,
      scheduledTeacherId: schedule.afternoonTeacher?.id ?? '',
      requiredSubjectId: subjectId,
      requiredTeacherId: teacherId,
    )) {
      slots.add(MissionReuseSlot(date: date, sessionType: 'afternoon'));
    }
  }

  return List<MissionReuseSlot>.unmodifiable(slots);
}

bool _isOwnedSubjectSlot({
  required String subjectId,
  required String scheduledTeacherId,
  required String requiredSubjectId,
  required String requiredTeacherId,
}) {
  return subjectId.trim() == requiredSubjectId.trim() &&
      scheduledTeacherId.trim() == requiredTeacherId.trim();
}

String _weekdayName(int weekday) {
  const names = <String>[
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

class MissionReuseResult {
  const MissionReuseResult({
    required this.mission,
    required this.targetStudentId,
    required this.openDraft,
  });

  final MissionPayload mission;
  final String targetStudentId;
  final bool openDraft;
}

Future<MissionReuseResult?> showMissionReuseSheet(
  BuildContext context, {
  required AuthSession session,
  required MissionPayload sourceMission,
  required String sourceStudentId,
  required List<StudentSummary> students,
  required FocusMissionApi api,
}) {
  return showModalBottomSheet<MissionReuseResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _MissionReuseSheet(
      session: session,
      sourceMission: sourceMission,
      sourceStudentId: sourceStudentId,
      students: students,
      api: api,
    ),
  );
}

class _MissionReuseSheet extends StatefulWidget {
  const _MissionReuseSheet({
    required this.session,
    required this.sourceMission,
    required this.sourceStudentId,
    required this.students,
    required this.api,
  });

  final AuthSession session;
  final MissionPayload sourceMission;
  final String sourceStudentId;
  final List<StudentSummary> students;
  final FocusMissionApi api;

  @override
  State<_MissionReuseSheet> createState() => _MissionReuseSheetState();
}

class _MissionReuseSheetState extends State<_MissionReuseSheet> {
  String _selectedYearGroup = kAllStudentYearGroups;
  String? _selectedStudentId;
  List<MissionReuseSlot> _slots = const [];
  String? _selectedSlotKey;
  bool _isLoadingTimetable = false;
  bool _isSubmitting = false;
  bool _shuffleQuestions = true;
  bool _shuffleAnswers = true;
  String _errorMessage = '';
  MissionPayload? _createdMission;
  int _timetableRequestNumber = 0;

  bool get _isObjective => widget.sourceMission.draftFormat == 'QUESTIONS';

  List<StudentSummary> get _availableStudents => widget.students
      .where(
        (student) =>
            student.id != widget.sourceStudentId && !student.isArchived,
      )
      .toList(growable: false);

  StudentSummary? get _selectedStudent {
    for (final student in _availableStudents) {
      if (student.id == _selectedStudentId) {
        return student;
      }
    }
    return null;
  }

  MissionReuseSlot? get _selectedSlot {
    for (final slot in _slots) {
      if (slot.key == _selectedSlotKey) {
        return slot;
      }
    }
    return null;
  }

  Future<void> _selectStudent(StudentSummary student) async {
    final requestNumber = ++_timetableRequestNumber;
    setState(() {
      _selectedStudentId = student.id;
      _slots = const [];
      _selectedSlotKey = null;
      _isLoadingTimetable = true;
      _errorMessage = '';
      _createdMission = null;
    });

    try {
      final timetable = await widget.api.fetchStudentTimetable(
        token: widget.session.token,
        studentId: student.id,
      );
      if (!mounted || requestNumber != _timetableRequestNumber) {
        return;
      }
      final slots = buildMissionReuseSlots(
        timetable: timetable,
        subjectId: widget.sourceMission.subject?.id ?? '',
        teacherId: widget.session.user.id,
      );
      setState(() {
        _slots = slots;
        _selectedSlotKey = slots.isEmpty ? null : slots.first.key;
        _isLoadingTimetable = false;
      });
    } catch (error) {
      if (!mounted || requestNumber != _timetableRequestNumber) {
        return;
      }
      setState(() {
        _isLoadingTimetable = false;
        _errorMessage = error.toString();
      });
    }
  }

  Future<void> _createDraft() async {
    final student = _selectedStudent;
    final slot = _selectedSlot;
    if (student == null || slot == null || _isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = '';
    });

    try {
      final mission = await widget.api.reuseTeacherMissionDraft(
        token: widget.session.token,
        missionId: widget.sourceMission.id,
        targetStudentId: student.id,
        targetDate: slot.dateKey,
        sessionType: slot.sessionType,
        shuffleQuestionOrder: _isObjective && _shuffleQuestions,
        shuffleAnswerOptions: _isObjective && _shuffleAnswers,
      );
      if (!mounted) {
        return;
      }
      setState(() => _createdMission = mission);
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

  @override
  Widget build(BuildContext context) {
    final createdMission = _createdMission;
    if (createdMission != null) {
      return _buildSuccess(context, createdMission);
    }

    final visibleStudents = filterStudentsByYearGroup(
      _availableStudents,
      _selectedYearGroup,
    );
    final selectedStudent = _selectedStudent;

    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.92,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            AppSpacing.item,
            AppSpacing.screen,
            AppSpacing.section,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Use for another student',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                'A new draft will be created. ${widget.sourceMission.title} stays unchanged.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppPalette.textMuted),
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.sourceMission.subject?.name ?? 'Mission'} · ${widget.sourceMission.questionCount} ${widget.sourceMission.draftFormat == 'ESSAY_BUILDER' ? 'sentences' : 'questions'}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppPalette.primaryBlue,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.item),
              Expanded(
                child: ListView(
                  children: [
                    Text(
                      '1. Choose student',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    StudentYearGroupFilter(
                      selectedYearGroup: _selectedYearGroup,
                      onChanged: (yearGroup) {
                        setState(() => _selectedYearGroup = yearGroup);
                      },
                    ),
                    if (selectedStudent != null &&
                        !visibleStudents.any(
                          (student) => student.id == selectedStudent.id,
                        )) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Selected: ${selectedStudent.name} · ${selectedStudent.yearGroup}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppPalette.primaryBlue,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    if (visibleStudents.isEmpty)
                      _NoticeCard(
                        text: _availableStudents.isEmpty
                            ? 'No other authorised active students are available.'
                            : 'No students are saved in this year group.',
                      )
                    else
                      ...visibleStudents.map(
                        (student) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _StudentChoiceCard(
                            student: student,
                            selected: student.id == _selectedStudentId,
                            onTap: () => _selectStudent(student),
                          ),
                        ),
                      ),
                    const SizedBox(height: AppSpacing.item),
                    Text(
                      '2. Choose their lesson slot',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    if (selectedStudent == null)
                      const _NoticeCard(
                        text: 'Choose a student to load their timetable.',
                      )
                    else if (_isLoadingTimetable)
                      const Center(child: CircularProgressIndicator())
                    else if (_slots.isEmpty)
                      _NoticeCard(
                        text:
                            '${selectedStudent.name} has no upcoming ${widget.sourceMission.subject?.name ?? 'matching'} lesson assigned to you.',
                      )
                    else
                      DropdownButtonFormField<String>(
                        initialValue: _selectedSlotKey,
                        isExpanded: true,
                        decoration: _fieldDecoration('Valid timetable slot'),
                        items: _slots
                            .map(
                              (slot) => DropdownMenuItem<String>(
                                value: slot.key,
                                child: Text(
                                  _slotLabel(slot),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) {
                          setState(() => _selectedSlotKey = value);
                        },
                      ),
                    const SizedBox(height: AppSpacing.item),
                    if (_isObjective) ...[
                      Text(
                        '3. Objective question order',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _shuffleQuestions = true;
                            _shuffleAnswers = true;
                          });
                        },
                        icon: const Icon(Icons.shuffle_rounded),
                        label: const Text('Shuffle for this student'),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Shuffle question order'),
                        value: _shuffleQuestions,
                        onChanged: (value) {
                          setState(() => _shuffleQuestions = value);
                        },
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Shuffle A/B/C/D options'),
                        subtitle: const Text(
                          'The correct answer follows its option.',
                        ),
                        value: _shuffleAnswers,
                        onChanged: (value) {
                          setState(() => _shuffleAnswers = value);
                        },
                      ),
                    ] else ...[
                      const _NoticeCard(
                        text:
                            'Theory and Essay Builder content will be copied unchanged.',
                      ),
                    ],
                    if (_errorMessage.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _NoticeCard(text: _errorMessage, isError: true),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed:
                      selectedStudent != null &&
                          _selectedSlot != null &&
                          !_isSubmitting
                      ? _createDraft
                      : null,
                  icon: Icon(
                    _isSubmitting
                        ? Icons.hourglass_top_rounded
                        : Icons.copy_all_rounded,
                  ),
                  label: Text(
                    _isSubmitting
                        ? 'Creating new draft...'
                        : selectedStudent == null
                        ? 'Create new draft'
                        : 'Create draft for ${selectedStudent.name}',
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuccess(BuildContext context, MissionPayload mission) {
    final selectedStudent = _selectedStudent;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.screen),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.check_circle_rounded,
              size: 52,
              color: AppPalette.mint,
            ),
            const SizedBox(height: 12),
            Text(
              'New draft ready',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              '${mission.title} was created for ${selectedStudent?.name ?? 'the selected student'} on ${mission.availableOnDate ?? 'their lesson date'}.',
            ),
            const SizedBox(height: AppSpacing.section),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(
                  MissionReuseResult(
                    mission: mission,
                    targetStudentId: selectedStudent?.id ?? '',
                    openDraft: true,
                  ),
                ),
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Open draft'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(
                  MissionReuseResult(
                    mission: mission,
                    targetStudentId: selectedStudent?.id ?? '',
                    openDraft: false,
                  ),
                ),
                child: const Text('Return to drafts'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _slotLabel(MissionReuseSlot slot) {
    const months = <String>[
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
    final session = slot.sessionType == 'morning' ? 'Morning' : 'Afternoon';
    return '${_weekdayName(slot.date.weekday)} ${slot.date.day} ${months[slot.date.month - 1]} · $session';
  }
}

class _StudentChoiceCard extends StatelessWidget {
  const _StudentChoiceCard({
    required this.student,
    required this.selected,
    required this.onTap,
  });

  final StudentSummary student;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        padding: const EdgeInsets.all(AppSpacing.item),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.84),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppPalette.primaryBlue : AppPalette.sky,
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.person_rounded, color: AppPalette.textMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                [
                  student.name,
                  if (student.yearGroup.trim().isNotEmpty)
                    student.yearGroup.trim(),
                ].join(' · '),
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_circle_rounded,
                color: AppPalette.primaryBlue,
              ),
          ],
        ),
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.text, this.isError = false});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.item),
      decoration: BoxDecoration(
        color: isError
            ? const Color(0xFFFFF2F2)
            : AppPalette.sky.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: isError ? const Color(0xFF9B1C1C) : AppPalette.navy,
        ),
      ),
    );
  }
}

InputDecoration _fieldDecoration(String label) {
  return InputDecoration(
    labelText: label,
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.92),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
  );
}
