/**
 * WHAT:
 * ProfileAvatarButton renders the tappable profile shortcut in top bars.
 * WHY:
 * The profile action replaces the old settings affordance and gives the user a
 * clear way to review identity and avatar choices.
 * HOW:
 * Draw a rounded button shell and place the user's avatar badge inside it.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'package:flutter/material.dart';

import '../../core/constants/app_palette.dart';
import '../models/focus_mission_models.dart';
import 'avatar_badge.dart';

class ProfileAvatarButton extends StatelessWidget {
  const ProfileAvatarButton({super.key, required this.user, this.onTap});

  final AppUser user;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.74),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Center(
          child: AvatarBadge(
            imageUrl: user.avatar,
            colors: const [AppPalette.sky, AppPalette.aqua],
            size: 34,
          ),
        ),
      ),
    );
  }
}
