/**
 * WHAT: Shows the 6K journey, milestone strip, and uncapped total XP.
 * WHY: Students need a lasting goal alongside their separate daily target.
 * HOW: Reuse theme typography and spacing, with labelled state icons and a
 * wrapped milestone strip shared by the hero and profile.
 * WHO: Shared student presentation; awarding remains backend-owned.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'package:flutter/material.dart';
import '../../core/constants/app_palette.dart';
import '../models/xp_journey.dart';

class XpJourneyPanel extends StatelessWidget {
  const XpJourneyPanel({
    super.key,
    required this.totalXp,
    this.onDark = false,
    this.achievements = const [],
    this.onLeaderboard,
  });
  final int totalXp;
  final List<XpAchievement> achievements;
  final VoidCallback? onLeaderboard;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final journey = XpJourney(totalXp, achievements: achievements);
    final foreground = onDark ? Colors.white : AppPalette.navy;
    final muted = onDark ? const Color(0xFFD8E5F5) : AppPalette.textMuted;
    final achievedColor = onDark
        ? const Color(0xFF77CFB2)
        : const Color(0xFF227A68);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          journey.journeyComplete ? '6K Journey Complete' : 'XP Journey',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: foreground),
        ),
        const SizedBox(height: 4),
        Text(
          journey.journeyComplete
              ? 'Total XP: ${XpJourney.formatXp(totalXp)}'
              : '${XpJourney.formatXp(totalXp)} / 6,000 XP',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(color: foreground),
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: journey.progress,
          minHeight: 8,
          semanticsLabel: '6K journey progress',
          semanticsValue: '${XpJourney.formatXp(totalXp)} XP',
          borderRadius: BorderRadius.circular(20),
          backgroundColor: foreground.withValues(alpha: 0.15),
          valueColor: AlwaysStoppedAnimation(achievedColor),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            for (final threshold in XpJourney.milestones)
              Semantics(
                label:
                    '${XpJourney.formatXp(threshold)} XP · ${journey.isAchieved(threshold)
                        ? 'Achieved'
                        : journey.nextMilestone == threshold
                        ? 'Next milestone'
                        : 'Future milestone'}',
                child: ExcludeSemantics(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        journey.isAchieved(threshold)
                            ? threshold >= XpJourney.goalXp
                                  ? Icons.emoji_events_rounded
                                  : Icons.check_circle_outline
                            : journey.nextMilestone == threshold
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        size: 16,
                        color: journey.isAchieved(threshold)
                            ? threshold >= XpJourney.goalXp
                                  ? AppPalette.sun
                                  : achievedColor
                            : journey.nextMilestone == threshold
                            ? onDark
                                  ? AppPalette.sky
                                  : AppPalette.primaryBlue
                            : muted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        XpJourney.shortLabel(threshold),
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: foreground),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        if (onLeaderboard != null) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onLeaderboard,
            style: onDark
                ? OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFF7992B5)),
                  )
                : null,
            icon: const Icon(Icons.leaderboard_outlined, size: 18),
            label: const Text('Leaderboard'),
          ),
        ],
        const SizedBox(height: 10),
        Text(
          journey.nextMilestone == null
              ? '10K achieved · Keep growing your total XP.'
              : 'Next milestone: ${XpJourney.formatXp(journey.nextMilestone!)} XP · ${XpJourney.formatXp(journey.remainingXp)} XP to go',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted),
        ),
      ],
    );
  }
}
