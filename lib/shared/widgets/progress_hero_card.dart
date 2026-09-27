/**
 * WHAT:
 * ProgressHeroCard renders the top progress summary card with avatar, streak,
 * XP progress, and optional celebration badges.
 * WHY:
 * Students need one high-signal summary area that shows momentum without
 * forcing them to scan multiple widgets.
 * HOW:
 * Compose a compact solid navy SoftPanel with the avatar, streak text, XP
 * labels, optional badge row, and the existing animated progress calculation.
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
      solid: true,
      padding: const EdgeInsets.all(AppSpacing.item),
      colors: const [AppPalette.navy],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AvatarBadge(
                imageUrl: avatarUrl,
                colors: const [Color(0xFF52719B), Color(0xFF52719B)],
                size: 48,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      streakLabel,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFFD8E5F5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(trailingIcon, color: AppPalette.sun, size: 28),
            ],
          ),
          if ((titleBadge ?? '').trim().isNotEmpty ||
              (highlightMessage ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 6,
              children: [
                if ((titleBadge ?? '').trim().isNotEmpty)
                  Text(
                    titleBadge!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppPalette.sun,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                if ((highlightMessage ?? '').trim().isNotEmpty)
                  Text(
                    highlightMessage!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFFD8E5F5),
                    ),
                  ),
              ],
            ),
          ],
          if (statBadges.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: statBadges
                  .map(
                    (badge) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        badge,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'XP: $currentXp / $goalXp',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 8),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: progress),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
            builder: (context, animatedProgress, child) =>
                LinearProgressIndicator(
                  value: animatedProgress,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(20),
                  backgroundColor: Colors.white.withValues(alpha: 0.16),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF77CFB2),
                  ),
                ),
          ),
        ],
      ),
    );
  }
}
