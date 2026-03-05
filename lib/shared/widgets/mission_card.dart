/**
 * WHAT:
 * MissionCard renders one mission summary card with its single primary action.
 * WHY:
 * Student mission entry points should stay visually obvious and keep only one
 * clear next step on screen.
 * HOW:
 * Compose a SoftPanel with mission copy, icon, and the shared gradient button.
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
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SoftPanel(
      padding: const EdgeInsets.all(AppSpacing.section),
      colors: [
        Colors.white.withValues(alpha: 0.88),
        colors.last.withValues(alpha: 0.18),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                  ],
                ),
              ),
            ],
          ),
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
