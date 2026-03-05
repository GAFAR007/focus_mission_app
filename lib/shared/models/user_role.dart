/**
 * WHAT:
 * user_role defines the app roles and their shared UI metadata.
 * WHY:
 * Role selection and routing need one consistent source of truth for labels,
 * colors, and icons.
 * HOW:
 * Store the enum and expose extension getters for role-specific presentation.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'package:flutter/material.dart';

import '../../core/constants/app_palette.dart';

enum UserRole { student, teacher, mentor, management }

extension UserRoleX on UserRole {
  String get title {
    switch (this) {
      case UserRole.student:
        return 'Student Login';
      case UserRole.teacher:
        return 'Teacher Login';
      case UserRole.mentor:
        return 'Learning Mentor';
      case UserRole.management:
        return 'Management Login';
    }
  }

  String get subtitle {
    switch (this) {
      case UserRole.student:
        return 'Jump into today\'s missions and build momentum.';
      case UserRole.teacher:
        return 'Track sessions with fast classroom-friendly controls.';
      case UserRole.mentor:
        return 'Review progress and tune support with clarity.';
      case UserRole.management:
        return 'Oversee mission delivery, outcomes, and reporting.';
    }
  }

  IconData get icon {
    switch (this) {
      case UserRole.student:
        return Icons.rocket_launch_rounded;
      case UserRole.teacher:
        return Icons.auto_stories_rounded;
      case UserRole.mentor:
        return Icons.psychology_rounded;
      case UserRole.management:
        return Icons.manage_accounts_rounded;
    }
  }

  List<Color> get colors {
    switch (this) {
      case UserRole.student:
        return AppPalette.studentGradient;
      case UserRole.teacher:
        return AppPalette.teacherGradient;
      case UserRole.mentor:
        return AppPalette.mentorGradient;
      case UserRole.management:
        return const [Color(0xFF9CC5FF), Color(0xFFB7E3FF)];
    }
  }
}
