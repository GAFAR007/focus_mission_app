/**
 * WHAT:
 * ProgressHeroCard renders the top progress summary card with avatar, streak,
 * XP progress, and optional celebration badges.
 * WHY:
 * Students need one high-signal summary area that shows momentum without
 * forcing them to scan multiple widgets.
 * HOW:
 * Compose a SoftPanel with the avatar, streak text, XP labels, optional badge
 * row, and an animated progress bar.
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
    this.titleBadge,
    this.highlightMessage,
    this.statBadges = const <String>[],
  });

  final String name;
  final String streakLabel;
  final int currentXp;
  final int goalXp;
  final IconData trailingIcon;
  final String? avatarUrl;
  final String? titleBadge;
  final String? highlightMessage;
  final List<String> statBadges;

  @override
  Widget build(BuildContext context) {
    final progress = goalXp == 0 ? 0.0 : (currentXp / goalXp).clamp(0.0, 1.0);

    return SoftPanel(
      colors: const [Color(0xFFEAF8FF), Color(0xFFFFFBF2)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((titleBadge ?? '').trim().isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                titleBadge!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppPalette.navy,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.item),
          ],
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
                    if ((highlightMessage ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        highlightMessage!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppPalette.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFFFFF), Color(0xFFE8F2FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(trailingIcon, color: AppPalette.primaryBlue),
              ),
            ],
          ),
          if (statBadges.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.item),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: statBadges
                  .map(
                    (badge) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.82),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        badge,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppPalette.navy,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
          const SizedBox(height: AppSpacing.item),
          Text(
            'XP: $currentXp / $goalXp',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: AppPalette.navy),
          ),
          const SizedBox(height: 10),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: progress),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
            builder: (context, animatedProgress, child) {
              return ClipRRect(
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
                          width: constraints.maxWidth * animatedProgress,
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
              );
            },
          ),
        ],
      ),
    );
  }
}
