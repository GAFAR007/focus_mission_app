/**
 * WHAT:
 * CriterionFilterBar renders the canonical qualification task-focus filters
 * and exposes a read-only mission filtering helper.
 * WHY:
 * Daily and Assessment draft lists must use identical P/M/D code semantics
 * without guessing a criterion from mission titles.
 * HOW:
 * Render All plus the shared canonical task-code list in a horizontally
 * scrollable chip row, and match normalized codes only against taskCodes.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'package:flutter/material.dart';

import '../../core/constants/app_palette.dart';
import '../../core/constants/task_focus_codes.dart';
import '../models/focus_mission_models.dart';

const String kAllCriterionFilter = 'All';

List<MissionPayload> filterMissionsByTaskCode(
  List<MissionPayload> missions,
  String selectedCriterion,
) {
  final normalizedCriterion = selectedCriterion.trim().toUpperCase();
  if (normalizedCriterion.isEmpty ||
      normalizedCriterion == kAllCriterionFilter.toUpperCase()) {
    // WHY: Return a separate list so filtering never mutates the workspace
    // draft collection or changes A/B metadata held on its mission objects.
    return List<MissionPayload>.of(missions, growable: false);
  }

  return missions
      .where(
        (mission) => mission.taskCodes.any(
          (taskCode) => taskCode.trim().toUpperCase() == normalizedCriterion,
        ),
      )
      .toList(growable: false);
}

class CriterionFilterBar extends StatelessWidget {
  const CriterionFilterBar({
    super.key,
    required this.selectedCriterion,
    required this.onCriterionSelected,
  });

  final String selectedCriterion;
  final ValueChanged<String> onCriterionSelected;

  @override
  Widget build(BuildContext context) {
    final filters = <String>[kAllCriterionFilter, ...kTaskFocusCodes];

    return Semantics(
      label: 'Filter drafts by task focus',
      child: SingleChildScrollView(
        key: const Key('criterion-filter-scroll'),
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters
              .map((criterion) {
                final selected = criterion == selectedCriterion;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    key: Key('criterion-filter-$criterion'),
                    label: Text(criterion),
                    selected: selected,
                    showCheckmark: false,
                    onSelected: (_) => onCriterionSelected(criterion),
                    selectedColor: AppPalette.primaryBlue,
                    backgroundColor: Colors.white.withValues(alpha: 0.84),
                    side: BorderSide(
                      color: selected
                          ? AppPalette.primaryBlue
                          : AppPalette.primaryBlue.withValues(alpha: 0.18),
                    ),
                    labelStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: selected ? Colors.white : AppPalette.navy,
                      fontWeight: FontWeight.w700,
                    ),
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                  ),
                );
              })
              .toList(growable: false),
        ),
      ),
    );
  }
}
