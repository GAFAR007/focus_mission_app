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
                  _PlannedSessionPanel(plan: plan.morning),
                  const SizedBox(height: AppSpacing.item),
                  _PlannedSessionPanel(plan: plan.afternoon),
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
  const _PlannedSessionPanel({required this.plan});

  final ManagementPlannedSession plan;

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
                child: _PlannedMissionTile(mission: mission),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlannedMissionTile extends StatelessWidget {
  const _PlannedMissionTile({required this.mission});

  final MissionPayload mission;

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
              _MiniPill(label: _draftFormatLabel(mission.draftFormat)),
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
        ],
      ),
    );
  }

  String _missionTypeLabel(MissionPayload mission) {
    return mission.questionCount >= 10 ? 'Assessment' : 'Daily';
  }

  String _draftFormatLabel(String value) {
    switch (value.trim().toUpperCase()) {
      case 'THEORY':
        return 'Theory';
      case 'ESSAY_BUILDER':
        return 'Essay';
      default:
        return 'Objective';
    }
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
        color: Colors.white.withValues(alpha: 0.82),
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
