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
import '../../../core/utils/focus_mission_api.dart';
import '../../../shared/models/focus_mission_models.dart';
import '../../../shared/widgets/focus_scaffold.dart';
import '../../../shared/widgets/notification_panel.dart';
import '../../../shared/widgets/profile_avatar_button.dart';
import '../../../shared/widgets/profile_sheet.dart';
import '../../../shared/widgets/soft_panel.dart';
import '../../../shared/widgets/stat_chip.dart';
import '../../../shared/widgets/weekly_timetable_calendar.dart';

class MentorOverviewScreen extends StatefulWidget {
  const MentorOverviewScreen({super.key, required this.session});

  final AuthSession session;

  @override
  State<MentorOverviewScreen> createState() => _MentorOverviewScreenState();
}

class _MentorOverviewScreenState extends State<MentorOverviewScreen> {
  final FocusMissionApi _api = FocusMissionApi();

  late AuthSession _session;
  late Future<MentorWorkspaceData> _future;
  String _selectedStudentId = '';
  MentorWorkspaceData? _workspace;
  NotificationInboxData? _notificationInbox;
  String _difficulty = 'Easy';
  bool _isUpdatingDifficulty = false;
  List<TargetSummary>? _targets;
  bool _isUpdatingTargets = false;

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    _future = _loadWorkspace();
  }

  Future<MentorWorkspaceData> _loadWorkspace() async {
    final workspace = await _api.loadMentorWorkspace(
      mentorSession: _session,
      selectedStudentId: _selectedStudentId,
    );
    _selectedStudentId = workspace.selectedStudent.id;
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
      _future = _loadWorkspace();
    });
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
