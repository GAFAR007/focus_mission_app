/**
 * WHAT:
 * StudentYearGroupFilter renders the shared All, Year 9, Year 10, and Year 11
 * filter used by teacher student-selection flows.
 * WHY:
 * Teachers need a short, consistent way to narrow authorised rosters without
 * changing which student is currently selected.
 * HOW:
 * Filter immutable StudentSummary lists by their saved yearGroup and expose a
 * large rounded ChoiceChip row for switching the visible group.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'package:flutter/material.dart';

import '../../core/constants/app_palette.dart';
import '../../core/constants/student_year_groups.dart';
import '../models/focus_mission_models.dart';

const String kAllStudentYearGroups = 'All';
final List<String> kStudentPickerYearGroups = <String>[
  kAllStudentYearGroups,
  ...kStudentYearGroupOptions.sublist(8, 11),
];

List<StudentSummary> filterStudentsByYearGroup(
  List<StudentSummary> students,
  String selectedYearGroup,
) {
  if (selectedYearGroup == kAllStudentYearGroups) {
    return List<StudentSummary>.unmodifiable(students);
  }

  return List<StudentSummary>.unmodifiable(
    students.where((student) => student.yearGroup.trim() == selectedYearGroup),
  );
}

class StudentYearGroupFilter extends StatelessWidget {
  const StudentYearGroupFilter({
    super.key,
    required this.selectedYearGroup,
    required this.onChanged,
  });

  final String selectedYearGroup;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Filter students by year group',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: kStudentPickerYearGroups
            .map(
              (yearGroup) => ChoiceChip(
                label: Text(yearGroup),
                selected: selectedYearGroup == yearGroup,
                onSelected: (_) => onChanged(yearGroup),
                showCheckmark: false,
                selectedColor: AppPalette.primaryBlue.withValues(alpha: 0.16),
                side: BorderSide(
                  color: selectedYearGroup == yearGroup
                      ? AppPalette.primaryBlue
                      : AppPalette.sky,
                ),
                labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppPalette.navy,
                  fontWeight: FontWeight.w700,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}
