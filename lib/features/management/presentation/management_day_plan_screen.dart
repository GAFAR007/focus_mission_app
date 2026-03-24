/**
 * WHAT:
 * ManagementDayPlanScreen shows the selected student's published mission plan
 * for one chosen day.
 * WHY:
 * Management needs a quick, readable planning view that confirms what the
 * learner is actually scheduled to receive without opening the full authoring
 * or results flows.
 * HOW:
 * Load the management-only day-plan endpoint for the chosen student/date,
 * render morning and afternoon lesson cards, and let management switch the
 * date from the same screen.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'package:flutter/material.dart';

import '../../../core/constants/app_palette.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/download_text_file.dart';
import '../../../core/utils/focus_mission_api.dart';
import '../../../shared/models/focus_mission_models.dart';
import '../../../shared/widgets/focus_scaffold.dart';
import '../../../shared/widgets/soft_panel.dart';
import '../../../shared/widgets/stat_chip.dart';
import '../../../shared/widgets/weekly_timetable_calendar.dart';

class ManagementDayPlanScreen extends StatefulWidget {
  const ManagementDayPlanScreen({
    super.key,
    required this.session,
    required this.student,
    required this.initialDate,
  });

  final AuthSession session;
  final StudentSummary student;
  final DateTime initialDate;

  @override
  State<ManagementDayPlanScreen> createState() =>
      _ManagementDayPlanScreenState();
}

class _ManagementDayPlanScreenState extends State<ManagementDayPlanScreen> {
  final FocusMissionApi _api = FocusMissionApi();

  late DateTime _selectedDate;
  late Future<ManagementDayPlan> _future;
  String _downloadingTeacherCopyMissionId = '';
  String _downloadingStudentCopyMissionId = '';

  @override
  void initState() {
    super.initState();
    _selectedDate = _dateOnly(widget.initialDate);
    _future = _loadPlan();
  }

  Future<ManagementDayPlan> _loadPlan() {
    return _api.fetchManagementStudentDayPlan(
      token: widget.session.token,
      studentId: widget.student.id,
      dateKey: _dateKey(_selectedDate),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FocusScaffold(
      child: FutureBuilder<ManagementDayPlan>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(AppSpacing.screen),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ManagementDayPlanHeader(
                    studentName: widget.student.name,
                    onBack: () => Navigator.of(context).pop(),
                    onChangeDate: _pickDate,
                  ),
                  const SizedBox(height: AppSpacing.section),
                  SoftPanel(
                    child: Text(
                      snapshot.error.toString(),
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(color: AppPalette.navy),
                    ),
                  ),
                ],
              ),
            );
          }

          final plan = snapshot.data!;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.screen),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ManagementDayPlanHeader(
                  studentName: widget.student.name,
                  onBack: () => Navigator.of(context).pop(),
                  onChangeDate: _pickDate,
                ),
                const SizedBox(height: AppSpacing.section),
                CurrentDatePanel(
                  title: 'Planned Missions',
                  subtitle:
                      'Review the live published missions scheduled for ${widget.student.name}.',
                  date: _selectedDate,
                ),
                const SizedBox(height: AppSpacing.item),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    StatChip(
                      value: '${plan.totalMissionCount}',
                      label: 'Published',
                      colors: const [AppPalette.primaryBlue, AppPalette.aqua],
                    ),
                    StatChip(
                      value: '${plan.morning.missions.length}',
                      label: 'Morning',
                      colors: const [AppPalette.sun, AppPalette.orange],
                    ),
                    StatChip(
                      value: '${plan.afternoon.missions.length}',
                      label: 'Afternoon',
                      colors: const [AppPalette.mint, AppPalette.aqua],
                    ),
                    StatChip(
                      value: plan.room.trim().isEmpty ? 'No room' : plan.room,
                      label: 'Room',
                      colors: const [AppPalette.sky, AppPalette.primaryBlue],
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.item),
                if (!plan.hasTimetableEntry)
                  SoftPanel(
                    child: Text(
                      'No timetable entry is saved for ${plan.weekday}. Management needs to add that lesson day before a mission plan can appear.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(color: AppPalette.navy),
                    ),
                  )
                else ...[
                  _PlannedSessionPanel(
                    plan: plan.morning,
                    downloadingTeacherCopyMissionId:
                        _downloadingTeacherCopyMissionId,
                    downloadingStudentCopyMissionId:
                        _downloadingStudentCopyMissionId,
                    onOpenTeacherCopy: _openTeacherCopyPreview,
                    onDownloadTeacherCopy: _downloadMissionTeacherCopy,
                    onDownloadStudentCopy: _downloadMissionStudentCopy,
                  ),
                  const SizedBox(height: AppSpacing.item),
                  _PlannedSessionPanel(
                    plan: plan.afternoon,
                    downloadingTeacherCopyMissionId:
                        _downloadingTeacherCopyMissionId,
                    downloadingStudentCopyMissionId:
                        _downloadingStudentCopyMissionId,
                    onOpenTeacherCopy: _openTeacherCopyPreview,
                    onDownloadTeacherCopy: _downloadMissionTeacherCopy,
                    onDownloadStudentCopy: _downloadMissionStudentCopy,
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _selectedDate = _dateOnly(picked);
      _future = _loadPlan();
    });
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  String _dateKey(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  Future<void> _openTeacherCopyPreview(MissionPayload mission) async {
    if (!mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _ManagementTeacherCopySheet(
          student: widget.student,
          mission: mission,
          selectedDate: _selectedDate,
          isDownloading:
              _downloadingTeacherCopyMissionId.trim() == mission.id.trim(),
          onDownload: () => _downloadMissionTeacherCopy(mission),
        );
      },
    );
  }

  Future<void> _downloadMissionTeacherCopy(MissionPayload mission) async {
    final missionId = mission.id.trim();
    if (missionId.isEmpty || _downloadingTeacherCopyMissionId.isNotEmpty) {
      return;
    }

    setState(() => _downloadingTeacherCopyMissionId = missionId);
    try {
      final downloaded = await downloadTextFile(
        fileName: _buildTeacherCopyFileName(
          student: widget.student,
          mission: mission,
          selectedDate: _selectedDate,
        ),
        content: _buildTeacherCopyHtml(
          student: widget.student,
          mission: mission,
          selectedDate: _selectedDate,
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

  Future<void> _downloadMissionStudentCopy(MissionPayload mission) async {
    final missionId = mission.id.trim();
    if (missionId.isEmpty || _downloadingStudentCopyMissionId.isNotEmpty) {
      return;
    }

    setState(() => _downloadingStudentCopyMissionId = missionId);
    try {
      final downloaded = await downloadTextFile(
        fileName: _buildStudentCopyFileName(
          student: widget.student,
          mission: mission,
          selectedDate: _selectedDate,
        ),
        content: _buildStudentCopyHtml(
          student: widget.student,
          mission: mission,
          selectedDate: _selectedDate,
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
                ? 'Downloaded $missionTitle student copy.'
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
        setState(() => _downloadingStudentCopyMissionId = '');
      }
    }
  }
}

class _ManagementDayPlanHeader extends StatelessWidget {
  const _ManagementDayPlanHeader({
    required this.studentName,
    required this.onBack,
    required this.onChangeDate,
  });

  final String studentName;
  final VoidCallback onBack;
  final VoidCallback onChangeDate;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _RoundHeaderButton(
          icon: Icons.arrow_back_ios_new_rounded,
          onTap: onBack,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Student Day Plan',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                studentName,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppPalette.textMuted),
              ),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: onChangeDate,
          icon: const Icon(Icons.edit_calendar_rounded),
          label: const Text('Change date'),
        ),
      ],
    );
  }
}

class _PlannedSessionPanel extends StatelessWidget {
  const _PlannedSessionPanel({
    required this.plan,
    required this.downloadingTeacherCopyMissionId,
    required this.downloadingStudentCopyMissionId,
    required this.onOpenTeacherCopy,
    required this.onDownloadTeacherCopy,
    required this.onDownloadStudentCopy,
  });

  final ManagementPlannedSession plan;
  final String downloadingTeacherCopyMissionId;
  final String downloadingStudentCopyMissionId;
  final ValueChanged<MissionPayload> onOpenTeacherCopy;
  final ValueChanged<MissionPayload> onDownloadTeacherCopy;
  final ValueChanged<MissionPayload> onDownloadStudentCopy;

  @override
  Widget build(BuildContext context) {
    final sessionLabel = plan.sessionType.trim().isEmpty
        ? 'Session'
        : '${plan.sessionType[0].toUpperCase()}${plan.sessionType.substring(1)}';

    return SoftPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: plan.sessionType == 'afternoon'
                        ? const [AppPalette.mint, AppPalette.aqua]
                        : const [AppPalette.sun, AppPalette.orange],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  plan.sessionType == 'afternoon'
                      ? Icons.nightlight_round
                      : Icons.wb_sunny_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$sessionLabel Session',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      plan.hasScheduledLesson
                          ? '${plan.subject?.name ?? 'Subject'}${plan.teacher == null ? '' : ' · ${plan.teacher!.name}'}'
                          : 'No scheduled lesson saved for this slot.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppPalette.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              _MiniPill(label: '${plan.missions.length} planned'),
            ],
          ),
          if (plan.missions.isEmpty) ...[
            const SizedBox(height: AppSpacing.item),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.item),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Text(
                plan.hasScheduledLesson
                    ? 'No published missions are planned for this session yet.'
                    : 'Add the timetable subject first, then published missions for this slot will appear here.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppPalette.textMuted),
              ),
            ),
          ] else ...[
            const SizedBox(height: AppSpacing.item),
            ...plan.missions.map(
              (mission) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _PlannedMissionTile(
                  mission: mission,
                  isDownloadingTeacherCopy:
                      downloadingTeacherCopyMissionId.trim() ==
                      mission.id.trim(),
                  isDownloadingStudentCopy:
                      downloadingStudentCopyMissionId.trim() ==
                      mission.id.trim(),
                  onOpenTeacherCopy: () => onOpenTeacherCopy(mission),
                  onDownloadTeacherCopy: () => onDownloadTeacherCopy(mission),
                  onDownloadStudentCopy: () => onDownloadStudentCopy(mission),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlannedMissionTile extends StatelessWidget {
  const _PlannedMissionTile({
    required this.mission,
    required this.isDownloadingTeacherCopy,
    required this.isDownloadingStudentCopy,
    required this.onOpenTeacherCopy,
    required this.onDownloadTeacherCopy,
    required this.onDownloadStudentCopy,
  });

  final MissionPayload mission;
  final bool isDownloadingTeacherCopy;
  final bool isDownloadingStudentCopy;
  final VoidCallback onOpenTeacherCopy;
  final VoidCallback onDownloadTeacherCopy;
  final VoidCallback onDownloadStudentCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.item),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            mission.title.trim().isEmpty ? 'Planned mission' : mission.title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniPill(label: _missionTypeLabel(mission)),
              _MiniPill(
                label: _managementDraftFormatLabel(mission.draftFormat),
              ),
              _MiniPill(label: '${mission.questionCount} items'),
            ],
          ),
          if (mission.teacherNote.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              mission.teacherNote.trim(),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppPalette.textMuted),
            ),
          ],
          const SizedBox(height: AppSpacing.compact),
          LayoutBuilder(
            builder: (context, constraints) {
              final stackButtons = constraints.maxWidth < 560;
              final openButton = stackButtons
                  ? SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: _managementDayPlanFilledActionStyle(context),
                        onPressed: onOpenTeacherCopy,
                        icon: const Icon(Icons.visibility_rounded),
                        label: const Text('Open teacher copy'),
                      ),
                    )
                  : Expanded(
                      child: FilledButton.icon(
                        style: _managementDayPlanFilledActionStyle(context),
                        onPressed: onOpenTeacherCopy,
                        icon: const Icon(Icons.visibility_rounded),
                        label: const Text('Open teacher copy'),
                      ),
                    );
              final downloadButton = stackButtons
                  ? SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: _managementDayPlanOutlinedActionStyle(context),
                        onPressed: isDownloadingTeacherCopy
                            ? null
                            : onDownloadTeacherCopy,
                        icon: Icon(
                          isDownloadingTeacherCopy
                              ? Icons.hourglass_top_rounded
                              : Icons.download_rounded,
                        ),
                        label: Text(
                          isDownloadingTeacherCopy
                              ? 'Preparing...'
                              : 'Download teacher copy',
                        ),
                      ),
                    )
                  : Expanded(
                      child: OutlinedButton.icon(
                        style: _managementDayPlanOutlinedActionStyle(context),
                        onPressed: isDownloadingTeacherCopy
                            ? null
                            : onDownloadTeacherCopy,
                        icon: Icon(
                          isDownloadingTeacherCopy
                              ? Icons.hourglass_top_rounded
                              : Icons.download_rounded,
                        ),
                        label: Text(
                          isDownloadingTeacherCopy
                              ? 'Preparing...'
                              : 'Download teacher copy',
                        ),
                      ),
                    );
              final studentCopyButton = stackButtons
                  ? SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: _managementDayPlanOutlinedActionStyle(
                          context,
                          backgroundColor: AppPalette.mint.withValues(
                            alpha: 0.12,
                          ),
                          borderColor: AppPalette.mint.withValues(alpha: 0.36),
                        ),
                        onPressed: isDownloadingStudentCopy
                            ? null
                            : onDownloadStudentCopy,
                        icon: Icon(
                          isDownloadingStudentCopy
                              ? Icons.hourglass_top_rounded
                              : Icons.assignment_rounded,
                        ),
                        label: Text(
                          isDownloadingStudentCopy
                              ? 'Preparing...'
                              : 'Download student copy',
                        ),
                      ),
                    )
                  : Expanded(
                      child: OutlinedButton.icon(
                        style: _managementDayPlanOutlinedActionStyle(
                          context,
                          backgroundColor: AppPalette.mint.withValues(
                            alpha: 0.12,
                          ),
                          borderColor: AppPalette.mint.withValues(alpha: 0.36),
                        ),
                        onPressed: isDownloadingStudentCopy
                            ? null
                            : onDownloadStudentCopy,
                        icon: Icon(
                          isDownloadingStudentCopy
                              ? Icons.hourglass_top_rounded
                              : Icons.assignment_rounded,
                        ),
                        label: Text(
                          isDownloadingStudentCopy
                              ? 'Preparing...'
                              : 'Download student copy',
                        ),
                      ),
                    );

              if (stackButtons) {
                return Column(
                  children: [
                    openButton,
                    const SizedBox(height: 10),
                    downloadButton,
                    const SizedBox(height: 10),
                    studentCopyButton,
                  ],
                );
              }

              return Row(
                children: [
                  openButton,
                  const SizedBox(width: 10),
                  downloadButton,
                  const SizedBox(width: 10),
                  studentCopyButton,
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  String _missionTypeLabel(MissionPayload mission) {
    return mission.questionCount >= 10 ? 'Assessment' : 'Daily';
  }
}

class _ManagementTeacherCopySheet extends StatelessWidget {
  const _ManagementTeacherCopySheet({
    required this.student,
    required this.mission,
    required this.selectedDate,
    required this.isDownloading,
    required this.onDownload,
  });

  final StudentSummary student;
  final MissionPayload mission;
  final DateTime selectedDate;
  final bool isDownloading;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final subjectName = (mission.subject?.name ?? 'No subject').trim();
    final taskCodes = mission.taskCodes.isEmpty
        ? 'None selected'
        : mission.taskCodes.join(', ');

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFF7FAFF),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 56,
                height: 6,
                margin: const EdgeInsets.only(top: 14, bottom: 18),
                decoration: BoxDecoration(
                  color: AppPalette.textMuted.withValues(alpha: 0.42),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screen,
                  0,
                  AppSpacing.screen,
                  AppSpacing.screen,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mission.title.trim().isEmpty
                          ? 'Teacher Copy'
                          : mission.title.trim(),
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Management can review the assigned question copy, answer keys, and teaching guidance for this published mission.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppPalette.textMuted,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.item),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _MiniPill(label: student.name),
                        _MiniPill(
                          label: subjectName.isEmpty
                              ? 'No subject'
                              : subjectName,
                        ),
                        _MiniPill(
                          label: mission.sessionType.trim().isEmpty
                              ? 'Session'
                              : mission.sessionType.trim().toUpperCase(),
                        ),
                        _MiniPill(
                          label: _formatTeacherCopyDate(
                            mission.availableOnDate,
                            selectedDate,
                          ),
                        ),
                        _MiniPill(
                          label: _managementDraftFormatLabel(
                            mission.draftFormat,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.item),
                    _TeacherCopyInfoPanel(
                      title: 'Teacher Copy',
                      body:
                          'Use this copy for oversight, answer checking, and confirming exactly what the learner was assigned.',
                    ),
                    if (mission.teacherNote.trim().isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.item),
                      _TeacherCopyTextPanel(
                        title: 'Teacher Note',
                        body: mission.teacherNote.trim(),
                      ),
                    ],
                    if (mission.sourceUnitText.trim().isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.item),
                      _TeacherCopyTextPanel(
                        title: 'Unit Text',
                        body: mission.sourceUnitText.trim(),
                        caption: 'Reviewed unit text saved with this mission.',
                      ),
                    ],
                    const SizedBox(height: AppSpacing.item),
                    _TeacherCopyInfoPanel(
                      title: 'Mission Details',
                      body:
                          'Difficulty: ${mission.difficulty.toUpperCase()} · XP: ${mission.xpReward} · Task Focus: $taskCodes',
                    ),
                    const SizedBox(height: AppSpacing.item),
                    mission.draftFormat.trim().toUpperCase() == 'ESSAY_BUILDER'
                        ? _TeacherCopyEssayPanel(mission: mission)
                        : _TeacherCopyQuestionPanel(mission: mission),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                12,
                AppSpacing.screen,
                AppSpacing.screen,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 18,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: _managementDayPlanOutlinedActionStyle(context),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      style: _managementDayPlanFilledActionStyle(context),
                      onPressed: isDownloading ? null : onDownload,
                      icon: Icon(
                        isDownloading
                            ? Icons.hourglass_top_rounded
                            : Icons.download_rounded,
                      ),
                      label: Text(
                        isDownloading
                            ? 'Preparing...'
                            : 'Download teacher copy',
                      ),
                    ),
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

class _TeacherCopyInfoPanel extends StatelessWidget {
  const _TeacherCopyInfoPanel({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.item),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            body,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppPalette.textMuted),
          ),
        ],
      ),
    );
  }
}

class _TeacherCopyTextPanel extends StatelessWidget {
  const _TeacherCopyTextPanel({
    required this.title,
    required this.body,
    this.caption,
  });

  final String title;
  final String body;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.item),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          if (caption != null && caption!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              caption!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppPalette.textMuted),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            body,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppPalette.navy,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

class _TeacherCopyQuestionPanel extends StatelessWidget {
  const _TeacherCopyQuestionPanel({required this.mission});

  final MissionPayload mission;

  @override
  Widget build(BuildContext context) {
    if (mission.questions.isEmpty) {
      return const _TeacherCopyInfoPanel(
        title: 'Questions',
        body: 'No question content was saved for this mission.',
      );
    }

    const optionLabels = ['A', 'B', 'C', 'D'];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.item),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            mission.draftFormat.trim().toUpperCase() == 'THEORY'
                ? 'Theory Questions'
                : 'Questions',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            mission.draftFormat.trim().toUpperCase() == 'THEORY'
                ? 'Teacher-ready theory prompts with expected responses and guidance.'
                : 'Teacher-ready question set with every option and answer key shown.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppPalette.textMuted),
          ),
          const SizedBox(height: AppSpacing.item),
          ...mission.questions.asMap().entries.map((entry) {
            final question = entry.value;
            final isTheory =
                mission.draftFormat.trim().toUpperCase() == 'THEORY';
            return Container(
              width: double.infinity,
              margin: EdgeInsets.only(
                bottom: entry.key == mission.questions.length - 1 ? 0 : 12,
              ),
              padding: const EdgeInsets.all(AppSpacing.item),
              decoration: BoxDecoration(
                color: AppPalette.surface.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _MiniPill(label: 'Question ${entry.key + 1}'),
                      const SizedBox(width: 8),
                      const _MiniPill(label: 'Teacher Copy'),
                    ],
                  ),
                  if (question.learningText.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Learn First',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      question.learningText.trim(),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text('Prompt', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 6),
                  Text(
                    question.prompt,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  if (isTheory) ...[
                    const SizedBox(height: 12),
                    _MiniPill(
                      label:
                          'Minimum Words: ${question.minWordCount > 0 ? question.minWordCount : 1}',
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Expected Answer',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      question.expectedAnswer.trim().isEmpty
                          ? question.explanation
                          : question.expectedAnswer,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (question.explanation.trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Teacher Guidance',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        question.explanation.trim(),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ] else ...[
                    const SizedBox(height: 12),
                    Text(
                      'Options',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 6),
                    ...question.options.asMap().entries.map((optionEntry) {
                      final optionIndex = optionEntry.key;
                      final isCorrect = question.correctIndex == optionIndex;
                      final optionLabel = optionLabels[optionIndex];
                      return Container(
                        width: double.infinity,
                        margin: EdgeInsets.only(
                          bottom: optionIndex == question.options.length - 1
                              ? 0
                              : 8,
                        ),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isCorrect
                              ? AppPalette.mint.withValues(alpha: 0.16)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isCorrect
                                ? AppPalette.mint
                                : AppPalette.sky.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isCorrect
                                    ? AppPalette.mint
                                    : AppPalette.sky.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                optionLabel,
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(
                                      color: isCorrect
                                          ? Colors.white
                                          : AppPalette.navy,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                optionEntry.value,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 12),
                    Text(
                      'Correct Answer',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _teacherCopyQuestionAnswerLine(question),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (question.explanation.trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Explanation',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        question.explanation.trim(),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _TeacherCopyEssayPanel extends StatelessWidget {
  const _TeacherCopyEssayPanel({required this.mission});

  final MissionPayload mission;

  @override
  Widget build(BuildContext context) {
    final draft = mission.essayBuilderDraft;
    if (draft == null) {
      return const _TeacherCopyInfoPanel(
        title: 'Essay Builder',
        body: 'Essay builder draft is missing for this mission.',
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.item),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Essay Builder', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            'Teacher-ready essay builder copy with full blank options and answer keys.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppPalette.textMuted),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniPill(label: 'Mode: ${draft.mode}'),
              _MiniPill(
                label:
                    'Target Words: ${draft.targets.targetWordMin}-${draft.targets.targetWordMax}',
              ),
              _MiniPill(
                label: 'Target Sentences: ${draft.targets.targetSentenceCount}',
              ),
              _MiniPill(
                label: 'Target Blanks: ${draft.targets.targetBlankCount}',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.item),
          ...draft.sentences.asMap().entries.map((entry) {
            final sentence = entry.value;
            final blankParts = sentence.parts
                .where((part) => part.isBlank)
                .toList(growable: false);
            return Container(
              width: double.infinity,
              margin: EdgeInsets.only(
                bottom: entry.key == draft.sentences.length - 1 ? 0 : 12,
              ),
              padding: const EdgeInsets.all(AppSpacing.item),
              decoration: BoxDecoration(
                color: AppPalette.surface.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _MiniPill(label: 'Sentence ${entry.key + 1}'),
                      const SizedBox(width: 8),
                      const _MiniPill(label: 'Teacher Copy'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    sentence.role,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  if (sentence.learnFirst.bullets.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Learn First',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 6),
                    ...sentence.learnFirst.bullets
                        .where((bullet) => bullet.trim().isNotEmpty)
                        .map(
                          (bullet) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '• ${bullet.trim()}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    'Sentence Preview',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _managementSentencePreviewText(sentence),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (blankParts.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ...blankParts.asMap().entries.map((blankEntry) {
                      final blank = blankEntry.value;
                      return Container(
                        width: double.infinity,
                        margin: EdgeInsets.only(
                          bottom: blankEntry.key == blankParts.length - 1
                              ? 0
                              : 10,
                        ),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppPalette.sky.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Blank ${blankEntry.key + 1}',
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            if (blank.hint.trim().isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                blank.hint.trim(),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: AppPalette.textMuted),
                              ),
                            ],
                            const SizedBox(height: 10),
                            ...const ['A', 'B', 'C', 'D'].map((label) {
                              final isCorrect = blank.correctOption == label;
                              return Container(
                                width: double.infinity,
                                margin: EdgeInsets.only(
                                  bottom: label == 'D' ? 0 : 8,
                                ),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isCorrect
                                      ? AppPalette.mint.withValues(alpha: 0.16)
                                      : AppPalette.surface,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  '$label) ${blank.options[label] ?? ''}',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              );
                            }),
                            const SizedBox(height: 10),
                            Text(
                              'Correct Answer: ${blank.correctOption}) ${blank.options[blank.correctOption] ?? ''}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

String _buildTeacherCopyFileName({
  required StudentSummary student,
  required MissionPayload mission,
  required DateTime selectedDate,
}) {
  final studentSlug = _sanitizeTeacherCopyFileName(student.name);
  final subjectSlug = _sanitizeTeacherCopyFileName(
    (mission.subject?.name ?? 'subject').trim(),
  );
  final missionSlug = _sanitizeTeacherCopyFileName(mission.title);
  final dateSlug = _sanitizeTeacherCopyFileName(
    mission.availableOnDate?.trim().isNotEmpty == true
        ? mission.availableOnDate!.trim()
        : _dateKeyForTeacherCopy(selectedDate),
  );
  return '${studentSlug}_${subjectSlug}_${dateSlug}_${missionSlug}_teacher-copy.html';
}

String _buildStudentCopyFileName({
  required StudentSummary student,
  required MissionPayload mission,
  required DateTime selectedDate,
}) {
  final studentSlug = _sanitizeTeacherCopyFileName(student.name);
  final subjectSlug = _sanitizeTeacherCopyFileName(
    (mission.subject?.name ?? 'subject').trim(),
  );
  final missionSlug = _sanitizeTeacherCopyFileName(mission.title);
  final dateSlug = _sanitizeTeacherCopyFileName(
    mission.availableOnDate?.trim().isNotEmpty == true
        ? mission.availableOnDate!.trim()
        : _dateKeyForTeacherCopy(selectedDate),
  );
  return '${studentSlug}_${subjectSlug}_${dateSlug}_${missionSlug}_student-copy.html';
}

String _buildTeacherCopyHtml({
  required StudentSummary student,
  required MissionPayload mission,
  required DateTime selectedDate,
}) {
  final subjectName = (mission.subject?.name ?? 'No subject').trim();
  final taskFocusText = mission.taskCodes.isEmpty
      ? 'None selected'
      : mission.taskCodes.join(', ');
  final buffer = StringBuffer()
    ..writeln('<!DOCTYPE html>')
    ..writeln('<html lang="en">')
    ..writeln('<head>')
    ..writeln('<meta charset="utf-8" />')
    ..writeln(
      '<meta name="viewport" content="width=device-width, initial-scale=1" />',
    )
    ..writeln(
      '<title>${_escapeTeacherCopyHtml('${mission.title} · Teacher Copy')}</title>',
    )
    ..writeln('<style>${_buildTeacherCopyStyles()}</style>')
    ..writeln('</head>')
    ..writeln('<body>')
    ..writeln('<main class="page">')
    ..writeln('<section class="hero">')
    ..writeln('<span class="copy-chip">Teacher Copy</span>')
    ..writeln('<h1>${_escapeTeacherCopyHtml(mission.title)}</h1>')
    ..writeln(
      '<p class="hero-summary">Teacher-ready mission copy with full question content, answer keys, and teaching guidance.</p>',
    )
    ..writeln('<div class="meta-grid">')
    ..writeln(_buildTeacherCopyMetaCard(label: 'Student', value: student.name))
    ..writeln(_buildTeacherCopyMetaCard(label: 'Subject', value: subjectName))
    ..writeln(
      _buildTeacherCopyMetaCard(
        label: 'Session',
        value: mission.sessionType.toUpperCase(),
      ),
    )
    ..writeln(
      _buildTeacherCopyMetaCard(
        label: 'Mission Date',
        value: _formatTeacherCopyDate(mission.availableOnDate, selectedDate),
      ),
    )
    ..writeln(
      _buildTeacherCopyMetaCard(
        label: 'Format',
        value: _managementDraftFormatLabel(mission.draftFormat),
      ),
    )
    ..writeln(
      _buildTeacherCopyMetaCard(
        label: 'Difficulty',
        value: mission.difficulty.toUpperCase(),
      ),
    )
    ..writeln(
      _buildTeacherCopyMetaCard(
        label: 'XP Reward',
        value: '${mission.xpReward} XP',
      ),
    )
    ..writeln(
      _buildTeacherCopyMetaCard(label: 'Task Focus', value: taskFocusText),
    )
    ..writeln('</div>')
    ..writeln('</section>');

  if (mission.teacherNote.trim().isNotEmpty) {
    buffer
      ..writeln('<section class="section-card">')
      ..writeln('<h2>Teacher Note</h2>')
      ..writeln(_buildTeacherCopyRichTextHtml(mission.teacherNote))
      ..writeln('</section>');
  }

  if (mission.sourceUnitText.trim().isNotEmpty) {
    buffer
      ..writeln('<section class="section-card">')
      ..writeln('<h2>Unit Text</h2>')
      ..writeln(
        '<p class="section-kicker">Reviewed unit text saved with this mission.</p>',
      )
      ..writeln(_buildTeacherCopyRichTextHtml(mission.sourceUnitText))
      ..writeln('</section>');
  }

  buffer.writeln(
    mission.draftFormat.trim().toUpperCase() == 'ESSAY_BUILDER'
        ? _buildTeacherCopyEssayHtml(mission)
        : _buildTeacherCopyQuestionHtml(mission),
  );

  buffer
    ..writeln('</main>')
    ..writeln('</body>')
    ..writeln('</html>');
  return buffer.toString();
}

String _buildStudentCopyHtml({
  required StudentSummary student,
  required MissionPayload mission,
  required DateTime selectedDate,
}) {
  final subjectName = (mission.subject?.name ?? 'No subject').trim();
  final buffer = StringBuffer()
    ..writeln('<!DOCTYPE html>')
    ..writeln('<html lang="en">')
    ..writeln('<head>')
    ..writeln('<meta charset="utf-8" />')
    ..writeln(
      '<meta name="viewport" content="width=device-width, initial-scale=1" />',
    )
    ..writeln(
      '<title>${_escapeTeacherCopyHtml('${mission.title} · Student Copy')}</title>',
    )
    ..writeln('<style>${_buildTeacherCopyStyles()}</style>')
    ..writeln('</head>')
    ..writeln('<body>')
    ..writeln('<main class="page">')
    ..writeln('<section class="hero">')
    ..writeln('<span class="copy-chip">Student Copy</span>')
    ..writeln('<h1>${_escapeTeacherCopyHtml(mission.title)}</h1>')
    ..writeln(
      '<p class="hero-summary">Student-ready mission copy without answers or teacher-only guidance.</p>',
    )
    ..writeln('<div class="meta-grid">')
    ..writeln(_buildTeacherCopyMetaCard(label: 'Student', value: student.name))
    ..writeln(_buildTeacherCopyMetaCard(label: 'Subject', value: subjectName))
    ..writeln(
      _buildTeacherCopyMetaCard(
        label: 'Session',
        value: mission.sessionType.toUpperCase(),
      ),
    )
    ..writeln(
      _buildTeacherCopyMetaCard(
        label: 'Mission Date',
        value: _formatTeacherCopyDate(mission.availableOnDate, selectedDate),
      ),
    )
    ..writeln(
      _buildTeacherCopyMetaCard(
        label: 'Format',
        value: _managementDraftFormatLabel(mission.draftFormat),
      ),
    )
    ..writeln('</div>')
    ..writeln('</section>')
    ..writeln('<section class="section-card">')
    ..writeln('<h2>Student Copy</h2>')
    ..writeln(
      '<p class="section-kicker">Use this version with the learner. It keeps the mission clean and answer-free.</p>',
    )
    ..writeln('</section>');

  buffer.writeln(
    mission.draftFormat.trim().toUpperCase() == 'ESSAY_BUILDER'
        ? _buildStudentCopyEssayHtml(mission)
        : _buildStudentCopyQuestionHtml(mission),
  );

  buffer
    ..writeln('</main>')
    ..writeln('</body>')
    ..writeln('</html>');
  return buffer.toString();
}

String _buildTeacherCopyQuestionHtml(MissionPayload mission) {
  if (mission.questions.isEmpty) {
    return '<section class="section-card"><h2>Questions</h2><p class="section-kicker">No question content was saved for this mission.</p></section>';
  }

  const optionLabels = ['A', 'B', 'C', 'D'];
  final isTheory = mission.draftFormat.trim().toUpperCase() == 'THEORY';
  final buffer = StringBuffer()
    ..writeln('<section class="section-card">')
    ..writeln('<h2>${isTheory ? 'Theory Questions' : 'Questions'}</h2>')
    ..writeln(
      '<p class="section-kicker">${isTheory ? 'Teacher-ready theory prompts with expected responses and guidance.' : 'Teacher-ready question set with every option and answer key shown.'}</p>',
    );

  for (final entry in mission.questions.asMap().entries) {
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
        ..writeln(_buildTeacherCopyRichTextHtml(question.learningText));
    }

    buffer
      ..writeln('<div class="field-label">Prompt</div>')
      ..writeln(_buildTeacherCopyRichTextHtml(question.prompt));

    if (isTheory) {
      buffer
        ..writeln(
          '<div class="pill-row"><span class="soft-pill">Minimum Words: ${question.minWordCount > 0 ? question.minWordCount : 1}</span></div>',
        )
        ..writeln('<div class="answer-card">')
        ..writeln('<div class="field-label">Expected Answer</div>')
        ..writeln(
          _buildTeacherCopyRichTextHtml(
            question.expectedAnswer.trim().isEmpty
                ? question.explanation
                : question.expectedAnswer,
          ),
        );
      if (question.explanation.trim().isNotEmpty) {
        buffer
          ..writeln('<div class="field-label">Teacher Guidance</div>')
          ..writeln(_buildTeacherCopyRichTextHtml(question.explanation));
      }
      buffer
        ..writeln('</div>')
        ..writeln('</article>');
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
        '<li class="option-row ${isCorrect ? 'correct-option' : ''}"><span class="option-badge">$optionLabel</span><span>${_escapeTeacherCopyHtml(optionEntry.value)}</span></li>',
      );
    }
    buffer
      ..writeln('</ul>')
      ..writeln('<div class="answer-card">')
      ..writeln(
        '<p class="answer-inline"><strong>Correct Answer:</strong> ${_escapeTeacherCopyHtml(_teacherCopyQuestionAnswerLine(question))}</p>',
      );
    if (question.explanation.trim().isNotEmpty) {
      buffer
        ..writeln('<div class="field-label">Explanation</div>')
        ..writeln(_buildTeacherCopyRichTextHtml(question.explanation));
    }
    buffer
      ..writeln('</div>')
      ..writeln('</article>');
  }

  buffer.writeln('</section>');
  return buffer.toString();
}

String _buildStudentCopyQuestionHtml(MissionPayload mission) {
  if (mission.questions.isEmpty) {
    return '<section class="section-card"><h2>Questions</h2><p class="section-kicker">No question content was saved for this mission.</p></section>';
  }

  final isTheory = mission.draftFormat.trim().toUpperCase() == 'THEORY';
  final buffer = StringBuffer()
    ..writeln('<section class="section-card">')
    ..writeln('<h2>${isTheory ? 'Theory Questions' : 'Questions'}</h2>')
    ..writeln(
      '<p class="section-kicker">${isTheory ? 'Student-ready theory prompts without teacher answers.' : 'Student-ready question set without answer keys.'}</p>',
    );

  for (final entry in mission.questions.asMap().entries) {
    final question = entry.value;
    buffer
      ..writeln('<article class="question-card">')
      ..writeln('<div class="question-top">')
      ..writeln(
        '<span class="question-pill">Question ${entry.key + 1}</span><span class="copy-pill">Student Copy</span>',
      )
      ..writeln('</div>');

    if (question.learningText.trim().isNotEmpty) {
      buffer
        ..writeln('<div class="field-label">Learn First</div>')
        ..writeln(_buildTeacherCopyRichTextHtml(question.learningText));
    }

    buffer
      ..writeln('<div class="field-label">Prompt</div>')
      ..writeln(_buildTeacherCopyRichTextHtml(question.prompt));

    if (isTheory) {
      if (question.minWordCount > 0) {
        buffer.writeln(
          '<div class="pill-row"><span class="soft-pill">Minimum Words: ${question.minWordCount}</span></div>',
        );
      }
      buffer
        ..writeln('<div class="answer-card">')
        ..writeln('<div class="field-label">Write Your Answer</div>')
        ..writeln(
          '<p class="section-kicker">Respond in your own words using the learning text and prompt.</p>',
        )
        ..writeln('</div>')
        ..writeln('</article>');
      continue;
    }

    buffer
      ..writeln('<div class="field-label">Options</div>')
      ..writeln('<ul class="option-list">');
    for (final optionEntry in question.options.asMap().entries) {
      final optionIndex = optionEntry.key;
      final optionLabel = String.fromCharCode(65 + optionIndex);
      buffer.writeln(
        '<li class="option-row"><span class="option-badge">$optionLabel</span><span>${_escapeTeacherCopyHtml(optionEntry.value)}</span></li>',
      );
    }
    buffer
      ..writeln('</ul>')
      ..writeln('</article>');
  }

  buffer.writeln('</section>');
  return buffer.toString();
}

String _buildTeacherCopyEssayHtml(MissionPayload mission) {
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
      '<span class="soft-pill">Mode: ${_escapeTeacherCopyHtml(draft.mode)}</span>',
    )
    ..writeln(
      '<span class="soft-pill">Target Words: ${draft.targets.targetWordMin}-${draft.targets.targetWordMax}</span>',
    )
    ..writeln(
      '<span class="soft-pill">Target Sentences: ${draft.targets.targetSentenceCount}</span>',
    )
    ..writeln(
      '<span class="soft-pill">Target Blanks: ${draft.targets.targetBlankCount}</span>',
    )
    ..writeln('</div>');

  for (final entry in draft.sentences.asMap().entries) {
    final sentence = entry.value;
    final blankParts = sentence.parts.where((part) => part.isBlank).toList();
    buffer
      ..writeln('<article class="question-card">')
      ..writeln('<div class="question-top">')
      ..writeln(
        '<span class="question-pill">Sentence ${entry.key + 1}</span><span class="copy-pill">Teacher Copy</span>',
      )
      ..writeln('</div>')
      ..writeln(
        '<h3 class="sentence-role">${_escapeTeacherCopyHtml(sentence.role)}</h3>',
      );

    if (sentence.learnFirst.bullets.isNotEmpty) {
      buffer
        ..writeln('<div class="field-label">Learn First</div>')
        ..writeln('<ul class="bullet-list">');
      for (final bullet in sentence.learnFirst.bullets) {
        if (bullet.trim().isEmpty) {
          continue;
        }
        buffer.writeln('<li>${_escapeTeacherCopyHtml(bullet.trim())}</li>');
      }
      buffer.writeln('</ul>');
    }

    buffer
      ..writeln('<div class="field-label">Sentence Preview</div>')
      ..writeln(
        '<p class="sentence-preview">${_escapeTeacherCopyHtml(_managementSentencePreviewText(sentence))}</p>',
      );

    for (final blankEntry in blankParts.asMap().entries) {
      final blank = blankEntry.value;
      buffer
        ..writeln('<div class="blank-card">')
        ..writeln('<div class="blank-head">Blank ${blankEntry.key + 1}</div>');
      if (blank.hint.trim().isNotEmpty) {
        buffer.writeln(
          '<p class="blank-hint">${_escapeTeacherCopyHtml(blank.hint.trim())}</p>',
        );
      }
      buffer.writeln('<ul class="option-list">');
      for (final label in const ['A', 'B', 'C', 'D']) {
        final isCorrect = blank.correctOption == label;
        buffer.writeln(
          '<li class="option-row ${isCorrect ? 'correct-option' : ''}"><span class="option-badge">$label</span><span>${_escapeTeacherCopyHtml(blank.options[label] ?? '')}</span></li>',
        );
      }
      buffer
        ..writeln('</ul>')
        ..writeln(
          '<p class="answer-inline"><strong>Correct Answer:</strong> ${_escapeTeacherCopyHtml('${blank.correctOption}) ${blank.options[blank.correctOption] ?? ''}')}</p>',
        )
        ..writeln('</div>');
    }

    buffer.writeln('</article>');
  }

  buffer.writeln('</section>');
  return buffer.toString();
}

String _buildStudentCopyEssayHtml(MissionPayload mission) {
  final draft = mission.essayBuilderDraft;
  if (draft == null) {
    return '<section class="section-card"><h2>Essay Builder</h2><p class="section-kicker">Essay builder draft is missing for this mission.</p></section>';
  }

  final buffer = StringBuffer()
    ..writeln('<section class="section-card">')
    ..writeln('<h2>Essay Builder</h2>')
    ..writeln(
      '<p class="section-kicker">Student-ready essay builder worksheet without answer keys.</p>',
    )
    ..writeln('<div class="pill-row">')
    ..writeln(
      '<span class="soft-pill">Target Words: ${draft.targets.targetWordMin}-${draft.targets.targetWordMax}</span>',
    )
    ..writeln(
      '<span class="soft-pill">Target Sentences: ${draft.targets.targetSentenceCount}</span>',
    )
    ..writeln('</div>');

  for (final entry in draft.sentences.asMap().entries) {
    final sentence = entry.value;
    final blankParts = sentence.parts.where((part) => part.isBlank).toList();
    buffer
      ..writeln('<article class="question-card">')
      ..writeln('<div class="question-top">')
      ..writeln(
        '<span class="question-pill">Sentence ${entry.key + 1}</span><span class="copy-pill">Student Copy</span>',
      )
      ..writeln('</div>')
      ..writeln(
        '<h3 class="sentence-role">${_escapeTeacherCopyHtml(sentence.role)}</h3>',
      );

    if (sentence.learnFirst.bullets.isNotEmpty) {
      buffer
        ..writeln('<div class="field-label">Learn First</div>')
        ..writeln('<ul class="bullet-list">');
      for (final bullet in sentence.learnFirst.bullets) {
        if (bullet.trim().isEmpty) {
          continue;
        }
        buffer.writeln('<li>${_escapeTeacherCopyHtml(bullet.trim())}</li>');
      }
      buffer.writeln('</ul>');
    }

    buffer
      ..writeln('<div class="field-label">Sentence Preview</div>')
      ..writeln(
        '<p class="sentence-preview">${_escapeTeacherCopyHtml(_managementSentencePreviewText(sentence))}</p>',
      );

    for (final blankEntry in blankParts.asMap().entries) {
      final blank = blankEntry.value;
      buffer
        ..writeln('<div class="blank-card">')
        ..writeln('<div class="blank-head">Blank ${blankEntry.key + 1}</div>');
      if (blank.hint.trim().isNotEmpty) {
        buffer.writeln(
          '<p class="blank-hint">${_escapeTeacherCopyHtml(blank.hint.trim())}</p>',
        );
      }
      buffer.writeln('<ul class="option-list">');
      for (final label in const ['A', 'B', 'C', 'D']) {
        buffer.writeln(
          '<li class="option-row"><span class="option-badge">$label</span><span>${_escapeTeacherCopyHtml(blank.options[label] ?? '')}</span></li>',
        );
      }
      buffer
        ..writeln('</ul>')
        ..writeln('</div>');
    }

    buffer.writeln('</article>');
  }

  buffer.writeln('</section>');
  return buffer.toString();
}

String _buildTeacherCopyStyles() {
  return '''
    :root {
      color-scheme: light;
      --navy: #2d4578;
      --muted: #6e7fa8;
      --line: rgba(121, 147, 198, 0.18);
      --white: rgba(255, 255, 255, 0.92);
      --panel: linear-gradient(180deg, rgba(255,255,255,0.96), rgba(240,247,255,0.94));
      --chip: linear-gradient(135deg, #6f86ff, #62d8ea);
      --mint: #6fd1b4;
      --surface: #f5f9ff;
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      font-family: Arial, sans-serif;
      color: var(--navy);
      background:
        radial-gradient(circle at top left, rgba(191, 224, 255, 0.42), transparent 32%),
        radial-gradient(circle at right center, rgba(126, 221, 213, 0.24), transparent 22%),
        linear-gradient(180deg, #eef5ff 0%, #f8fbff 100%);
    }
    .page {
      max-width: 1120px;
      margin: 0 auto;
      padding: 40px 24px 56px;
    }
    .hero, .section-card {
      background: var(--panel);
      border: 1px solid var(--line);
      border-radius: 28px;
      padding: 28px;
      box-shadow: 0 24px 50px rgba(57, 88, 143, 0.08);
    }
    .hero { margin-bottom: 20px; }
    .copy-chip, .copy-pill, .question-pill, .soft-pill {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      padding: 8px 14px;
      border-radius: 999px;
      font-size: 13px;
      font-weight: 700;
    }
    .copy-chip, .copy-pill, .question-pill {
      color: white;
      background: var(--chip);
    }
    h1, h2, h3 { margin: 0; }
    h1 { margin-top: 14px; font-size: 42px; line-height: 1.08; }
    h2 { font-size: 30px; margin-bottom: 10px; }
    h3 { font-size: 22px; margin: 0 0 10px; }
    .hero-summary, .section-kicker, p, li { line-height: 1.6; }
    .hero-summary, .section-kicker, .blank-hint { color: var(--muted); }
    .meta-grid, .pill-row {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
      gap: 12px;
      margin-top: 18px;
    }
    .meta-card {
      background: var(--white);
      border: 1px solid var(--line);
      border-radius: 20px;
      padding: 16px;
    }
    .meta-card-label {
      font-size: 12px;
      font-weight: 700;
      letter-spacing: 0.12em;
      text-transform: uppercase;
      color: var(--muted);
      margin-bottom: 8px;
    }
    .meta-card-value {
      font-size: 18px;
      font-weight: 700;
      color: var(--navy);
      word-break: break-word;
    }
    .question-card, .blank-card {
      background: var(--white);
      border: 1px solid var(--line);
      border-radius: 22px;
      padding: 18px;
      margin-top: 16px;
    }
    .question-top {
      display: flex;
      gap: 10px;
      align-items: center;
      flex-wrap: wrap;
      margin-bottom: 12px;
    }
    .field-label, .blank-head {
      font-size: 12px;
      font-weight: 700;
      letter-spacing: 0.08em;
      text-transform: uppercase;
      color: var(--muted);
      margin: 14px 0 8px;
    }
    .option-list, .bullet-list {
      list-style: none;
      padding: 0;
      margin: 10px 0 0;
    }
    .bullet-list {
      list-style: disc;
      padding-left: 22px;
    }
    .option-row {
      display: flex;
      align-items: flex-start;
      gap: 12px;
      padding: 12px 14px;
      border-radius: 18px;
      background: #ffffff;
      border: 1px solid var(--line);
      margin-top: 10px;
    }
    .correct-option {
      background: rgba(111, 209, 180, 0.16);
      border-color: rgba(111, 209, 180, 0.46);
    }
    .option-badge {
      width: 28px;
      height: 28px;
      flex: 0 0 28px;
      border-radius: 999px;
      display: inline-flex;
      align-items: center;
      justify-content: center;
      color: white;
      background: var(--chip);
      font-weight: 700;
      font-size: 13px;
    }
    .answer-card {
      margin-top: 16px;
      padding: 16px;
      border-radius: 18px;
      background: #ffffff;
      border: 1px solid var(--line);
    }
    .answer-inline {
      margin: 0;
      font-weight: 600;
    }
    .soft-pill {
      color: var(--navy);
      background: #ffffff;
      border: 1px solid var(--line);
    }
    .sentence-preview {
      white-space: pre-wrap;
    }
  ''';
}

String _buildTeacherCopyMetaCard({
  required String label,
  required String value,
}) {
  return '''
    <div class="meta-card">
      <div class="meta-card-label">${_escapeTeacherCopyHtml(label)}</div>
      <div class="meta-card-value">${_escapeTeacherCopyHtml(value)}</div>
    </div>
  ''';
}

String _buildTeacherCopyRichTextHtml(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return '<p class="section-kicker">No saved text.</p>';
  }
  final paragraphs = trimmed
      .split(RegExp(r'\n\s*\n'))
      .map((paragraph) => paragraph.trim())
      .where((paragraph) => paragraph.isNotEmpty)
      .toList(growable: false);
  if (paragraphs.isEmpty) {
    return '<p class="section-kicker">No saved text.</p>';
  }
  return paragraphs
      .map(
        (paragraph) =>
            '<p>${_escapeTeacherCopyHtml(paragraph).replaceAll('\n', '<br />')}</p>',
      )
      .join();
}

String _escapeTeacherCopyHtml(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');
}

String _sanitizeTeacherCopyFileName(String value) {
  final collapsed = value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  return collapsed.isEmpty ? 'mission' : collapsed;
}

String _dateKeyForTeacherCopy(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

String _formatTeacherCopyDate(String? value, DateTime fallbackDate) {
  final raw = value?.trim() ?? '';
  if (raw.isEmpty) {
    return _dateKeyForTeacherCopy(fallbackDate);
  }
  return raw;
}

String _teacherCopyQuestionAnswerLine(MissionQuestion question) {
  const labels = ['A', 'B', 'C', 'D'];
  final index = question.correctIndex.clamp(0, 3);
  final label = labels[index];
  final answer = question.options.length > index ? question.options[index] : '';
  return '$label) $answer';
}

String _managementDraftFormatLabel(String value) {
  switch (value.trim().toUpperCase()) {
    case 'THEORY':
      return 'Theory';
    case 'ESSAY_BUILDER':
      return 'Essay';
    default:
      return 'Objective';
  }
}

String _managementSentencePreviewText(EssayBuilderSentence sentence) {
  return sentence.parts
      .map((part) => part.isBlank ? '____' : part.value)
      .join()
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

class _MiniPill extends StatelessWidget {
  const _MiniPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppPalette.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppPalette.sky.withValues(alpha: 0.68)),
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

ButtonStyle _managementDayPlanFilledActionStyle(BuildContext context) {
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

ButtonStyle _managementDayPlanOutlinedActionStyle(
  BuildContext context, {
  Color? backgroundColor,
  Color? borderColor,
}) {
  return OutlinedButton.styleFrom(
    minimumSize: const Size(0, 46),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    backgroundColor:
        backgroundColor ?? AppPalette.surface.withValues(alpha: 0.96),
    foregroundColor: AppPalette.navy,
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

class _RoundHeaderButton extends StatelessWidget {
  const _RoundHeaderButton({required this.icon, this.onTap});

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
