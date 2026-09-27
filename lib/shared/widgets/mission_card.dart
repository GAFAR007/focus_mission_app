/**
 * WHAT:
 * MissionCard renders one mission summary card with its single primary action.
 * WHY:
 * Student mission entry points should stay visually obvious and keep only one
 * clear next step on screen.
 * HOW:
 * Compose a compact solid SoftPanel with all mission copy, status information
 * and the existing action callback on a high-contrast primary button.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'package:flutter/material.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_palette.dart';
import 'soft_panel.dart';

class MissionCard extends StatelessWidget {
  const MissionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.icon,
    required this.colors,
    required this.onPressed,
    this.eyebrow,
    this.toneMessage,
    this.featurePills = const <String>[],
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onPressed;
  final String? eyebrow;
  final String? toneMessage;
  final List<String> featurePills;

  @override
  Widget build(BuildContext context) {
    return SoftPanel(
      solid: true,
      padding: const EdgeInsets.all(AppSpacing.item),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppPalette.navy,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    if ((eyebrow ?? '').trim().isNotEmpty)
                      Text(
                        eyebrow!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
          if ((toneMessage ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(toneMessage!, style: Theme.of(context).textTheme.bodySmall),
          ],
          if (featurePills.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: featurePills
                  .map(
                    (pill) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colors.first.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        pill,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppPalette.navy,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: onPressed,
            icon: const Icon(Icons.play_arrow_rounded, size: 20),
            label: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}
