/**
 * WHAT:
 * RoleSelectionScreen is the first screen that lets the user pick student,
 * teacher, or mentor login.
 * WHY:
 * The product has distinct role workspaces, so the app begins with one clear
 * branching decision before any authenticated flow starts.
 * HOW:
 * Render the branded landing layout and push the matching LoginScreen when a
 * role card is tapped.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'package:flutter/material.dart';

import '../../../core/constants/app_palette.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../shared/models/user_role.dart';
import '../../../shared/widgets/avatar_badge.dart';
import '../../../shared/widgets/focus_scaffold.dart';
import '../../../shared/widgets/role_card.dart';
import 'login_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FocusScaffold(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screen),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Row(
              children: [
                const AvatarBadge(
                  icon: Icons.track_changes_rounded,
                  colors: AppPalette.studentGradient,
                  size: 60,
                ),
                const SizedBox(width: AppSpacing.item),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Focus Mission',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Level up learning with colorful missions and calm momentum.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppPalette.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            Text(
              'Choose your path',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Every role gets a bright, simple workspace built for focus.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.section),
            RoleCard(
              role: UserRole.student,
              onTap: () => _openRole(context, UserRole.student),
            ),
            const SizedBox(height: AppSpacing.item),
            RoleCard(
              role: UserRole.teacher,
              onTap: () => _openRole(context, UserRole.teacher),
            ),
            const SizedBox(height: AppSpacing.item),
            RoleCard(
              role: UserRole.mentor,
              onTap: () => _openRole(context, UserRole.mentor),
            ),
          ],
        ),
      ),
    );
  }

  void _openRole(BuildContext context, UserRole role) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => LoginScreen(role: role)));
  }
}
