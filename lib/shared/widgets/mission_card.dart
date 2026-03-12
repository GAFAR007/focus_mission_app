/**
 * WHAT:
 * MissionCard renders one mission summary card with its single primary action.
 * WHY:
 * Student mission entry points should stay visually obvious and keep only one
 * clear next step on screen.
 * HOW:
 * Compose a SoftPanel with mission copy, optional playful support text, and
 * the shared gradient button.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'package:flutter/material.dart';

import '../../core/constants/app_spacing.dart';
import 'gradient_button.dart';
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
      padding: const EdgeInsets.all(AppSpacing.section),
      colors: [
        Colors.white.withValues(alpha: 0.92),
        colors.last.withValues(alpha: 0.22),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((eyebrow ?? '').trim().isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                eyebrow!,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: AppSpacing.item),
          ],
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: colors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Icon(icon, color: Colors.white),
              ),
              const SizedBox(width: AppSpacing.item),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if ((toneMessage ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        toneMessage!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.black.withValues(alpha: 0.62),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (featurePills.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.item),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: featurePills
                  .map(
                    (pill) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.74),
                        borderRadius: BorderRadius.circular(999),
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
          const SizedBox(height: AppSpacing.item),
          GradientButton(
            label: actionLabel,
            colors: colors,
            onPressed: onPressed,
          ),
        ],
      ),
    );
  }
}
