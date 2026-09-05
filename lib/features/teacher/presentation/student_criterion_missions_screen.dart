/**
 * WHAT:
 * StudentCriterionMissionsScreen groups one learner's tagged missions by Task
 * Focus and displays them in the qualification learning-pathway order.
 * WHY:
 * Teachers need to inspect P1/P2 work without treating a mission's Task Focus
 * as proof that the learner has achieved that criterion.
 * HOW:
 * Fetch the teacher-scoped pathway, group missions into Q5, Q8, Essay, Theory,
 * and Assessment A/B stages, and render learning progress separately from the
 * backend-owned certification evidence.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'package:flutter/material.dart';

import '../../../core/constants/app_palette.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/task_focus_codes.dart';
import '../../../core/utils/focus_mission_api.dart';
import '../../../shared/models/focus_mission_models.dart';
import '../../../shared/widgets/soft_panel.dart';

enum MissionPathwayStage { q5, q8, essay, theory, assessment }

class MissionPathwayEntry {
  const MissionPathwayEntry({
    required this.mission,
    required this.stage,
    required this.statusLabel,
    this.assessmentSequence = '',
  });

  final MissionPayload mission;
  final MissionPathwayStage stage;
  final String statusLabel;
  final String assessmentSequence;

  bool get isAssessment => stage == MissionPathwayStage.assessment;
  bool get isCompleted => mission.latestResultPackageId.trim().isNotEmpty;

  String get stageLabel {
    switch (stage) {
      case MissionPathwayStage.q5:
        return 'Q5';
      case MissionPathwayStage.q8:
        return 'Q8';
      case MissionPathwayStage.essay:
        return 'Essay';
      case MissionPathwayStage.theory:
        return 'Theory';
      case MissionPathwayStage.assessment:
        return assessmentSequence.isEmpty
            ? 'Assessment'
            : 'Assessment $assessmentSequence';
    }
  }
}

class MissionCriterionPathwayGroup {
  const MissionCriterionPathwayGroup({
    required this.taskCode,
    required this.entries,
    this.achievementEvidence,
  });

  final String taskCode;
  final List<MissionPathwayEntry> entries;
  final CertificationEvidenceRow? achievementEvidence;

  List<MissionPathwayEntry> get learningEntries =>
      entries.where((entry) => !entry.isAssessment).toList(growable: false);

  List<MissionPathwayEntry> get assessmentEntries =>
      entries.where((entry) => entry.isAssessment).toList(growable: false);

  int get completedLearningCount =>
      learningEntries.where((entry) => entry.isCompleted).length;

  String get achievementLabel {
    switch (achievementEvidence?.status) {
      case 'passed':
        return 'Passed';
      case 'pending_review':
        return 'Pending review';
      case 'not_passed':
        return 'Not passed';
      case 'not_started':
        return 'Not started';
      case null:
        return 'Not configured';
      default:
        return 'Not started';
    }
  }
}

List<MissionCriterionPathwayGroup> buildMissionCriterionPathwayGroups({
  required List<MissionPayload> missions,
  required List<SubjectCertificationSummary> certifications,
}) {
  final missionsByTaskCode = <String, List<MissionPayload>>{};

  for (final mission in missions) {
    final uniqueCodes = mission.taskCodes
        .map((code) => code.trim().toUpperCase())
        .where((code) => RegExp(r'^[PMD]\d+$').hasMatch(code))
        .toSet();
    for (final taskCode in uniqueCodes) {
      missionsByTaskCode.putIfAbsent(taskCode, () => []).add(mission);
    }
  }

  final taskCodes = missionsByTaskCode.keys.toList(growable: false)
    ..sort((left, right) {
      final leftIndex = kTaskFocusCodes.indexOf(left);
      final rightIndex = kTaskFocusCodes.indexOf(right);
      if (leftIndex >= 0 && rightIndex >= 0) {
        return leftIndex.compareTo(rightIndex);
      }
      if (leftIndex >= 0) {
        return -1;
      }
      if (rightIndex >= 0) {
        return 1;
      }
      return left.compareTo(right);
    });

  return taskCodes
      .map(
        (taskCode) => _buildMissionCriterionPathwayGroup(
          taskCode: taskCode,
          missions: missionsByTaskCode[taskCode] ?? const [],
          certifications: certifications,
        ),
      )
      .toList(growable: false);
}

MissionCriterionPathwayGroup _buildMissionCriterionPathwayGroup({
  required String taskCode,
  required List<MissionPayload> missions,
  required List<SubjectCertificationSummary> certifications,
}) {
  final sortedMissions = [...missions]
    ..sort((left, right) {
      final stageComparison = _stageForMission(
        left,
      ).index.compareTo(_stageForMission(right).index);
      if (stageComparison != 0) {
        return stageComparison;
      }
      final leftDate = left.availableOnDate ?? left.createdAt ?? '';
      final rightDate = right.availableOnDate ?? right.createdAt ?? '';
      final dateComparison = leftDate.compareTo(rightDate);
      return dateComparison != 0 ? dateComparison : left.id.compareTo(right.id);
    });

  final evidence = _evidenceForTaskCode(certifications, taskCode);
  final usedAssessmentSequences = <String>{};
  final entries = <MissionPathwayEntry>[];

  for (final mission in sortedMissions) {
    final stage = _stageForMission(mission);
    var assessmentSequence = '';
    if (stage == MissionPathwayStage.assessment) {
      final storedSequence =
          mission.assessmentSequenceByTaskCode[taskCode]?.toUpperCase() ?? '';
      if (storedSequence == 'A' || storedSequence == 'B') {
        assessmentSequence = storedSequence;
      } else if (!usedAssessmentSequences.contains('A')) {
        assessmentSequence = 'A';
      } else if (!usedAssessmentSequences.contains('B')) {
        assessmentSequence = 'B';
      }
      if (assessmentSequence.isNotEmpty) {
        usedAssessmentSequences.add(assessmentSequence);
      }
    }

    final isPendingReview =
        evidence?.isPendingReview == true &&
        evidence?.bestMissionId == mission.id;
    final isPassedAssessment =
        stage == MissionPathwayStage.assessment &&
        evidence?.isPassed == true &&
        evidence?.bestMissionId == mission.id;
    final statusLabel = mission.isDraft
        ? 'Draft'
        : isPendingReview
        ? 'Needs review'
        : isPassedAssessment
        ? 'Passed'
        : mission.latestResultPackageId.trim().isNotEmpty
        ? 'Completed'
        : 'Assigned';
    entries.add(
      MissionPathwayEntry(
        mission: mission,
        stage: stage,
        statusLabel: statusLabel,
        assessmentSequence: assessmentSequence,
      ),
    );
  }

  entries.sort((left, right) {
    final stageComparison = left.stage.index.compareTo(right.stage.index);
    if (stageComparison != 0) {
      return stageComparison;
    }
    if (left.isAssessment && right.isAssessment) {
      return left.assessmentSequence.compareTo(right.assessmentSequence);
    }
    return 0;
  });

  return MissionCriterionPathwayGroup(
    taskCode: taskCode,
    entries: entries,
    achievementEvidence: evidence,
  );
}

CertificationEvidenceRow? _evidenceForTaskCode(
  List<SubjectCertificationSummary> certifications,
  String taskCode,
) {
  for (final certification in certifications) {
    for (final evidence in certification.evidenceRows) {
      if (evidence.taskCode.trim().toUpperCase() == taskCode) {
        return evidence;
      }
    }
  }
  return null;
}

MissionPathwayStage _stageForMission(MissionPayload mission) {
  switch (mission.draftFormat.trim().toUpperCase()) {
    case 'ESSAY_BUILDER':
      return MissionPathwayStage.essay;
    case 'THEORY':
      return MissionPathwayStage.theory;
    default:
      if (mission.questionCount >= 10) {
        return MissionPathwayStage.assessment;
      }
      if (mission.questionCount <= 5) {
        return MissionPathwayStage.q5;
      }
      return MissionPathwayStage.q8;
  }
}

class StudentCriterionMissionsScreen extends StatefulWidget {
  const StudentCriterionMissionsScreen({
    super.key,
    required this.session,
    required this.student,
    required this.subjects,
    required this.api,
    this.initialSubject,
  });

  final AuthSession session;
  final StudentSummary student;
  final List<SubjectSummary> subjects;
  final SubjectSummary? initialSubject;
  final FocusMissionApi api;

  @override
  State<StudentCriterionMissionsScreen> createState() =>
      _StudentCriterionMissionsScreenState();
}

class _StudentCriterionMissionsScreenState
    extends State<StudentCriterionMissionsScreen> {
  late String _selectedSubjectId;
  String _selectedTaskCode = 'All';
  late Future<TeacherMissionPathwayData> _future;

  @override
  void initState() {
    super.initState();
    _selectedSubjectId = _resolveInitialSubjectId();
    _future = _loadPathway();
  }

  String _resolveInitialSubjectId() {
    final initialId = widget.initialSubject?.id.trim() ?? '';
    if (widget.subjects.any((subject) => subject.id == initialId)) {
      return initialId;
    }
    for (final subject in widget.subjects) {
      if (subject.name.trim().toLowerCase() == 'business') {
        return subject.id;
      }
    }
    return widget.subjects.isEmpty ? '' : widget.subjects.first.id;
  }

  Future<TeacherMissionPathwayData> _loadPathway() {
    return widget.api.fetchTeacherMissionPathway(
      token: widget.session.token,
      studentId: widget.student.id,
      subjectId: _selectedSubjectId,
    );
  }

  void _changeSubject(String? subjectId) {
    if (subjectId == null || subjectId == _selectedSubjectId) {
      return;
    }
    setState(() {
      _selectedSubjectId = subjectId;
      _selectedTaskCode = 'All';
      _future = _loadPathway();
    });
  }

  void _refresh() {
    setState(() => _future = _loadPathway());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.backgroundTop,
      appBar: AppBar(
        title: Text('${widget.student.name} · Task Focus work'),
        actions: [
          IconButton(
            tooltip: 'Refresh pathway',
            onPressed: _selectedSubjectId.isEmpty ? null : _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: widget.subjects.isEmpty
          ? const Center(child: Text('No assigned subjects are available.'))
          : FutureBuilder<TeacherMissionPathwayData>(
              future: _future,
              builder: (context, snapshot) {
                return ListView(
                  padding: const EdgeInsets.all(AppSpacing.screen),
                  children: [
                    _buildFilters(context),
                    const SizedBox(height: AppSpacing.item),
                    if (snapshot.connectionState == ConnectionState.waiting)
                      const Padding(
                        padding: EdgeInsets.all(48),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (snapshot.hasError)
                      _PathwayMessagePanel(
                        icon: Icons.error_outline_rounded,
                        message: snapshot.error.toString(),
                        actionLabel: 'Try again',
                        onAction: _refresh,
                      )
                    else
                      ..._buildPathwayPanels(
                        context,
                        snapshot.data ??
                            const TeacherMissionPathwayData(
                              missions: [],
                              certifications: [],
                            ),
                      ),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildFilters(BuildContext context) {
    return SoftPanel(
      colors: const [Color(0xFFF7FBFF), Color(0xFFE6F3FF)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Learning pathway',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            'Task Focus shows what each mission supports. Criterion achievement remains a separate, result-based decision.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppPalette.textMuted),
          ),
          const SizedBox(height: AppSpacing.item),
          DropdownButtonFormField<String>(
            key: const Key('mission_pathway_subject_filter'),
            initialValue: _selectedSubjectId,
            decoration: const InputDecoration(labelText: 'Subject'),
            items: widget.subjects
                .map(
                  (subject) => DropdownMenuItem<String>(
                    value: subject.id,
                    child: Text(subject.name),
                  ),
                )
                .toList(growable: false),
            onChanged: _changeSubject,
          ),
          const SizedBox(height: AppSpacing.item),
          Text('Criterion', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['All', ...kTaskFocusCodes]
                  .map(
                    (taskCode) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        key: Key('mission_pathway_filter_$taskCode'),
                        label: Text(taskCode),
                        selected: _selectedTaskCode == taskCode,
                        onSelected: (_) =>
                            setState(() => _selectedTaskCode = taskCode),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPathwayPanels(
    BuildContext context,
    TeacherMissionPathwayData data,
  ) {
    final groups = buildMissionCriterionPathwayGroups(
      missions: data.missions,
      certifications: data.certifications,
    );
    final visibleGroups = _selectedTaskCode == 'All'
        ? [...groups]
        : groups.where((group) => group.taskCode == _selectedTaskCode).toList();

    if (_selectedTaskCode != 'All' && visibleGroups.isEmpty) {
      visibleGroups.add(
        _buildMissionCriterionPathwayGroup(
          taskCode: _selectedTaskCode,
          missions: const [],
          certifications: data.certifications,
        ),
      );
    }

    if (visibleGroups.isEmpty) {
      return const [
        _PathwayMessagePanel(
          icon: Icons.route_rounded,
          message:
              'No Task Focus missions are in this workflow for the selected student and subject.',
        ),
      ];
    }

    return visibleGroups
        .map(
          (group) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.item),
            child: _CriterionPathwayPanel(
              group: group,
              onOpenMission: (mission) => Navigator.of(context).pop(mission),
            ),
          ),
        )
        .toList(growable: false);
  }
}

class _CriterionPathwayPanel extends StatelessWidget {
  const _CriterionPathwayPanel({
    required this.group,
    required this.onOpenMission,
  });

  final MissionCriterionPathwayGroup group;
  final ValueChanged<MissionPayload> onOpenMission;

  @override
  Widget build(BuildContext context) {
    final learningEntries = group.learningEntries;
    final assessmentBySequence = <String, MissionPathwayEntry>{
      for (final entry in group.assessmentEntries)
        if (entry.assessmentSequence.isNotEmpty)
          entry.assessmentSequence: entry,
    };

    return SoftPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppPalette.primaryBlue,
                child: Text(
                  group.taskCode,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.compact),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${group.taskCode} mission pathway',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${group.completedLearningCount}/${learningEntries.length} learning missions completed',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppPalette.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.item),
          Text(
            'Learning progress',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          if (learningEntries.isEmpty)
            const _EmptyPathwayStage(
              label: 'No tagged learning missions in this workflow.',
            )
          else
            ...learningEntries.map(
              (entry) => _MissionPathwayTile(
                entry: entry,
                onTap: () => onOpenMission(entry.mission),
              ),
            ),
          const SizedBox(height: AppSpacing.item),
          Text(
            'Assessment evidence',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          _AssessmentSlot(
            label: 'Assessment A',
            entry: assessmentBySequence['A'],
            onOpenMission: onOpenMission,
          ),
          const SizedBox(height: 8),
          _AssessmentSlot(
            label: 'Assessment B · Optional',
            entry: assessmentBySequence['B'],
            onOpenMission: onOpenMission,
          ),
          const SizedBox(height: AppSpacing.item),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.item),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F8F3),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: AppPalette.mint),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Criterion achievement',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 5),
                Text(
                  group.achievementLabel,
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: AppPalette.navy),
                ),
                const SizedBox(height: 4),
                Text(
                  group.achievementEvidence?.reason.trim().isNotEmpty == true
                      ? group.achievementEvidence!.reason
                      : 'Task Focus alone does not mark this criterion as achieved.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppPalette.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MissionPathwayTile extends StatelessWidget {
  const _MissionPathwayTile({required this.entry, required this.onTap});

  final MissionPathwayEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = (entry.mission.availableOnDate ?? '').trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.item),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F1FF),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    entry.stageLabel,
                    style: Theme.of(
                      context,
                    ).textTheme.labelLarge?.copyWith(color: AppPalette.navy),
                  ),
                ),
                const SizedBox(width: AppSpacing.compact),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.mission.title,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        date.isEmpty
                            ? entry.statusLabel
                            : '${entry.statusLabel} · $date',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
      ),
    );
  }
}

class _AssessmentSlot extends StatelessWidget {
  const _AssessmentSlot({
    required this.label,
    required this.entry,
    required this.onOpenMission,
  });

  final String label;
  final MissionPathwayEntry? entry;
  final ValueChanged<MissionPayload> onOpenMission;

  @override
  Widget build(BuildContext context) {
    final missionEntry = entry;
    if (missionEntry == null) {
      return _EmptyPathwayStage(label: '$label · Not created');
    }
    return _MissionPathwayTile(
      entry: missionEntry,
      onTap: () => onOpenMission(missionEntry.mission),
    );
  }
}

class _EmptyPathwayStage extends StatelessWidget {
  const _EmptyPathwayStage({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.item),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: AppPalette.textMuted),
      ),
    );
  }
}

class _PathwayMessagePanel extends StatelessWidget {
  const _PathwayMessagePanel({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return SoftPanel(
      child: Column(
        children: [
          Icon(icon, size: 36, color: AppPalette.primaryBlue),
          const SizedBox(height: AppSpacing.compact),
          Text(message, textAlign: TextAlign.center),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpacing.compact),
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
