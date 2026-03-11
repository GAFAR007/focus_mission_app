/**
 * WHAT:
 * weekly_timetable_calendar renders the teacher and mentor planner views for
 * weekly and monthly timetable browsing.
 * WHY:
 * Lesson ownership, future mission drafting, and rest-day visibility all rely
 * on one timetable component that can represent the schedule clearly.
 * HOW:
 * Build reusable date panels, week and month layouts, and slot cards from the
 * shared timetable models.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/app_palette.dart';
import '../../core/constants/app_spacing.dart';
import '../models/focus_mission_models.dart';
import 'soft_panel.dart';

class CurrentDatePanel extends StatelessWidget {
  const CurrentDatePanel({
    super.key,
    this.title = 'Today',
    this.subtitle,
    this.date,
  });

  final String title;
  final String? subtitle;
  final DateTime? date;

  @override
  Widget build(BuildContext context) {
    final resolvedDate = date ?? DateTime.now();

    return SoftPanel(
      colors: const [Color(0xF0FFFFFF), Color(0xD7EDF9FF)],
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppPalette.primaryBlue, AppPalette.aqua],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: const Icon(
              Icons.calendar_month_rounded,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: AppSpacing.item),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppPalette.textMuted),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatLongDate(resolvedDate),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppPalette.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              _formatShortDate(resolvedDate),
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: AppPalette.navy),
            ),
          ),
        ],
      ),
    );
  }
}

class WeeklyTimetableCalendar extends StatefulWidget {
  const WeeklyTimetableCalendar({
    super.key,
    required this.entries,
    this.title = 'Timetable Planner',
    this.subtitle = 'Switch between a full week and the current month.',
    this.date,
    this.onDateChanged,
    this.onDateTap,
  });

  final List<TodaySchedule> entries;
  final String title;
  final String subtitle;
  final DateTime? date;
  final ValueChanged<DateTime>? onDateChanged;
  final ValueChanged<DateTime>? onDateTap;

  @override
  State<WeeklyTimetableCalendar> createState() =>
      _WeeklyTimetableCalendarState();
}

class _WeeklyTimetableCalendarState extends State<WeeklyTimetableCalendar> {
  late DateTime _focusedDate;
  _PlannerMode _mode = _PlannerMode.month;

  @override
  void initState() {
    super.initState();
    _focusedDate = _normalizeDate(widget.date ?? DateTime.now());
  }

  @override
  void didUpdateWidget(covariant WeeklyTimetableCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.date != null && widget.date != oldWidget.date) {
      _focusedDate = _normalizeDate(widget.date!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final entriesByDay = <String, TodaySchedule>{
      for (final entry in widget.entries) entry.day: entry,
    };

    return SoftPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PlannerHeader(title: widget.title, subtitle: widget.subtitle),
          const SizedBox(height: AppSpacing.section),
          _PlannerModeSwitch(
            mode: _mode,
            onChanged: (mode) => setState(() => _mode = mode),
          ),
          const SizedBox(height: AppSpacing.item),
          _PlannerToolbar(
            mode: _mode,
            focusedDate: _focusedDate,
            onPrevious: _moveBackward,
            onNext: _moveForward,
            onToday: () => _setFocusedDate(_normalizeDate(DateTime.now())),
          ),
          const SizedBox(height: AppSpacing.item),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _InfoPill(
                icon: Icons.event_note_rounded,
                label: 'Monday to Sunday view',
              ),
              const _InfoPill(
                icon: Icons.weekend_rounded,
                label: 'Weekends: No subject',
              ),
              _InfoPill(
                icon: Icons.calendar_view_month_rounded,
                label: _mode == _PlannerMode.month
                    ? 'Whole month planner'
                    : 'Live week planner',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.section),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: _mode == _PlannerMode.week
                ? _WeekPlanner(
                    key: ValueKey<String>(
                      'week-${_focusedDate.toIso8601String()}',
                    ),
                    focusedDate: _focusedDate,
                    entriesByDay: entriesByDay,
                    onSelectDate: (date) =>
                        _setFocusedDate(date, triggerTap: true),
                  )
                : _MonthPlanner(
                    key: ValueKey<String>(
                      'month-${_focusedDate.toIso8601String()}',
                    ),
                    focusedDate: _focusedDate,
                    entriesByDay: entriesByDay,
                    onSelectDate: (date) =>
                        _setFocusedDate(date, triggerTap: true),
                  ),
          ),
        ],
      ),
    );
  }

  void _moveBackward() {
    _setFocusedDate(
      _mode == _PlannerMode.week
          ? _focusedDate.subtract(const Duration(days: 7))
          : DateTime(_focusedDate.year, _focusedDate.month - 1, 1),
    );
  }

  void _moveForward() {
    _setFocusedDate(
      _mode == _PlannerMode.week
          ? _focusedDate.add(const Duration(days: 7))
          : DateTime(_focusedDate.year, _focusedDate.month + 1, 1),
    );
  }

  void _setFocusedDate(DateTime date, {bool triggerTap = false}) {
    final normalized = _normalizeDate(date);
    setState(() => _focusedDate = normalized);
    widget.onDateChanged?.call(normalized);
    if (triggerTap) {
      // WHY: The date editor should open only when a planner tile is tapped,
      // not when toolbar navigation changes the focused date.
      widget.onDateTap?.call(normalized);
    }
  }
}

class _PlannerHeader extends StatelessWidget {
  const _PlannerHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: AppPalette.teacherGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.edit_calendar_rounded, color: Colors.white),
        ),
        const SizedBox(width: AppSpacing.item),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppPalette.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlannerModeSwitch extends StatelessWidget {
  const _PlannerModeSwitch({required this.mode, required this.onChanged});

  final _PlannerMode mode;
  final ValueChanged<_PlannerMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ModeSegment(
              label: 'Week',
              selected: mode == _PlannerMode.week,
              onTap: () => onChanged(_PlannerMode.week),
            ),
          ),
          Expanded(
            child: _ModeSegment(
              label: 'Month',
              selected: mode == _PlannerMode.month,
              onTap: () => onChanged(_PlannerMode.month),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeSegment extends StatelessWidget {
  const _ModeSegment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = selected
        ? const [AppPalette.aqua, AppPalette.sky]
        : const [Colors.transparent, Colors.transparent];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Center(
            child: Text(
              label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: selected ? AppPalette.navy : AppPalette.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlannerToolbar extends StatelessWidget {
  const _PlannerToolbar({
    required this.mode,
    required this.focusedDate,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
  });

  final _PlannerMode mode;
  final DateTime focusedDate;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    final heading = mode == _PlannerMode.week
        ? _formatWeekRange(focusedDate)
        : _formatMonthYear(focusedDate);
    final subtitle = mode == _PlannerMode.week
        ? 'Full timetable from Monday to Sunday.'
        : 'Whole month view with weekend rest days.';

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 760;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (narrow)
              _PlannerNavigation(
                onPrevious: onPrevious,
                onToday: onToday,
                onNext: onNext,
              ),
            if (narrow) const SizedBox(height: AppSpacing.item),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        heading,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppPalette.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!narrow) ...[
                  const SizedBox(width: AppSpacing.item),
                  _PlannerNavigation(
                    onPrevious: onPrevious,
                    onToday: onToday,
                    onNext: onNext,
                  ),
                ],
              ],
            ),
          ],
        );
      },
    );
  }
}

class _PlannerNavigation extends StatelessWidget {
  const _PlannerNavigation({
    required this.onPrevious,
    required this.onToday,
    required this.onNext,
  });

  final VoidCallback onPrevious;
  final VoidCallback onToday;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.76)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _NavigationButton(
            icon: Icons.chevron_left_rounded,
            onTap: onPrevious,
          ),
          const SizedBox(width: 4),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onToday,
              borderRadius: BorderRadius.circular(999),
              child: Ink(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppPalette.aqua.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Today',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: AppPalette.navy),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          _NavigationButton(icon: Icons.chevron_right_rounded, onTap: onNext),
        ],
      ),
    );
  }
}

class _NavigationButton extends StatelessWidget {
  const _NavigationButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Ink(
        width: 42,
        height: 42,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(999)),
        child: Icon(icon, color: AppPalette.textMuted),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.70),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AppPalette.textMuted),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppPalette.navy),
          ),
        ],
      ),
    );
  }
}

class _WeekPlanner extends StatelessWidget {
  const _WeekPlanner({
    super.key,
    required this.focusedDate,
    required this.entriesByDay,
    required this.onSelectDate,
  });

  final DateTime focusedDate;
  final Map<String, TodaySchedule> entriesByDay;
  final ValueChanged<DateTime> onSelectDate;

  @override
  Widget build(BuildContext context) {
    final datesByDay = _weekDates(focusedDate);

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1500
            ? 7
            : constraints.maxWidth >= 1120
            ? 4
            : constraints.maxWidth >= 720
            ? 2
            : 1;
        const spacing = 12.0;
        final cardWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: _plannerWeekdays
              .map(
                (day) => SizedBox(
                  width: cardWidth,
                  child: _WeekDayCard(
                    date: datesByDay[day]!,
                    day: day,
                    entry: entriesByDay[day],
                    isToday: _isSameDate(datesByDay[day]!, DateTime.now()),
                    isSelected: _isSameDate(datesByDay[day]!, focusedDate),
                    onTap: () => onSelectDate(datesByDay[day]!),
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _WeekDayCard extends StatelessWidget {
  const _WeekDayCard({
    required this.date,
    required this.day,
    required this.entry,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
  });

  final DateTime date;
  final String day;
  final TodaySchedule? entry;
  final bool isToday;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final weekend = _isWeekend(date);
    final colors = isToday
        ? [
            AppPalette.primaryBlue.withValues(alpha: 0.16),
            AppPalette.aqua.withValues(alpha: 0.16),
          ]
        : weekend
        ? [
            AppPalette.sun.withValues(alpha: 0.12),
            Colors.white.withValues(alpha: 0.74),
          ]
        : [
            Colors.white.withValues(alpha: 0.88),
            Colors.white.withValues(alpha: 0.74),
          ];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Ink(
          padding: const EdgeInsets.all(AppSpacing.item),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF205F59)
                  : isToday
                  ? AppPalette.primaryBlue.withValues(alpha: 0.30)
                  : Colors.white.withValues(alpha: 0.76),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      day,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (isSelected)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        isToday ? 'Today' : 'Selected',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: const Color(0xFF205F59)),
                      ),
                    )
                  else if (isToday)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Today',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: AppPalette.primaryBlue),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _formatDayCardDate(date),
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppPalette.textMuted),
              ),
              const SizedBox(height: AppSpacing.item),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.80),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  weekend
                      ? 'Weekend reset'
                      : entry == null || entry!.room.isEmpty
                      ? 'Room pending'
                      : entry!.room,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppPalette.navy),
                ),
              ),
              const SizedBox(height: AppSpacing.item),
              if (weekend || entry == null)
                Text(
                  weekend ? 'No subject planned.' : 'No sessions assigned yet.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppPalette.textMuted),
                )
              else ...[
                _SessionTile(
                  label: 'Morning',
                  icon: Icons.wb_sunny_rounded,
                  colors: AppPalette.studentGradient,
                  subject: entry!.morningMission.name,
                  teacher: entry!.morningTeacher?.name,
                ),
                const SizedBox(height: 10),
                _SessionTile(
                  label: 'Afternoon',
                  icon: Icons.nights_stay_rounded,
                  colors: const [AppPalette.primaryBlue, AppPalette.sun],
                  subject: entry!.afternoonMission.name,
                  teacher: entry!.afternoonTeacher?.name,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthPlanner extends StatelessWidget {
  const _MonthPlanner({
    super.key,
    required this.focusedDate,
    required this.entriesByDay,
    required this.onSelectDate,
  });

  final DateTime focusedDate;
  final Map<String, TodaySchedule> entriesByDay;
  final ValueChanged<DateTime> onSelectDate;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final calendarWidth = math.max(constraints.maxWidth, 760.0);
        final cellWidth = (calendarWidth - 60) / 7;
        final desiredHeight = calendarWidth > 1240
            ? 144.0
            : calendarWidth > 980
            ? 128.0
            : 104.0;
        final aspectRatio = cellWidth / desiredHeight;
        final days = _monthGridDates(focusedDate);

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: calendarWidth,
            child: Column(
              children: [
                Row(
                  children: _plannerWeekdays
                      .map(
                        (day) => Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Center(
                              child: Text(
                                _weekdayShortLabel(day),
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(color: AppPalette.textMuted),
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: days.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: aspectRatio,
                  ),
                  itemBuilder: (context, index) {
                    final date = days[index];
                    final inCurrentMonth = date.month == focusedDate.month;
                    final weekend = _isWeekend(date);
                    final entry = inCurrentMonth && !weekend
                        ? entriesByDay[_weekdayName(date.weekday)]
                        : null;

                    return _MonthDayCard(
                      date: date,
                      entry: entry,
                      inCurrentMonth: inCurrentMonth,
                      isToday: _isSameDate(date, DateTime.now()),
                      isSelected: _isSameDate(date, focusedDate),
                      onTap: () => onSelectDate(date),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MonthDayCard extends StatelessWidget {
  const _MonthDayCard({
    required this.date,
    required this.entry,
    required this.inCurrentMonth,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
  });

  final DateTime date;
  final TodaySchedule? entry;
  final bool inCurrentMonth;
  final bool isToday;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final weekend = _isWeekend(date);
    final baseColors = !inCurrentMonth
        ? [
            Colors.white.withValues(alpha: 0.36),
            Colors.white.withValues(alpha: 0.20),
          ]
        : isToday
        ? [
            AppPalette.primaryBlue.withValues(alpha: 0.12),
            AppPalette.aqua.withValues(alpha: 0.12),
          ]
        : weekend
        ? [
            AppPalette.sun.withValues(alpha: 0.12),
            Colors.white.withValues(alpha: 0.78),
          ]
        : [
            Colors.white.withValues(alpha: 0.88),
            Colors.white.withValues(alpha: 0.74),
          ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.maxHeight < 126 || constraints.maxWidth < 112;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            child: Ink(
              padding: EdgeInsets.all(compact ? 8 : 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: baseColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF205F59)
                      : isToday
                      ? const Color(0xFF205F59)
                      : Colors.white.withValues(alpha: 0.76),
                  width: isSelected || isToday ? 2 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${date.day}',
                        style:
                            (compact
                                    ? Theme.of(context).textTheme.titleSmall
                                    : Theme.of(context).textTheme.titleMedium)
                                ?.copyWith(
                                  color: inCurrentMonth
                                      ? AppPalette.navy
                                      : AppPalette.textMuted.withValues(
                                          alpha: 0.60,
                                        ),
                                ),
                      ),
                      const Spacer(),
                      if (isSelected)
                        Icon(
                          Icons.event_available_rounded,
                          size: compact ? 14 : 16,
                          color: const Color(0xFF205F59),
                        )
                      else if (isToday)
                        Icon(
                          Icons.event_available_rounded,
                          size: compact ? 14 : 16,
                          color: const Color(0xFF205F59),
                        ),
                    ],
                  ),
                  SizedBox(height: compact ? 6 : 8),
                  if (!inCurrentMonth)
                    const SizedBox.shrink()
                  else if (weekend)
                    _MonthBadge(
                      label: compact ? 'Rest day' : 'No subject',
                      background: AppPalette.sun.withValues(alpha: 0.16),
                      textColor: AppPalette.navy,
                    )
                  else if (entry == null)
                    _MonthBadge(
                      label: 'To schedule',
                      background: Colors.white.withValues(alpha: 0.68),
                      textColor: AppPalette.textMuted,
                    )
                  else ...[
                    _MonthLine(
                      icon: Icons.wb_sunny_rounded,
                      subject: entry!.morningMission.name,
                      color: AppPalette.mint,
                      compact: compact,
                    ),
                    SizedBox(height: compact ? 4 : 6),
                    _MonthLine(
                      icon: Icons.nights_stay_rounded,
                      subject: entry!.afternoonMission.name,
                      color: AppPalette.primaryBlue,
                      compact: compact,
                    ),
                    if (!compact) ...[
                      const Spacer(),
                      _MonthBadge(
                        label: entry!.room,
                        background: Colors.white.withValues(alpha: 0.74),
                        textColor: AppPalette.navy,
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({
    required this.label,
    required this.icon,
    required this.colors,
    required this.subject,
    this.teacher,
  });

  final String label;
  final IconData icon;
  final List<Color> colors;
  final String subject;
  final String? teacher;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppPalette.textMuted),
              ),
              const SizedBox(height: 3),
              Text(
                subject,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 3),
              Text(
                teacher == null || teacher!.isEmpty
                    ? 'Teacher to update'
                    : teacher!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppPalette.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MonthLine extends StatelessWidget {
  const _MonthLine({
    required this.icon,
    required this.subject,
    required this.color,
    this.compact = false,
  });

  final IconData icon;
  final String subject;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: compact ? 12 : 14, color: color),
        SizedBox(width: compact ? 3 : 4),
        Expanded(
          child: Text(
            subject,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                (compact
                        ? Theme.of(context).textTheme.labelSmall
                        : Theme.of(context).textTheme.bodySmall)
                    ?.copyWith(color: AppPalette.navy),
          ),
        ),
      ],
    );
  }
}

class _MonthBadge extends StatelessWidget {
  const _MonthBadge({
    required this.label,
    required this.background,
    required this.textColor,
  });

  final String label;
  final Color background;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: textColor),
      ),
    );
  }
}

enum _PlannerMode { week, month }

const List<String> _plannerWeekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const List<String> _weekdayShort = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];
const List<String> _weekdayLong = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
const List<String> _monthLong = [
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
const List<String> _monthShort = [
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

Map<String, DateTime> _weekDates(DateTime date) {
  final monday = date.subtract(Duration(days: date.weekday - DateTime.monday));

  return {
    for (var index = 0; index < _plannerWeekdays.length; index++)
      _plannerWeekdays[index]: monday.add(Duration(days: index)),
  };
}

List<DateTime> _monthGridDates(DateTime date) {
  final firstOfMonth = DateTime(date.year, date.month, 1);
  final lastOfMonth = DateTime(date.year, date.month + 1, 0);
  final start = firstOfMonth.subtract(
    Duration(days: firstOfMonth.weekday - DateTime.monday),
  );
  final end = lastOfMonth.add(
    Duration(days: DateTime.sunday - lastOfMonth.weekday),
  );
  final totalDays = end.difference(start).inDays + 1;

  return List<DateTime>.generate(
    totalDays,
    (index) => start.add(Duration(days: index)),
    growable: false,
  );
}

DateTime _normalizeDate(DateTime date) =>
    DateTime(date.year, date.month, date.day);

bool _isSameDate(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

bool _isWeekend(DateTime date) {
  return date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
}

String _weekdayName(int weekday) => _weekdayLong[weekday - 1];

String _weekdayShortLabel(String day) {
  return _weekdayShort[_plannerWeekdays.indexOf(day)];
}

String _formatLongDate(DateTime date) {
  return '${_weekdayLong[date.weekday - 1]}, ${_monthLong[date.month - 1]} ${date.day}, ${date.year}';
}

String _formatShortDate(DateTime date) {
  return '${_weekdayShort[date.weekday - 1]} ${date.day}';
}

String _formatDayCardDate(DateTime date) {
  return '${_monthShort[date.month - 1]} ${date.day}, ${date.year}';
}

String _formatMonthYear(DateTime date) {
  return '${_monthLong[date.month - 1]} ${date.year}';
}

String _formatWeekRange(DateTime date) {
  final week = _weekDates(date).values.toList(growable: false);
  final start = week.first;
  final end = week.last;

  if (start.month == end.month) {
    return '${_monthLong[start.month - 1]} ${start.day} - ${end.day}, ${end.year}';
  }

  if (start.year == end.year) {
    return '${_monthShort[start.month - 1]} ${start.day} - ${_monthShort[end.month - 1]} ${end.day}, ${end.year}';
  }

  return '${_monthShort[start.month - 1]} ${start.day}, ${start.year} - ${_monthShort[end.month - 1]} ${end.day}, ${end.year}';
}
