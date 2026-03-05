/**
 * WHAT:
 * StatChip renders a compact colored stat card for summary metrics.
 * WHY:
 * Small progress signals like XP and focus score should stay readable without
 * introducing dense dashboard chrome.
 * HOW:
 * Wrap the text pair in a SoftPanel and tint it with the supplied gradient
 * colors.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'package:flutter/material.dart';

import '../../core/constants/app_spacing.dart';
import 'soft_panel.dart';

class StatChip extends StatelessWidget {
  const StatChip({
    super.key,
    required this.value,
    required this.label,
    required this.colors,
  });

  final String value;
  final String label;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 110,
      child: SoftPanel(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.compact,
          vertical: AppSpacing.item,
        ),
        colors: [
          colors.first.withValues(alpha: 0.24),
          colors.last.withValues(alpha: 0.16),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontSize: 24),
            ),
            const SizedBox(height: 4),
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
