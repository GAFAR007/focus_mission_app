/**
 * WHAT:
 * Shared task-focus and activity-type filters for authorised result history.
 * WHY:
 * Teacher and management results need matching, view-only filters that compose
 * with their existing subject/date controls and retain saved A/B identity.
 * HOW:
 * Derive codes and counts from the supplied result set, classify using stored
 * format/sequence metadata, and notify the owning screen of chip selections.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'package:flutter/material.dart';

import '../../core/constants/app_palette.dart';
import '../../core/constants/task_focus_codes.dart';
import '../models/focus_mission_models.dart';

enum ResultHistoryTypeFilter {
  all('All'),
  objective('Objective'),
  theory('Theory'),
  essay('Essay'),
  assessmentA('Assessment A'),
  assessmentB('Assessment B'),
  paper('Paper assessment'),
  unknown('Type unavailable');

  const ResultHistoryTypeFilter(this.label);
  final String label;
}

ResultHistoryTypeFilter resultHistoryType(ResultHistoryItem result) {
  if (result.isPaperAssessment) return ResultHistoryTypeFilter.paper;
  final format = (result.namingDraftFormat ?? result.draftFormat)
      .trim()
      .toUpperCase();
  if (format == 'THEORY') return ResultHistoryTypeFilter.theory;
  if (format == 'ESSAY_BUILDER') return ResultHistoryTypeFilter.essay;
  final sequences = result.assessmentSequenceByTaskCode.values
      .map((value) => value.trim().toUpperCase())
      .toSet();
  // WHY: Titles and question counts cannot establish assessment identity.
  if (sequences.contains('A')) return ResultHistoryTypeFilter.assessmentA;
  if (sequences.contains('B')) return ResultHistoryTypeFilter.assessmentB;
  return format == 'QUESTIONS'
      ? ResultHistoryTypeFilter.objective
      : ResultHistoryTypeFilter.unknown;
}

bool resultMatchesTaskCode(ResultHistoryItem result, String taskCode) =>
    taskCode == 'All' ||
    result.taskCodes.any(
      (code) => code.trim().toUpperCase() == taskCode.trim().toUpperCase(),
    );

List<ResultHistoryItem> filterResultHistory(
  List<ResultHistoryItem> results, {
  required String taskCode,
  required ResultHistoryTypeFilter type,
}) => results
    .where(
      (result) =>
          resultMatchesTaskCode(result, taskCode) &&
          (type == ResultHistoryTypeFilter.all ||
              resultHistoryType(result) == type),
    )
    .toList(growable: false);

class ResultHistoryFilterBar extends StatelessWidget {
  const ResultHistoryFilterBar({
    super.key,
    required this.results,
    required this.selectedTaskCode,
    required this.selectedType,
    required this.onTaskCodeSelected,
    required this.onTypeSelected,
  });

  final List<ResultHistoryItem> results;
  final String selectedTaskCode;
  final ResultHistoryTypeFilter selectedType;
  final ValueChanged<String> onTaskCodeSelected;
  final ValueChanged<ResultHistoryTypeFilter> onTypeSelected;

  @override
  Widget build(BuildContext context) {
    final codes = results
        .expand((result) => result.taskCodes)
        .map((code) => code.trim().toUpperCase())
        .where((code) => code.isNotEmpty)
        .toSet();
    final extraCodes = codes.difference(kTaskFocusCodes.toSet()).toList()
      ..sort();
    final taskCodes = [
      'All',
      ...kTaskFocusCodes.where(codes.contains),
      ...extraCodes,
    ];
    if (!taskCodes.contains(selectedTaskCode)) taskCodes.add(selectedTaskCode);
    final taskResults = results
        .where((result) => resultMatchesTaskCode(result, selectedTaskCode))
        .toList(growable: false);
    final types = ResultHistoryTypeFilter.values.where(
      (type) =>
          type.index <= ResultHistoryTypeFilter.assessmentB.index ||
          type == selectedType ||
          results.any((result) => resultHistoryType(result) == type),
    );

    Widget chip(
      String label,
      int count,
      bool selected,
      VoidCallback onTap,
      String key,
    ) => ChoiceChip(
      key: Key(key),
      label: Text('$label $count'),
      selected: selected,
      showCheckmark: false,
      // WHY: Empty combinations stay selectable so the teacher can see an
      // explicit empty state without silently clearing another filter.
      onSelected: (_) => onTap(),
      selectedColor: AppPalette.primaryBlue,
      labelStyle: TextStyle(color: selected ? Colors.white : AppPalette.navy),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Task focus', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 7),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: taskCodes
              .map(
                (code) => chip(
                  code,
                  results
                      .where((result) => resultMatchesTaskCode(result, code))
                      .length,
                  code == selectedTaskCode,
                  () => onTaskCodeSelected(code),
                  'result_task_filter_${code.toLowerCase()}',
                ),
              )
              .toList(growable: false),
        ),
        const SizedBox(height: 12),
        const Text(
          'Result type',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 7),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: types
              .map(
                (type) => chip(
                  type.label,
                  taskResults
                      .where(
                        (result) =>
                            type == ResultHistoryTypeFilter.all ||
                            resultHistoryType(result) == type,
                      )
                      .length,
                  type == selectedType,
                  () => onTypeSelected(type),
                  'result_type_filter_${type.name}',
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }
}
