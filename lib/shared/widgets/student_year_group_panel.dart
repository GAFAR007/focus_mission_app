/**
 * WHAT:
 * student_year_group_panel renders the reusable year-group editor used by
 * teacher and management workspaces.
 * WHY:
 * Student year affects profile context and bulk Test/Exam targeting, so both
 * roles need one consistent control for updating it.
 * HOW:
 * Show a short explainer, a year-group dropdown, and a save action inside a
 * standard soft panel, or inline when embedded in a compact context card.
 * Optional layout and button-style overrides fit management summary cards.
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
    this.compact = false,
    this.expandCompactField = false,
    this.saveButtonStyle,
    this.secondaryActionLabel,
    this.secondaryActionIcon,
    this.onSecondaryAction,
  });

  final String title;
  final String subtitle;
  final String selectedYearGroup;
  final ValueChanged<String?> onChanged;
  final VoidCallback onSave;
  final bool isSaving;
  final String saveLabel;
  final bool compact;
  final bool expandCompactField;
  final ButtonStyle? saveButtonStyle;
  final String? secondaryActionLabel;
  final IconData? secondaryActionIcon;
  final VoidCallback? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    final yearGroupField = DropdownButtonFormField<String>(
      key: ValueKey<String>(selectedYearGroup.trim()),
      initialValue: selectedYearGroup.trim(),
      decoration: _yearGroupFieldDecoration(compact: compact),
      isExpanded: true,
      items: <DropdownMenuItem<String>>[
        const DropdownMenuItem<String>(value: '', child: Text('Not set yet')),
        ...kStudentYearGroupOptions.map(
          (yearGroup) => DropdownMenuItem<String>(
            value: yearGroup,
            child: Text(yearGroup),
          ),
        ),
      ],
      onChanged: onChanged,
    );
    final defaultSaveButtonStyle = FilledButton.styleFrom(
      minimumSize: Size(0, compact ? 38 : 46),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 18,
        vertical: compact ? 8 : 14,
      ),
      backgroundColor: compact ? AppPalette.primaryBlue : AppPalette.navy,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(compact ? AppSpacing.chip : 18),
      ),
    );
    final saveButton = FilledButton.icon(
      style:
          saveButtonStyle?.merge(defaultSaveButtonStyle) ??
          defaultSaveButtonStyle,
      onPressed: isSaving ? null : onSave,
      icon: Icon(isSaving ? Icons.hourglass_top_rounded : Icons.save_rounded),
      label: Text(
        isSaving ? (compact ? 'Saving...' : 'Saving year group...') : saveLabel,
      ),
    );

    // WHY: Reuse the same explicit-save control in compact context cards;
    // presentation options never introduce autosave or change API ownership.
    if (compact) {
      if (!expandCompactField) {
        return Wrap(
          spacing: AppSpacing.compact,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(width: 200, child: yearGroupField),
            saveButton,
          ],
        );
      }
      return LayoutBuilder(
        builder: (context, constraints) {
          // WHY: Management can fill a dashboard card while narrow layouts
          // keep the same selector and explicit Save action on separate lines.
          if (constraints.maxWidth >= 360) {
            return Row(
              children: [
                Expanded(child: yearGroupField),
                const SizedBox(width: AppSpacing.compact),
                saveButton,
              ],
            );
          }
          return Wrap(
            spacing: AppSpacing.compact,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(width: constraints.maxWidth, child: yearGroupField),
              saveButton,
            ],
          );
        },
      );
    }

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
          yearGroupField,
          const SizedBox(height: AppSpacing.item),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                saveButton,
                if ((secondaryActionLabel ?? '').trim().isNotEmpty &&
                    onSecondaryAction != null)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 46),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      foregroundColor: AppPalette.navy,
                      backgroundColor: AppPalette.surface.withValues(
                        alpha: 0.98,
                      ),
                      side: BorderSide(
                        color: AppPalette.sky.withValues(alpha: 0.82),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    onPressed: onSecondaryAction,
                    icon: Icon(
                      secondaryActionIcon ?? Icons.flag_outlined,
                      size: 20,
                    ),
                    label: Text(secondaryActionLabel!.trim()),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

InputDecoration _yearGroupFieldDecoration({bool compact = false}) {
  final baseBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(
      compact ? AppSpacing.chip : AppSpacing.radiusMd,
    ),
    borderSide: BorderSide(color: AppPalette.sky.withValues(alpha: 0.72)),
  );
  return InputDecoration(
    labelText: 'Year group',
    isDense: compact,
    filled: true,
    fillColor: AppPalette.surface.withValues(alpha: 0.96),
    contentPadding: EdgeInsets.symmetric(
      horizontal: compact ? 12 : 18,
      vertical: compact ? 12 : 18,
    ),
    border: baseBorder,
    enabledBorder: baseBorder,
    focusedBorder: baseBorder.copyWith(
      borderSide: const BorderSide(color: AppPalette.primaryBlue, width: 1.6),
    ),
  );
}
