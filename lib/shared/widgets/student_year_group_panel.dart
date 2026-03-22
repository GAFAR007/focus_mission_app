/**
 * WHAT:
 * student_year_group_panel renders the reusable year-group editor used by
 * teacher and management workspaces.
 * WHY:
 * Student year affects profile context and bulk Test/Exam targeting, so both
 * roles need one consistent control for updating it.
 * HOW:
 * Show a short explainer, a year-group dropdown, and a save action inside a
 * standard soft panel.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'package:flutter/material.dart';

import '../../core/constants/app_palette.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/student_year_groups.dart';
import 'soft_panel.dart';

class StudentYearGroupPanel extends StatelessWidget {
  const StudentYearGroupPanel({
    super.key,
    required this.title,
    required this.subtitle,
    required this.selectedYearGroup,
    required this.onChanged,
    required this.onSave,
    required this.isSaving,
    this.saveLabel = 'Save year group',
  });

  final String title;
  final String subtitle;
  final String selectedYearGroup;
  final ValueChanged<String?> onChanged;
  final VoidCallback onSave;
  final bool isSaving;
  final String saveLabel;

  @override
  Widget build(BuildContext context) {
    return SoftPanel(
      colors: const [Color(0xFFF8FCFF), Color(0xFFEAF5FF)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppPalette.textMuted),
          ),
          const SizedBox(height: AppSpacing.item),
          DropdownButtonFormField<String>(
            key: ValueKey<String>(selectedYearGroup.trim()),
            initialValue: selectedYearGroup.trim(),
            decoration: const InputDecoration(labelText: 'Year group'),
            items: <DropdownMenuItem<String>>[
              const DropdownMenuItem<String>(
                value: '',
                child: Text('Not set yet'),
              ),
              ...kStudentYearGroupOptions.map(
                (yearGroup) => DropdownMenuItem<String>(
                  value: yearGroup,
                  child: Text(yearGroup),
                ),
              ),
            ],
            onChanged: onChanged,
          ),
          const SizedBox(height: AppSpacing.item),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: isSaving ? null : onSave,
              icon: Icon(
                isSaving ? Icons.hourglass_top_rounded : Icons.save_rounded,
              ),
              label: Text(isSaving ? 'Saving year group...' : saveLabel),
            ),
          ),
        ],
      ),
    );
  }
}
