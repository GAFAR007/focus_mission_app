/**
 * WHAT:
 * ProgressHeroCard renders the top progress summary card with avatar, streak,
 * and XP progress.
 * WHY:
 * Students need one high-signal summary area that shows momentum without
 * forcing them to scan multiple widgets.
 * HOW:
 * Compose a SoftPanel with the avatar, streak text, XP labels, and progress
 * bar.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'package:flutter/material.dart';

import '../../core/constants/app_palette.dart';
import '../../core/constants/app_spacing.dart';
import 'avatar_badge.dart';
import 'soft_panel.dart';

class ProgressHeroCard extends StatelessWidget {
  const ProgressHeroCard({
    super.key,
    required this.name,
    required this.streakLabel,
    required this.currentXp,
    required this.goalXp,
    required this.trailingIcon,
    this.avatarUrl,
  });

  final String name;
  final String streakLabel;
  final int currentXp;
  final int goalXp;
  final IconData trailingIcon;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final progress = goalXp == 0 ? 0.0 : (currentXp / goalXp).clamp(0.0, 1.0);

    return SoftPanel(
      colors: const [Color(0xFFF3F9FF), Color(0xFFDFF0FF)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AvatarBadge(
                imageUrl: avatarUrl,
                colors: AppPalette.heroGradient,
                size: 64,
              ),
              const SizedBox(width: AppSpacing.item),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.local_fire_department_rounded,
                          size: 16,
                          color: AppPalette.orange,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          streakLabel,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppPalette.navy),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(trailingIcon, color: AppPalette.primaryBlue),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.item),
          Text(
            'XP: $currentXp / $goalXp',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: AppPalette.navy),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    Container(
                      height: 14,
                      width: double.infinity,
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                    Container(
                      height: 14,
                      width: constraints.maxWidth * progress,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: AppPalette.progressGradient,
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
